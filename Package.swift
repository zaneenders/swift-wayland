// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-wayland",
    dependencies: [
        // .package(path: "../swift-nio")
        .package(
            url: "https://github.com/zaneenders/swift-nio.git",
            branch: "zane-add-cmsghdr")
    ],
    targets: [
        .executableTarget(
            name: "SwiftWayland",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Span"),
                .enableExperimentalFeature("ValueGenerics"),
                .enableExperimentalFeature("LifetimeDependence"),
                // .strictMemorySafety(), // TODO formatting bug
            ]
        )
    ]
)
