import MonitorCore
import SwiftUI

struct ProcessTableSection: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var filterText = ""
    @State private var sortOrder = [KeyPathComparator(\ProcessSample.cpuPercent, order: .reverse)]
    @State private var selection: ProcessSample.ID?
    @State private var processToStop: ProcessSample?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Processes", count: rows.count) {
                TextField("Filter processes", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }
            table
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 480)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.border))
        }
    }

    private var table: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
            TableColumn("PID", value: \.pid) { Text(String($0.pid)).monospacedDigit() }
                .width(70)
            TableColumn("CPU", value: \.cpuPercent) { Text(String(format: "%.1f%%", $0.cpuPercent)).monospacedDigit() }
                .width(80)
            TableColumn("Memory", value: \.memoryBytes) { Text(Formatters.bytes($0.memoryBytes)).monospacedDigit() }
                .width(100)
        }
        .themedScrollBackground()
        .contextMenu(forSelectionType: ProcessSample.ID.self) { ids in
            if let process = rows.first(where: { ids.contains($0.id) }) {
                Button("Stop \(process.name)…") { processToStop = process }
            }
        }
        .confirmationDialog("Stop \(processToStop?.name ?? "")?", isPresented: isConfirmingStop, presenting: processToStop) { process in
            Button("Stop process", role: .destructive) { store.stopProcess(process.pid) }
        }
    }

    private var rows: [ProcessSample] {
        let processes = store.snapshot?.processes ?? []
        let filtered = filterText.isEmpty ? processes : processes.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
        return filtered.sorted(using: sortOrder)
    }

    private var isConfirmingStop: Binding<Bool> {
        Binding(get: { processToStop != nil }, set: { if !$0 { processToStop = nil } })
    }
}
