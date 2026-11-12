import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmClearHistory = false
    @AppStorage("appearance") private var appearance = "System"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CBSpacing.xLarge) {
                SectionHeading(title: "Settings", subtitle: "Scan scope, safety defaults, privacy, and local data.")
                SettingsSection(title: "Appearance", symbol: "circle.lefthalf.filled") {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("System")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }.pickerStyle(.segmented).frame(maxWidth: 320)
                    Text("System follows your current macOS appearance.").font(.callout).foregroundStyle(.secondary)
                }
                SettingsSection(title: "Scan Locations", symbol: "folder.badge.gearshape") {
                    if model.workspaceURLs.isEmpty {
                        Text("No workspaces added. Flutter build folders are scanned only inside workspaces you choose.").foregroundStyle(.secondary)
                    } else {
                        ForEach(model.workspaceURLs, id: \.self) { url in PathSettingRow(url: url) { model.removeWorkspace(url) } }
                    }
                    Button("Add Workspace…") { model.chooseWorkspace() }
                }
                SettingsSection(title: "Exclusions", symbol: "nosign") {
                    if model.exclusionURLs.isEmpty { Text("No excluded folders.").foregroundStyle(.secondary) }
                    else { ForEach(model.exclusionURLs, id: \.self) { url in PathSettingRow(url: url) { model.removeExclusion(url) } } }
                    Button("Add Exclusion…") { model.chooseExclusion() }
                }
                SettingsSection(title: "Safety", symbol: "checkmark.shield") {
                    Toggle("Use dry run by default", isOn: Binding(get: { model.dryRun }, set: { model.updateDryRun($0) }))
                    Text("Protected items are never selectable. Real cleanup moves eligible ordinary folders to the Trash only after revalidation.").font(.callout).foregroundStyle(.secondary)
                }
                SettingsSection(title: "Privacy & History", symbol: "hand.raised") {
                    Text("Scanning and history stay on this Mac. CleanBuild does not use analytics or a network connection.").foregroundStyle(.secondary)
                    Button("Clear Local History", role: .destructive) { confirmClearHistory = true }
                }
                SettingsSection(title: "About", symbol: "info.circle") {
                    LabeledContent("Version", value: "1.0 (1)")
                    Text("CleanBuild — Make Room for What You’re Building.").foregroundStyle(.secondary)
                }
            }.padding(CBLayout.pageInset).frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("Settings")
        .confirmationDialog("Clear local history?", isPresented: $confirmClearHistory) {
            Button("Clear History", role: .destructive) { Task { await model.clearHistory() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes saved scan and cleanup records from this Mac. It does not change files found by a scan.") }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String, symbol: String
    @ViewBuilder let content: Content
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: CBSpacing.medium) {
                Label(title, systemImage: symbol).font(.headline)
                Divider()
                content
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PathSettingRow: View {
    let url: URL
    let remove: () -> Void
    var body: some View {
        HStack(spacing: CBSpacing.medium) {
            Image(systemName: "folder").foregroundStyle(.tint)
            Text(url.path).lineLimit(1).truncationMode(.middle).textSelection(.enabled).pathHelp(url.path)
            Spacer()
            Button("Remove", role: .destructive, action: remove)
        }
    }
}
