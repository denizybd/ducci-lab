// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "DucciLab", platforms: [.macOS(.v14)], products: [
    .executable(name: "DucciLab", targets: ["DucciLab"]),
    .executable(name: "DucciChecks", targets: ["DucciChecks"])
], targets: [
    .target(name: "DucciCore"),
    .executableTarget(name: "DucciLab", dependencies: ["DucciCore"]),
    .executableTarget(name: "DucciChecks", dependencies: ["DucciCore"])
], swiftLanguageVersions: [.v5])
