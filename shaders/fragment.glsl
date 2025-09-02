#version 300 es
precision mediump float;
in vec2 vUV;
uniform sampler2D uTex;
out vec4 fragColor;
void main() {
  float a = texture(uTex, vUV).r;
  fragColor = vec4(1.0, 1.0, 1.0, a);
}
