import XCTest
#if canImport(CleanBuildCore)
@testable import CleanBuildCore
#else
@testable import CleanBuild
#endif

final class RecordingFileSystem: CleanupFileSystem, @unchecked Sendable {
    enum Failure: Error { case denied }
    private let lock = NSLock()
    var trashed: [String] = []
    var failingPaths = Set<String>()
    func itemExists(at url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
    func isSymbolicLink(at url: URL) throws -> Bool { try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true }
    func fingerprint(at url: URL) throws -> FileFingerprint { try PathSafety.fingerprint(url) }
    func allocatedBytes(at url: URL) throws -> Int64 { try DiskMeasurement.allocatedBytes(at: url) }
    func trashItem(at url: URL) throws {
        if failingPaths.contains(url.path) { throw Failure.denied }
        lock.lock(); trashed.append(url.path); lock.unlock()
        try FileManager.default.removeItem(at: url)
    }
}

struct ActiveChecker: ActiveUseChecking { let active: Bool; func isActive(_ target: ScanTarget) async -> Bool { active } }
struct SlowChecker: ActiveUseChecking { func isActive(_ target: ScanTarget) async -> Bool { try? await Task.sleep(for: .milliseconds(120)); return false } }

final class CoreTests: XCTestCase {
    private var temporary: [URL] = []
    override func tearDown() { for url in temporary { try? FileManager.default.removeItem(at: url) }; temporary = []; super.tearDown() }

    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CleanBuildTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); temporary.append(url); return url
    }
    @discardableResult private func directory(_ name: String, in root: URL, bytes: Int = 32) throws -> URL {
        let url = root.appendingPathComponent(name); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url.appendingPathComponent("data.bin")); return url
    }
    private func target(_ url: URL, root: URL, source: ScanSource = .derivedData, classification: SafetyClassification = .safe) throws -> ScanTarget {
        ScanTarget(source: source, name: url.lastPathComponent, path: url.path, bytes: try DiskMeasurement.allocatedBytes(at: url), modifiedAt: nil, classification: classification, reason: "fixture", consequence: "fixture", authorizedRootPath: PathSafety.canonical(root).path, fingerprint: try PathSafety.fingerprint(url))
    }
    private func executor(root: URL, fs: RecordingFileSystem = RecordingFileSystem(), active: any ActiveUseChecking = ActiveChecker(active: false), exclusions: [URL] = [], journal: URL? = nil) -> CleanupExecutor {
        CleanupExecutor(fileSystem: fs, policy: CleanupPolicy(allowedRoots: [.derivedData: [root]], exclusions: exclusions), activeUseChecker: active, journalURL: journal)
    }

    func testProtectedRootsAndTraversal() {
        XCTAssertTrue(PathSafety.isProtected(URL(fileURLWithPath: "/")))
        XCTAssertTrue(PathSafety.isProtected(FileManager.default.homeDirectoryForCurrentUser))
        XCTAssertEqual(URL(fileURLWithPath: "/tmp/root/../escape").standardizedFileURL.path, "/tmp/escape")
    }

    func testAllocatedSizeMeasuresFiles() throws {
        let root = try fixture(); let item = try directory("item", in: root, bytes: 8192)
        XCTAssertGreaterThanOrEqual(try DiskMeasurement.allocatedBytes(at: item), 8192)
    }

    func testKnownDirectoryAdapterDiscoversFingerprintAndRoot() async throws {
        let root = try fixture(); _ = try directory("artifact", in: root); try Data("marker".utf8).write(to: root.appendingPathComponent("CACHEDIR.TAG"))
        let adapter = KnownDirectoryAdapter(source: .derivedData, directories: [root], classification: .safe, reason: "generated", consequence: "rebuild")
        let items = try await adapter.discoverTargets(workspaces: [])
        XCTAssertEqual(items.count, 1); XCTAssertEqual(items[0].name, "artifact"); XCTAssertNotNil(items[0].fingerprint); XCTAssertEqual(items[0].authorizedRootPath, root.path)
    }

    func testFlutterRequiresMarkerAndExactBuildChild() async throws {
        let root = try fixture(); _ = try directory("build", in: root)
        let before = try await WorkspaceBuildAdapter().discoverTargets(workspaces: [root])
        XCTAssertTrue(before.isEmpty)
        try Data().write(to: root.appendingPathComponent("pubspec.yaml"))
        let after = try await WorkspaceBuildAdapter().discoverTargets(workspaces: [root])
        XCTAssertEqual(after.count, 1)
    }

    func testNestedTargetsAreDeduplicated() throws {
        let root = try fixture(); let a = try directory("a", in: root); let b = try directory("b", in: a)
        XCTAssertEqual(ScanCoordinator.deduplicate([try target(b, root: a), try target(a, root: root)]).count, 1)
    }

    func testDryRunDoesNotMutate() async throws {
        let root = try fixture(); let item = try directory("item", in: root); let fs = RecordingFileSystem()
        let job = await executor(root: root, fs: fs).execute(CleanupPlan(targets: [try target(item, root: root)], dryRun: true))
        XCTAssertEqual(job.outcomes[0].status, .simulated); XCTAssertTrue(fs.trashed.isEmpty); XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
    }

    func testFixtureTrashExecution() async throws {
        let root = try fixture(); let item = try directory("item", in: root); let fs = RecordingFileSystem()
        let job = await executor(root: root, fs: fs).execute(CleanupPlan(targets: [try target(item, root: root)], dryRun: false))
        XCTAssertEqual(job.outcomes[0].status, .succeeded); XCTAssertEqual(fs.trashed, [item.path]); XCTAssertFalse(FileManager.default.fileExists(atPath: item.path))
    }

    func testSymlinkTargetFailsClosed() async throws {
        let root = try fixture(); let real = try directory("real", in: root); let link = root.appendingPathComponent("link"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        var forged = try target(real, root: root)
        forged = ScanTarget(source: forged.source, name: "link", path: link.path, bytes: forged.bytes, modifiedAt: nil, classification: .safe, reason: "fixture", consequence: "fixture", authorizedRootPath: root.path, fingerprint: forged.fingerprint)
        let job = await executor(root: root).execute(CleanupPlan(targets: [forged], dryRun: true))
        XCTAssertEqual(job.outcomes[0].status, .failed); XCTAssertTrue(FileManager.default.fileExists(atPath: real.path))
    }

    func testForgedPathOutsideAllowlistFails() async throws {
        let root = try fixture(); let outside = try fixture(); let item = try directory("source", in: outside)
        let job = await executor(root: root).execute(CleanupPlan(targets: [try target(item, root: outside)], dryRun: true))
        XCTAssertEqual(job.outcomes[0].status, .failed); XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
    }

    func testReplacedPathFingerprintFails() async throws {
        let root = try fixture(); let item = try directory("item", in: root); let scanned = try target(item, root: root)
        try FileManager.default.removeItem(at: item); _ = try directory("item", in: root, bytes: 32)
        let job = await executor(root: root).execute(CleanupPlan(targets: [scanned], dryRun: false))
        XCTAssertEqual(job.outcomes[0].status, .failed); XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
    }

    func testSizeMutationFails() async throws {
        let root = try fixture(); let item = try directory("item", in: root); let scanned = try target(item, root: root)
        try Data(repeating: 1, count: 100_000).write(to: item.appendingPathComponent("later.bin"))
        let job = await executor(root: root).execute(CleanupPlan(targets: [scanned], dryRun: false))
        XCTAssertEqual(job.outcomes[0].status, .failed)
    }

    func testExternallyDeletedTargetFails() async throws {
        let root = try fixture(); let item = try directory("item", in: root); let scanned = try target(item, root: root); try FileManager.default.removeItem(at: item)
        let job = await executor(root: root).execute(CleanupPlan(targets: [scanned], dryRun: false))
        XCTAssertEqual(job.outcomes[0].status, .failed)
    }

    func testExcludedTargetFails() async throws {
        let root = try fixture(); let item = try directory("item", in: root)
        let job = await executor(root: root, exclusions: [item]).execute(CleanupPlan(targets: [try target(item, root: root)], dryRun: true))
        XCTAssertEqual(job.outcomes[0].status, .failed)
    }

    func testProtectedAndReportOnlyTargetsFail() async throws {
        let root = try fixture(); let item = try directory("item", in: root)
        let protected = try target(item, root: root, classification: .protected)
        let protectedJob = await executor(root: root).execute(CleanupPlan(targets: [protected], dryRun: true))
        XCTAssertEqual(protectedJob.outcomes[0].status, .failed)
        let docker = try target(item, root: root, source: .docker)
        let dockerJob = await executor(root: root).execute(CleanupPlan(targets: [docker], dryRun: true))
        XCTAssertEqual(dockerJob.outcomes[0].status, .failed)
    }

    func testActiveUseFails() async throws {
        let root = try fixture(); let item = try directory("item", in: root)
        let job = await executor(root: root, active: ActiveChecker(active: true)).execute(CleanupPlan(targets: [try target(item, root: root)], dryRun: false))
        XCTAssertEqual(job.outcomes[0].status, .failed); XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
    }

    func testTrashFailureBecomesPartialFailure() async throws {
        let root = try fixture(); let good = try directory("good", in: root); let bad = try directory("bad", in: root); let fs = RecordingFileSystem(); fs.failingPaths.insert(bad.path)
        let job = await executor(root: root, fs: fs).execute(CleanupPlan(targets: [try target(good, root: root), try target(bad, root: root)], dryRun: false))
        XCTAssertEqual(job.outcomes.map(\.status), [.succeeded, .failed]); XCTAssertTrue(FileManager.default.fileExists(atPath: bad.path))
    }

    func testDuplicatePlanRejectedBeforeMutation() async throws {
        let root = try fixture(); let item = try directory("item", in: root); let scanned = try target(item, root: root); let fs = RecordingFileSystem()
        let job = await executor(root: root, fs: fs).execute(CleanupPlan(targets: [scanned, scanned], dryRun: false))
        XCTAssertTrue(job.outcomes.allSatisfy { $0.status == .failed }); XCTAssertTrue(fs.trashed.isEmpty)
    }

    func testDuplicateFilesystemIdentityRejected() async throws {
        let root = try fixture(); let first = try directory("first", in: root); let second = try directory("second", in: root)
        let firstTarget = try target(first, root: root); let ordinarySecond = try target(second, root: root)
        let duplicateIdentity = ScanTarget(source: ordinarySecond.source, name: ordinarySecond.name, path: ordinarySecond.path, bytes: ordinarySecond.bytes, modifiedAt: ordinarySecond.modifiedAt, classification: ordinarySecond.classification, reason: ordinarySecond.reason, consequence: ordinarySecond.consequence, authorizedRootPath: ordinarySecond.authorizedRootPath, fingerprint: firstTarget.fingerprint)
        let fs = RecordingFileSystem(); let job = await executor(root: root, fs: fs).execute(CleanupPlan(targets: [firstTarget, duplicateIdentity], dryRun: false))
        XCTAssertTrue(job.outcomes.allSatisfy { $0.status == .failed }); XCTAssertTrue(fs.trashed.isEmpty)
    }

    func testFlutterCleanupRequiresIndependentlyApprovedWorkspace() async throws {
        let approved = try fixture(); let unapproved = try fixture(); let build = try directory("build", in: unapproved)
        let scanned = try target(build, root: unapproved, source: .flutter)
        let policy = CleanupPolicy.production(exclusions: [], flutterRoots: [approved])
        let job = await CleanupExecutor(fileSystem: RecordingFileSystem(), policy: policy, activeUseChecker: ActiveChecker(active: false)).execute(CleanupPlan(targets: [scanned], dryRun: true))
        XCTAssertEqual(job.outcomes[0].status, .failed)
    }

    func testConcurrentExecutionIsRejected() async throws {
        let root = try fixture(); let one = try directory("one", in: root); let two = try directory("two", in: root)
        let executor = CleanupExecutor(fileSystem: RecordingFileSystem(), policy: CleanupPolicy(allowedRoots: [.derivedData: [root]]), activeUseChecker: SlowChecker())
        let firstTarget = try target(one, root: root); let secondTarget = try target(two, root: root)
        async let first = executor.execute(CleanupPlan(targets: [firstTarget], dryRun: true))
        try await Task.sleep(for: .milliseconds(20))
        let second = await executor.execute(CleanupPlan(targets: [secondTarget], dryRun: true))
        _ = await first
        XCTAssertEqual(second.outcomes[0].status, .failed)
    }

    func testCancellationSkipsWithoutMutation() async throws {
        let root = try fixture(); let item = try directory("item", in: root); let fs = RecordingFileSystem(); let executor = self.executor(root: root, fs: fs); let scanned = try target(item, root: root)
        let task = Task { await executor.execute(CleanupPlan(targets: [scanned], dryRun: false)) }; task.cancel(); let job = await task.value
        XCTAssertEqual(job.outcomes[0].status, .skipped); XCTAssertTrue(fs.trashed.isEmpty)
    }

    func testJournalExistsDuringOperationAndClearsAfter() async throws {
        let root = try fixture(); let item = try directory("item", in: root); let journal = root.appendingPathComponent("journal/pending.json")
        let executor = self.executor(root: root, active: SlowChecker(), journal: journal); let scanned = try target(item, root: root)
        let task = Task { await executor.execute(CleanupPlan(targets: [scanned], dryRun: true)) }
        try await Task.sleep(for: .milliseconds(30)); XCTAssertTrue(FileManager.default.fileExists(atPath: journal.path)); _ = await task.value
        XCTAssertFalse(FileManager.default.fileExists(atPath: journal.path))
    }

    func testHistoryRoundTripAndRetention() async throws {
        let root = try fixture(); let url = root.appendingPathComponent("history.json"); let store = HistoryStore(url: url)
        for _ in 0..<55 { try await store.save(scan: ScanSession()) }
        let firstSnapshot = await store.snapshot(); XCTAssertEqual(firstSnapshot.scans.count, 50)
        let reloaded = HistoryStore(url: url); let secondSnapshot = await reloaded.snapshot(); XCTAssertEqual(secondSnapshot.scans.count, 50)
    }

    func testCorruptHistoryIsReported() async throws {
        let root = try fixture(); let url = root.appendingPathComponent("history.json"); try Data("bad".utf8).write(to: url)
        let store = HistoryStore(url: url); let error = await store.loadError; XCTAssertNotNil(error)
    }

    func testSettingsRoundTrip() async throws {
        let root = try fixture(); let store = SettingsStore(url: root.appendingPathComponent("settings.json")); let value = CleanBuildPreferences(workspacePaths: ["/tmp/work"], exclusionPaths: ["/tmp/excluded"], dryRun: false)
        try await store.save(value); let loaded = try await store.load(); XCTAssertEqual(loaded, value)
    }

    func testByteFormatting() { XCTAssertFalse(ByteFormatting.string(1024).isEmpty) }

    func testPerformanceLargeTree100kFiles() throws {
        guard ProcessInfo.processInfo.environment["CLEANBUILD_RUN_PERFORMANCE"] == "1" else { throw XCTSkip("Set CLEANBUILD_RUN_PERFORMANCE=1 for the 100k-file benchmark") }
        let root = try fixture(); let tree = root.appendingPathComponent("large"); try FileManager.default.createDirectory(at: tree, withIntermediateDirectories: true)
        let createStart = Date()
        for index in 0..<100_000 { FileManager.default.createFile(atPath: tree.appendingPathComponent("f-\(index)").path, contents: Data([0x41])) }
        let createdIn = Date().timeIntervalSince(createStart)
        let scanStart = Date(); let bytes = try DiskMeasurement.allocatedBytes(at: tree); let scannedIn = Date().timeIntervalSince(scanStart)
        print("PERFORMANCE 100000 files create_seconds=\(createdIn) scan_seconds=\(scannedIn) measured_bytes=\(bytes)")
        XCTAssertGreaterThan(bytes, 0); XCTAssertLessThan(scannedIn, 60)
    }
}
