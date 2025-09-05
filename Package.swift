// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-wayland",
    targets: [
        .executableTarget(
            name: "SwiftWayland",
            dependencies: [
                "CWaylandClient",
                "CWaylandEGL",
                "CEGL",
                "CGLES3",
                "CXDGShell",
            ],
            resources: [
                .process("../../shaders/vertex.glsl"),
                .process("../../shaders/fragment.glsl"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .systemLibrary(
            name: "CWaylandClient",
            pkgConfig: "wayland-client",
            providers: [
                .yum(["wayland-devel"])
            ]
        ),
        .systemLibrary(
            name: "CWaylandEGL",
            pkgConfig: "wayland-egl",
            providers: [
                .yum(["wayland-protocols", "wayland-devel"])
            ]
        ),
        .systemLibrary(
            name: "CEGL",
            pkgConfig: "egl",
            providers: [
                .yum(["mesa-libEGL-devel"])
            ]
        ),
        .systemLibrary(
            name: "CGLES3",
            pkgConfig: "glesv3",
            providers: [
                .yum(["mesa-libGLES-devel"])
            ]
        ),
        .target(
            name: "CXDGShell",
            path: "Sources/CXDGShell",
            publicHeadersPath: "include",
        ),
    ]
)
