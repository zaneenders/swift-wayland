// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-wayland",
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-nio.git",
            revision: "2.84.0")
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
