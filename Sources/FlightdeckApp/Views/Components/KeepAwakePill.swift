import SwiftUI

/// Turns keeping the Mac awake while agents work on and off, and says whether it is holding.
struct KeepAwakePill: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            store.setKeepAwakeWhileAgentsWork(!isEnabled)
        } label: {
            Label(store.keepAwakeStatusText, systemImage: isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(tint)
                .background(tint.opacity(0.14), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(isEnabled ? "Stop keeping the Mac awake while agents work" : "Keep the Mac awake while agents work. The display can still sleep.")
        .accessibilityAddTraits(isEnabled ? .isSelected : [])
    }

    private var isEnabled: Bool { store.settings.keepAwakeWhileAgentsWork }

    private var tint: Color {
        guard isEnabled else { return theme.muted }
        return store.busyAgentCount > 0 ? theme.primary : theme.foreground
    }
}
