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
swift run --package-path Example -c release RemoteDemoDaemon
```

```sh
swift run --package-path Example -c release RemoteDemoClient
```

To connect across a LAN, bind the daemon to all interfaces and pass its IP or
hostname to the client:

```sh
swift run --package-path Example -c release RemoteDemoDaemon 0.0.0.0 9328
swift run --package-path Example -c release RemoteDemoClient 192.168.1.42 9328
```

The remote demo includes a scrollable sidebar of 10,000 UUIDs beside the animated
shapes. Hover over the list and use the mouse wheel or trackpad, use Page Up/Down,
or click Top/Bottom. Generate replaces the UUIDs without resetting the scroll
position; the sidebar header and scene controls remain outside the scroll area.
The same Mandelbrot bitmap used in the native demo appears above the shapes, demonstrating remote image rendering through
Chroma's `Image` block. Both demos use the shared `DemoImages` generator.
The daemon generates the 640×400 RGBA image once, with no
external assets or downloads, and the client displays it with its aspect ratio
preserved. Wire protocol v3 sends its 1,000 KiB of pixels once per connection or
image revision; subsequent frames reference the image ID and generation. Both
peers must be rebuilt together (older protocol versions are rejected). Wire
resources use deterministic FIFO eviction at 128 IDs / 64 MiB; evicted images
are automatically redefined on their next use. Encoding must remain ordered
and encoded frames must not be dropped after resource-cache updates.

### Virtualized lists

For uniform-height rows, use the data-driven `LazyVStack` initializer:

```swift
LazyVStack(
  id: WidgetID("items"),
  data: items,
  rowHeight: 48,
  spacing: 5,
  controller: scrollController
) { item in
  Text(item.title).padding(8)
}
```

It accepts a random-access collection and constructs only rows intersecting the
viewport—no application-owned row cache or full-list measurement is needed.
`rowHeight` is the complete row height in logical points, including padding, not
an estimate. Visible content is rebuilt from current data each frame. Give
interactive widgets stable IDs derived from their items. The stack owns scrolling;
constrain its viewport rather than nesting it in `ScrollView`.

The existing `rows:` initializer supports measured, variable-height rows, but is
only draw-culled: callers construct all rows, and uncached rows are measured even
when offscreen. It is not the same virtualization guarantee. Dynamic-height
measurement invalidation and scroll anchoring remain future work.

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
still measures and draws every row. Conservative display-list culling now
removes invisible primitives before transmission, but does not avoid layout work. The current lazy stack caches row measurements,
but still constructs row descriptions and scans the cache each frame.

Measure the demo without networking or a GPU, using the same 1100×720 viewport:

```sh
swift run --package-path Example -c release RemoteDemoDaemon --benchmark
```

This reports cold-frame draw/cull time, mean draw/cull time over 60 subsequent
frames, command count, cached wire encode/decode time, and steady-state bytes
per frame. It does not include networking or client Metal rendering.

### Remote clipboard and app-owned input

The remote demo has **Scene** and **Clipboard** tabs. In Clipboard, drag across
selectable text or edit the copy-source field, then paste into the target field
or another local application. The demo application chooses Command+C/X/V/A;
the remote client does not hardcode these shortcuts. Escape ends editing.

`RemoteServer.keyBindings` supplies the app's movement-mode bindings;
`editingKeyBindings` overlays them while editing. Both default to empty, and
bindings may be overridden or explicitly disabled. Configure modifiers for the
client platform, not the daemon's host OS.

Protocol v2 transports normalized keys and platform-produced text candidates.
Pointer events and keys are sent immediately in order; NIO deliveries enter the
main queue in FIFO order. Clipboard operations use sequence-correlated requests
and replies. The client alone accesses `NSPasteboard`. Subsequent input waits
for clipboard completion (or a five-second timeout), while frames continue.
Cut deletes only after a successful clipboard write and an unchanged editor
selection. Clipboard payloads are limited to 1 MiB of encoded data. The current
server supports one active client, and rejects competing connections.

The Metal client displays clipboard failures and disconnections in a dismissible
banner at the top of its window, without taking keyboard focus. Oversized paste
replies are replaced with a correlated failure reply immediately, so subsequent
input does not wait for the clipboard timeout. The 1 MiB limit includes JSON
metadata and escaping, not just the raw clipboard text.

This remains a plain-text prototype: use a trusted connection or protected
tunnel, not an exposed unauthenticated TCP port. Full IME composition, rich
clipboard formats, and native Edit-menu integration are not implemented.
Protocol v1 peers must be rebuilt together with the client and daemon.

### Remote performance diagnostics

Use **release builds on both machines**; debug Swift per-field decoding and
instance construction are not representative performance measurements:

```sh
swift run --package-path Example -c release RemoteDemoDaemon 0.0.0.0 9328
swift run --package-path Example -c release RemoteDemoClient 192.168.1.177 9328 30
```

The final client argument negotiates 1–240 fps. Each request grants one response;
input and invalidations cannot independently send extra frames. Input is still
processed in order immediately (the current interaction engine evaluates the
graph to process it); visual snapshots are coalesced until the presentation
credit/cadence permits sending. An unchanged scene receives a tiny unchanged
reply rather than another display list. Polling still evaluates the graph so
clock-driven demo animations continue to advance.

Client counters separate received and rendered fps, decode CPU time, CPU Metal
encoding time per actual draw, completed-command-buffer GPU time, request/reply
latency, draw calls, and instances. GPU completion samples may fall in a later
reporting interval. Server counters include draw/cull and encode time plus image
pixel versus remaining protocol bandwidth. Text glyph runs are cached with
bounded storage; clipping preserves painter order and antialiasing margins.
The client limits in-flight GPU work to protect its three shared buffer slots.

For repeatable comparisons, keep viewport, scene/shape count, and fps identical;
record both server and client statistics after warmup. Actual LAN/GPU speedups
need measurement on the target machines, not inference from debug logs.

A headless live-transport smoke test checks pacing, unchanged replies, and image
reuse across a viewport change:

```sh
swift build --package-path Example -c release --product RemoteDemoDaemon
python3 IntegrationTests/Remote/pacing.py
```
