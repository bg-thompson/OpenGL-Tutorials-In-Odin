#version 330 core

in vec2 TexCoords;
out vec4 FragColor;

uniform sampler2D glyph_texture;

void main() {
        // Cyan color is: 0.5, 1, 1
        FragColor = vec4(0.5, 1, 1, texture(glyph_texture, TexCoords).r);
}
