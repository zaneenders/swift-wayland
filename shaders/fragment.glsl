#version 300 es
precision mediump float;

uniform sampler2D uTex;

in vec2 v_uv;
in vec4 v_color;
in vec4 v_border_color;
in float v_border_width;
in vec2 v_dst_size;

out vec4 fragColor;

void main() {
  vec4 tex = texture(uTex, v_uv);
  vec4 baseColor = tex * v_color;
  
  // Calculate if this fragment is on the border
  if (v_border_width > 0.0 && v_border_color.a > 0.0) {
    vec2 pixelPos = v_uv * v_dst_size;
    
    // Check if fragment is within border width of any edge
    bool isBorder = 
      pixelPos.x < v_border_width ||           // Left border
      pixelPos.x > v_dst_size.x - v_border_width ||  // Right border
      pixelPos.y < v_border_width ||           // Top border
      pixelPos.y > v_dst_size.y - v_border_width;    // Bottom border
    
    if (isBorder) {
      fragColor = v_border_color;
    } else {
      fragColor = baseColor;
    }
  } else {
    fragColor = baseColor;
  }
}
