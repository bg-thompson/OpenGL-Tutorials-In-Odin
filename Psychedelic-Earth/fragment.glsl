#version 330 core

in vec2 TexCoords;
out vec4 FragColor;

uniform sampler2D earth_texture;

uniform mat3 psych_mat;

vec4 NormalColor;

void main() {
    NormalColor = texture(earth_texture, TexCoords);
    FragColor = vec4( psych_mat * NormalColor.rgb, NormalColor.a);
}
