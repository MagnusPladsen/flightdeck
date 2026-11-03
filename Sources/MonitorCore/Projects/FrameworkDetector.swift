import Foundation

/// Recognises what a listening process is, from its command line and its project's manifest.
public enum FrameworkDetector {
    struct Rule {
        let framework: Framework
        let commandTokens: [String]
        let packageDependencies: [String]
    }

    static func rule(_ id: String, _ name: String, command: [String], dependencies: [String] = []) -> Rule {
        Rule(framework: Framework(id: id, displayName: name), commandTokens: command, packageDependencies: dependencies)
    }

    /// Ordered: specific frameworks before the generic runtimes that host them.
    static let rules: [Rule] = [
        rule("nextjs", "Next.js", command: ["next dev", "next start", "next-server", "/next/dist/", "next-router-worker"], dependencies: ["next"]),
        rule("nuxt", "Nuxt", command: ["nuxt", "nuxi"], dependencies: ["nuxt"]),
        rule("sveltekit", "SvelteKit", command: ["svelte-kit"], dependencies: ["@sveltejs/kit"]),
        rule("astro", "Astro", command: ["astro dev", "/astro/"], dependencies: ["astro"]),
        rule("remix", "Remix", command: ["remix dev", "remix-serve"], dependencies: ["@remix-run/dev"]),
        rule("storybook", "Storybook", command: ["storybook"]),
        rule("expo", "Expo", command: ["expo start", "/expo/"], dependencies: ["expo"]),
        rule("metro", "Metro", command: ["react-native start", "metro"], dependencies: ["react-native"]),
        rule("angular", "Angular", command: ["ng serve", "@angular/cli"], dependencies: ["@angular/core"]),
        rule("vite", "Vite", command: ["vite"], dependencies: ["vite"]),
        rule("cra", "Create React App", command: ["react-scripts"], dependencies: ["react-scripts"]),
        rule("webpack", "webpack", command: ["webpack"]),
        rule("nestjs", "NestJS", command: ["nest start"], dependencies: ["@nestjs/core"]),
        rule("wrangler", "Wrangler", command: ["wrangler"]),
        rule("convex", "Convex", command: ["convex dev"]),
        rule("prisma", "Prisma Studio", command: ["prisma studio"]),
        rule("django", "Django", command: ["manage.py runserver"]),
        rule("fastapi", "FastAPI", command: ["uvicorn", "fastapi"]),
        rule("flask", "Flask", command: ["flask run"]),
        rule("rails", "Rails", command: ["rails server", "puma"]),
        rule("laravel", "Laravel", command: ["artisan serve"]),
        rule("dotnet", ".NET", command: ["dotnet", "/bin/debug/", "/bin/release/"]),
        rule("rust", "Rust", command: ["/target/debug/", "/target/release/", "cargo run"]),
        rule("go", "Go", command: ["/go-build", "go run"]),
        rule("hugo", "Hugo", command: ["hugo server"]),
        rule("jekyll", "Jekyll", command: ["jekyll serve"]),
        rule("postgres", "PostgreSQL", command: ["postgres"]),
        rule("redis", "Redis", command: ["redis-server"]),
        rule("mysql", "MySQL", command: ["mysqld"]),
        rule("mongodb", "MongoDB", command: ["mongod"]),
        rule("ollama", "Ollama", command: ["ollama"]),
        rule("docker", "Docker", command: ["com.docker", "vpnkit", "docker-proxy", "orbstack"]),
        rule("godot", "Godot", command: ["godot"]),
        rule("python", "Python", command: ["http.server", "python"]),
        rule("bun", "Bun", command: ["bun "]),
        rule("deno", "Deno", command: ["deno"]),
        rule("node", "Node.js", command: ["node", "tsx", "ts-node", "nodemon"]),
    ]

    public static func detect(commandLine: String, processName: String, projectRoot: String?) -> Framework? {
        let haystack = (processName + " " + commandLine).lowercased()
        let dependencies = projectRoot.map(packageDependencies(at:)) ?? []

        if let match = rules.first(where: { rule in rule.commandTokens.contains { haystack.contains($0) } }) {
            let isGenericRuntime = ["node", "bun", "deno"].contains(match.framework.id)
            if isGenericRuntime, let refined = frameworkFromDependencies(dependencies) { return refined }
            return match.framework
        }
        return nil
    }

    static func frameworkFromDependencies(_ dependencies: Set<String>) -> Framework? {
        rules.first { rule in rule.packageDependencies.contains { dependencies.contains($0) } }?.framework
    }

    static func packageDependencies(at root: String) -> Set<String> {
        guard let data = FileManager.default.contents(atPath: root + "/package.json"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let sections = ["dependencies", "devDependencies"].compactMap { json[$0] as? [String: Any] }
        return Set(sections.flatMap(\.keys))
    }
}
