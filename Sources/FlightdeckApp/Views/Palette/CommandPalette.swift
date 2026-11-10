import MonitorCore
import Observation
import SwiftUI

/// Whether the command palette is open, shared by the ⌘K menu item and the dashboard.
@MainActor
@Observable
final class CommandPaletteState {
    private(set) var isPresented = false

    func open() { isPresented = true }
    func dismiss() { isPresented = false }
}

/// ⌘K: jump to a page, agent, dev server or worktree, run an action, or ask Claude what you typed.
struct CommandPalette: View {
    private static let visibleLimit = 9

    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var state: CommandPaletteState
    var source: PaletteCommandSource
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        let commands = Array(source.commands(matching: query).prefix(Self.visibleLimit))
        ZStack(alignment: .top) {
            Color.black.opacity(0.55).contentShape(Rectangle()).onTapGesture { state.dismiss() }
            VStack(alignment: .leading, spacing: 0) {
                field(commands)
                Rectangle().fill(theme.border).frame(height: 1)
                list(commands)
            }
            .frame(maxWidth: 640)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(theme.border))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
            .padding(.horizontal, 24)
            .padding(.top, 96)
        }
        .onChange(of: query) { selection = 0 }
    }

    private func field(_ commands: [PaletteCommand]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "command").foregroundStyle(theme.accent).font(.system(size: 15, weight: .bold))
            TextField("Go to a page, agent, server or worktree, or ask Claude", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .focused($isFieldFocused)
                .onSubmit { run(commands, at: selection) }
                .onExitCommand { state.dismiss() }
                .onKeyPress(.downArrow) { move(1, in: commands) }
                .onKeyPress(.upArrow) { move(-1, in: commands) }
            KeyHint(text: "esc")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .onAppear { isFieldFocused = true }
    }

    private func list(_ commands: [PaletteCommand]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if commands.isEmpty {
                Text("Type to search").foregroundStyle(theme.muted).padding(14)
            }
            ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                PaletteRow(command: command, isSelected: index == selection)
                    .onTapGesture { run(commands, at: index) }
                    .onHover { if $0 { selection = index } }
            }
        }
        .padding(8)
    }

    private func move(_ step: Int, in commands: [PaletteCommand]) -> KeyPress.Result {
        guard !commands.isEmpty else { return .handled }
        selection = (selection + step + commands.count) % commands.count
        return .handled
    }

    private func run(_ commands: [PaletteCommand], at index: Int) {
        guard commands.indices.contains(index) else { return }
        let command = commands[index]
        store.achievements.record(.paletteUses)
        state.dismiss()
        query = ""
        command.run()
    }
}

private struct PaletteRow: View {
    @Environment(\.theme) private var theme
    var command: PaletteCommand
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.symbol).frame(width: 22).foregroundStyle(isSelected ? theme.accent : theme.muted)
            VStack(alignment: .leading, spacing: 1) {
                Text(command.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                if let subtitle = command.subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(command.group.rawValue).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.muted)
            if isSelected { KeyHint(text: "↩") }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? theme.overlay : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct KeyHint: View {
    @Environment(\.theme) private var theme
    var text: String

    var body: some View {
        Text(text).font(.system(size: 11)).foregroundStyle(theme.muted)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(theme.border))
    }
}
