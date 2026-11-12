import SwiftUI

private enum TargetSort: String, CaseIterable, Identifiable {
    case size = "Size", name = "Name", source = "Source", modified = "Modified"
    var id: String { rawValue }
}

struct ExplorerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showInspector = true
    @State private var sort: TargetSort = .size
    @State private var ascending = false

    private var sortedTargets: [ScanTarget] {
        model.filteredTargets.sorted { lhs, rhs in
            let ordered: Bool
            switch sort {
            case .size: ordered = lhs.bytes < rhs.bytes
            case .name: ordered = lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .source: ordered = lhs.source.rawValue.localizedStandardCompare(rhs.source.rawValue) == .orderedAscending
            case .modified: ordered = (lhs.modifiedAt ?? .distantPast) < (rhs.modifiedAt ?? .distantPast)
            }
            return ascending ? ordered : !ordered
        }
    }

    var body: some View {
        Group {
            if model.targets.isEmpty { ExplorerEmptyState() }
            else { populatedExplorer }
        }
        .toolbar {
            if !model.targets.isEmpty {
                ToolbarItemGroup {
                    Picker("Safety", selection: $model.safetyFilter) {
                        Text("All Safety Levels").tag(SafetyClassification?.none)
                        ForEach(SafetyClassification.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                    }.frame(width: 150)
                    Picker("Sort", selection: $sort) { ForEach(TargetSort.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 105)
                    Button { ascending.toggle() } label: { Image(systemName: ascending ? "arrow.up" : "arrow.down") }
                        .help(ascending ? "Sort ascending" : "Sort descending")
                        .accessibilityLabel(ascending ? "Sort ascending" : "Sort descending")
                    Button { showInspector.toggle() } label: { Image(systemName: CBIcon.inspector) }
                        .help(showInspector ? "Hide Inspector" : "Show Inspector")
                        .accessibilityLabel(showInspector ? "Hide Inspector" : "Show Inspector")
                }
            }
        }
        .navigationTitle("Storage Explorer")
    }

    private var populatedExplorer: some View {
        VStack(spacing: 0) {
            HSplitView {
                SourceFilterView().frame(minWidth: 188, idealWidth: 200, maxWidth: 210, maxHeight: .infinity)
                TargetTableView(items: sortedTargets).frame(minWidth: 500, maxHeight: .infinity)
                if showInspector { TargetInspectorView().frame(minWidth: 260, idealWidth: CBLayout.inspectorWidth, maxWidth: 300, maxHeight: .infinity) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if !model.selectedTargets.isEmpty {
                Divider()
                HStack(spacing: CBSpacing.medium) {
                    Text("\(model.selectedTargets.count) \(model.selectedTargets.count == 1 ? "item" : "items") selected · \(ByteFormatting.string(model.selectedBytes))")
                        .fontWeight(.medium).monospacedDigit()
                    Spacer()
                    Button("Review Cleanup…") { model.showingReview = true }
                        .buttonStyle(.borderedProminent).disabled(model.isCleaning)
                        .keyboardShortcut(.return, modifiers: [.command])
                }
                .padding(.horizontal, CBSpacing.large).frame(height: 48)
            }
        }
        .searchable(text: $model.search, prompt: "Search name or path")
    }
}

private struct ExplorerEmptyState: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(spacing: CBSpacing.large) {
            Image(systemName: "externaldrive.badge.magnifyingglass")
                .font(.system(size: 42, weight: .light)).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(spacing: CBSpacing.xSmall) {
                Text(model.session == nil ? "Inspect developer storage" : "No developer storage found")
                    .font(.title2.weight(.semibold))
                Text(model.session == nil
                     ? "Run a scan to inspect exact paths, measured sizes, and cleanup safety."
                     : "The latest scan did not find measurable items in the configured locations.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            Button(model.session == nil ? "Scan Mac" : "Scan Again", systemImage: "magnifyingglass") { model.startScan() }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CBLayout.pageInset)
    }
}

private struct SourceFilterView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        List(selection: $model.selectedSource) {
            HStack(spacing: 7) {
                Label("All Sources", systemImage: "square.stack.3d.up")
                Spacer()
                Text(ByteFormatting.string(model.targets.reduce(0) { $0 + $1.bytes }))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .tag(ScanSource?.none)
            .accessibilityLabel("All Sources, \(model.targets.count) items, \(ByteFormatting.string(model.targets.reduce(0) { $0 + $1.bytes }))")
            Section("Sources") {
                ForEach(ScanSource.allCases) { source in
                    let items = model.targets.filter { $0.source == source }
                    let status = model.session?.statuses.first { $0.source == source }
                    let total = items.reduce(Int64(0)) { $0 + $1.bytes }
                    HStack(spacing: 7) {
                        Label(source.rawValue, systemImage: source.symbol).lineLimit(1)
                        Spacer()
                        if status?.availability == .available {
                            Text(ByteFormatting.string(total)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                        else { Image(systemName: status?.availability == .permissionRequired ? "exclamationmark.lock" : "minus.circle").font(.caption).foregroundStyle(status?.availability == .permissionRequired ? .orange : .secondary) }
                    }
                    .tag(Optional(source))
                    .help(status?.availability == .available ? "\(items.count) items · \(ByteFormatting.string(total))" : status?.detail ?? "Not included in this scan")
                    .accessibilityLabel("\(source.rawValue), \(items.count) items, \(ByteFormatting.string(total))")
                }
            }
        }.listStyle(.sidebar)
    }
}

private struct TargetTableView: View {
    @EnvironmentObject private var model: AppModel
    let items: [ScanTarget]
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.selectedSource?.rawValue ?? "All Storage").font(.headline)
                Spacer()
                Text("\(items.count) items · \(ByteFormatting.string(items.reduce(0) { $0 + $1.bytes }))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }.padding(.horizontal, 14).frame(height: 42).background(.bar)
            Divider()
            Table(items, selection: $model.selectedTargetID) {
                TableColumn("Name") { item in
                    HStack(spacing: 8) {
                        Button { model.toggle(item) } label: {
                            Image(systemName: model.selectedIDs.contains(item.id) ? "checkmark.square.fill" : item.classification == .protected ? "lock.square" : "square")
                        }
                        .buttonStyle(.plain)
                        .disabled(item.classification == .protected)
                        .accessibilityLabel(model.selectedIDs.contains(item.id) ? "Deselect \(item.name)" : "Select \(item.name) for cleanup")
                        Image(systemName: item.source.symbol).foregroundStyle(.tint).frame(width: 18)
                        Text(item.name).fontWeight(.medium).lineLimit(1).help(item.name)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { model.reveal(item) }
                    .contextMenu {
                        Button("Reveal in Finder", systemImage: "folder") { model.reveal(item) }
                        Button("Copy Path", systemImage: "doc.on.doc") { model.copyPath(item) }
                        Divider()
                        Button(model.selectedIDs.contains(item.id) ? "Remove from Cleanup" : "Add to Cleanup", systemImage: "checkmark.square") { model.toggle(item) }
                            .disabled(item.classification == .protected)
                    }
                }.width(min: 115, ideal: 140)
                TableColumn("Size") { item in Text(ByteFormatting.string(item.bytes)).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing) }.width(min: 54, ideal: 62)
                TableColumn("Safety") { item in ClassificationBadge(value: item.classification) }.width(min: 64, ideal: 72)
                TableColumn("Modified") { item in Text(item.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown").foregroundStyle(.secondary) }.width(min: 76, ideal: 88)
                TableColumn("Source") { item in Text(item.source.rawValue).lineLimit(1).help(item.source.rawValue) }.width(min: 70, ideal: 84)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("No matching items", systemImage: "magnifyingglass")
                    } description: {
                        Text("Change the search, source, or safety filter.")
                    } actions: {
                        Button("Clear Filters") { model.search = ""; model.safetyFilter = nil; model.selectedSource = nil }
                    }
                }
            }
        }
    }
}

private struct TargetInspectorView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Group {
            if let item = model.selectedTarget {
                ScrollView {
                    VStack(alignment: .leading, spacing: CBSpacing.xLarge) {
                        VStack(alignment: .leading, spacing: CBSpacing.small) {
                            Image(systemName: item.source.symbol).font(.system(size: 28)).foregroundStyle(.tint)
                            Text(item.name).font(.title2.weight(.semibold)).textSelection(.enabled)
                            ClassificationBadge(value: item.classification)
                        }
                        HStack(alignment: .top, spacing: CBSpacing.xLarge) {
                            InspectorSection(title: "Size") { Text(ByteFormatting.string(item.bytes)).font(.headline).monospacedDigit() }
                            InspectorSection(title: "Modified") { Text(item.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown") }
                        }
                        InspectorSection(title: "Source") { Label(item.source.rawValue, systemImage: item.source.symbol) }
                        InspectorSection(title: "Why this classification") { Text(item.reason) }
                        InspectorSection(title: "Consequence") { Text(item.consequence) }
                        InspectorSection(title: "Location") {
                            Text(item.path).font(.caption.monospaced()).textSelection(.enabled).pathHelp(item.path)
                            HStack {
                                Button("Reveal in Finder") { model.reveal(item) }
                                Button("Copy Path") { model.copyPath(item) }
                            }
                        }
                        Button(model.selectedIDs.contains(item.id) ? "Remove from Cleanup" : "Review for Cleanup") { model.toggle(item) }
                            .buttonStyle(.bordered)
                            .disabled(item.classification == .protected)
                    }.padding(CBSpacing.xLarge)
                }
            } else {
                ContentUnavailableView("Select an item", systemImage: "sidebar.right", description: Text("Inspect its location, classification, and cleanup consequence."))
            }
        }.background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .leading, spacing: 6) { Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary); content } }
}

struct CleanupReviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = false
    private var hasReview: Bool { model.selectedTargets.contains { $0.classification == .review } }
    private var safeCount: Int { model.selectedTargets.filter { $0.classification == .safe }.count }
    private var reviewCount: Int { model.selectedTargets.filter { $0.classification == .review }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: CBSpacing.large) {
            HStack {
                Label("Review Cleanup", systemImage: "checklist.checked").font(.title.weight(.semibold))
                Spacer()
                Text("\(model.selectedTargets.count) items · \(ByteFormatting.string(model.selectedBytes))").font(.headline).monospacedDigit()
            }
            HStack { ClassificationBadge(value: .safe); Text("\(safeCount)"); ClassificationBadge(value: .review); Text("\(reviewCount)") }
            Text("Every path will be revalidated immediately before action. Changed, active, excluded, or unsafe paths will fail closed.").foregroundStyle(.secondary)
            List(model.selectedTargets) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack { Text(item.name).font(.headline); Spacer(); ClassificationBadge(value: item.classification); Text(ByteFormatting.string(item.bytes)).monospacedDigit() }
                    Text(item.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).pathHelp(item.path)
                    Text(item.consequence).font(.caption)
                }.padding(.vertical, 4)
            }
            Toggle("Dry run — validate and record without changing files", isOn: Binding(get: { model.dryRun }, set: { model.updateDryRun($0) }))
            if hasReview { Toggle("I understand Review items may require downloads, rebuilds, or remove archival capability.", isOn: $acknowledged) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(model.dryRun ? "Run Dry Run" : "Move Selected Items to Trash") { Task { await model.runCleanup() } }
                    .buttonStyle(.borderedProminent).tint(model.dryRun ? .accentColor : .red).keyboardShortcut(.defaultAction)
                    .disabled(hasReview && !acknowledged)
            }
        }.padding(CBSpacing.xLarge).frame(minWidth: 760, minHeight: 600)
    }
}

struct CleanupCompletionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private var job: CleanupJob? { model.lastCompletedJob }
    private var succeeded: [CleanupOutcome] { job?.outcomes.filter { $0.status == .succeeded || $0.status == .simulated } ?? [] }
    private var failed: [CleanupOutcome] { job?.outcomes.filter { $0.status == .failed || $0.status == .skipped } ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: CBSpacing.xLarge) {
            HStack(spacing: 14) {
                Image(systemName: failed.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(failed.isEmpty ? .green : .orange)
                VStack(alignment: .leading) {
                    Text(failed.isEmpty ? "Cleanup Complete" : "Cleanup Finished with Issues").font(.title.weight(.semibold))
                    Text(job?.plan.dryRun == true ? "Dry run only — no files were changed." : "Successful items were moved to the Trash.").foregroundStyle(.secondary)
                }
            }
            HStack(spacing: CBSpacing.large) {
                CompletionMetric(title: job?.plan.dryRun == true ? "Validated" : "Moved to Trash", value: "\(succeeded.count)")
                CompletionMetric(title: "Failed or skipped", value: "\(failed.count)")
                CompletionMetric(title: job?.plan.dryRun == true ? "Estimated" : "Reclaimed", value: ByteFormatting.string(succeeded.reduce(0) { $0 + ($1.status == .simulated ? $1.target.bytes : $1.measuredBytes) }))
            }
            if !failed.isEmpty {
                List(failed) { outcome in
                    VStack(alignment: .leading, spacing: 3) { Text(outcome.target.name).font(.headline); Text(outcome.message).foregroundStyle(.secondary) }
                }
            } else { Spacer() }
            HStack { Button("View History") { dismiss(); model.route = .history }; Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent) }
        }.padding(CBSpacing.xxLarge).frame(minWidth: 660, minHeight: 440)
    }
}

private struct CompletionMetric: View {
    let title: String, value: String
    var body: some View { Surface { VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2.weight(.semibold)).monospacedDigit() }.frame(maxWidth: .infinity, alignment: .leading) } }
}
