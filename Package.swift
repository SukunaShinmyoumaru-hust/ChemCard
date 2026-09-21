// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ChemCards",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ChemCards",
            path: "Sources/ChemCards",
            swiftSettings: [.unsafeFlags(["-O", "-whole-module-optimization"], .when(configuration: .release))]
        ),
        .testTarget(
            name: "ChemCardsTests",
            dependencies: ["ChemCards"],
            path: "Tests/ChemCardsTests"
        )
    ]
)
