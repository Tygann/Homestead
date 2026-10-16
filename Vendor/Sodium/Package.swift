// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "Sodium",
    platforms: [.iOS("26.5")],
    products: [.library(name: "Sodium", targets: ["Sodium"])],
    targets: [
        .binaryTarget(name: "ClibsodiumBinary", path: "Clibsodium.xcframework"),
        .target(name: "_Clibsodium", dependencies: ["ClibsodiumBinary"]),
        .target(name: "Sodium", dependencies: ["_Clibsodium"]),
    ]
)
