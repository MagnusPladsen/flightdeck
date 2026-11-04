// swift-tools-version: 6.0
import PackageDescription

let languageMode: [SwiftSetting] = [.swiftLanguageMode(.v5)]

var products: [Product] = [
    .library(name: "MonitorCore", targets: ["MonitorCore"]),
]

var targets: [Target] = [
    .target(name: "MonitorCore", swiftSettings: languageMode),
    .testTarget(name: "MonitorCoreTests", dependencies: ["MonitorCore"], swiftSettings: languageMode),
]

// The SwiftUI shell is macOS-only; Linux builds just the shared core (see docs/architecture.md).
#if os(macOS)
products.append(.executable(name: "Flightdeck", targets: ["FlightdeckApp"]))
targets.append(.executableTarget(name: "FlightdeckApp", dependencies: ["MonitorCore"], swiftSettings: languageMode))
#endif

let package = Package(
    name: "Flightdeck",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
