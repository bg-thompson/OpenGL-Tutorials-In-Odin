#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

out vec3 ourColor;

uniform float k;

float kk = 0.5;

uniform mat3 model_mat;
uniform mat3 camera_to_x_mat;
uniform mat4 view_mat;
uniform mat4 perspective_mat;

void main() {

	gl_Position = perspective_mat * view_mat * vec4(camera_to_x_mat * model_mat * aPos, 1);
	ourColor    = aColor;
}
