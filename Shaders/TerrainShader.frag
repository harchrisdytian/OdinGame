#version 330 core

out vec4 FragColor;

in float Height;

void main()
{
    float h = (Height - 32)/225.0f;	// shift and scale the height into a grayscale value
    FragColor = vec4(h, h*1.2, h, 1.0);
}