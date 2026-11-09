import MonitorCore
import SwiftUI

/// A dev server that stopped without being stopped from Flightdeck, kept for a while with its command and folder.
struct CrashedServerRow: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var crashed: CrashedServer
    @State private var logLines: [String] = []

    private var server: ListeningPort { crashed.server }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StatusDot(color: theme.warning)
                VStack(alignment: .leading, spacing: 3) {
                    Text(server.title).fontWeight(.medium).lineLimit(1)
                    details
                }
                Spacer(minLength: 4)
                actions
                Text(verbatim: ":\(crashed.id.port)").font(.system(.caption, design: .monospaced).weight(.semibold)).foregroundStyle(theme.muted)
            }
            if store.serverHealth.hasLog(for: crashed.id) {
                ServerLogLines(lines: logLines).foregroundStyle(theme.muted).padding(.leading, 16)
            }
        }
        .padding(.vertical, 3)
        .task(id: crashed.id) { logLines = await store.serverHealth.logLines(for: crashed.id) }
    }

    private var details: some View {
        HStack(spacing: 4) {
            Text("Stopped \(Formatters.relative(crashed.stoppedAt))").foregroundStyle(theme.warning)
            Text(verbatim: server.commandLine).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary).help(server.workingDirectory ?? crashed.id.folder)
        }
        .font(.caption)
    }

    private var actions: some View {
        HStack(spacing: 2) {
            if store.canRestart(server) {
                IconButton(systemImage: "arrow.clockwise.circle", help: "Run it again in a new terminal tab") { store.relaunch(crashed) }
            }
            IconButton(systemImage: "terminal", help: "Open in terminal") { store.openInTerminal(crashed.id.folder) }
            IconButton(systemImage: "xmark.circle", help: "Dismiss") { store.serverHealth.dismiss(crashed) }
        }
    }
}

/// The crashed servers under a list of live ones.
struct CrashedServerRows: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        ForEach(store.serverHealth.crashed) { crashed in
            Hairline()
            CrashedServerRow(crashed: crashed).padding(.vertical, 8)
        }
    }
}
