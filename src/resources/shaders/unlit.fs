#version 330

uniform vec4 colDiffuse; 
in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

void main()
{
     finalColor = colDiffuse;
}