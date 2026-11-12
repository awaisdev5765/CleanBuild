import AppKit
import SwiftUI

enum CBSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 20
    static let xxLarge: CGFloat = 24
    static let xxxLarge: CGFloat = 32
}

enum CBLayout {
    static let pageInset: CGFloat = 28
    static let cornerRadius: CGFloat = 8
    static let compactCornerRadius: CGFloat = 8
    static let sidebarWidth: CGFloat = 210
    static let sourcePaneWidth: CGFloat = 205
    static let inspectorWidth: CGFloat = 280
}

enum CBIcon {
    static let overview = "gauge.with.dots.needle.50percent"
    static let explorer = "externaldrive"
    static let history = "clock.arrow.circlepath"
    static let settings = "gearshape"
    static let scan = "arrow.clockwise"
    static let privacy = "lock.shield"
    static let inspector = "sidebar.right"
    static let safe = "checkmark.shield"
    static let review = "exclamationmark.triangle"
    static let protected = "lock.shield"
}

struct AppIdentityIcon: View {
    var size: CGFloat = 44
    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct BrandMark: View {
    var size: CGFloat = 72
    var body: some View { AppIdentityIcon(size: size) }
}

struct Surface<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(CBSpacing.large)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: CBLayout.cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: CBLayout.cornerRadius).stroke(.separator.opacity(0.45), lineWidth: 0.5) }
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: CBSpacing.xSmall) {
            Text(title).font(.system(size: 18, weight: .semibold))
            if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
        }
    }
}

struct AvailabilityBadge: View {
    let value: ToolAvailability
    var body: some View {
        Label(value.rawValue, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.11), in: Capsule())
            .accessibilityLabel("Status: \(value.rawValue)")
    }
    private var symbol: String {
        switch value { case .available: "checkmark.circle"; case .notInstalled: "minus.circle"; case .permissionRequired: "exclamationmark.lock"; case .unavailable: "xmark.circle" }
    }
    private var tint: Color {
        switch value { case .available: .green; case .notInstalled: .secondary; case .permissionRequired: .orange; case .unavailable: .secondary }
    }
}

struct ClassificationBadge: View {
    let value: SafetyClassification
    var body: some View {
        Label(value.rawValue, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10), in: Capsule())
            .accessibilityLabel("Safety classification: \(value.rawValue)")
    }
    private var symbol: String { value == .safe ? CBIcon.safe : value == .review ? CBIcon.review : CBIcon.protected }
    private var tint: Color { value == .safe ? .green : value == .review ? .orange : .secondary }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action { Button(actionTitle, action: action).buttonStyle(.borderedProminent) }
        }
    }
}

extension View {
    func pathHelp(_ path: String) -> some View { help(path).accessibilityHint(path) }
}
