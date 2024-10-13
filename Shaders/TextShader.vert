#version 430 core
layout (location = 0) in vec2 vertex;
layout (location = 1) in vec2 UV;
out vec2 TexCoords;

uniform mat4 projection;

void main()
{
    gl_Position = projection * vec4(vertex.xy, 0.5, 1.0);
    TexCoords = UV;
}  