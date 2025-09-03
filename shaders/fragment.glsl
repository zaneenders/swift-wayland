#version 300 es
precision mediump float;

uniform sampler2D uTex;

in vec2 v_uv;
in vec4 v_color;

out vec4 fragColor;

void main() {
  vec4 tex = texture(uTex, v_uv);
  fragColor = tex * v_color;
}
