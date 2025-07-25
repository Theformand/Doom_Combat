#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;  // Original scene
uniform sampler2D texture1;  // Bloom texture
uniform float intensity;
uniform int blendMode;

vec3 screen_blend(vec3 base, vec3 bloom) {
    return 1.0 - (1.0 - base) * (1.0 - bloom);
}

vec3 multiply_blend(vec3 base, vec3 bloom) {
    return base * bloom;
}

vec3 overlay_blend(vec3 base, vec3 bloom) {
    vec3 result;
    result.r = base.r < 0.5 ? 2.0 * base.r * bloom.r : 1.0 - 2.0 * (1.0 - base.r) * (1.0 - bloom.r);  
    result.g = base.g < 0.5 ? 2.0 * base.g * bloom.g : 1.0 - 2.0 * (1.0 - base.g) * (1.0 - bloom.g);
    result.b = base.b < 0.5 ? 2.0 * base.b * bloom.b : 1.0 - 2.0 * (1.0 - base.b) * (1.0 - bloom.b);
    return result;
}

vec3 soft_light_blend(vec3 base, vec3 bloom) {
    vec3 result;
    result.r = bloom.r < 0.5 ? base.r - (1.0 - 2.0 * bloom.r) * base.r * (1.0 - base.r) : 
               base.r + (2.0 * bloom.r - 1.0) * (sqrt(base.r) - base.r);
    result.g = bloom.g < 0.5 ? base.g - (1.0 - 2.0 * bloom.g) * base.g * (1.0 - base.g) : 
               base.g + (2.0 * bloom.g - 1.0) * (sqrt(base.g) - base.g);
    result.b = bloom.b < 0.5 ? base.b - (1.0 - 2.0 * bloom.b) * base.b * (1.0 - base.b) : 
               base.b + (2.0 * bloom.b - 1.0) * (sqrt(base.b) - base.b);
    return result;
}

vec3 linear_dodge_blend(vec3 base, vec3 bloom) {
    return min(base + bloom, 1.0);
}

void main() {
    vec4 scene = texture(texture0, fragTexCoord);
    vec4 bloom = texture(texture1, fragTexCoord) * intensity;
    
    vec3 result;
    
    if (blendMode == 0) {
        // Additive
        result = scene.rgb + bloom.rgb;
    } else if (blendMode == 1) {
        // Screen
        result = screen_blend(scene.rgb, bloom.rgb);
    } else if (blendMode == 2) {
        // Multiply
        result = multiply_blend(scene.rgb, bloom.rgb);
    } else if (blendMode == 3) {
        // Overlay
        result = overlay_blend(scene.rgb, bloom.rgb);
    } else if (blendMode == 4) {
        // Soft Light
        result = soft_light_blend(scene.rgb, bloom.rgb);
    } else if (blendMode == 5) {
        // Linear Dodge
        result = linear_dodge_blend(scene.rgb, bloom.rgb);
    } else {
        // Default to additive
        result = scene.rgb + bloom.rgb;
    }
    
    finalColor = vec4(result, scene.a);
}