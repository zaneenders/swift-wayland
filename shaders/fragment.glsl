#version 300 es
precision mediump float;

uniform sampler2D uTex;
in vec2 vTex;
out vec4 fragColor;

void main() {
  float a = texture(uTex, vTex).r;
  fragColor = vec4(1.0, 1.0, 1.0, a);
}
