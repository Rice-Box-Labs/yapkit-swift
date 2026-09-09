// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YapKitSDK",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "YapKit", targets: ["YapKit"]),
        .library(name: "YapKitUI", targets: ["YapKitUI"])
    ],
    targets: [
        .target(name: "YapKit"),
        .target(name: "YapKitUI", dependencies: ["YapKit"]),
        .testTarget(name: "YapKitTests", dependencies: ["YapKit"]),
        .testTarget(name: "YapKitUITests", dependencies: ["YapKit", "YapKitUI"])
    ]
)
