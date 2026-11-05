import SwiftUI

/// The look a layout gives the dashboard on top of the theme's colours.
struct LayoutStyle {
    enum SectionChrome {
        /// Sections sit straight on the background, separated by their own hairlines.
        case plain
        case card(radius: CGFloat)
        /// Borderless filled tiles.
        case tile(radius: CGFloat)
        case glass(radius: CGFloat)
        case outlined(radius: CGFloat, glows: Bool = false)
    }

    enum Navigation {
        /// Labelled page list.
        case list
        /// Narrow column of icons.
        case rail
    }

    enum Backdrop {
        case none
        /// Large blurred colour glows behind frosted panels.
        case blobs
        case grid
        case scanlines
    }

    var fontDesign: Font.Design = .default
    var chrome: SectionChrome = .plain
    var columnSpacing: CGFloat = 32
    var rowSpacing: CGFloat = 36
    var padding: CGFloat = 32
    var maxWidth: CGFloat = 1180
    var navigation: Navigation = .list
    var backdrop: Backdrop = .none
}

/// Draws a section's card, tile, glass or outline for the layout.
struct SectionChromeModifier: ViewModifier {
    @Environment(\.theme) private var theme
    var chrome: LayoutStyle.SectionChrome

    func body(content: Content) -> some View {
        switch chrome {
        case .plain:
            content
        case .card(let radius):
            content.padding(18)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(theme.border))
        case .tile(let radius):
            content.padding(22)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: radius))
        case .glass(let radius):
            content.padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
                .background(theme.surface.opacity(0.35), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(theme.foreground.opacity(0.14)))
        case .outlined(let radius, let glows):
            content.padding(16)
                .background(theme.background.opacity(glows ? 0.85 : 0), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(glows ? theme.primary.opacity(0.55) : theme.border))
                .shadow(color: glows ? theme.primary.opacity(0.3) : .clear, radius: 11)
        }
    }
}

/// The layout's background: plain, or with glows, a grid or scanlines drawn behind the sections.
struct LayoutBackground: View {
    @Environment(\.theme) private var theme
    var backdrop: LayoutStyle.Backdrop

    var body: some View {
        ZStack {
            theme.background
            switch backdrop {
            case .none: EmptyView()
            case .blobs: blobs
            case .grid: lines(every: 40, color: theme.primary.opacity(0.07), vertical: true)
            case .scanlines: lines(every: 24, color: theme.overlay.opacity(0.7), vertical: false)
            }
        }
        .ignoresSafeArea()
    }

    private var blobs: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Circle().fill(theme.accent.opacity(0.5)).frame(width: 520, height: 520).position(x: size.width * 0.15, y: size.height * 0.1)
                Circle().fill(theme.info.opacity(0.4)).frame(width: 460, height: 460).position(x: size.width * 0.9, y: size.height * 0.35)
                Circle().fill(theme.error.opacity(0.3)).frame(width: 420, height: 420).position(x: size.width * 0.45, y: size.height * 0.95)
            }
            .blur(radius: 120)
        }
    }

    private func lines(every spacing: CGFloat, color: Color, vertical: Bool) -> some View {
        Canvas { context, size in
            var path = Path()
            for y in stride(from: 0, through: size.height, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            if vertical {
                for x in stride(from: 0, through: size.width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
    }
}
