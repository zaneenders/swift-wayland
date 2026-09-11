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
