//blur

#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;
uniform vec2 resolution;
uniform vec2 direction;
uniform float radius;

void main() {
    vec2 texelSize = 1.0 / resolution;
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;
    
    // Sample in the blur direction
    for (int i = -int(radius); i <= int(radius); i++) {
        vec2 offset = direction * float(i) * texelSize;
        float weight = exp(-float(i * i) / (2.0 * radius * radius));
        color += texture(texture0, fragTexCoord + offset) * weight;
        totalWeight += weight;
    }
    
    finalColor = color / totalWeight;
}