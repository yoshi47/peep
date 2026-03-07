// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Peep",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Peep", targets: ["Peep"])
    ],
    targets: [
        .executableTarget(
            name: "Peep",
            path: "Sources/Peep",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

