// swift-tools-version: 6.3
import PackageDescription

var dependencies: [Target.Dependency] = [
  "DemoContent",
  .product(name: "Chroma", package: "chroma"),
]
var swiftSettings: [SwiftSetting] = []
var chromaTraits: Set<Package.Dependency.Trait> = []
var targets: [Target] = [
  .target(
    name: "DemoBackend",
    dependencies: [
      "DemoContent", .product(name: "Chroma", package: "chroma"),
      .product(name: "RemoteServer", package: "chroma"),
    ]),
  .testTarget(
    name: "DemoContentTests",
    dependencies: [
      "DemoContent", .product(name: "HeadlessBackend", package: "chroma"),
      .product(name: "RemoteProtocol", package: "chroma"),
    ]
  ),
  .target(
    name: "DemoContent",
    dependencies: [
      "DemoImages", .product(name: "Chroma", package: "chroma"),
      .product(name: "RemoteProtocol", package: "chroma"),
    ]
  ),
  .target(
    name: "DemoImages",
    dependencies: [.product(name: "Chroma", package: "chroma")]
  ),
  .executableTarget(
    name: "RemoteDemoDaemon",
    dependencies: [
      "DemoContent", "DemoBackend",
      .product(name: "Chroma", package: "chroma"),
      .product(name: "RemoteServer", package: "chroma"),
      .product(name: "RemoteProtocol", package: "chroma"),
      .product(name: "HeadlessBackend", package: "chroma"),
    ]
  ),
]

#if os(macOS)
chromaTraits.insert("MetalBackend")
dependencies.append("DemoBackend")
dependencies.append(.product(name: "RemoteMetalClient", package: "chroma"))
swiftSettings.append(.define("METAL_BACKEND"))
targets.append(
  .executableTarget(
    name: "RemoteDemoClient",
    dependencies: [
      .product(name: "Chroma", package: "chroma"),
      .product(name: "RemoteMetalClient", package: "chroma"),
    ],
    swiftSettings: swiftSettings
  )
)
#elseif os(Linux)
chromaTraits.insert("WaylandBackend")
dependencies.append(.product(name: "WaylandBackend", package: "chroma"))
swiftSettings.append(.define("WAYLAND_BACKEND"))
#endif

targets.append(
  .executableTarget(
    name: "ChromaDemo",
    dependencies: dependencies,
    swiftSettings: swiftSettings
  )
)

let package = Package(
  name: "ChromaExample",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(path: "..", traits: chromaTraits)
  ],
  targets: targets
)
