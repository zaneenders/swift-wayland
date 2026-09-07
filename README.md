# Chroma

UI library written in Swift

⚠️ Unstable: Heavy AI • Active API [dogfooding](https://github.com/zaneenders/scribe)

## Demo

Run the native Metal demo on macOS:

```sh
swift run --package-path Example ChromaDemo
```

Run the Wayland/EGL/OpenGL ES demo on Linux:

```sh
swift run --package-path Example ChromaDemo
```

## Remote rendering prototype

On macOS, run the block graph daemon and Metal display client in separate terminals:

```sh
swift run --package-path Example RemoteDemoDaemon
```

```sh
swift run --package-path Example RemoteDemoClient
```

To connect across a LAN, bind the daemon to all interfaces and pass its IP or
hostname to the client:

```sh
swift run --package-path Example RemoteDemoDaemon 0.0.0.0 9328
swift run --package-path Example RemoteDemoClient 192.168.1.42 9328
```

The remote demo includes a scrollable sidebar of 10,000 UUIDs beside the animated
shapes. Hover over the list and use the mouse wheel or trackpad, use Page Up/Down,
or click Top/Bottom. Generate replaces the UUIDs without resetting the scroll
position; the sidebar header and scene controls remain outside the scroll area.

By default the daemon listens on `127.0.0.1:9328`. It evaluates the Chroma block graph and
sends complete binary `DrawList` frames over SwiftNIO. The client owns the
AppKit window and GPU, sends pointer input and resize events to the daemon, and
renders received frames with Metal. This initial prototype sends full frames
(and embeds image pixels); resource caching, culling, and backpressure are
future optimizations.

The example is a separate package and selects the native backend for its host
platform. Building it also verifies that Chroma can be consumed through its
public API. To build only the libraries without a graphical backend, run
`swift build --disable-default-traits` from the repository root.

## Fonts

Chroma ships its authored monospaced bitmap display glyphs plus a pre-rasterized
Bedstead readable face in `ChromaFont`. Bedstead is CC0/public-domain dedicated.
Graphical backends build one shared atlas from that bundled data and do not
require HarfBuzz, FreeType, Fontconfig, or an installed system font.

### Remote list performance

The UUID sidebar uses `LazyVStack` directly (it owns its scroll viewport), so
only visible rows emit drawing commands. A normal `VStack` inside `ScrollView`
still measures and draws every row; clipping alone does not reduce server work
or the remote command stream. The current lazy stack caches row measurements,
but still constructs row descriptions and scans the cache each frame.

Measure the demo without networking or a GPU, using the same 1100×720 viewport:

```sh
swift run --package-path Example -c release RemoteDemoDaemon --benchmark
```

This reports cold-frame draw time, mean draw time over 60 subsequent frames,
and command count. It does not include wire encoding or client rendering.
