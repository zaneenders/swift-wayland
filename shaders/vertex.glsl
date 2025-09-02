#version 300 es
layout(location=0) in vec3 positions;
layout(location=1) in vec3 colors;

out vec3 v_vertexColors;

void main() {
    v_vertexColors = colors;
    gl_Position = vec4(positions, 1.0);
}
