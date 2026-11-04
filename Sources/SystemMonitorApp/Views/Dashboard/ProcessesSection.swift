import MonitorCore
import SwiftUI

struct ProcessesSection: View {
    @Environment(MonitorStore.self) private var store
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\ProcessSample.cpuPercent, order: .reverse)]
    @State private var selection: ProcessSample.ID?
    @State private var processToStop: ProcessSample?

    var body: some View {
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
        .searchable(text: $searchText, prompt: "Filter processes")
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
        let filtered = searchText.isEmpty ? processes : processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted(using: sortOrder)
    }

    private var isConfirmingStop: Binding<Bool> {
        Binding(get: { processToStop != nil }, set: { if !$0 { processToStop = nil } })
    }
}
