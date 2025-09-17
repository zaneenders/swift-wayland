// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-wayland",
    products: [
        .library(name: "Wayland", targets: ["Wayland"])
    ],
    traits: [
        "Toolbar",
        "FrameInfo",
        .default(enabledTraits: []),
    ],
    targets: [
        .executableTarget(
            name: "SwiftWayland",
            dependencies: ["Wayland"],
        ),
        .target(
            name: "Wayland",
            dependencies: [
                "CWaylandClient",
                "CWaylandEGL",
                "CEGL",
                "CGLES3",
                "CWaylandProtocols",
            ],
            resources: [
                .process("../../shaders/vertex.glsl"),
                .process("../../shaders/fragment.glsl"),
            ],
            swiftSettings: [
                .strictMemorySafety(),
                .treatAllWarnings(as: .error, .when(configuration: .release)),
            ],
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
            name: "CWaylandProtocols",
            publicHeadersPath: "include",
        ),
        .testTarget(
            name: "WaylandTests",
            dependencies: ["Wayland", "SwiftWayland"]),
    ]
)
