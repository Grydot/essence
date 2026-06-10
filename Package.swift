// swift-tools-version: 5.9
import PackageDescription

// For a quick compile check of all the Swift: `swift build`.
// (SPM produces a bare binary; use the CMake build for the real Essence.app.)
let package = Package(
    name: "Essence",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Essence", path: "Sources/Essence")
    ]
)
