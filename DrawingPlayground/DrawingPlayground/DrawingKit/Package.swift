// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DrawingKit",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "DrawingKit", targets: ["DrawingKit"])
    ],
    targets: [
        .target(name: "DrawingKit")
    ]
)
