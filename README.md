# Swift Wayland Client

A minimal graphics client using Wayland.

Currently I am using `wayland-client` to get this up and running but ideally 
this will be down without this dependency.

## Setup

Install dependencies

```console
sudo dnf install wayland-protocols-devel
```

## Dev

Generate xdg-shell files from `protocols/xdg-shell.xml`

```console
wayland-scanner client-header < xdg-shell.xml > xdg-shell-client-protocol.h
wayland-scanner private-code < xdg-shell.xml > xdg-shell-protocol.c
```