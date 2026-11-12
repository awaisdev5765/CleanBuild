import AppKit
import Foundation
import Combine

enum AppRoute: String, CaseIterable, Identifiable { case overview = "Overview", explorer = "Storage Explorer", history = "History", settings = "Settings"; var id: String { rawValue }; var symbol: String { switch self { case .overview: CBIcon.overview; case .explorer: CBIcon.explorer; case .history: CBIcon.history; case .settings: CBIcon.settings } } }

@MainActor
final class AppModel: ObservableObject {
    @Published var route: AppRoute? = .overview
    @Published var session: ScanSession?
    @Published var jobs: [CleanupJob] = []
    @Published var scans: [ScanSession] = []
    @Published var isScanning = false
    @Published var currentSource: ScanSource?
    @Published var scanStartedAt: Date?
    @Published var selectedIDs = Set<UUID>()
    @Published var search = ""
    @Published var safetyFilter: SafetyClassification?
    @Published var workspaceURLs: [URL] = []
    @Published var dryRun = true
    @Published var showingOnboarding = !UserDefaults.standard.bool(forKey: "didOnboard")
    @Published var showingReview = false
    @Published var showingError: String?
    @Published var exclusionURLs: [URL] = []
    @Published var isCleaning = false
    @Published var showingCompletion = false
    @Published var lastCompletedJob: CleanupJob?
    @Published var selectedSource: ScanSource?
    @Published var selectedTargetID: UUID?
    private var scanTask: Task<Void, Never>?
    private let history = HistoryStore()
    private let settings = SettingsStore()
    private let coordinator: ScanCoordinator
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        coordinator = ScanCoordinator(adapters: [
            KnownDirectoryAdapter(source: .derivedData, directories: [home.appendingPathComponent("Library/Developer/Xcode/DerivedData")], classification: .safe, reason: "Generated Xcode build intermediates", consequence: "Projects will rebuild on next use."),
            KnownDirectoryAdapter(source: .archives, directories: [home.appendingPathComponent("Library/Developer/Xcode/Archives")], classification: .review, reason: "Archives may be needed for distribution or symbolication", consequence: "Removing an archive can prevent re-export or crash symbolication."),
            KnownDirectoryAdapter(source: .gradle, directories: [home.appendingPathComponent(".gradle/caches")], classification: .review, reason: "Gradle cache can be recreated but may be expensive", consequence: "Dependencies will be downloaded and builds may take longer."),
            KnownDirectoryAdapter(source: .node, directories: [home.appendingPathComponent(".npm/_cacache"), home.appendingPathComponent("Library/Caches/Yarn")], classification: .review, reason: "Package-manager cache", consequence: "Packages will need to be downloaded again."),
            WorkspaceBuildAdapter()
        ])
    }
    var targets: [ScanTarget] { session?.targets ?? [] }
    var filteredTargets: [ScanTarget] { targets.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.path.localizedCaseInsensitiveContains(search)) && (safetyFilter == nil || $0.classification == safetyFilter) && (selectedSource == nil || $0.source == selectedSource) } }
    var selectedTarget: ScanTarget? { targets.first { $0.id == selectedTargetID } }
    var selectedTargets: [ScanTarget] { targets.filter { selectedIDs.contains($0.id) && $0.classification != .protected } }
    var selectedBytes: Int64 { selectedTargets.reduce(0) { $0 + $1.bytes } }
    var eligibleBytes: Int64 { targets.filter { $0.classification != .protected }.reduce(0) { $0 + $1.bytes } }
    func loadHistory() async {
        let s = await history.snapshot(); scans = s.scans; jobs = s.jobs
        if let error = await history.loadError { showingError = "History could not be loaded: \(error)" }
        do { let p = try await settings.load(); workspaceURLs = p.workspacePaths.map(URL.init(fileURLWithPath:)); exclusionURLs = p.exclusionPaths.map(URL.init(fileURLWithPath:)); dryRun = p.dryRun }
        catch { showingError = "Settings could not be loaded: \(error.localizedDescription)" }
        let journal = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("CleanBuild/pending-cleanup.json")
        if FileManager.default.fileExists(atPath: journal.path) { showingError = "A previous cleanup did not finish normally. No action was resumed. Run a new scan before cleaning again." }
    }
    func finishOnboarding(scan: Bool) { UserDefaults.standard.set(true, forKey: "didOnboard"); showingOnboarding = false; if scan { startScan() } }
    func startScan() {
        guard !isScanning else { return }; isScanning = true; scanStartedAt = .now; currentSource = nil; selectedIDs.removeAll(); route = .overview
        scanTask = Task { [weak self] in
            guard let self else { return }
            let result = await coordinator.scan(workspaces: workspaceURLs) { source in await MainActor.run { self.currentSource = source } }
            guard !Task.isCancelled || result.cancelled else { self.isScanning = false; return }
            self.session = result; self.isScanning = false; self.currentSource = nil; self.scans.insert(result, at: 0)
            do { try await history.save(scan: result) } catch { self.showingError = "The scan completed but history could not be saved: \(error.localizedDescription)" }
        }
    }
    func cancelScan() { scanTask?.cancel(); isScanning = false }
    func toggle(_ target: ScanTarget) { guard target.classification != .protected else { return }; if selectedIDs.contains(target.id) { selectedIDs.remove(target.id) } else { selectedIDs.insert(target.id) } }
    func isSourceSelected(_ source: ScanSource) -> Bool {
        let eligible = targets.filter { $0.source == source && $0.classification != .protected }
        return !eligible.isEmpty && eligible.allSatisfy { selectedIDs.contains($0.id) }
    }
    func toggleSourceSelection(_ source: ScanSource) {
        let eligible = targets.filter { $0.source == source && $0.classification != .protected }
        guard !eligible.isEmpty else { return }
        if eligible.allSatisfy({ selectedIDs.contains($0.id) }) {
            selectedIDs.subtract(eligible.map(\.id))
        } else {
            selectedIDs.formUnion(eligible.map(\.id))
        }
    }
    func reveal(_ target: ScanTarget) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: target.path)]) }
    func copyPath(_ target: ScanTarget) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(target.path, forType: .string)
    }
    func chooseWorkspace() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = true; panel.prompt = "Add Workspace"
        if panel.runModal() == .OK { workspaceURLs.append(contentsOf: panel.urls.filter { !workspaceURLs.contains($0) }); persistSettings() }
    }
    func removeWorkspace(_ url: URL) { workspaceURLs.removeAll { $0 == url }; persistSettings() }
    func chooseExclusion() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = true; panel.prompt = "Exclude"
        if panel.runModal() == .OK { exclusionURLs.append(contentsOf: panel.urls.filter { !exclusionURLs.contains($0) }); persistSettings() }
    }
    func removeExclusion(_ url: URL) { exclusionURLs.removeAll { $0 == url }; persistSettings() }
    func updateDryRun(_ value: Bool) { dryRun = value; persistSettings() }
    private func persistSettings() {
        let value = CleanBuildPreferences(workspacePaths: workspaceURLs.map(\.path), exclusionPaths: exclusionURLs.map(\.path), dryRun: dryRun)
        Task { do { try await settings.save(value) } catch { await MainActor.run { self.showingError = "Settings could not be saved: \(error.localizedDescription)" } } }
    }
    func runCleanup() async {
        guard !isCleaning else { return }
        isCleaning = true; defer { isCleaning = false }
        let plan = CleanupPlan(targets: selectedTargets, dryRun: dryRun); showingReview = false
        let journal = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("CleanBuild/pending-cleanup.json")
        let executor = CleanupExecutor(policy: .production(exclusions: exclusionURLs, flutterRoots: workspaceURLs), journalURL: journal)
        let job = await executor.execute(plan); jobs.insert(job, at: 0); lastCompletedJob = job
        do { try await history.save(job: job) } catch { showingError = "Cleanup finished but the audit record could not be saved: \(error.localizedDescription)" }
        selectedIDs.removeAll(); showingCompletion = true
    }
    func clearHistory() async { do { try await history.clear(); scans = []; jobs = [] } catch { showingError = "History could not be cleared: \(error.localizedDescription)" } }
}

