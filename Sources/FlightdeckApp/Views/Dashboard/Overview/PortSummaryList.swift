import MonitorCore
import SwiftUI

/// The overview's short list of dev servers: port, name, stack and checkout. A row opens it in the browser.
struct PortSummaryList: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var ports: [ListeningPort]
    var navigate: (DashboardPage) -> Void
    private static let rowLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Ports").font(.system(size: 15, weight: .bold))
                Text("\(ports.count)").font(.system(size: 15)).foregroundStyle(theme.muted)
                Spacer()
                SeeAllLink(title: ports.count > Self.rowLimit ? "See all \(ports.count) ports →" : "Servers & Ports →") { navigate(.ports) }
            }
            if ports.isEmpty {
                Text("No dev servers running").font(.system(size: 13)).foregroundStyle(theme.muted).padding(.vertical, 14)
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
                ForEach(ports.prefix(Self.rowLimit)) { port in
                    Hairline().gridCellColumns(4)
                    GridRow {
                        Text(verbatim: ":\(port.port)").font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text(port.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(port.framework?.displayName ?? port.containerName ?? port.processName).foregroundStyle(theme.muted).lineLimit(1)
                        Text(checkout(port)).foregroundStyle(port.project?.isWorktree == true ? theme.info : theme.muted).lineLimit(1)
                            .truncationMode(.middle).gridColumnAlignment(.trailing)
                    }
                    .font(.system(size: 13))
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture { store.openInBrowser(port: port.port) }
                    .help("Open localhost:\(port.port)")
                }
            }
        }
    }

    private func checkout(_ port: ListeningPort) -> String {
        guard let project = port.project else { return "" }
        return project.isWorktree ? "⧉ " + (project.worktreeName ?? "worktree") : project.branch ?? ""
    }
}
