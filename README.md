# Swift Wayland Client

A minimal graphics client using Wayland.

## Note

Currently I am using `wayland-client` to get this up and running but ideally 
this will be down without this dependency.

## Setup

Install Dependencies

- Wayland compositor ([Hyprland](https://hypr.land/))
- [Swift](https://www.swift.org/install)

## Run

```
swift run
```

## Dev

Install wayland headers

```console
sudo dnf install -y wayland-devel wayland-protocols-devel mesa-libEGL-devel mesa-libGLES-devel
```

Generate xdg-shell files from `protocols/xdg-shell.xml`

```console
wayland-scanner client-header < xdg-shell.xml > xdg-shell-client-protocol.h
wayland-scanner private-code < xdg-shell.xml > xdg-shell-protocol.c
```
