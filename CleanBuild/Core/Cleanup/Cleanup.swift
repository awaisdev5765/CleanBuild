import Foundation

public enum PlanValidationError: LocalizedError, Equatable {
    case protectedTarget, unsupportedSource, unsafePath, symlink, changed, duplicateTarget, excluded, activeUse, concurrentCleanup
    public var errorDescription: String? {
        switch self {
        case .protectedTarget: "Protected targets cannot be cleaned."
        case .unsupportedSource: "This source is report-only and cannot be cleaned."
        case .unsafePath: "The path is outside its approved cleanup boundary."
        case .symlink: "Symbolic links are never cleanup targets."
        case .changed: "The target changed after scanning; scan again."
        case .duplicateTarget: "The cleanup plan contains duplicate or nested targets."
        case .excluded: "The target is covered by an exclusion."
        case .activeUse: "The target appears to be in active use."
        case .concurrentCleanup: "Another cleanup is already running."
        }
    }
}

public struct CleanupPolicy: Sendable {
    public let allowedRoots: [ScanSource: [URL]]
    public let exclusions: [URL]
    public init(allowedRoots: [ScanSource: [URL]], exclusions: [URL] = []) { self.allowedRoots = allowedRoots; self.exclusions = exclusions }
    public static var production: CleanupPolicy {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return CleanupPolicy(allowedRoots: [
            .derivedData: [home.appendingPathComponent("Library/Developer/Xcode/DerivedData")],
            .archives: [home.appendingPathComponent("Library/Developer/Xcode/Archives")],
            .gradle: [home.appendingPathComponent(".gradle/caches")],
            .node: [home.appendingPathComponent(".npm/_cacache"), home.appendingPathComponent("Library/Caches/Yarn")]
        ])
    }
    public static func production(exclusions: [URL], flutterRoots: [URL] = []) -> CleanupPolicy {
        var roots = production.allowedRoots
        roots[.flutter] = flutterRoots
        return CleanupPolicy(allowedRoots: roots, exclusions: exclusions)
    }
    public func permits(_ target: ScanTarget, canonicalURL: URL) -> Bool {
        if exclusions.contains(where: { canonicalURL.path == PathSafety.canonical($0).path || PathSafety.isDescendant(canonicalURL, of: $0) }) { return false }
        if target.source == .flutter {
            guard let rootPath = target.authorizedRootPath else { return false }
            let root = URL(fileURLWithPath: rootPath)
            guard allowedRoots[.flutter, default: []].contains(where: { PathSafety.canonical($0).path == PathSafety.canonical(root).path }) else { return false }
            return canonicalURL.lastPathComponent == "build" && PathSafety.isDirectChild(canonicalURL, of: root)
        }
        guard let roots = allowedRoots[target.source] else { return false }
        return roots.contains { root in
            let canonicalRoot = PathSafety.canonical(root)
            return PathSafety.isDirectChild(canonicalURL, of: canonicalRoot) && target.authorizedRootPath == canonicalRoot.path
        }
    }
}

public protocol CleanupFileSystem: Sendable {
    func itemExists(at url: URL) -> Bool
    func isSymbolicLink(at url: URL) throws -> Bool
    func fingerprint(at url: URL) throws -> FileFingerprint
    func allocatedBytes(at url: URL) throws -> Int64
    func trashItem(at url: URL) throws
}

public struct FoundationCleanupFileSystem: CleanupFileSystem {
    public init() {}
    public func itemExists(at url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
    public func isSymbolicLink(at url: URL) throws -> Bool { try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true }
    public func fingerprint(at url: URL) throws -> FileFingerprint { try PathSafety.fingerprint(url) }
    public func allocatedBytes(at url: URL) throws -> Int64 { try DiskMeasurement.allocatedBytes(at: url) }
    public func trashItem(at url: URL) throws { var result: NSURL?; try FileManager.default.trashItem(at: url, resultingItemURL: &result) }
}

public protocol ActiveUseChecking: Sendable { func isActive(_ target: ScanTarget) async -> Bool }
public struct ToolProcessActiveUseChecker: ActiveUseChecking {
    public init() {}
    public func isActive(_ target: ScanTarget) async -> Bool {
        if target.source == .docker || target.source == .simulators || target.source == .android { return true }
        let pattern: String
        switch target.source {
        case .derivedData, .archives: pattern = "Xcode"
        case .gradle: pattern = "GradleDaemon"
        case .node: pattern = "node"
        case .flutter: pattern = "flutter|dart"
        default: return true
        }
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep"); process.arguments = ["-f", pattern]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit(); return process.terminationStatus == 0 } catch { return true }
    }
}

public actor CleanupExecutor {
    private let fileSystem: any CleanupFileSystem
    private let policy: CleanupPolicy
    private let activeUseChecker: any ActiveUseChecking
    private let journalURL: URL?
    private var executing = false

    public init(fileSystem: any CleanupFileSystem = FoundationCleanupFileSystem(), policy: CleanupPolicy = .production, activeUseChecker: any ActiveUseChecking = ToolProcessActiveUseChecker(), journalURL: URL? = nil) {
        self.fileSystem = fileSystem; self.policy = policy; self.activeUseChecker = activeUseChecker; self.journalURL = journalURL
    }

    public func execute(_ plan: CleanupPlan) async -> CleanupJob {
        let start = Date()
        guard !executing else { return failureJob(plan, start: start, error: PlanValidationError.concurrentCleanup) }
        executing = true
        defer { executing = false }
        do { try validatePlanShape(plan); try writeJournal(plan) }
        catch { return failureJob(plan, start: start, error: error) }

        var outcomes: [CleanupOutcome] = []
        for target in plan.targets {
            if Task.isCancelled { outcomes.append(CleanupOutcome(target: target, status: .skipped, measuredBytes: 0, message: "Cancelled before this target")); continue }
            do {
                try validate(target)
                if await activeUseChecker.isActive(target) { throw PlanValidationError.activeUse }
                if plan.dryRun { outcomes.append(CleanupOutcome(target: target, status: .simulated, measuredBytes: 0, message: "Validated; no files changed in dry run")); continue }
                try fileSystem.trashItem(at: URL(fileURLWithPath: target.path))
                outcomes.append(CleanupOutcome(target: target, status: .succeeded, measuredBytes: target.bytes, message: "Moved to Trash"))
            } catch { outcomes.append(CleanupOutcome(target: target, status: .failed, measuredBytes: 0, message: error.localizedDescription)) }
        }
        clearJournal()
        return CleanupJob(id: UUID(), startedAt: start, completedAt: .now, plan: plan, outcomes: outcomes)
    }

    private func validatePlanShape(_ plan: CleanupPlan) throws {
        guard ScanCoordinator.deduplicate(plan.targets).count == plan.targets.count else { throw PlanValidationError.duplicateTarget }
        let fingerprints = plan.targets.compactMap(\.fingerprint).map { "\($0.volume):\($0.file)" }
        guard Set(fingerprints).count == fingerprints.count else { throw PlanValidationError.duplicateTarget }
    }

    private func validate(_ target: ScanTarget) throws {
        guard target.classification != .protected else { throw PlanValidationError.protectedTarget }
        guard target.operation == "trash" else { throw PlanValidationError.unsupportedSource }
        let original = URL(fileURLWithPath: target.path).standardizedFileURL
        guard fileSystem.itemExists(at: original), !PathSafety.isProtected(original) else { throw PlanValidationError.unsafePath }
        guard try !fileSystem.isSymbolicLink(at: original) else { throw PlanValidationError.symlink }
        let canonical = PathSafety.canonical(original)
        guard canonical.path == original.path, policy.permits(target, canonicalURL: canonical) else {
            if policy.exclusions.contains(where: { canonical.path == PathSafety.canonical($0).path || PathSafety.isDescendant(canonical, of: $0) }) { throw PlanValidationError.excluded }
            throw PlanValidationError.unsafePath
        }
        guard let expected = target.fingerprint, try fileSystem.fingerprint(at: canonical) == expected else { throw PlanValidationError.changed }
        guard try fileSystem.allocatedBytes(at: canonical) == target.bytes else { throw PlanValidationError.changed }
    }

    private func failureJob(_ plan: CleanupPlan, start: Date, error: Error) -> CleanupJob {
        CleanupJob(id: UUID(), startedAt: start, completedAt: .now, plan: plan, outcomes: plan.targets.map { CleanupOutcome(target: $0, status: .failed, measuredBytes: 0, message: error.localizedDescription) })
    }
    private func writeJournal(_ plan: CleanupPlan) throws {
        guard let journalURL else { return }
        try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(plan).write(to: journalURL, options: .atomic)
    }
    private func clearJournal() { guard let journalURL else { return }; try? FileManager.default.removeItem(at: journalURL) }
}
