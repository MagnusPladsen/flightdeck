import MonitorCore
import SwiftUI

struct DevServersSection: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Dev servers", count: store.devServers.count)
            HairlineRows(items: store.devServers, emptyText: "No dev servers running") { PortRow(port: $0) }
        }
    }
}

struct OtherPortsSection: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        let ports = store.ports.filter { !$0.isDevServer }
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Other listening ports", count: ports.count)
            HairlineRows(items: ports, emptyText: "No other ports open") { PortRow(port: $0) }
        }
    }
}
