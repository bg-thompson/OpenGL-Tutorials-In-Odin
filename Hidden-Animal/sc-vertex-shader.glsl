#version 330 core

layout (location = 0) in vec2 aPos;
layout (location = 1) in vec3 aColor;

out vec3 ourColor;

uniform float cam_posx_wv;
uniform float cam_posy_wv;
uniform float window_w_wv;
uniform float window_h_wv;

void main() {
  // Convert (x,y) coordinates in pixels to [0,1] x [0,1] coordinates.
  float sposx = (aPos.x - cam_posx_wv) / window_w_wv;
  float sposy = (aPos.y - cam_posy_wv) / window_h_wv;
  // Convert [0,1] x [0,1] into [-1,1] x [-1,1]
  gl_Position = vec4(2 * sposx - 1, 2 * sposy - 1, 0, 1);

  // Pass the color on, unmodified.
  ourColor    = aColor;
}
