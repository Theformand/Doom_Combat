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

//// Enhanced fog calculation with height-based density
//float calculateFog(vec3 worldPos, vec3 viewPos) {
//    float distance = length(worldPos - viewPos);
//    
//    // Linear fog transition between fogStart and fogEnd
//    float linearFog = (distance - fogStart) / (fogEnd - fogStart);
//    linearFog = clamp(linearFog, 0.0, 1.0);
//    
//    // Height-based fog (denser at lower elevations)
//    float heightFactor = exp(-max(worldPos.y - 50.0, 0.0) * 0.02);
//    float adjustedDensity = fogDensity * (1.0 + heightFactor);
//    
//    // Exponential fog with smooth transition
//    float exponentialFog = 1.0 - exp(-adjustedDensity * distance * distance);
//    
//    // Combine linear and exponential fog
//    float fogFactor = max(linearFog, exponentialFog);
//    return clamp(fogFactor, 0.0, 1.0);
//}

// float calculateFog(vec3 worldPos, vec3 viewPos) {
//     // Calculate distance in the XZ plane (top-down perspective)
//     float distance = length(worldPos.xz - viewPos.xz);
    
//     // Define fog parameters
//     float fogStart = 10.0; // Distance where fog starts
//     float fogEnd = 50.0;   // Distance where fog is fully opaque
//     float fogDensity = 0.002; // Controls fog thickness

//     // Linear fog for smooth transition
//     float linearFog = smoothstep(fogStart, fogEnd, distance);
    
//     // Optional: Slight height influence for subtle vertical variation
//     float heightFactor = smoothstep(-10.0, 10.0, worldPos.y); // Adjusts fog based on height
//     float adjustedDensity = fogDensity * (0.8 + 0.2 * heightFactor); // Subtle height modulation
    
//     // Exponential fog for natural falloff
//     float exponentialFog = 1.0 - exp(-adjustedDensity * distance);
    
//     // Blend linear and exponential fog for balanced effect
//     float fogFactor = mix(linearFog, exponentialFog, 0.5);
    
//     return clamp(fogFactor, 0.0, 1.0);
// }

// Color grading function
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

float calculateFresnel(vec3 worldPos, vec3 viewPos, vec3 normal, float fresnelPower, float fresnelScale, float fresnelBias) {
    // Normalize inputs
    vec3 normalizedNormal = normalize(normal);
    vec3 viewDir = normalize(viewPos - worldPos);
    
    // Calculate view angle (dot product between normal and view direction)
    float fresnelTerm = max(dot(normalizedNormal, viewDir), 0.0);
    
    // Apply Fresnel equation with tunable parameters
    float fresnel = fresnelBias + fresnelScale * pow(1.0 - fresnelTerm, fresnelPower);
    
    return clamp(fresnel, 0.0, 1.0);
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
    
    // Ambient lighting with slight color variation
    vec3 ambient = ambientColor.rgb * ambientStrength * albedo;
    
    // Directional lighting (global illumination)
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
    
    // Apply fog
    //float fogFactor = calculateFog(fragPosition, viewPos);
    //finalColor = mix(finalColor, fogColor.rgb, fogFactor);
    
    // Color grading and post-processing
    finalColor = colorGrade(finalColor);
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / gamma));
    
    // Ensure we don't exceed 1.0 while preserving color relationships
    float maxComponent = max(max(finalColor.r, finalColor.g), finalColor.b);
    if(maxComponent > 1.0) {
        finalColor /= maxComponent;
    }
    
    FragColor = vec4(finalColor, texColor.a);
}