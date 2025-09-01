// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-wayland",
    targets: [
        .executableTarget(
            name: "SwiftWayland",
            linkerSettings: [
                .linkedLibrary("m"),
                .linkedLibrary("wayland-client"),
                .linkedLibrary("wayland-egl"),
                .linkedLibrary("EGL"),
                .linkedLibrary("GLESv2"),
            ]
        )
    ]
)
