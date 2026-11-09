import MonitorCore
import SwiftUI

/// The last lines a server Flightdeck relaunched printed, read when the popover opens.
struct ServerLogButton: View {
    @Environment(MonitorStore.self) private var store
    var id: ServerIdentity

    @State private var isShowing = false

    var body: some View {
        IconButton(systemImage: "text.alignleft", help: "Show recent output") { isShowing = true }
            .popover(isPresented: $isShowing, arrowEdge: .bottom) {
                ServerLogLines(lines: store.serverHealth.logLines(for: id)).padding(12).frame(width: 460)
            }
    }
}

struct ServerLogLines: View {
    @Environment(\.theme) private var theme
    var lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if lines.isEmpty { Text("No output yet").foregroundStyle(theme.muted) }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line).lineLimit(1).truncationMode(.tail)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
