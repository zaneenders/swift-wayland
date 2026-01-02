#version 300 es
// === VERTEX SHADER OPTIMIZATION FOR BORDER RENDERING ===
// This shader implements the distance field approach for efficient border rendering
// Key optimization: Pass pixel position to fragment shader instead of per-pixel calculations

layout(location=0) in vec2 a_quad;    // [-1,1] corners - defines which vertex of the quad we're processing
layout(location=1) in vec2 i_dst_p0;  // pixel-space top-left - rectangle's top-left corner in screen pixels
layout(location=2) in vec2 i_dst_p1;  // pixel-space bottom-right - rectangle's bottom-right corner in screen pixels
layout(location=3) in vec2 i_src_p0;  // UV-space top-left - texture coordinates (usually 0,0)
layout(location=4) in vec2 i_src_p1;  // UV-space bottom-right - texture coordinates (usually 1,1)
layout(location=5) in vec4 i_color;  // Main rectangle color
layout(location=6) in vec4 i_border_color;  // Border color (rgba) - optimized: could be removed later
layout(location=7) in float i_border_width;  // Border width in pixels - optimized: could be removed later

uniform vec2 uRes;  // Screen resolution (width, height) for coordinate conversion

// === OPTIMIZED INTERPOLATING VALUES ===
// These values are interpolated across the quad by GPU hardware (free linear interpolation)
out vec2 v_uv;              // Texture coordinates interpolated across the quad
out vec4 v_color;           // Color interpolated across the quad (can be flat since we don't interpolate)
out vec4 v_border_color;    // Border color (flat - same for all vertices)
out float v_border_width;   // Border width (flat - same for all vertices)
out vec2 v_dst_size;        // Rectangle dimensions in pixels (flat - same for all vertices)
out vec2 v_position;        // NEW: Actual pixel position within this rectangle

// === COORDINATE SYSTEM CONVERSION ===
// Convert pixel coordinates to Normalized Device Coordinates (NDC)
// NDC ranges from (-1,-1) at bottom-left to (1,1) at top-right
vec2 px_to_ndc(vec2 p) {
    // Map [0, screen_width] -> [-1, 1]
    float x = (p.x / uRes.x) * 2.0 - 1.0;
    // Map [0, screen_height] -> [1, -1] (flipped because screen coords start at top)
    float y = 1.0 - (p.y / uRes.y) * 2.0;
    return vec2(x, y);
}

void main() {
    // === BARYCENTRIC COORDINATE CALCULATION ===
    // a_quad contains (-1,-1), (1,-1), (-1,1), (1,1) for the 4 quad vertices
    // Adding 1 gives (0,0), (2,0), (0,2), (2,2)
    // Multiplying by 0.5 gives (0,0), (1,0), (0,1), (1,1)
    // This 't' is the interpolation factor for barycentric coordinates
    vec2 t = 0.5 * (a_quad + 1.0);

    // === PIXEL POSITION CALCULATION ===
    // Mix between top-left and bottom-right corners using barycentric coordinates
    // This gives us the actual screen pixel position for this vertex
    vec2 ppx = mix(i_dst_p0, i_dst_p1, t);

    // Convert to NDC and set final vertex position
    gl_Position = vec4(px_to_ndc(ppx), 0.0, 1.0);

    // === INTERPOLATING VALUES SETUP ===
    // These values will be automatically interpolated across the quad by GPU

    // UV coordinates for texture sampling (interpolated)
    v_uv = mix(i_src_p0, i_src_p1, t);

    // Colors (flat qualifiers tell GPU not to interpolate, saving cycles)
    v_color = i_color;
    v_border_color = i_border_color;
    v_border_width = i_border_width;

    // Rectangle dimensions (flat - same for all vertices)
    v_dst_size = i_dst_p1 - i_dst_p0;

    // === KEY OPTIMIZATION: Pass pixel position to fragment shader ===
    // Instead of calculating position in fragment shader for every pixel, 
    // we pass it as an interpolated varying. The GPU interpolates this for free!
    // This reduces O(width*height) calculations to O(4) vertex calculations.
    v_position = t * v_dst_size;  // Convert barycentric coords to pixel position within rect
}
