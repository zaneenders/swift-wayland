// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-wayland",
  products: [
    .library(name: "Wayland", targets: ["Wayland"]),
    .library(name: "ShapeTree", targets: ["ShapeTree"]),
  ],
  traits: [
    "Toolbar",
    .default(enabledTraits: []),
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.30.0"),
    .package(url: "https://github.com/swift-cloud/swift-xxh3", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.8.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.86.0"),
  ],
  targets: [
    .executableTarget(
      name: "SwiftWayland",
      dependencies: [
        "Wayland",
        "ShapeTree",
        "Fixtures",
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "ShapeTree",
      dependencies: [
        .product(name: "XXH3", package: "swift-xxh3"),
        .product(name: "Logging", package: "swift-log"),
      ]),
    .target(name: "Fixtures", dependencies: ["ShapeTree"]),
    .target(
      name: "Wayland",
      dependencies: [
        "ShapeTree",
        "CWaylandClient",
        "CWaylandEGL",
        "CEGL",
        "CGLES3",
        "CWaylandProtocols",
        .product(name: "XXH3", package: "swift-xxh3"),
        .product(name: "Logging", package: "swift-log"),
      ],
      swiftSettings: swiftSettings,
      plugins: [
        .plugin(name: "ShaderGenerator")
      ]
    ),
    .testTarget(
      name: "WaylandTests",
      dependencies: [
        "Wayland", "SwiftWayland", "Fixtures",
      ],
      swiftSettings: swiftSettings),
    // Linked Libraries
    .systemLibrary(
      name: "CWaylandClient",
      path: "Sources/LinkedLibraries/CWaylandClient",
      pkgConfig: "wayland-client",
      providers: [
        .yum(["wayland-devel"])
      ]
    ),
    .systemLibrary(
      name: "CWaylandEGL",
      path: "Sources/LinkedLibraries/CWaylandEGL",
      pkgConfig: "wayland-egl",
      providers: [
        .yum(["wayland-protocols", "wayland-devel"])
      ],
    ),
    .systemLibrary(
      name: "CEGL",
      path: "Sources/LinkedLibraries/CEGL",
      pkgConfig: "egl",
      providers: [
        .yum(["mesa-libEGL-devel"])
      ]
    ),
    .systemLibrary(
      name: "CGLES3",
      path: "Sources/LinkedLibraries/CGLES3",
      pkgConfig: "glesv3",
      providers: [
        .yum(["mesa-libGLES-devel"])
      ]
    ),
    .target(
      name: "CWaylandProtocols",
      path: "Sources/LinkedLibraries/CWaylandProtocols",
      publicHeadersPath: "include",
      swiftSettings: swiftSettings
    ),
    // Plugin targets
    .executableTarget(
      name: "ShaderGeneratorTool",
      dependencies: []
    ),
    .plugin(
      name: "ShaderGenerator",
      capability: .buildTool(),
      dependencies: [
        "ShaderGeneratorTool"
      ]
    ),
  ]
)

let swiftSettings: [SwiftSetting] = [
  .strictMemorySafety(),
  .treatAllWarnings(as: .error),
  .enableUpcomingFeature("ExistentialAny"),
  .enableExperimentalFeature("LifetimeDependence"),
  .enableExperimentalFeature("Lifetimes"),
  .enableExperimentalFeature("Span"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("InternalImportsByDefault"),
]
