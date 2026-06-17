// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TimeInBarKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TimeInBarKit", targets: ["TimeInBarKit"])
    ],
    targets: [
        .target(name: "TimeInBarKit"),
        .testTarget(name: "TimeInBarKitTests", dependencies: ["TimeInBarKit"])
    ]
)
