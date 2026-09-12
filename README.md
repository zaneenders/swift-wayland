# Chroma

UI library written in Swift.

⚠️ Unstable: Heavy AI • Active API [dogfooding](https://github.com/zaneenders/scribe)

## Run

```sh
swift run --package-path Example ChromaDemo
```

Requires Swift tools 6.4 or newer. Until a release toolchain is available, this
repository pins `main-snapshot-2026-09-10` in `.swift-version` (the compiler
identifies itself as Swift 6.5-dev). Install and use the pinned toolchain with
[Swiftly](https://www.swift.org/install/):

```sh
swiftly install
swiftly run swift --version
swiftly run swift test
swiftly run swift test --package-path Example
```

The root pin also applies to `Example` and `Benchmarks`. If Swiftly's proxies are
on your `PATH`, plain `swift` commands select it automatically. The package tools
requirement is 6.4; testing with this snapshot does not establish compatibility
with a released 6.4 compiler. The macOS deployment minimum is macOS 27 for post-setter Observation tracking.

On macOS, the demo launches a local backend subprocess and Metal client. Linux
uses Wayland/EGL/OpenGL ES.

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

### Single-font API and wire format

Text uses one bundled font. `FontFace`, `.fontFace(...)`, and `face:` arguments
have been removed; use `FontMetrics.cellAdvance` for character spacing.
Remote wire version 4 removes the font-face byte from text commands. Rebuild
clients and servers together; captures from older wire versions must be recorded
again.

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

## Bundled font license

Chroma's single text font is derived from Noto Sans Mono under SIL OFL 1.1.
Distributions must include the ChromaFont resource bundle containing the prebuilt
font atlas and `OFL.txt`. The atlas is loaded from that bundle at runtime.
See [font provenance and regeneration](Sources/ChromaFont/README.md).

## Observable application state

Chroma tracks Swift Observation property reads while evaluating a frame. Keep UI
models main-actor isolated and mark them `@Observable`:

```swift
import Chroma
import Observation
import RemoteServer

@MainActor
@Observable
final class CounterModel {
  var count = 0
}

@MainActor
func makeServer(model: CounterModel) -> RemoteServer {
  RemoteServer {
    VStack {
      Text("Count: \(model.count)")
      Button("Increment", id: WidgetID("increment")) { model.count += 1 }
    }
  }
}
```

The server's builder runs during frame evaluation, so root-level property reads
and conditionals stay live. `App` runners defer their root body automatically.
For directly assigned content, use `renderer.content = DeferredBlock { ... }`;
the existing `content:` server initializer still accepts prebuilt blocks.

Changes to properties read by the current frame request another evaluation on
the main queue after the setter completes. Tracking is renewed each frame;
unread properties do not request redraws. Frame-capture observer callbacks are
outside dependency tracking. `RenderContext.requestRedraw()` remains available
for non-observable state and custom primitives.

Headless rendering remains explicitly driven: assign `onRedrawRequested` to
receive model-change notifications, then call `render()` when appropriate.
Windowed backends retain their scheduling policies. Remote updates still obey
client presentation credits and frame-rate limits; frame requests currently
reevaluate the graph even when no observed property has changed. Observation
does not track time passing, so animations and caret blinking still require
refresh scheduling. This is whole-frame invalidation, not per-block caching.
