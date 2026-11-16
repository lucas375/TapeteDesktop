// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapeteDesktop",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TapeteDesktop", targets: ["TapeteDesktop"])],
    targets: [
        .executableTarget(name: "TapeteDesktop", resources: [.process("Resources")]),
        .testTarget(name: "TapeteDesktopTests", dependencies: ["TapeteDesktop"])
    ]
)
