# Not actually using the GPU.

For Asahi linux adding the following lines to the `.config/hypr/hyprland.conf` 
does fix the error with running on the GPU but is sluggish. I assume this is 
because the driver isn’t as optimize because this is a very unbeaten path.

```
env = MESA_LOADER_DRIVER_OVERRIDE,asahi
env = WLR_RENDERER,vulkan
```
