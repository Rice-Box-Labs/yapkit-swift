// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YapKitSDK",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "YapKit", targets: ["YapKit"]),
        .library(name: "YapKitUI", targets: ["YapKitUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/iconoir-icons/iconoir-swift.git", from: "7.0.0")
    ],
    targets: [
        .target(name: "YapKit"),
        .target(name: "YapKitUI", dependencies: [
            "YapKit",
            .product(name: "Iconoir", package: "iconoir-swift")
        ]),
        .testTarget(name: "YapKitTests", dependencies: ["YapKit"]),
        .testTarget(name: "YapKitUITests", dependencies: ["YapKit", "YapKitUI"])
    ]
)
