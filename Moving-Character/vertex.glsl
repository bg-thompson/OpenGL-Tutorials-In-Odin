#version 330 core

layout (location = 0) in vec2 xyPos;
layout (location = 1) in vec2 aTexCoords;
out vec2 TexCoords;

uniform mat2 projection;
uniform mat4 translation;

void main() {
	gl_Position = translation * vec4(projection * xyPos, 0, 1);
	TexCoords = aTexCoords;
}
