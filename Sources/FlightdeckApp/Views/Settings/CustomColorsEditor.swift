import MonitorCore
import SwiftUI

/// Edits the selected custom theme. Built-in themes are read-only, so for those it offers a copy instead.
struct CustomColorsEditor: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let custom = store.settings.customTheme(id: store.settings.themeID) {
                CustomThemeEditor(custom: custom)
            } else {
                Text("Your colours").font(.headline)
                Text("Built-in themes can't be changed. Copy one to make a theme of your own.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Copy \(theme.name) to custom") { store.settings.copyToCustomTheme(theme) }
            }
        }
        .padding(.top, 8)
    }
}

private struct CustomThemeEditor: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var isConfirmingDelete = false
    var custom: CustomTheme

    var body: some View {
        HStack {
            TextField("Name", text: nameBinding)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
                .frame(maxWidth: 220)
            Spacer()
            Button("Duplicate") { store.settings.copyToCustomTheme(theme) }
            Button("Delete…", role: .destructive) { isConfirmingDelete = true }
        }
        .confirmationDialog("Delete \(custom.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) { store.settings.deleteCustomTheme(id: custom.id) }
        } message: {
            Text("The app switches back to \(baseTheme.name).")
        }
        HStack {
            Text("Copied from \(baseTheme.name).")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reset all") { store.settings.resetColors(inCustomTheme: custom.id) }
                .disabled(ThemeColorRole.allCases.allSatisfy { !isChanged($0) })
        }
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 8) {
            ForEach(ThemeColorRole.allCases) { role in
                row(for: role)
            }
        }
    }

    private func row(for role: ThemeColorRole) -> some View {
        HStack(spacing: 6) {
            Text(role.title)
            Spacer(minLength: 4)
            if isChanged(role) {
                Button {
                    store.settings.resetColors(role, inCustomTheme: custom.id)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Back to \(baseTheme.name)'s colour")
            }
            ColorPicker(role.title, selection: binding(for: role), supportsOpacity: false)
                .labelsHidden()
        }
    }

    private func isChanged(_ role: ThemeColorRole) -> Bool {
        custom.colors[role.rawValue] != basePalette[role.rawValue]
    }

    private func binding(for role: ThemeColorRole) -> Binding<Color> {
        Binding(
            get: { theme[role] },
            set: { store.settings.setColor($0, for: role, inCustomTheme: custom.id) }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { custom.name },
            set: { store.settings.renameCustomTheme(id: custom.id, to: $0) }
        )
    }

    private var baseTheme: Theme {
        Theme.resolve(id: custom.baseThemeID, systemScheme: .dark)
    }

    private var basePalette: [String: String] {
        baseTheme.palette.colors
    }
}
