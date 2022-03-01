#version 330 core

in vec2 TexCoords;
out vec4 FragColor;

uniform sampler2D glyph_texture;

void main() {
	FragColor = vec4(0.5, 1, 1, texture(glyph_texture, TexCoords).r);
	//FragColor   = vec4(TexCoords.x,TexCoords.y,1,1);
}
