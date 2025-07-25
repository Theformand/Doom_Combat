/**********************************************************************************************
*
*   raylib.lights - Some useful functions to deal with lights data
*
*   CONFIGURATION:
*
*   #define RLIGHTS_IMPLEMENTATION
*       Generates the implementation of the library into the included file.
*       If not defined, the library is in header only mode and can be included in other headers 
*       or source files without problems. But only ONE file should hold the implementation.
*
*   LICENSE: zlib/libpng
*
*   Copyright (c) 2017-2024 Victor Fisac (@victorfisac) and Ramon Santamaria (@raysan5)
*
*   This software is provided "as-is", without any express or implied warranty. In no event
*   will the authors be held liable for any damages arising from the use of this software.
*
*   Permission is granted to anyone to use this software for any purpose, including commercial
*   applications, and to alter it and redistribute it freely, subject to the following restrictions:
*
*     1. The origin of this software must not be misrepresented; you must not claim that you
*     wrote the original software. If you use this software in a product, an acknowledgment
*     in the product documentation would be appreciated but is not required.
*
*     2. Altered source versions must be plainly marked as such, and must not be misrepresented
*     as being the original software.
*
*     3. This notice may not be removed or altered from any source distribution.
*
**********************************************************************************************/

package main
import rl "vendor:raylib"

//----------------------------------------------------------------------------------
// Defines and Macros
//----------------------------------------------------------------------------------
MAX_LIGHTS :: 4 // Max dynamic lights supported by shader

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

// Light data
Light :: struct {
  type:           int,
  enabled:        bool,
  position:       float3,
  target:         float3,
  color:          rl.Color,
  attenuation:    float,

  // Shader locations
  enabledLoc:     int,
  typeLoc:        int,
  positionLoc:    int,
  targetLoc:      int,
  colorLoc:       int,
  attenuationLoc: int,
}

// Light type
LightType :: enum int {
  LIGHT_DIRECTIONAL = 0,
  LIGHT_POINT       = 1,
}


lightsCount: int

// Create a light and get shader locations
create_light :: proc(type: int, position, target: float3, color: rl.Color, shader: rl.Shader) -> Light {
  light: Light

  if (lightsCount < MAX_LIGHTS) {
    light.enabled = true
    light.type = type
    light.position = position
    light.target = target
    light.color = color

    // NOTE: Lighting shader naming must be the provided ones
    light.enabledLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].enabled", lightsCount))
    light.typeLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].type", lightsCount))
    light.positionLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].position", lightsCount))
    light.targetLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].target", lightsCount))
    light.colorLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].color", lightsCount))
    update_lightValues(shader, &light)
    lightsCount += 1
  }
  return light
}


// Send light properties to shader
// NOTE: Light shader locations should be available 
update_lightValues :: proc(shader: rl.Shader, light: ^Light) {
  // Send to shader light enabled state and type
  rl.SetShaderValue(shader, light.enabledLoc, &light.enabled, rl.ShaderUniformDataType.INT)
  rl.SetShaderValue(shader, light.typeLoc, &light.type, rl.ShaderUniformDataType.INT)

  // Send to shader light position values
  position := [3]float{light.position.x, light.position.y, light.position.z}
  rl.SetShaderValue(shader, light.positionLoc, &position, rl.ShaderUniformDataType.VEC3)

  // Send to shader light target position values
  target := [3]float{light.target.x, light.target.y, light.target.z}
  rl.SetShaderValue(shader, light.targetLoc, &target, rl.ShaderUniformDataType.VEC3)

  // Send to shader light color values

  color := [4]float {
    float(light.color.r) / float(255),
    float(light.color.g) / float(255),
    float(light.color.b) / float(255),
    float(light.color.a) / float(255),
  }
  rl.SetShaderValue(shader, light.colorLoc, &color, rl.ShaderUniformDataType.VEC4)
}
