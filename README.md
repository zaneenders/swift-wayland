# Swift Wayland Client

This is [Wayland](https://wayland-book.com/introduction.html) client app using 
[Swift NIO](https://github.com/apple/swift-nio) and 
[wayland from scratch](https://gaultier.github.io/blog/wayland_from_scratch.html)
 as a reference.

## Run

```console
swift run --swift-sdk aarch64-swift-linux-musl -c release
# or
swift run --swift-sdk x86_64-swift-linux-musl -c release
```

Requires Swift 6.2 and compatible with static Linux SDK. See 
[install swift](https://www.swift.org/install/linux/) for help setting up 
swift.