# Swift Wayland Client

A minimal dependency graphics client using Wayland.

## Features

- [x] Expose keyboard events
- [x] Render colored rectangles
- [x] ASCII 5x7 character rendering
- [x] Swift concurrency support
- [x] Flexible layout algorithm (inspired by Clay)
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
[static cross compilation](https://www.swift.org/documentation/articles/static-linux-getting-started.html)
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

- [ ] Support adding borders.

# Resources & References

Helpful resources for getting to this point in the project.

**[The Interaction Medium by Ryan Fleury](https://www.rfleury.com/p/ui-part-1-the-interaction-medium)**

- Good series about programming UI
- Starting point for shader code

**[Clay Layout Algorithm by Nic Barker](https://www.youtube.com/watch?v=by9lQvpvMIc)**

- Inspired the layout algorithm implementation

**[Learn Wayland by writing a GUI from scratch](https://gaultier.github.io/blog/wayland_from_scratch.html)**

- Step-by-step guide to setting up a Wayland client

# Design

As mentioned in the Resources and References section this is inspired from Clay
as well as a blog series by Ryan Fleury.

One of the goals of the project was to leverage Swift’s `resultBuilder` feature
in building this UI framework for a declarative interface. In doing so the 
Block come together as a tree which is parsed by a few what I call Walkers.

## Attribute Walker

This is the first walk over the tree which is responsible for collecting the
attributes and assembling the basic structure of the three. This step may be 
unnecessary in the long run but the goal is to have all the attributes for a 
given block known. This also builds up a tree structure which can be used in 
following phases to look up the parent, siblings or children of the current
block.

## Size Walker

The next walker is the size walker which is responsible for computing known 
sizes of any blocks. This is done using the attributes from the previous phase 
so that padding, .fixed height and width modifiers can be applied. to compute 
the consumed areas of the layout. This information will be used in the 
fallowing Grow phase to compute the sizes of features that expand to the area 
they may consume.

### Sizing

Sizing can come in three forms `.fit`, `.grow` and `.fixed`. Fit sizing is used
to fit around the size of it’s children. This is the default sizing. A leaf 
node of fit sizing with no text or child elements will be a 0 x 0 rect and will
be observed but not visible on the screen. The grow modifier is used to specif 
that the element should expand and fill as much space as it can within it’s 
direction container. Lastly the fixed modifier is used to hard code what the 
size will be through out the algorithm. If the child of the fixed size 
container are larger then the specified size they are to be clipped and not or 
only partially visible.

### Direction

The direction blocks are a form of container that specify everything within 
this block will be laid out in this orientation defaulting to left to right 
and top to bottom. These can be nested to create more complex layouts and are 
`.fit` by default but can be specified with grow or fixed to create backgrounds 
or general rectangles.

## Grow Walker

The Grow walker uses the attributes and sizes computed in the previous phases 
to compute the sizes of the remaining elements that have a dynamic size. This 
has to be after the sizing phase as we must know how but the siblings of a 
grow element are to know how much area we have to expand to.

## Position Walker

This is the last phase as at this point we know all the sizes of all of the 
elements and can now compute there final positions. I’m not sure if it is best 
to do this is in pre or post order. But after this phase we will have enough 
information to start rendering the shapes and text on to the screen.
