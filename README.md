# Swift Wayland Client

A minimal dependency graphics client using Wayland.

## Features

- [x] Expose keyboard events
- [x] Render colored rectangles
- [x] ASCII 5x7 character rendering
- [x] Swift concurrency support
- [x] Flexible layout algorithm (inspired by Clay)
- [x] Toolbar and Windowed example applications.

-----

## Setup

Install Dependencies

- Wayland compositor ([Hyprland](https://hypr.land/))
- [Swift](https://www.swift.org/install)

Install Wayland headers

```console
sudo dnf install -y wayland-devel wayland-protocols-devel mesa-libEGL-devel mesa-libGLES-devel
```

You should be able to run the toolbar example app now.

```
swift run --traits Toolbar SwiftWayland
```

-----

## Design

As mentioned in the Resources and References section this is inspired from Clay
as well as a blog series by Ryan Fleury.

One of the goals of the project was to leverage Swift’s `resultBuilder` feature
in building this UI framework for a declarative interface. In doing so the 
Block come together as a tree which is parsed by a few what I call Walkers.

### Attribute Walker

This is the first walk over the tree which is responsible for collecting the 
attributes and assembling the basic structure of the three. This step may be 
unnecessary in the long run but the goal is to have all the attributes for a 
given block known. This also builds up a tree structure which can be used in 
following phases to look up the parent, siblings or children of the current 
block.

### Size Walker

The next walker is the size walker which is responsible for computing known 
sizes of any blocks. This is done using the attributes from the previous phase 
so that padding, .fixed height and width modifiers can be applied. to compute 
the consumed areas of the layout. This information will be used in the 
fallowing Grow phase to compute the sizes of features that expand to the area 
they may consume.

#### Sizing

Sizing can come in three forms `.fit`, `.grow` and `.fixed`. Fit sizing is used
to fit around the size of it’s children. This is the default sizing. A leaf 
node of fit sizing with no text or child elements will be a 0 x 0 rect and will
be observed but not visible on the screen. The grow modifier is used to specif 
that the element should expand and fill as much space as it can within it’s 
direction container. Lastly the fixed modifier is used to hard code what the 
size will be through out the algorithm. If the child of the fixed size 
container are larger then the specified size they are to be clipped and not or 
only partially visible.

#### Direction

The direction blocks are a form of container that specify everything within 
this block will be laid out in this orientation defaulting to left to right and
top to bottom. These can be nested to create more complex layouts and are 
`.fit` by default but can be specified with grow or fixed to create backgrounds
or general rectangles.

### Grow Walker

The Grow walker uses the attributes and sizes computed in the previous phases 
to compute the sizes of the remaining elements that have a dynamic size. This 
has to be after the sizing phase as we must know how but the siblings of a grow
element are to know how much area we have to expand to.

### Position Walker

This is the last phase as at this point we know all the sizes of all of the 
elements and can now compute there final positions. I’m not sure if it is best 
to do this is in pre or post order. But after this phase we will have enough 
information to start rendering the shapes and text on to the screen.

-----

## Resources & References

Helpful resources for getting to this point in the project.

**[The Interaction Medium by Ryan Fleury](https://www.rfleury.com/p/ui-part-1-the-interaction-medium)**

- Good series about programming UI
- Starting point for shader code

**[Clay Layout Algorithm by Nic Barker](https://www.youtube.com/watch?v=by9lQvpvMIc)**

- Inspired the layout algorithm implementation

**[Learn Wayland by writing a GUI from scratch](https://gaultier.github.io/blog/wayland_from_scratch.html)**

- Step-by-step guide to setting up a Wayland client

-----

## Development

See `.dev/` directory for development setup, testing, and known issues.
