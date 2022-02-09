#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

out vec3 ourColor;

uniform float theta;

void main() {

	mat3 rotation_mat = mat3(
		cos(theta), sin(-theta), 0,
		sin(theta), cos( theta), 0,
		         0,           0, 1
	);

	gl_Position = vec4(rotation_mat * aPos, 1);
	ourColor    = aColor;
}
