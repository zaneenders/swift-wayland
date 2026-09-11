# Chroma Examples

## Local demo

On macOS, the demo owns a backend subprocess and connects a Metal client over
loopback. Closing the window stops the backend. Linux uses Wayland/EGL/OpenGL ES:

```sh
swift run ChromaDemo
```

From the repository root, use:

```sh
swift run --package-path Example ChromaDemo
```

## Remote rendering prototype

The remote demo separates the Chroma block graph from the native window and GPU:

- `RemoteDemoDaemon` owns the block graph, application state, interaction state,
  layout, and `DrawList` generation.
- `RemoteDemoClient` owns the AppKit window and Metal renderer, sends input to
  the daemon, and renders received `DrawList` frames on its local GPU.

### Run both processes on one computer

Open two terminals in the `Example` directory.

Start the daemon:

```sh
swift run RemoteDemoDaemon
```

Start the client:

```sh
swift run RemoteDemoClient
```

The default address is `127.0.0.1:9328`.

From the repository root, the equivalent commands are:

```sh
swift run --package-path Example RemoteDemoDaemon
swift run --package-path Example RemoteDemoClient
```

### Connect from another computer

On the daemon computer, bind to all network interfaces:

```sh
swift run RemoteDemoDaemon 0.0.0.0 9328
```

Find the daemon computer's Wi-Fi IP address on macOS:

```sh
ipconfig getifaddr en0
```

For Ethernet or another interface, inspect the available addresses:

```sh
ifconfig | grep "inet "
```

Use a LAN address such as `192.168.1.42` or `10.0.0.42`, not `127.0.0.1`.

On the client computer, pass the daemon's IP address and port:

```sh
swift run RemoteDemoClient 192.168.1.42 9328
```

A hostname can also be used:

```sh
swift run RemoteDemoClient daemon-mac.local 9328
```

From outside the `Example` directory, add `--package-path Example` before the
product name.

### Check connectivity

From the client computer:

```sh
nc -vz 192.168.1.42 9328
```

If the connection fails:

- verify both computers are on the same network;
- verify the daemon is running with `0.0.0.0`, rather than its localhost default;
- allow the daemon through the macOS firewall if prompted;
- verify TCP port `9328` is not blocked or already occupied.

### Performance scene and metrics

The daemon demo continuously animates a configurable number of shapes. The
remote window is interactive: click (or use the arrow keys and Enter) to pause,
change density or speed, switch palettes and shape styles, and trigger a phase
burst. All of that UI state remains on the daemon, demonstrating round-trip
remote input as well as remote rendering.

Its arguments configure the bind address, port, and initial shape count:

```text
RemoteDemoDaemon [bind-host] [port] [items]
RemoteDemoClient [host] [port] [fps]
```

For example, test 2,000 animated shapes at 30 requested frames per second:

```sh
swift run RemoteDemoDaemon 0.0.0.0 9328 2000
```

The client requests frames at 30 FPS by default. Override it with, for example,
`swift run RemoteDemoClient 192.168.1.177 9328 60`. Only one frame request
is allowed in flight, so a slow network or server does not accumulate stale frames.
Try progressively heavier daemon runs such as `5000`, `10000`, and `20000` items. Both
processes print statistics approximately once per second. The daemon reports:

- generated frames per second;
- transmitted Mbit/s;
- commands per frame;
- block drawing time;
- binary encoding time.

The client reports:

- received frames per second;
- received Mbit/s;
- commands per frame;
- binary decoding time;
- CPU time used to encode commands into Metal (not GPU completion time).

Compare localhost and LAN runs with the same FPS and item count. This helps
separate server generation, wire bandwidth, client decoding, and Metal command
encoding costs.

The prototype currently sends complete frames and embeds image pixels. It does
not yet provide authentication or encryption. Only expose it on a trusted local
network.

## Capture a live scene

The native `ChromaDemo` defaults to the demo package directory (`Example/`),
resolved from its source location at build time, not the launching directory.
If you move the binary away from the source checkout, use the explicit override.
Nothing is saved until you press **Ctrl+Shift+G**. Override the destination with
an existing writable directory:

```sh
mkdir -p "$HOME/ChromaCaptures"
swift run --package-path Example -c release ChromaDemo \
  --capture-directory "$HOME/ChromaCaptures"
# For remote rendering, configure the daemon instead:
swift run --package-path Example -c release RemoteDemoDaemon \
  --capture-directory "$HOME/ChromaCaptures"
```

Then press **Ctrl+Shift+G** (Control, not Command, on macOS). The shortcut requests
one complete produced frame before renderer culling. The footer shows the chosen
directory and request/save status; the full saved path is printed to the launching
terminal. Files are named `scene-<UUID>.chromacapture` in that exact directory.

The remote daemon remains **opt-in**: without `--capture-directory`, it installs
no capture observer, shortcut, command handler, or footer. It has no default directory.
A missing value, duplicate option, nonexistent explicit directory, or failed
write-access probe rejects setup. Directories must already exist; setup does not create them. Relative paths resolve
against the launching directory. Failure to validate the native default
also rejects setup; there is no temporary fallback.
Later write failures are reported in the footer, never redirected elsewhere.

Encoding and writing run on a utility task. Repeated requests while a save is
pending are ignored; there is no continuous logging or capture-specific timer.
The demo's existing 30 Hz refresh updates the status after saving. The footer
itself is included in this initial capture format. The remote demo supports the
same command, but saves on the **daemon machine**, not the display client.

Captures contain exact text (including potentially offscreen emitted text) and
image pixels. They are not redacted. Files are created with owner-only permissions;
review before sharing. The demo rejects encoded captures over 64 MiB; this is an
output limit, not a strict bound on transient codec allocations. Saved files remain in your selected directory until you remove them.

Replay a saved file without the application graph or window:

```sh
swift run --package-path Benchmarks -c release RenderBenchmark \
  --capture /path/to/scene.chromacapture --stage pipeline
```

Use `--stage wire` without a GPU; `metal` and `pipeline` require macOS/Metal.
Captured raster scale is preserved (unknown/headless scale defaults to 1x).
This first version records one display list, not an executable Block graph,
layout trace, screenshot, input recording, or continuous frame sequence.

### Consumer hook

`App.frameObserver` defaults to nil; native app runners forward it to their
renderer. `MetalRenderer`, `WaylandRenderer`, `HeadlessRenderer`, and `RemoteServer`
also expose `frameObserver` directly. It receives a `FrameObservation` after
interaction completion, before culling. This is a produced frame, not necessarily
one presented to the user (especially with remote input-triggered evaluations).

Callbacks run synchronously on the main actor: check whether a capture is wanted,
retain the snapshot, and dispatch expensive work elsewhere. Avoid mutating UI
state or recursively rendering from the callback. With no observer installed,
the optional callback does not construct a snapshot. An installed demo observer
only checks its pending flag until the shortcut is used; overhead has not yet
been quantified. The demo uses `DemoApplication(captureConfiguration:)`, whose default is nil.
Constructing `DemoCaptureConfiguration(directory:)` requires and validates an
explicit file URL before capture can be enabled. Consumers may gate installation using their own configuration
or environment variables; Chroma defines no environment-variable policy.

`SceneCapture.encode/decode` lives in `RemoteProtocol`, separate from the core
Chroma hook, and uses a versioned header plus a self-contained wire frame. Capture
and protocol versions must match; no migration support exists yet.
