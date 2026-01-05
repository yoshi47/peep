// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickShot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "StickShot", targets: ["StickShot"])
    ],
    targets: [
        .executableTarget(
            name: "StickShot",
            path: "Sources/StickShot"
        )
    ]
)

