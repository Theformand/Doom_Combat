package main
import "core:c"
import "core:log"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"

Light :: struct {
  position:  float3,
  color:     rl.Color,
  intensity: float,
  range:     float,
  direction: float3, //only used for the 1 allowed directional light
}

LightType :: enum {
  DIRECTIONAL = 0,
  POINT       = 1,
}


SceneLightingValues :: struct {
  fogColor:        rl.Color,
  ambientColor:    rl.Color,
  fogDensity:      float,
  fogStart:        float,
  fogEnd:          float,
  saturation:      float,
  contrast:        float,
  brightness:      float,
  gamma:           float,
  ambientStrength: float,
}


scene_lighting_values: SceneLightingValues
scene_lights: [dynamic]Light
default_shader: rl.Shader
scene_lights_dirty: bool
ts_last_shader_file_mod: c.long

init_lighting :: proc() 
{
  scene_lights = make([dynamic]Light)
  append(&update_procs, update_scene_lights)

  scene_lighting_values = {
    ambientColor    = rl.DARKGRAY,
    ambientStrength = .4,
    saturation      = 1.1,
    contrast        = 1.2,
    brightness      = 0.1,
    gamma           = 2.2,
    fogDensity      = 0.002,
    fogColor        = rl.GRAY,
    fogStart        = -2000,
    fogEnd          = 3000,
  }

  sun_light = Light {
    color     = rl.DARKBLUE,
    position  = camera.position,
    direction = camera.position,
    intensity = .1,
  }

  default_shader = rl.LoadShader(PATH_SHADERS + "default_lighting.vs", PATH_SHADERS + "default_lighting.fs")

  set_default_uniforms()
  synty_mat = rl.LoadMaterialDefault()
  synty_mat.shader = default_shader


  //rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "ambientColor"), &color_scene_ambient, .VEC4)
}

set_default_uniforms :: proc() 
{

  default_shader.locs[rl.ShaderLocationIndex.MAP_ALBEDO] = i32(rl.GetShaderLocation(default_shader, "diffuseTexture"))
  default_shader.locs[rl.ShaderLocationIndex.MAP_NORMAL] = i32(normalLoc)
  default_shader.locs[rl.ShaderLocationIndex.MATRIX_MVP] = i32(rl.GetShaderLocation(default_shader, "mvp"))
  default_shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = i32(rl.GetShaderLocation(default_shader, "viewPos"))
  //default_shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = i32(rl.GetShaderLocationAttrib(default_shader, "instanceTransform"))

  sun_color := rl.ColorNormalize(sun_light.color)
  amb_color := rl.ColorNormalize(scene_lighting_values.ambientColor)
  fog_color := rl.ColorNormalize(scene_lighting_values.fogColor)

  //scene params uniforms
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "fogColor"), &fog_color, .VEC4)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "fogDensity"), &scene_lighting_values.fogDensity, .FLOAT)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "fogStart"), &scene_lighting_values.fogStart, .FLOAT)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "fogEnd"), &scene_lighting_values.fogEnd, .FLOAT)

  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "dirLightDirection"), &sun_light.direction, .VEC3)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "dirLightColor"), &sun_color, .VEC4)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "dirLightIntensity"), &sun_light.intensity, .FLOAT)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "ambientColor"), &amb_color, .VEC4)

  //Lighting uniforms
  loc_light_positions = rl.GetShaderLocation(default_shader, "pointLightPositions")
  loc_light_colors = rl.GetShaderLocation(default_shader, "pointLightColors")
  loc_intensities = rl.GetShaderLocation(default_shader, "pointLightIntensities")
  loc_ranges = rl.GetShaderLocation(default_shader, "pointLightRanges")
  loc_light_count = rl.GetShaderLocation(default_shader, "numPointLights")

  rl.SetShaderValue(
    default_shader,
    rl.GetShaderLocation(default_shader, "ambientStrength"),
    &scene_lighting_values.ambientStrength,
    .FLOAT,
  )

  //postprocessing
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "saturation"), &scene_lighting_values.saturation, .FLOAT)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "contrast"), &scene_lighting_values.contrast, .FLOAT)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "brightness"), &scene_lighting_values.brightness, .FLOAT)
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "gamma"), &scene_lighting_values.gamma, .FLOAT)
}


create_point_light :: proc(position: float3, color: rl.Color, intensity, range: float) -> Light 
{
  light := Light {
    position  = position,
    color     = color,
    intensity = intensity,
    range     = range,
  }
  append(&scene_lights, light)
  scene_lights_dirty = true
  return light
}

update_scene_lights :: proc() 
{

  //SHADER HOT RELOAD - BORKED
  // if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.R) {
  // log.debug("RELOAD")
  // ts_shader_mod := rl.GetFileModTime(PATH_SHADERS + "default_lighting.fs")
  // if ts_shader_mod != ts_last_shader_file_mod {
  // ts_last_shader_file_mod = ts_shader_mod
  // updated_shader := rl.LoadShader(PATH_SHADERS + "default_lighting.vs", PATH_SHADERS + "default_lighting.fs")
  // 
  // if updated_shader.id != gl.GetShaderIdDefault() {
  // 
  // rl.UnloadShader(default_shader)
  // default_shader = updated_shader
  // set_default_uniforms()
  // synty_mat.shader = default_shader
  // }
  // }
  // }

  if !scene_lights_dirty {
    return
  }
  scene_lights_dirty = false
  positions := make([dynamic]float3, context.temp_allocator)
  colors := make([dynamic]float4, context.temp_allocator)
  intensities := make([dynamic]float, context.temp_allocator)
  ranges := make([dynamic]float, context.temp_allocator)

  for light in scene_lights {
    append(&ranges, light.range)
    append(&intensities, light.intensity)
    color_f32 := rl.ColorNormalize(light.color)
    append(&colors, color_f32)
    append(&positions, light.position)
  }

  count := i32(len(scene_lights))
  rl.SetShaderValueV(default_shader, loc_ranges, raw_data(ranges), rl.ShaderUniformDataType.FLOAT, count)
  rl.SetShaderValueV(default_shader, loc_intensities, raw_data(intensities), rl.ShaderUniformDataType.FLOAT, count)
  rl.SetShaderValueV(default_shader, loc_light_colors, raw_data(colors), rl.ShaderUniformDataType.VEC4, count)
  rl.SetShaderValueV(default_shader, loc_light_positions, raw_data(positions), rl.ShaderUniformDataType.VEC3, count)
  rl.SetShaderValue(default_shader, loc_light_count, &count, rl.ShaderUniformDataType.INT)

  sun_color := rl.ColorNormalize(sun_light.color)
  //sunlight
  rl.SetShaderValue(default_shader, loc_dirlight_pos, &sun_light.position, rl.ShaderUniformDataType.VEC3)
  rl.SetShaderValue(default_shader, loc_dirlight_color, &sun_color, rl.ShaderUniformDataType.VEC4)
  rl.SetShaderValue(default_shader, loc_dir_light_intensity, &sun_light.intensity, rl.ShaderUniformDataType.FLOAT)


}
