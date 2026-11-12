import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Group {
            if model.jobs.isEmpty && model.scans.isEmpty {
                EmptyState(symbol: "clock.arrow.circlepath", title: "No history", message: "Completed scans and cleanup outcomes appear here and remain only on this Mac.")
            } else {
                List {
                    if !model.jobs.isEmpty {
                        Section("Cleanup Jobs") {
                            ForEach(model.jobs) { job in CleanupJobRow(job: job) }
                        }
                    }
                    if !model.scans.isEmpty {
                        Section("Scans") {
                            ForEach(model.scans) { scan in ScanHistoryRow(scan: scan) }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("History")
    }
}

private struct CleanupJobRow: View {
    let job: CleanupJob
    private var successCount: Int { job.outcomes.filter { $0.status == .succeeded || $0.status == .simulated }.count }
    private var failedCount: Int { job.outcomes.filter { $0.status == .failed || $0.status == .skipped }.count }
    private var measured: Int64 { job.outcomes.reduce(0) { $0 + $1.measuredBytes } }
    var body: some View {
        DisclosureGroup {
            ForEach(job.outcomes) { outcome in OutcomeRow(outcome: outcome) }
        } label: {
            HStack(spacing: CBSpacing.medium) {
                Image(systemName: failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(failedCount == 0 ? .green : .orange).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.plan.dryRun ? "Dry Run" : "Cleanup").font(.headline)
                    Text(job.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(job.plan.dryRun ? "\(successCount) validated" : ByteFormatting.string(measured)).monospacedDigit()
                    Text(failedCount == 0 ? "All \(job.outcomes.count) completed" : "\(failedCount) issue(s)").font(.caption).foregroundStyle(failedCount == 0 ? Color.secondary : Color.orange)
                }
            }.padding(.vertical, 5)
        }
    }
}

private struct OutcomeRow: View {
    let outcome: CleanupOutcome
    private var symbol: String {
        switch outcome.status { case .succeeded: "checkmark.circle.fill"; case .failed: "xmark.circle.fill"; case .skipped: "forward.circle"; case .simulated: "checkmark.circle" }
    }
    private var tint: Color {
        switch outcome.status { case .succeeded: .green; case .failed: .red; case .skipped: .orange; case .simulated: .blue }
    }
    var body: some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack { Text(outcome.target.name).fontWeight(.medium); ClassificationBadge(value: outcome.target.classification) }
                Text(outcome.message).font(.caption).foregroundStyle(.secondary)
                Text(outcome.target.path).font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle).pathHelp(outcome.target.path)
            }
            Spacer()
            Text(ByteFormatting.string(outcome.measuredBytes)).monospacedDigit().foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

private struct ScanHistoryRow: View {
    let scan: ScanSession
    private var total: Int64 { scan.targets.reduce(0) { $0 + $1.bytes } }
    private var available: Int { scan.statuses.filter { $0.availability == .available }.count }
    var body: some View {
        DisclosureGroup {
            ForEach(scan.statuses) { status in
                HStack { Label(status.source.rawValue, systemImage: status.source.symbol); Spacer(); AvailabilityBadge(value: status.availability); Text(status.detail).font(.caption).foregroundStyle(.secondary).frame(maxWidth: 260, alignment: .trailing) }
            }
        } label: {
            HStack(spacing: CBSpacing.medium) {
                Image(systemName: scan.cancelled ? "stop.circle" : "externaldrive.badge.checkmark").foregroundStyle(scan.cancelled ? Color.orange : Color.accentColor).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scan.cancelled ? "Cancelled scan" : "Completed scan").font(.headline)
                    Text(scan.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormatting.string(total)).monospacedDigit()
                    Text("\(scan.targets.count) items · \(available) sources available").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 5)
        }
    }
}
