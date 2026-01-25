# Use static Linux sdk.

Currently I am using `wayland-client.h` to get this up and running but ideally 
this will be down without this dependency. The goal of removing this dependency
is for 
[static cross compilation](https://www.swift.org/documentation/articles/static-linux-getting-started.html).

we are linking against a few wayland libraries to handle sending messages to
the wayland compositor. This can be switched out for our own server. I have had
some success getting [swift-nio](https://github.com/apple/swift-nio/pull/3316)
working but my implementation broke and decided to spend the time getting a
working project and figured I could come back to the feature.
