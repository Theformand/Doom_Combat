//bright

#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;
uniform float threshold;

void main() {
    vec4 color = texture(texture0, fragTexCoord);
    float brightness = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    //float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722))
    
    if (brightness > threshold) {
        finalColor = color;
    } else {
        finalColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}