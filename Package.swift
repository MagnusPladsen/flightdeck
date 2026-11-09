// swift-tools-version: 6.0
import PackageDescription

let languageMode: [SwiftSetting] = [.swiftLanguageMode(.v5)]

var products: [Product] = [
    .library(name: "MonitorCore", targets: ["MonitorCore"]),
    .executable(name: "flightdeck-cli", targets: ["FlightdeckCLI"]),
]

var dependencies: [Package.Dependency] = []

var targets: [Target] = [
    .target(name: "MonitorCore", swiftSettings: languageMode),
    .executableTarget(name: "FlightdeckCLI", dependencies: ["MonitorCore"], swiftSettings: languageMode),
    .testTarget(name: "MonitorCoreTests", dependencies: ["MonitorCore"], swiftSettings: languageMode),
]

// The SwiftUI shell is macOS-only; Linux builds just the shared core (see docs/architecture.md).
#if os(macOS)
products.append(.executable(name: "Flightdeck", targets: ["FlightdeckApp"]))
dependencies.append(.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"))
targets.append(.executableTarget(
    name: "FlightdeckApp",
    dependencies: ["MonitorCore", .product(name: "Sparkle", package: "Sparkle")],
    swiftSettings: languageMode
))
#endif

let package = Package(
    name: "Flightdeck",
    platforms: [.macOS(.v14)],
    products: products,
    dependencies: dependencies,
    targets: targets
)
