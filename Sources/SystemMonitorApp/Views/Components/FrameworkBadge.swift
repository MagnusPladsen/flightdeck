import MonitorCore
import SwiftUI

struct FrameworkBadge: View {
    @Environment(\.theme) private var theme
    var framework: Framework

    var body: some View {
        Text(framework.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }

    var color: Color {
        switch framework.id {
        case "nextjs", "remix", "hugo", "jekyll", "bun", "ollama": theme.foreground
        case "vite", "storybook", "dotnet", "laravel", "astro", "prisma": theme.secondary
        case "cra", "metro", "expo", "go", "deno", "mongodb": theme.accent
        case "nuxt", "node", "nestjs", "convex": theme.success
        case "sveltekit", "rust", "wrangler", "mysql": theme.warning
        case "angular", "rails", "redis": theme.error
        case "django", "fastapi", "flask", "python": theme.info
        case "postgres", "docker", "godot", "webpack": theme.primary
        default: theme.foreground.opacity(0.6)
        }
    }
}

struct Chip: View {
    @Environment(\.theme) private var theme
    var text: String
    var systemImage: String?

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let systemImage { Image(systemName: systemImage) }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption2)
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(theme.overlay.opacity(0.7), in: Capsule())
    }
}
