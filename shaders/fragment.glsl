#version 310 es
precision mediump float;
uniform float u_anim;
out vec4 fragColor;
void main() {
    fragColor = vec4(u_anim, 0.3, 1.0 - u_anim, 1.0);
}
