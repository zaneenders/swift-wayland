# Swift Wayland Client

A minimal dependency graphics client using Wayland.

## Features

- [x] Expose keyboard events
- [x] Render colored rectangles
- [x] ASCII 5x7 character rendering
- [x] Swift concurrency support
- [x] Toolbar and Windowed Applications.

## Example

### Window Example

```
swift run
```

### Toolbar Example

```
swift run --traits Toolbar
```

## Library

You can import `Wayland` as a package dependency to build your own Wayland 
clients.

Optional include `"Toolbar"` 
[trait](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)
 if you would like to build your client as a Toolbar. By default apps are built
as Windowed.

```swift
.package(url: "https://github.com/zaneenders/swift-wayland.git", branch: "main", traits: ["Toolbar"])
```

## Dev

### Setup

Install Dependencies

- Wayland compositor ([Hyprland](https://hypr.land/))
- [Swift](https://www.swift.org/install)

Install Wayland headers

```console
sudo dnf install -y wayland-devel wayland-protocols-devel mesa-libEGL-devel mesa-libGLES-devel
```

### Wayland Protocol

Currently we are using `wayland-client.h`. To regenerate the protocol imports 
you can run the following commands.

Basic Windowing support

```console
wayland-scanner client-header < protocols/xdg-shell.xml > Sources/CXDGShell/include/xdg-shell-client-protocol.h
wayland-scanner private-code < protocols/xdg-shell.xml > Sources/CXDGShell/xdg-shell-protocol.c
```

Toolbar support headers

```console
wayland-scanner client-header < protocols/wlr-layer-shell-unstable-v1.xml > Sources/CXDGShell/include/layer-shell-client-protocol.h
wayland-scanner private-code < protocols/wlr-layer-shell-unstable-v1.xml > Sources/CXDGShell/layer-shell-protocol.c
```

## Testing

### Code Coverage Report

Generate detailed coverage report:

```console
swift test --enable-code-coverage
llvm-cov report .build/debug/swift-waylandPackageTests.xctest --instr-profile=.build/debug/codecov/default.profdata --ignore-filename-regex='(.build|Tests)[/\\].*'
```

## Feature Direction

Currently I am using `wayland-client.h` to get this up and running but ideally 
this will be down without this dependency. The goal of removing this dependency
is for 
[static cross complication](https://www.swift.org/documentation/articles/static-linux-getting-started.html)
 .

# Bugs

## Not actually using the GPU.

For Asahi linux adding the following lines to the `.config/hypr/hyprland.conf` 
does fix the error with running on the GPU but is sluggish. I assume this is 
because the driver isn’t as optimize because this is a very unbeaten path.

```
env = MESA_LOADER_DRIVER_OVERRIDE,asahi
env = WLR_RENDERER,vulkan
```

## Use static Linux sdk.

Currently we are linking against a few wayland libraries to handle sending 
messages to the wayland compositor. This can be switched out for our own 
server. I have had some success getting 
[swift-nio](https://github.com/apple/swift-nio/pull/3316) working but my 
implementation broke and decided to spend the time getting a working project 
and figured I could come back to the feature.

# TODO

- [ ] Support adding boarders.