import SwiftUI

/// Lets the user replace any colour of the current theme, kept per theme so switching back restores them.
struct CustomColorsEditor: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your colours").font(.headline)
                Spacer()
                Button("Reset all") { store.settings.resetCustomColors(inTheme: baseTheme.id) }
                    .disabled(customColors.isEmpty)
            }
            Text("Changes apply to \(baseTheme.name) and stay with it when you switch themes.")
                .font(.callout)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 8) {
                ForEach(ThemeColorRole.allCases) { role in
                    row(for: role)
                }
            }
        }
        .padding(.top, 8)
    }

    private func row(for role: ThemeColorRole) -> some View {
        HStack(spacing: 6) {
            ColorPicker(role.title, selection: binding(for: role), supportsOpacity: false)
            Spacer(minLength: 0)
            if customColors[role.rawValue] != nil {
                Button {
                    store.settings.setCustomColor(nil, for: role, inTheme: baseTheme.id)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Back to \(baseTheme.name)'s colour")
            }
        }
    }

    private func binding(for role: ThemeColorRole) -> Binding<Color> {
        Binding(
            get: { theme[role] },
            set: { store.settings.setCustomColor($0, for: role, inTheme: baseTheme.id) }
        )
    }

    private var baseTheme: Theme {
        Theme.resolve(id: store.settings.themeID, systemScheme: systemScheme)
    }

    private var customColors: [String: String] {
        store.settings.customColors[baseTheme.id] ?? [:]
    }
}
