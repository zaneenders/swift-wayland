#version 300 es
precision mediump float;

in vec3 v_vertexColors;
out vec4 color;

void main() {
  color = vec4(v_vertexColors, 1.0);
}
