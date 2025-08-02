#version 330 core

in vec3 fragPosition;
in vec3 fragNormal;
in vec2 fragTexCoord;

out vec4 FragColor;

uniform sampler2D diffuseTexture;
uniform sampler2D normalTexture;
uniform vec3 viewPos;

// Lighting uniforms
uniform vec4 ambientColor;
uniform float ambientStrength;

// Point lights (for torches, lava, etc.)
#define MAX_POINT_LIGHTS 32
uniform int numPointLights;
uniform vec3 pointLightPositions[MAX_POINT_LIGHTS];
uniform vec4 pointLightColors[MAX_POINT_LIGHTS];
uniform float pointLightIntensities[MAX_POINT_LIGHTS];
uniform float pointLightRanges[MAX_POINT_LIGHTS];

// Directional light (global illumination)
uniform vec3 dirLightDirection;
uniform vec4 dirLightColor;
uniform float dirLightIntensity;

uniform vec4 fresnelColor;
// Fog parameters
uniform vec4 fogColor;
uniform float fogDensity;
uniform float fogStart;
uniform float fogEnd;

// Post-processing parameters
uniform float saturation;
uniform float contrast;
uniform float brightness;
uniform float gamma;

// Noise function for subtle texture variation
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// Calculate point light contribution
vec3 calculatePointLight(vec3 lightPos, vec4 lightColor, float intensity, float range, vec3 fragPosition, vec3 fragNormal, vec3 albedo) {
    vec3 lightDir = lightPos - fragPosition;
    float distance = length(lightDir);
    lightDir = normalize(lightDir);
    
    // Smooth falloff (not physically accurate but looks good)
    float attenuation = 1.0 - smoothstep(0.0, range, distance);
    attenuation *= attenuation; // Quadratic falloff for more dramatic lighting
    
    // Simple diffuse lighting with slight wrap-around for softer shadows
    float diff = max(dot(fragNormal, lightDir) * 0.8 + 0.2, 0.0);
    
    // Slight rim lighting effect
    vec3 viewDir = normalize(viewPos - fragPosition);
    float rim = 1.0 - max(dot(viewDir, fragNormal), 0.0);
    rim = pow(rim, 2.0) * 0.3;
    
    return (diff + rim) * lightColor.rgb * intensity * attenuation * albedo;
}


vec3 colorGrade(vec3 color) {

    // Adjust brightness and contrast
    color = (color - 0.5) * contrast + 0.5 + brightness;
    
    // Saturation adjustment
    vec3 grayscale = vec3(dot(color, vec3(0.299, 0.587, 0.114)));
    color = mix(grayscale, color, saturation);
    
    // Slight warm/cool tint based on luminance
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec3 warmTint = vec3(1.0, 0.95, 0.85);
    vec3 coolTint = vec3(0.85, 0.95, 1.0);
    vec3 tint = mix(coolTint, warmTint, luminance);
    color *= tint;
    
    return color;
}


float calculateDirectionalFresnel(vec3 viewDir, vec3 normal, vec3 rimDirection, float rimPower,
 float rimIntensity, float rimBias) {
    // Base fresnel calculation
    float fresnel = 1.0 - max(dot(viewDir, normal), 0.0);
    
    // Soft base rim using rimPower for main control
    float softRim = pow(fresnel, rimPower * 0.5); // Half power for softer base
    softRim = smoothstep(0.0, 0.8, softRim) * 0.3;
    
    // Sharp accent rim using rimPower for consistent control
    float sharpRim = pow(fresnel, rimPower); // Double power for sharper accent
    sharpRim = smoothstep(0.2, 0.8, sharpRim) * 0.7;
    
    // Combine the two rim effects
    float finalRim = softRim + sharpRim;
    
    // Directional bias - stronger rim in the direction of rimDirection
    float directionalFactor = max(dot(normal, rimDirection), 0.0);
    directionalFactor = pow(directionalFactor, 2.0); // Square for smoother falloff
    
    // Combine fresnel with directional bias
    float directionalFresnel = finalRim * (rimBias + directionalFactor * (1.0 - rimBias));
    
    return directionalFresnel * rimIntensity;
}

// ACES tone mapping (more cinematic)
vec3 acesToneMapping(vec3 color) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0, 1.0);
}


// Vibrance (more natural than saturation)
vec3 adjustVibrance(vec3 color, float vibrance) {
    float maxComponent = max(max(color.r, color.g), color.b);
    float minComponent = min(min(color.r, color.g), color.b);
    float saturation = maxComponent - minComponent;
    
    // Apply vibrance more to less saturated colors
    float vibranceAmount = (1.0 - saturation) * vibrance;
    vec3 grayscale = vec3(dot(color, vec3(0.299, 0.587, 0.114)));
    
    return mix(grayscale, color, 1.0 + vibranceAmount);
}


void main() {
    vec4 texColor = texture(diffuseTexture, fragTexCoord);
    vec3 albedo = texColor.rgb;
    
     // Subtle texture noise for variation
     //vec2 noiseCoord = fragTexCoord * 64.0 + time * 0.1;
     //float noise = random(noiseCoord) * 0.05;
     //albedo += noise;
    
    vec3 normal = normalize(fragNormal);
    // vec3 normal_from_tex = texture(normalTexture, fragTexCoord).xyz;
    // if (normal_from_tex.b > 0){
    //     //normal = normalize(normal_from_tex * 2.0 - 1.0) * 0.5; 
    // }
    
    vec3 ambient = ambientColor.rgb * ambientStrength * albedo;
    
    float dirDiff = max(dot(normal, -dirLightDirection) * 0.7 + 0.3, 0.0);
    vec3 directional = dirLightColor.rgb * dirLightIntensity * dirDiff * albedo;
    
    // Point lights accumulation
    vec3 pointLighting = vec3(0.0);
    for(int i = 0; i < min(numPointLights, MAX_POINT_LIGHTS); i++) {
        pointLighting += calculatePointLight(
            pointLightPositions[i],
            pointLightColors[i],
            pointLightIntensities[i],
            pointLightRanges[i],
            fragPosition,
            normal,
            albedo
        );
    }
    
    //float fresnel = calculateFresnel(fragPosition,viewPos,fragNormal,0.1,0.1,0.1);
    // Combine all lighting
    vec3 finalColor = ambient + directional + pointLighting;
    
    float fresnelPower = 30;
    float fresnelIntensity = .1;
    float fresnelBias = 1;
    vec3 viewDir = normalize(viewPos - fragPosition);

    vec3 rimDirection = -dirLightDirection;
    vec4 fresnel = calculateDirectionalFresnel(
        viewDir,
        normal,
        rimDirection,
        fresnelPower,
        fresnelIntensity,
        fresnelBias) * fresnelColor;

    finalColor += fresnel.rgb;
    // Apply fog
    //float fogFactor = calculateFog(fragPosition, viewPos);
    //finalColor = mix(finalColor, fogColor.rgb, fogFactor);
    
    // Color grading and post-processing
    finalColor = colorGrade(finalColor);

    finalColor = adjustVibrance(finalColor,0.3);

    finalColor = acesToneMapping(finalColor);
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / gamma));
    
    // Ensure we don't exceed 1.0 while preserving color relationships
    float maxComponent = max(max(finalColor.r, finalColor.g), finalColor.b);
    if(maxComponent > 1.0) {
        finalColor /= maxComponent;
    }
    
    FragColor = vec4(finalColor, texColor.a);
}