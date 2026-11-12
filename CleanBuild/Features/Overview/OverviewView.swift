import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingRecommendations = false

    private var foundBytes: Int64 { model.targets.reduce(0) { $0 + $1.bytes } }
    private func bytes(_ value: SafetyClassification) -> Int64 {
        model.targets.filter { $0.classification == value }.reduce(0) { $0 + $1.bytes }
    }
    private var sourceRows: [SourceOverviewRow] {
        ScanSource.allCases.map { source in
            let items = model.targets.filter { $0.source == source }
            let status = model.session?.statuses.first { $0.source == source }
            return SourceOverviewRow(
                source: source,
                bytes: items.reduce(0) { $0 + $1.bytes },
                classification: items.map(\.classification).max(by: { $0.severity < $1.severity }),
                availability: status?.availability ?? .unavailable
            )
        }.sorted {
            $0.bytes == $1.bytes ? $0.source.rawValue < $1.source.rawValue : $0.bytes > $1.bytes
        }
    }
    private var quickWins: [SourceOverviewRow] {
        Array(sourceRows.filter { $0.bytes > 0 && $0.classification != .protected }.prefix(3))
    }

    var body: some View {
        Group {
            if showingRecommendations, model.session != nil, !model.isScanning {
                RecommendationsView(rows: sourceRows.filter { $0.bytes > 0 && $0.classification != .protected }) {
                    showingRecommendations = false
                }
            } else if model.session == nil && !model.isScanning {
                WelcomeOverview()
            } else {
                populatedOverview
            }
        }
        .navigationTitle(showingRecommendations ? "Recommendations" : "Overview")
    }

    private var populatedOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CBSpacing.xLarge) {
                header
                if model.isScanning {
                    ScanStatusView()
                } else {
                    if model.session?.cancelled == true {
                        Label("The previous scan was cancelled. Results may be incomplete.", systemImage: "stop.circle")
                            .font(.callout).foregroundStyle(.orange)
                    }
                    HStack(alignment: .top, spacing: CBSpacing.large) {
                        StorageSummary(
                            total: foundBytes,
                            safe: bytes(.safe),
                            review: bytes(.review),
                            protected: bytes(.protected),
                            itemCount: model.targets.count
                        )
                        .frame(maxWidth: .infinity)
                        ScanHealthView().frame(width: 300)
                    }
                    quickWinsSection
                    storageByToolSection
                }
            }
            .padding(CBLayout.pageInset)
            .frame(maxWidth: 1220, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: CBSpacing.xSmall) {
                Text("Developer Storage").font(.system(size: 28, weight: .semibold))
                Text(lastScanText).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !model.isScanning {
                Button("Scan Again", systemImage: CBIcon.scan) { model.startScan() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: CBSpacing.medium) {
            SectionHeading(title: "Quick Wins", subtitle: "Largest rebuildable items found in this scan.")
            Surface {
                VStack(spacing: 0) {
                    if quickWins.isEmpty {
                        Text("No eligible cleanup suggestions were found.")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(quickWins.enumerated()), id: \.element.id) { index, row in
                            QuickWinRow(row: row)
                            if index < quickWins.count - 1 { Divider() }
                        }
                    }
                }
            }
            HStack {
                Label("Nothing is removed until you confirm", systemImage: CBIcon.privacy)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("View Recommendations") { showingRecommendations = true }
                Button("Review Selected") { model.showingReview = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedTargets.isEmpty)
            }
        }
    }

    private var storageByToolSection: some View {
        VStack(alignment: .leading, spacing: CBSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("Storage by Tool").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button("Open Explorer") { model.route = .explorer }
            }
            Surface {
                VStack(spacing: 0) {
                    ForEach(Array(sourceRows.prefix(5).enumerated()), id: \.element.id) { index, row in
                        StorageToolRow(row: row, maximum: max(sourceRows.first?.bytes ?? 0, 1))
                        if index < min(sourceRows.count, 5) - 1 { Divider() }
                    }
                }
            }
        }
    }

    private var lastScanText: String {
        guard let completed = model.session?.completedAt else { return "Scanning known developer-tool locations…" }
        return "Last scanned \(completed.formatted(date: .abbreviated, time: .shortened))"
    }
}

private enum RecommendationFilter: String, CaseIterable, Identifiable {
    case all = "All", safe = "Safe", review = "Review"
    var id: String { rawValue }
}

private struct RecommendationsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: RecommendationFilter = .all
    let rows: [SourceOverviewRow]
    let onBack: () -> Void

    private var visibleRows: [SourceOverviewRow] {
        switch filter {
        case .all: rows
        case .safe: rows.filter { $0.classification == .safe }
        case .review: rows.filter { $0.classification == .review }
        }
    }

    private var recoverableBytes: Int64 { rows.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: CBSpacing.xLarge) {
                    header
                    summary
                    Picker("Recommendation safety", selection: $filter) {
                        ForEach(RecommendationFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 310)

                    Surface {
                        VStack(spacing: 0) {
                            if visibleRows.isEmpty {
                                ContentUnavailableView(
                                    "No \(filter.rawValue.lowercased()) recommendations",
                                    systemImage: "checkmark.shield",
                                    description: Text("Choose another safety filter to review the current scan.")
                                )
                                .frame(maxWidth: .infinity, minHeight: 190)
                            } else {
                                ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                                    RecommendationRow(row: row)
                                    if index < visibleRows.count - 1 { Divider() }
                                }
                            }
                        }
                    }
                }
                .padding(CBLayout.pageInset)
                .frame(maxWidth: 1220, alignment: .leading)
            }
            Divider()
            footer
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CBSpacing.medium) {
            Button("Back to Overview", systemImage: "chevron.left", action: onBack)
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .keyboardShortcut("[", modifiers: .command)
            VStack(alignment: .leading, spacing: CBSpacing.xSmall) {
                Text("Recommendations").font(.system(size: 28, weight: .semibold))
                Text("Review rebuildable storage before anything changes.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var summary: some View {
        Surface {
            HStack(spacing: CBSpacing.xxLarge) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ByteFormatting.string(recoverableBytes))
                        .font(.system(size: 30, weight: .semibold)).monospacedDigit()
                    Text("recoverable").font(.callout).foregroundStyle(.secondary)
                }
                Divider().frame(height: 54)
                Label("\(rows.count) \(rows.count == 1 ? "recommendation" : "recommendations")", systemImage: "square.stack.3d.up")
                    .font(.title3.weight(.medium))
                Spacer()
            }
        }
    }

    private var footer: some View {
        HStack(spacing: CBSpacing.large) {
            Text("\(model.selectedTargets.count) selected · \(ByteFormatting.string(model.selectedBytes))")
                .font(.headline).monospacedDigit()
            Divider().frame(height: 28)
            Label("Nothing is removed until you confirm", systemImage: CBIcon.privacy)
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Review Cleanup…") { model.showingReview = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.selectedTargets.isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, CBLayout.pageInset)
        .frame(minHeight: 66)
        .background(.bar)
    }
}

private struct RecommendationRow: View {
    @EnvironmentObject private var model: AppModel
    let row: SourceOverviewRow

    var body: some View {
        HStack(spacing: CBSpacing.medium) {
            Toggle(isOn: Binding(
                get: { model.isSourceSelected(row.source) },
                set: { _ in model.toggleSourceSelection(row.source) }
            )) { Text("Select \(row.recommendationTitle)") }
            .toggleStyle(.checkbox)
            .labelsHidden()
            Image(systemName: row.source.symbol)
                .font(.title3).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.recommendationTitle).font(.headline)
                Text(row.consequence).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: CBSpacing.xLarge)
            Text(ByteFormatting.string(row.bytes)).font(.headline).monospacedDigit()
            if let classification = row.classification { ClassificationBadge(value: classification) }
        }
        .padding(.vertical, CBSpacing.medium)
        .accessibilityElement(children: .contain)
    }
}

private struct WelcomeOverview: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack {
            Spacer(minLength: 52)
            VStack(spacing: CBSpacing.large) {
                AppIdentityIcon(size: 72)
                VStack(spacing: CBSpacing.small) {
                    Text("Find space used by development tools")
                        .font(.system(size: 28, weight: .semibold)).multilineTextAlignment(.center)
                    Text("Measure build artifacts and caches from Xcode, Gradle, Node, and approved Flutter workspaces.")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).frame(maxWidth: 480)
                }
                Button("Scan Mac", systemImage: "magnifyingglass") { model.startScan() }
                    .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                Label("Your files stay on this Mac. Nothing is removed automatically.", systemImage: CBIcon.privacy)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CBLayout.pageInset)
    }
}

private struct ScanStatusView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: CBSpacing.medium) {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Scanning \(model.currentSource?.rawValue ?? "known locations")").font(.headline)
                    Spacer()
                    Button("Cancel") { model.cancelScan() }
                }
                ProgressView().progressViewStyle(.linear)
                Text("CleanBuild measures directly from disk. Source totals are not known in advance, so progress is indeterminate.")
                    .font(.callout).foregroundStyle(.secondary)
            }.padding(CBSpacing.xSmall)
        }
    }
}

private struct StorageSummary: View {
    let total: Int64, safe: Int64, review: Int64, protected: Int64, itemCount: Int
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: CBSpacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECOVERABLE SPACE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(ByteFormatting.string(safe + review)).font(.system(size: 38, weight: .semibold)).monospacedDigit()
                    Text("\(itemCount) items across this scan").font(.callout).foregroundStyle(.secondary)
                }
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        segment(safe, color: .green, width: proxy.size.width)
                        segment(review, color: .orange, width: proxy.size.width)
                        segment(protected, color: .secondary, width: proxy.size.width)
                        if total == 0 { Capsule().fill(.quaternary).frame(maxWidth: .infinity) }
                    }
                }
                .frame(height: 8)
                .accessibilityLabel("Storage classification summary")
                .accessibilityValue("\(ByteFormatting.string(safe)) safe, \(ByteFormatting.string(review)) review, \(ByteFormatting.string(protected)) protected")
                HStack(spacing: CBSpacing.xxxLarge) {
                    SummaryLegend(title: "Safe", bytes: safe, symbol: CBIcon.safe, tint: .green)
                    SummaryLegend(title: "Review", bytes: review, symbol: CBIcon.review, tint: .orange)
                    SummaryLegend(title: "Protected", bytes: protected, symbol: CBIcon.protected, tint: .secondary)
                }
            }
        }
    }
    private func segment(_ value: Int64, color: Color, width: CGFloat) -> some View {
        Capsule().fill(color).frame(width: total > 0 ? max(value > 0 ? 2 : 0, width * CGFloat(Double(value) / Double(total))) : 0)
    }
}

private struct SummaryLegend: View {
    let title: String, bytes: Int64, symbol: String, tint: Color
    var body: some View {
        HStack(spacing: CBSpacing.small) {
            Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(ByteFormatting.string(bytes)).font(.headline).monospacedDigit()
            }
        }.accessibilityElement(children: .combine)
    }
}

private struct ScanHealthView: View {
    @EnvironmentObject private var model: AppModel
    private var available: Int { model.session?.statuses.filter { $0.availability == .available }.count ?? 0 }
    private var permissionRequired: Int { model.session?.statuses.filter { $0.availability == .permissionRequired }.count ?? 0 }
    private var unavailable: Int { ScanSource.allCases.count - available }
    private var duration: String {
        guard let session = model.session, let completed = session.completedAt else { return "—" }
        let seconds = max(0, Int(completed.timeIntervalSince(session.startedAt).rounded()))
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: CBSpacing.medium) {
                Text("SCAN HEALTH").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Label("\(available) sources scanned", systemImage: "square.stack.3d.up")
                Label(permissionRequired > 0 ? "\(permissionRequired) need access" : "\(unavailable) unavailable", systemImage: CBIcon.review)
                Label("Completed in \(duration)", systemImage: "clock")
                Divider()
                Button("Review Access") { model.route = .settings }.frame(maxWidth: .infinity)
            }.font(.callout)
        }
    }
}

private struct QuickWinRow: View {
    @EnvironmentObject private var model: AppModel
    let row: SourceOverviewRow
    var body: some View {
        HStack(spacing: CBSpacing.medium) {
            Toggle(isOn: Binding(
                get: { model.isSourceSelected(row.source) },
                set: { _ in model.toggleSourceSelection(row.source) }
            )) { EmptyView() }
            .toggleStyle(.checkbox).labelsHidden()
            Image(systemName: row.source.symbol).frame(width: 18).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.recommendationTitle).font(.headline)
                Text(row.consequence).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(ByteFormatting.string(row.bytes)).font(.headline).monospacedDigit()
            if let classification = row.classification { ClassificationBadge(value: classification) }
        }
        .padding(.vertical, CBSpacing.small)
    }
}

private struct StorageToolRow: View {
    @EnvironmentObject private var model: AppModel
    let row: SourceOverviewRow
    let maximum: Int64
    var body: some View {
        Button {
            model.selectedSource = row.source
            model.route = .explorer
        } label: {
            HStack(spacing: CBSpacing.medium) {
                Label(row.source.rawValue.replacingOccurrences(of: "Xcode ", with: ""), systemImage: row.source.symbol)
                    .frame(width: 170, alignment: .leading)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        if row.bytes > 0 {
                            Capsule().fill(Color.accentColor)
                                .frame(width: max(3, proxy.size.width * CGFloat(Double(row.bytes) / Double(maximum))))
                        }
                    }
                }.frame(height: 8)
                Text(ByteFormatting.string(row.bytes)).monospacedDigit().frame(width: 90, alignment: .trailing)
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, CBSpacing.small)
        .accessibilityLabel("\(row.source.rawValue), \(ByteFormatting.string(row.bytes))")
    }
}

private struct SourceOverviewRow: Identifiable {
    var id: ScanSource { source }
    let source: ScanSource
    let bytes: Int64
    let classification: SafetyClassification?
    let availability: ToolAvailability

    var recommendationTitle: String {
        switch source {
        case .gradle: "Old Gradle caches"
        case .node: "Node package caches"
        case .derivedData: "Xcode DerivedData"
        case .archives: "Xcode Archives"
        case .flutter: "Flutter build artifacts"
        case .simulators: "Simulator storage"
        case .docker: "Docker storage"
        case .android: "Android build storage"
        }
    }
    var consequence: String {
        switch source {
        case .gradle: "Rebuilds from source and may re-download dependencies."
        case .node: "Re-downloads packages when you build."
        case .derivedData: "Recreates on the next Xcode build."
        case .archives: "May remove distribution and symbolication history."
        case .flutter: "Recreates during the next workspace build."
        case .simulators: "Review device data before removing anything."
        case .docker: "Review images, containers, and volumes separately."
        case .android: "Recreates during a future Android build."
        }
    }
}

private extension SafetyClassification {
    var severity: Int { switch self { case .safe: 0; case .review: 1; case .protected: 2 } }
}
