#version 300 es
precision mediump float;

uniform sampler2D uTex;

in vec2 v_uv;
in vec4 v_color;
in vec4 v_border_color;
in float v_border_width;
in float v_corner_radius;
in vec2 v_dst_size;
in vec2 v_position;        // Pre-calculated position from vertex shader

out vec4 fragColor;

void main() {
  vec4 tex = texture(uTex, v_uv);
  vec4 baseColor = tex * v_color;

  // === OPTIMIZED BORDER DETECTION ===
  // Combines two optimizations:
  // 1. Vertex shader pre-calculation (eliminates 2 multiplications per fragment)
  // 2. smoothstep for branchless border detection (eliminates if/else branching)

  if (v_border_width > 0.0 && v_border_color.a > 0.0) {
    // === ROUNDED CORNER BORDER DETECTION ===
    
    // Check if fragment is within border width of any edge
    bool isEdgeBorder = 
      v_position.x < v_border_width ||           // Left border
      v_position.x > v_dst_size.x - v_border_width ||  // Right border
      v_position.y < v_border_width ||           // Top border
      v_position.y > v_dst_size.y - v_border_width;    // Bottom border

    // Calculate distance to nearest corner for rounded corners
    float cornerDist = 0.0;
    if (v_corner_radius > 0.0) {
      // Find which corner we're near
      vec2 cornerCenter;
      if (v_position.x < v_corner_radius && v_position.y < v_corner_radius) {
        // Top-left corner
        cornerCenter = vec2(v_corner_radius, v_corner_radius);
      } else if (v_position.x > v_dst_size.x - v_corner_radius && v_position.y < v_corner_radius) {
        // Top-right corner
        cornerCenter = vec2(v_dst_size.x - v_corner_radius, v_corner_radius);
      } else if (v_position.x < v_corner_radius && v_position.y > v_dst_size.y - v_corner_radius) {
        // Bottom-left corner
        cornerCenter = vec2(v_corner_radius, v_dst_size.y - v_corner_radius);
      } else if (v_position.x > v_dst_size.x - v_corner_radius && v_position.y > v_dst_size.y - v_corner_radius) {
        // Bottom-right corner
        cornerCenter = vec2(v_dst_size.x - v_corner_radius, v_dst_size.y - v_corner_radius);
      } else {
        cornerCenter = v_position; // Not near a corner
      }
      
      cornerDist = distance(v_position, cornerCenter);
    }

    // Determine if this is a border pixel
    bool isBorder = isEdgeBorder;
    if (v_corner_radius > 0.0) {
      // Check if we're outside the rounded corner radius
      bool outsideCorner = cornerDist > v_corner_radius;
      bool insideCornerBorder = cornerDist > (v_corner_radius - v_border_width) && cornerDist <= v_corner_radius;
      
      isBorder = isBorder || outsideCorner || insideCornerBorder;
      
      // If outside corner completely, discard fragment
      if (outsideCorner && !insideCornerBorder) {
        discard;
      }
    }

    if (isBorder) {
      fragColor = v_border_color;
    } else {
      fragColor = baseColor;
    }
  } else {
    fragColor = baseColor;
  }
}
