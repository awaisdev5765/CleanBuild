import Foundation

public protocol ScanAdapter: Sendable {
    var source: ScanSource { get }
    func availability() async -> SourceStatus
    func discoverTargets(workspaces: [URL]) async throws -> [ScanTarget]
}

public enum PathSafety {
    public static func canonical(_ url: URL) -> URL { url.standardizedFileURL.resolvingSymlinksInPath() }
    public static func isProtected(_ url: URL) -> Bool {
        let p = canonical(url).path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return p == "/" || p == home || p == "/System" || p.hasPrefix("/System/") || p == "/Library" || p == "/Applications"
    }
    public static func isDescendant(_ child: URL, of parent: URL) -> Bool {
        let c = canonical(child).path + "/", p = canonical(parent).path + "/"
        return c.hasPrefix(p) && c != p
    }
    public static func isDirectChild(_ child: URL, of parent: URL) -> Bool {
        canonical(child).deletingLastPathComponent().path == canonical(parent).path
    }
    public static func fingerprint(_ url: URL) throws -> FileFingerprint {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let volume = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
              let file = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value else {
            throw CocoaError(.fileReadUnknown)
        }
        return FileFingerprint(volume: volume, file: file, modifiedAt: attributes[.modificationDate] as? Date)
    }
}

public enum DiskMeasurement {
    public static func allocatedBytes(at root: URL) throws -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        var enumerationError: Error?
        guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, error in enumerationError = error; return false }) else { throw CocoaError(.fileReadUnknown) }
        var total: Int64 = 0
        for case let url as URL in en {
            try Task.checkCancellation()
            let v = try url.resourceValues(forKeys: keys)
            if v.isSymbolicLink == true { continue }
            if v.isRegularFile == true { total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0) }
        }
        if let enumerationError { throw enumerationError }
        return total
    }
}

public struct KnownDirectoryAdapter: ScanAdapter {
    public let source: ScanSource
    private let directories: [URL]
    private let classification: SafetyClassification
    private let reason: String
    private let consequence: String
    public init(source: ScanSource, directories: [URL], classification: SafetyClassification, reason: String, consequence: String) { self.source = source; self.directories = directories; self.classification = classification; self.reason = reason; self.consequence = consequence }
    public func availability() async -> SourceStatus {
        let found = directories.contains { FileManager.default.fileExists(atPath: $0.path) }
        return SourceStatus(source: source, availability: found ? .available : .notInstalled, detail: found ? "Known storage location found" : "No known storage location found")
    }
    public func discoverTargets(workspaces: [URL]) async throws -> [ScanTarget] {
        var result: [ScanTarget] = []
        for base in directories where FileManager.default.fileExists(atPath: base.path) {
            let children = (try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            for child in children {
                try Task.checkCancellation()
                let values = try? child.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey])
                if values?.isSymbolicLink == true || values?.isDirectory != true || PathSafety.isProtected(child) { continue }
                let bytes = try DiskMeasurement.allocatedBytes(at: child)
                result.append(ScanTarget(source: source, name: child.lastPathComponent, path: child.path, bytes: bytes, modifiedAt: values?.contentModificationDate, classification: classification, reason: reason, consequence: consequence, authorizedRootPath: PathSafety.canonical(base).path, fingerprint: try PathSafety.fingerprint(child)))
            }
        }
        return result
    }
}

public struct WorkspaceBuildAdapter: ScanAdapter {
    public let source: ScanSource = .flutter
    public func availability() async -> SourceStatus { SourceStatus(source: source, availability: .available, detail: "Scans only folders you explicitly add") }
    public func discoverTargets(workspaces: [URL]) async throws -> [ScanTarget] {
        var result: [ScanTarget] = []
        for root in workspaces {
            let marker = root.appendingPathComponent("pubspec.yaml")
            let build = root.appendingPathComponent("build")
            guard FileManager.default.fileExists(atPath: marker.path), FileManager.default.fileExists(atPath: build.path), !PathSafety.isProtected(build) else { continue }
            let canonicalRoot = PathSafety.canonical(root)
            let canonicalBuild = PathSafety.canonical(build)
            guard PathSafety.isDirectChild(canonicalBuild, of: canonicalRoot), canonicalBuild.lastPathComponent == "build" else { continue }
            result.append(ScanTarget(source: .flutter, name: "\(root.lastPathComponent) build", path: canonicalBuild.path, bytes: try DiskMeasurement.allocatedBytes(at: canonicalBuild), modifiedAt: (try? canonicalBuild.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, classification: .safe, reason: "Generated Flutter build output in an approved workspace", consequence: "The next build will regenerate these files.", authorizedRootPath: canonicalRoot.path, fingerprint: try PathSafety.fingerprint(canonicalBuild)))
        }
        return result
    }
}

public actor ScanCoordinator {
    private let adapters: [any ScanAdapter]
    public init(adapters: [any ScanAdapter]) { self.adapters = adapters }
    public func scan(workspaces: [URL], progress: @Sendable (ScanSource) async -> Void) async -> ScanSession {
        var session = ScanSession()
        for adapter in adapters {
            if Task.isCancelled { session.cancelled = true; break }
            await progress(adapter.source)
            let status = await adapter.availability(); session.statuses.append(status)
            guard status.availability == .available else { continue }
            do { session.targets.append(contentsOf: try await adapter.discoverTargets(workspaces: workspaces)) }
            catch is CancellationError { session.cancelled = true; break }
            catch { session.statuses[session.statuses.count - 1] = SourceStatus(source: adapter.source, availability: .unavailable, detail: error.localizedDescription) }
        }
        session.completedAt = .now
        session.targets = Self.deduplicate(session.targets)
        return session
    }
    public static func deduplicate(_ targets: [ScanTarget]) -> [ScanTarget] {
        targets.sorted { $0.path.count < $1.path.count }.reduce(into: []) { out, item in
            guard !out.contains(where: { item.path == $0.path || PathSafety.isDescendant(URL(fileURLWithPath: item.path), of: URL(fileURLWithPath: $0.path)) }) else { return }
            out.append(item)
        }
    }
}

