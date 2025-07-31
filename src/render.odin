package main

import "core:fmt"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"

// Blend modes for bloom combination
BlendMode :: enum {
  ADDITIVE     = 0,
  SCREEN       = 1,
  MULTIPLY     = 2,
  OVERLAY      = 3,
  SOFT_LIGHT   = 4,
  LINEAR_DODGE = 5,
}

// Bloom configuration parameters
BloomConfig :: struct {
  intensity:   f32, // How strong the bloom effect is (0.0 - 2.0)
  threshold:   f32, // Brightness threshold for bloom (0.0 - 1.0) 
  blur_passes: i32, // Number of blur iterations for quality (1-10)
  blur_radius: f32, // Size of the blur effect (1.0 - 10.0)
  blend_mode:  BlendMode, // How bloom combines with the scene
}

// Bloom rendering context
BloomContext :: struct {
  screen_width:   i32,
  screen_height:  i32,

  // Render targets
  scene_target:   rl.RenderTexture2D, // Main scene
  bright_target:  rl.RenderTexture2D, // Bright pixels extraction
  blur_target_a:  rl.RenderTexture2D, // Ping-pong blur buffer A
  blur_target_b:  rl.RenderTexture2D, // Ping-pong blur buffer B

  // Shaders
  bright_shader:  rl.Shader, // Brightness extraction
  blur_shader:    rl.Shader, // Gaussian blur
  combine_shader: rl.Shader, // Final combine
  config:         BloomConfig,
}

init_bloom :: proc(ctx: ^BloomContext, width, height: i32) 
{
  ctx.screen_width = width
  ctx.screen_height = height

  // Initialize default config
  ctx.config = BloomConfig {
    intensity   = 5.2,
    threshold   = 0.9,
    blur_passes = 2,
    blur_radius = 20.0,
    blend_mode  = .SCREEN,
  }

  // Create render targets
  ctx.scene_target = rl.LoadRenderTexture(width, height)
  ctx.bright_target = rl.LoadRenderTexture(width, height)
  ctx.blur_target_a = rl.LoadRenderTexture(width, height)
  ctx.blur_target_b = rl.LoadRenderTexture(width, height)

  rl.SetTextureWrap(ctx.blur_target_a.texture, rl.TextureWrap.CLAMP)
  rl.SetTextureWrap(ctx.blur_target_b.texture, rl.TextureWrap.CLAMP)
  rl.SetTextureWrap(ctx.bright_target.texture, rl.TextureWrap.CLAMP)

  // Load shaders
  ctx.bright_shader = rl.LoadShader(nil, "resources/shaders/bright.fs")
  ctx.blur_shader = rl.LoadShader(nil, "resources/shaders/blur.fs")
  ctx.combine_shader = rl.LoadShader(nil, "resources/shaders/composite.fs")
}

cleanup_bloom :: proc(ctx: ^BloomContext) 
{
  rl.UnloadRenderTexture(ctx.scene_target)
  rl.UnloadRenderTexture(ctx.bright_target)
  rl.UnloadRenderTexture(ctx.blur_target_a)
  rl.UnloadRenderTexture(ctx.blur_target_b)

  rl.UnloadShader(ctx.bright_shader)
  rl.UnloadShader(ctx.blur_shader)
  rl.UnloadShader(ctx.combine_shader)
}

begin_bloom_scene :: proc(ctx: ^BloomContext) 
{
  rl.BeginTextureMode(ctx.scene_target)
  rl.ClearBackground(rl.DARKGRAY)
}

end_bloom_scene :: proc(ctx: ^BloomContext) 
{
  rl.EndTextureMode()
}

render_bloom :: proc(ctx: ^BloomContext) 
{
  // Step 1: Extract bright pixels
  rl.BeginTextureMode(ctx.bright_target)
  rl.ClearBackground(rl.BLACK)

  rl.BeginShaderMode(ctx.bright_shader)
  rl.SetShaderValue(
    ctx.bright_shader,
    rl.GetShaderLocation(ctx.bright_shader, "threshold"),
    &ctx.config.threshold,
    rl.ShaderUniformDataType.FLOAT,
  )

  rl.DrawTextureRec(ctx.scene_target.texture, {0, 0, f32(ctx.screen_width), -f32(ctx.screen_height)}, {0, 0}, rl.WHITE)
  rl.EndShaderMode()
  rl.EndTextureMode()

  // Step 2: Apply Gaussian blur (ping-pong between buffers)
  resolution := [2]f32{f32(ctx.screen_width), f32(ctx.screen_height)}

  // Start with bright pixels as source
  source_tex := &ctx.bright_target.texture
  target_a := &ctx.blur_target_a
  target_b := &ctx.blur_target_b

  for pass in 0 ..< ctx.config.blur_passes {
    // Horizontal blur pass
    rl.BeginTextureMode(target_a^)
    rl.ClearBackground(rl.BLACK)

    rl.BeginShaderMode(ctx.blur_shader)
    rl.SetShaderValue(ctx.blur_shader, rl.GetShaderLocation(ctx.blur_shader, "resolution"), &resolution, rl.ShaderUniformDataType.VEC2)

    horizontal_dir := [2]f32{1.0, 0.0}
    rl.SetShaderValue(ctx.blur_shader, rl.GetShaderLocation(ctx.blur_shader, "direction"), &horizontal_dir, rl.ShaderUniformDataType.VEC2)
    rl.SetShaderValue(
      ctx.blur_shader,
      rl.GetShaderLocation(ctx.blur_shader, "radius"),
      &ctx.config.blur_radius,
      rl.ShaderUniformDataType.FLOAT,
    )

    rl.DrawTextureRec(source_tex^, {0, 0, f32(ctx.screen_width), -f32(ctx.screen_height)}, {0, 0}, rl.WHITE)
    rl.EndShaderMode()
    rl.EndTextureMode()

    // Vertical blur pass
    rl.BeginTextureMode(target_b^)
    rl.ClearBackground(rl.BLACK)

    rl.BeginShaderMode(ctx.blur_shader)
    rl.SetShaderValue(ctx.blur_shader, rl.GetShaderLocation(ctx.blur_shader, "resolution"), &resolution, rl.ShaderUniformDataType.VEC2)

    vertical_dir := [2]f32{0.0, 1.0}
    rl.SetShaderValue(ctx.blur_shader, rl.GetShaderLocation(ctx.blur_shader, "direction"), &vertical_dir, rl.ShaderUniformDataType.VEC2)
    rl.SetShaderValue(
      ctx.blur_shader,
      rl.GetShaderLocation(ctx.blur_shader, "radius"),
      &ctx.config.blur_radius,
      rl.ShaderUniformDataType.FLOAT,
    )

    rl.DrawTextureRec(target_a.texture, {0, 0, f32(ctx.screen_width), -f32(ctx.screen_height)}, {0, 0}, rl.WHITE)
    rl.EndShaderMode()
    rl.EndTextureMode()

    // For next pass, use the result as source
    source_tex = &target_b.texture
  }

  // Final blur result is now in target_b


  // Step 3: Combine original scene with bloom
  rl.BeginShaderMode(ctx.combine_shader)

  // Set the bloom texture (texture1) - final result is in target_b
  rl.SetShaderValueTexture(ctx.combine_shader, rl.GetShaderLocation(ctx.combine_shader, "texture1"), target_b.texture)
  rl.SetShaderValue(
    ctx.combine_shader,
    rl.GetShaderLocation(ctx.combine_shader, "intensity"),
    &ctx.config.intensity,
    rl.ShaderUniformDataType.FLOAT,
  )

  blend_mode_int := i32(ctx.config.blend_mode)
  rl.SetShaderValue(
    ctx.combine_shader,
    rl.GetShaderLocation(ctx.combine_shader, "blendMode"),
    &blend_mode_int,
    rl.ShaderUniformDataType.INT,
  )

  // Draw the original scene (texture0) combined with bloom
  rl.DrawTextureRec(ctx.scene_target.texture, {0, 0, f32(ctx.screen_width), -f32(ctx.screen_height)}, {0, 0}, rl.WHITE)
  rl.EndShaderMode()
}
