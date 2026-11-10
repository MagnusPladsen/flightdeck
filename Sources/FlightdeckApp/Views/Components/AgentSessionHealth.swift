import MonitorCore
import SwiftUI

/// A thin bar showing how full a Claude session's context is, warning when it will compact soon.
struct ContextMeter: View {
    @Environment(\.theme) private var theme
    var context: ContextUsage
    private static let width: CGFloat = 46

    var body: some View {
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Capsule().fill(theme.overlay)
                Capsule().fill(color).frame(width: max(2, Self.width * context.fraction))
            }
            .frame(width: Self.width, height: 4)
            Text(Formatters.percent(context.fraction))
                .font(.caption2.monospacedDigit().weight(context.isNearlyFull ? .semibold : .regular))
                .foregroundStyle(context.isNearlyFull ? theme.warning : theme.muted)
                .frame(width: 30, alignment: .leading)
        }
        .help(helpText)
    }

    private var color: Color { context.isNearlyFull ? theme.warning : theme.info }

    private var helpText: String {
        let limit = "\(context.isMeasured ? "" : "about ")\(Formatters.tokens(context.compactsAtTokens))"
        let used = "Context: \(Formatters.tokens(context.usedTokens)) of \(limit) tokens before Claude compacts it."
        return context.isNearlyFull ? used + " It will compact soon, so finish or hand off the task." : used
    }
}

/// Says another agent works in the same checkout, and which files they both changed.
struct CheckoutClashNote: View {
    @Environment(\.theme) private var theme
    var clash: CheckoutClash
    var onUseWorktree: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Label(text, systemImage: "exclamationmark.2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.warning)
                .lineLimit(1)
                .truncationMode(.tail)
                .help("Agents in one checkout overwrite each other's edits and builds. Give the next one its own worktree.")
            Button("New agent in a worktree", action: onUseWorktree)
                .buttonStyle(.link)
                .font(.caption)
                .fixedSize()
        }
    }

    private var text: String {
        let others = clash.otherPIDs.count == 1 ? "another agent" : "\(clash.otherPIDs.count) other agents"
        guard let first = clash.sharedFiles.first else { return "Same checkout as \(others)" }
        let name = (first as NSString).lastPathComponent
        let more = clash.sharedFiles.count > 1 ? " +\(clash.sharedFiles.count - 1)" : ""
        return "Same checkout as \(others) · both changed \(name)\(more)"
    }
}
