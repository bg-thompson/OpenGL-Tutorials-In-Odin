#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec3 aColor;

out vec3 ourColor;

uniform float theta;

void main() {

        mat2 rotation_mat = mat2(
                cos(theta), sin(-theta),
                sin(theta), cos( theta)
        );

        gl_Position = vec4(rotation_mat * aPos, 0, 1);
        ourColor    = aColor;
}
