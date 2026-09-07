# Chroma Examples

## Native demo

Run the native Metal demo on macOS or the Wayland/EGL/OpenGL ES demo on Linux:

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

### Command-line syntax

```text
RemoteDemoDaemon [bind-host] [port]
RemoteDemoClient [host] [port]
```

The prototype currently sends complete frames and embeds image pixels. It does
not yet provide authentication or encryption. Only expose it on a trusted local
network.
