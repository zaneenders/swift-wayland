# Chroma

UI library written in Swift.

⚠️ Unstable: Heavy AI • Active API [dogfooding](https://github.com/zaneenders/scribe)

## Run

```sh
swift run --package-path Example ChromaDemo
```

Requires Swift 6.3. On macOS, the demo launches a local backend subprocess and
Metal client. Linux uses Wayland/EGL/OpenGL ES.

For separate remote sessions:

```sh
swift run --package-path Example -c release RemoteDemoDaemon
swift run --package-path Example -c release RemoteDemoClient
```

Remote rendering is an unauthenticated prototype: use a trusted connection or
protected tunnel. See [Examples](Example/README.md) for options and scene capture.

## Test

```sh
swift test
swift test --package-path Example
```

[Rendering benchmarks and capture replay](Benchmarks/README.md).

## macOS rendering architecture

macOS applications use `RemoteServer` for the block graph and interaction state,
and `RemoteMetalClient` for the window, input transport, and GPU presentation.
Local apps use the same protocol over loopback; see the owned subprocess launcher
in `Example/Sources/ChromaDemo/ManagedDemo.swift`.

The former in-process `MetalApp` and `MetalRenderer` APIs have been removed.
`MetalBackend` now supplies display-list rendering and input capture to the remote
client, not a second application runner. Headless rendering and the Linux Wayland
runner remain available.
