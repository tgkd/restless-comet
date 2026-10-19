// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RestlessCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "RestlessCore", targets: ["RestlessCore"])
    ],
    targets: [
        .target(name: "RestlessCore"),
        .testTarget(name: "RestlessCoreTests", dependencies: ["RestlessCore"])
    ]
)
