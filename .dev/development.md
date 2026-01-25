# Development

## Wayland Protocol

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
