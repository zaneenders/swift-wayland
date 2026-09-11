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

### Remote input limits

Each server connection has a bounded NIO-to-main-actor mailbox: at most 256
queued messages or 8 MiB of queued wire payloads. Delivery preserves input order
and yields after 32 messages so input bursts do not monopolize the main actor.
An overloaded connection is closed, rather than silently dropping key/button
events; queued input is discarded on disconnect. These are handoff limits, not
a replacement for the protocol's per-message validation or authentication.

`swift test --filter RemoteLoopbackTests` exercises real loopback TCP reconnects,
disconnects during frame encoding and clipboard operations, and server shutdown.
It does not require a Metal window.
