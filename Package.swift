// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LCGRemote",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LCGRemote",
            targets: ["LCGRemote"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LCGRemote",
            dependencies: [],
            path: "LCGRemote"
        ),
        .testTarget(
            name: "LCGRemoteTests",
            dependencies: ["LCGRemote"],
            path: "LCGRemoteTests"
        ),
    ]
)
