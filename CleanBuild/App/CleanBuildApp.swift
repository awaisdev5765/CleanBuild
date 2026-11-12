import SwiftUI

@main
struct CleanBuildApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .frame(minWidth: 1000, minHeight: 680)
                .task { await model.loadHistory() }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { Button("New Scan") { model.startScan() }.keyboardShortcut("n") }
            CommandMenu("Scan") { Button("Rescan") { model.startScan() }.keyboardShortcut("r"); Button("Cancel Scan") { model.cancelScan() }.disabled(!model.isScanning) }
            CommandGroup(replacing: .help) { Button("CleanBuild Help") { model.route = .settings } }
        }
        Settings { SettingsView().environmentObject(model).frame(width: 560, height: 460) }
    }
}

