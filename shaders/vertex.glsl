#version 300 es
layout(location=0) in vec2 a_quad;    // [-1,1] corners
layout(location=1) in vec2 i_dst_p0;  // pixel-space top-left
layout(location=2) in vec2 i_dst_p1;  // pixel-space bottom-right
layout(location=3) in vec2 i_src_p0;  // UV-space top-left
layout(location=4) in vec2 i_src_p1;  // UV-space bottom-right
layout(location=5) in vec4 i_color;

uniform vec2 uRes;

out vec2 v_uv;
out vec4 v_color;

vec2 px_to_ndc(vec2 p) {
    float x = (p.x / uRes.x) * 2.0 - 1.0;
    float y = 1.0 - (p.y / uRes.y) * 2.0;   // <-- only geometry Y flipped
    return vec2(x, y);
}

void main() {
    vec2 t   = 0.5 * (a_quad + 1.0);
    vec2 ppx = mix(i_dst_p0, i_dst_p1, t);
    gl_Position = vec4(px_to_ndc(ppx), 0.0, 1.0);

    v_uv    = mix(i_src_p0, i_src_p1, t);
    v_color = i_color;
}
