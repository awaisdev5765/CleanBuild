import Foundation

public enum SafetyClassification: String, Codable, CaseIterable, Sendable {
    case safe = "Safe", review = "Review", protected = "Protected"
}

public enum ToolAvailability: String, Codable, Sendable {
    case available = "Available", notInstalled = "Not Installed", permissionRequired = "Permission Required", unavailable = "Unavailable"
}

public enum ScanSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case derivedData = "Xcode DerivedData", archives = "Xcode Archives", gradle = "Gradle", flutter = "Flutter", node = "Node", simulators = "iOS Simulators", docker = "Docker", android = "Android"
    public var id: String { rawValue }
    public var symbol: String {
        switch self { case .derivedData: "hammer"; case .archives: "archivebox"; case .gradle: "shippingbox"; case .flutter: "bird"; case .node: "hexagon"; case .simulators: "iphone"; case .docker: "container"; case .android: "smartphone" }
    }
}

public struct ScanTarget: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let source: ScanSource
    public let name: String
    public let path: String
    public let bytes: Int64
    public let modifiedAt: Date?
    public let classification: SafetyClassification
    public let reason: String
    public let consequence: String
    public let operation: String
    public let authorizedRootPath: String?
    public let fingerprint: FileFingerprint?
    public init(id: UUID = UUID(), source: ScanSource, name: String, path: String, bytes: Int64, modifiedAt: Date?, classification: SafetyClassification, reason: String, consequence: String, operation: String = "trash", authorizedRootPath: String? = nil, fingerprint: FileFingerprint? = nil) {
        self.id = id; self.source = source; self.name = name; self.path = path; self.bytes = bytes; self.modifiedAt = modifiedAt; self.classification = classification; self.reason = reason; self.consequence = consequence; self.operation = operation; self.authorizedRootPath = authorizedRootPath; self.fingerprint = fingerprint
    }
}

public struct FileFingerprint: Codable, Hashable, Sendable {
    public let volume: UInt64
    public let file: UInt64
    public let modifiedAt: Date?
    public init(volume: UInt64, file: UInt64, modifiedAt: Date?) { self.volume = volume; self.file = file; self.modifiedAt = modifiedAt }
}

public struct SourceStatus: Identifiable, Codable, Sendable {
    public var id: ScanSource { source }
    public let source: ScanSource
    public var availability: ToolAvailability
    public var detail: String
}

public struct ScanSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var completedAt: Date?
    public var targets: [ScanTarget]
    public var statuses: [SourceStatus]
    public var cancelled: Bool
    public init(id: UUID = UUID(), startedAt: Date = .now, completedAt: Date? = nil, targets: [ScanTarget] = [], statuses: [SourceStatus] = [], cancelled: Bool = false) { self.id = id; self.startedAt = startedAt; self.completedAt = completedAt; self.targets = targets; self.statuses = statuses; self.cancelled = cancelled }
}

public struct CleanupPlan: Identifiable, Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let targets: [ScanTarget]
    public let dryRun: Bool
    public init(id: UUID = UUID(), createdAt: Date = .now, targets: [ScanTarget], dryRun: Bool) { self.id = id; self.createdAt = createdAt; self.targets = targets; self.dryRun = dryRun }
}

public enum CleanupOutcomeStatus: String, Codable, Sendable { case succeeded, failed, skipped, simulated }
public struct CleanupOutcome: Identifiable, Codable, Sendable {
    public let id: UUID
    public let target: ScanTarget
    public let status: CleanupOutcomeStatus
    public let measuredBytes: Int64
    public let message: String
    public init(id: UUID = UUID(), target: ScanTarget, status: CleanupOutcomeStatus, measuredBytes: Int64, message: String) { self.id = id; self.target = target; self.status = status; self.measuredBytes = measuredBytes; self.message = message }
}

public struct CleanupJob: Identifiable, Codable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date
    public let plan: CleanupPlan
    public let outcomes: [CleanupOutcome]
}

public struct AuditEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: String
    public let message: String
    public init(id: UUID = UUID(), timestamp: Date = .now, kind: String, message: String) { self.id = id; self.timestamp = timestamp; self.kind = kind; self.message = message }
}

public enum ByteFormatting {
    public static func string(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
}

