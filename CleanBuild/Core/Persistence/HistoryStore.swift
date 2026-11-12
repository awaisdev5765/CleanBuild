import Foundation

public actor HistoryStore {
    private struct DataFile: Codable { var scans: [ScanSession] = []; var jobs: [CleanupJob] = []; var audits: [AuditEvent] = [] }
    private let url: URL
    private var data = DataFile()
    public private(set) var loadError: String?
    public init(url: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("CleanBuild", isDirectory: true)
        self.url = url ?? base.appendingPathComponent("history.json")
        if FileManager.default.fileExists(atPath: self.url.path) {
            do { data = try JSONDecoder().decode(DataFile.self, from: Data(contentsOf: self.url)) }
            catch { loadError = error.localizedDescription }
        }
    }
    public func save(scan: ScanSession) throws { data.scans.insert(scan, at: 0); data.scans = Array(data.scans.prefix(50)); try persist() }
    public func save(job: CleanupJob) throws { data.jobs.insert(job, at: 0); data.audits.insert(AuditEvent(kind: "cleanup", message: "Cleanup job \(job.id.uuidString): \(job.outcomes.count) outcomes"), at: 0); try persist() }
    public func snapshot() -> (scans: [ScanSession], jobs: [CleanupJob], audits: [AuditEvent]) { (data.scans, data.jobs, data.audits) }
    public func clear() throws { data = DataFile(); try persist() }
    private func persist() throws { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(data).write(to: url, options: .atomic) }
}

public struct CleanBuildPreferences: Codable, Equatable, Sendable {
    public var workspacePaths: [String]
    public var exclusionPaths: [String]
    public var dryRun: Bool
    public init(workspacePaths: [String] = [], exclusionPaths: [String] = [], dryRun: Bool = true) { self.workspacePaths = workspacePaths; self.exclusionPaths = exclusionPaths; self.dryRun = dryRun }
}

public actor SettingsStore {
    private let url: URL
    public init(url: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("CleanBuild", isDirectory: true)
        self.url = url ?? base.appendingPathComponent("settings.json")
    }
    public func load() throws -> CleanBuildPreferences {
        guard FileManager.default.fileExists(atPath: url.path) else { return CleanBuildPreferences() }
        return try JSONDecoder().decode(CleanBuildPreferences.self, from: Data(contentsOf: url))
    }
    public func save(_ preferences: CleanBuildPreferences) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(preferences).write(to: url, options: .atomic)
    }
}
