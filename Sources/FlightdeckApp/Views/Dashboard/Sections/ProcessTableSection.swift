import MonitorCore
import SwiftUI

struct ProcessTableSection: View {
    @Environment(MonitorStore.self) private var store
    @State private var filterText = ""
    @State private var sort = ProcessSort(column: .cpu, isDescending: true)
    @State private var processToStop: ProcessSample?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Processes", count: rows.count) {
                TextField("Filter processes", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }
            ProcessBreakdown { filterText = $0 }
            ProcessListHeader(sort: $sort)
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { process in
                    ProcessListRow(process: process, maximumCPU: maximumCPU) { processToStop = process }
                }
            }
        }
        .confirmationDialog("Stop \(processToStop?.name ?? "")?", isPresented: isConfirmingStop, presenting: processToStop) { process in
            Button("Stop process", role: .destructive) { store.stopProcess(process.pid) }
        }
    }

    private var rows: [ProcessSample] {
        let processes = store.snapshot?.processes ?? []
        let filtered = filterText.isEmpty ? processes : processes.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
        return sort.sorted(filtered)
    }

    private var maximumCPU: Double { max(rows.map(\.cpuPercent).max() ?? 0, 1) }

    private var isConfirmingStop: Binding<Bool> {
        Binding(get: { processToStop != nil }, set: { if !$0 { processToStop = nil } })
    }
}

struct ProcessSort: Equatable {
    enum Column: String, CaseIterable {
        case name = "Name", pid = "PID", cpu = "CPU", memory = "Memory"
    }

    var column: Column
    var isDescending: Bool

    func sorted(_ processes: [ProcessSample]) -> [ProcessSample] {
        processes.sorted { isDescending ? isOrdered($1, before: $0) : isOrdered($0, before: $1) }
    }

    private func isOrdered(_ first: ProcessSample, before second: ProcessSample) -> Bool {
        switch column {
        case .name: first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        case .pid: first.pid < second.pid
        case .cpu: first.cpuPercent < second.cpuPercent
        case .memory: first.memoryBytes < second.memoryBytes
        }
    }

    /// A second click on the sorted column flips it; a new column starts largest first, names A to Z.
    mutating func select(_ newColumn: Column) {
        if column == newColumn { return isDescending.toggle() }
        column = newColumn
        isDescending = newColumn != .name
    }
}

/// Column widths shared by the header and the rows.
private enum ProcessColumns {
    static let pid: CGFloat = 70
    static let cpu: CGFloat = 150
    static let memory: CGFloat = 96
    static let actions: CGFloat = 28
}

private struct ProcessListHeader: View {
    @Environment(\.theme) private var theme
    @Binding var sort: ProcessSort

    var body: some View {
        HStack(spacing: 12) {
            button(.name).frame(maxWidth: .infinity, alignment: .leading)
            button(.pid).frame(width: ProcessColumns.pid, alignment: .trailing)
            button(.cpu).frame(width: ProcessColumns.cpu, alignment: .trailing)
            button(.memory).frame(width: ProcessColumns.memory, alignment: .trailing)
            Color.clear.frame(width: ProcessColumns.actions, height: 1)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func button(_ column: ProcessSort.Column) -> some View {
        let isSorted = sort.column == column
        return Button { sort.select(column) } label: {
            HStack(spacing: 3) {
                Text(column.rawValue)
                if isSorted { Image(systemName: sort.isDescending ? "chevron.down" : "chevron.up").font(.system(size: 9, weight: .bold)) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSorted ? theme.foreground : theme.muted)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProcessListRow: View {
    @Environment(\.theme) private var theme
    var process: ProcessSample
    var maximumCPU: Double
    var onStop: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text(process.name).lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
            Text(String(process.pid)).foregroundStyle(theme.muted).frame(width: ProcessColumns.pid, alignment: .trailing)
            HStack(spacing: 8) {
                ThinBar(fraction: process.cpuPercent / maximumCPU, color: UsageLevel.color(forFraction: process.cpuPercent / 100, in: theme), height: 3)
                    .frame(width: 60)
                Text(String(format: "%.1f%%", process.cpuPercent)).frame(width: 58, alignment: .trailing)
            }
            .frame(width: ProcessColumns.cpu, alignment: .trailing)
            Text(Formatters.bytes(process.memoryBytes)).frame(width: ProcessColumns.memory, alignment: .trailing)
            IconButton(systemImage: "xmark.circle", help: "Stop \(process.name)…", action: onStop)
                .foregroundStyle(theme.muted)
                .opacity(isHovering ? 1 : 0)
                .frame(width: ProcessColumns.actions)
        }
        .font(.system(size: 13).monospacedDigit())
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(isHovering ? theme.overlay.opacity(0.6) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, -6)
        .overlay(alignment: .bottom) { Hairline() }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu { Button("Stop \(process.name)…", action: onStop) }
    }
}
