import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("appearance") private var appearance = "System"
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                sidebarBrand
                List(selection: $model.route) {
                    Section("WORKSPACE") {
                        sidebarRow(.overview)
                        sidebarRow(.explorer)
                        sidebarRow(.history)
                    }
                    Section("MANAGE") {
                        sidebarRow(.settings)
                    }
                }
                .listStyle(.sidebar)
                Divider()
                sidebarStatus
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 235, max: 255)
        } detail: {
            Group {
                switch model.route ?? .overview {
                case .overview: OverviewView()
                case .explorer: ExplorerView()
                case .history: HistoryView()
                case .settings: SettingsView()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if model.isScanning {
                    ProgressView().controlSize(.small)
                    Text(model.currentSource?.rawValue ?? "Preparing scan…").foregroundStyle(.secondary)
                    Button("Cancel") { model.cancelScan() }
                }
            }
        }
        .overlay { if model.isCleaning { CleanupProgressOverlay() } }
        .sheet(isPresented: $model.showingOnboarding) { OnboardingView() }
        .sheet(isPresented: $model.showingReview) { CleanupReviewView() }
        .sheet(isPresented: $model.showingCompletion) { CleanupCompletionView() }
        .alert("CleanBuild", isPresented: Binding(get: { model.showingError != nil }, set: { if !$0 { model.showingError = nil } })) {
            Button("OK") {}
        } message: { Text(model.showingError ?? "") }
        .preferredColorScheme(appearance == "Light" ? .light : appearance == "Dark" ? .dark : nil)
    }

    private var sidebarBrand: some View {
        HStack(spacing: CBSpacing.medium) {
            AppIdentityIcon(size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("CleanBuild").font(.headline)
                Text("Developer Storage").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CBSpacing.large)
        .padding(.top, CBSpacing.medium)
        .padding(.bottom, CBSpacing.small)
        .accessibilityElement(children: .combine)
    }

    private func sidebarRow(_ route: AppRoute) -> some View {
        Label(route.rawValue, systemImage: route.symbol)
            .font(.system(size: 14))
            .tag(route)
            .accessibilityLabel(route.rawValue)
    }

    private var sidebarStatus: some View {
        HStack(spacing: CBSpacing.small) {
            if model.isScanning {
                ProgressView().controlSize(.small)
            } else {
                Circle()
                    .fill(model.session == nil ? Color.secondary : Color.green)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(model.isScanning ? "Scanning…" : model.session == nil ? "Ready to scan" : "Scan complete")
                    .font(.caption.weight(.semibold))
                Text(sidebarStatusDetail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button { model.startScan() } label: {
                Image(systemName: CBIcon.scan).frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(model.isScanning)
            .help("Scan Again")
            .accessibilityLabel("Scan Again")
        }
        .padding(.horizontal, CBSpacing.large)
        .padding(.vertical, CBSpacing.medium)
    }

    private var sidebarStatusDetail: String {
        if model.isScanning { return model.currentSource?.rawValue ?? "Preparing known locations" }
        guard model.session != nil else { return "No storage scan yet" }
        let total = model.targets.reduce(Int64(0)) { $0 + $1.bytes }
        return "\(ByteFormatting.string(total)) measured"
    }
}

private struct CleanupProgressOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            Surface {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text("Validating and cleaning…").font(.headline)
                    Text("Every path is being checked again before any action. Keep CleanBuild open until this finishes.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 330)
                }.padding(12)
            }.frame(width: 400)
        }.accessibilityElement(children: .combine).accessibilityLabel("Cleanup in progress")
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var page = 0
    var body: some View {
        VStack(spacing: 24) {
            BrandMark(size: 92)
            if page == 0 {
                Text("Make Room for What You’re Building").font(.largeTitle.weight(.semibold))
                Text("CleanBuild measures developer-tool storage and lets you review every eligible item before anything changes.").multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
                Label("Works offline. No tracking. No blanket disk permission.", systemImage: "hand.raised")
            } else {
                Text("Choose Your Scan Scope").font(.title.weight(.semibold))
                Text("Known developer cache locations are scanned automatically. Flutter build folders are scanned only inside workspaces you add.").multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
                Button("Add Workspace…") { model.chooseWorkspace() }
                Text("\(model.workspaceURLs.count) workspace(s) added").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack {
                if page > 0 { Button("Back") { page -= 1 } }
                Spacer()
                if page == 0 { Button("Continue") { page = 1 }.buttonStyle(.borderedProminent) }
                else {
                    Button("Not Now") { model.finishOnboarding(scan: false) }
                    Button("Scan Developer Storage") { model.finishOnboarding(scan: true) }.buttonStyle(.borderedProminent)
                }
            }
        }.padding(36).frame(width: 660, height: 520)
    }
}
