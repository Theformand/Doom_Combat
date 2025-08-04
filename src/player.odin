package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:sort"
import rl "vendor:raylib"

player_handle: EntityHandle

//ground plane
ground_plane_p1 :: float3{-1000, 0, -1000}
ground_plane_p2 :: float3{-1000, 0, 1000}
ground_plane_p3 :: float3{1000, 0, 1000}
ground_plane_p4 :: float3{1000, 0, -1000}

animCurrentFrame: i32
animCount: i32
animIndex: i32

player_model: rl.Model
player_anims: [^]rl.ModelAnimation
player_shader: rl.Shader
anims_loaded: bool
player_accel: float
synt_atlas_1: rl.Texture
player_fresnel_color :: rl.Color{114, 232, 195, 255}
loc_fresnel: int


init_player :: proc() 
{
  loc_fresnel = rl.GetShaderLocation(default_shader, "fresnelColor")
  player_handle = create_entity()
  player := get_entity(player_handle)
  player.flags = {.player}
  player.position = float3_zero
  player.rotation = quaternion_identity
  init_player_stats()
  //create_crossbow()
  create_shotgun()
  create_divine_weapons()
  //create_shield_dash()

  //animation test
  animCount = 0
  animIndex = 0
  animCurrentFrame = 0

  //material and shader setup
  idx := load_entity_model("player.glb")
  player_model = entity_models[idx]
  for i in 0 ..< player_model.meshCount {
    smooth_all_mesh_normals(&player_model.meshes[i])
  }

  assign_material_all_mats(&player_model, synty_mat)
  if animCount != 0 {
    anims_loaded = true
  }

  append(&update_procs, update_player)
  append(&draw_procs, draw_player)
}


update_player :: proc() 
{
  player := get_entity(player_handle)
  player.stats.speed = 5
  accel: float = 40
  decel: float = 50

  // read input, construct move vector and transform move vector by camera rotation so its camera relative
  moveVec := norm(float3{core_input.moveHorizontal, 0, core_input.moveVertical})
  moveVec = rl.Vector3RotateByAxisAngle(moveVec, float3_up, RAD_45)
  // calculate desired velocity based on input
  desiredVelocity := moveVec * player.stats.speed

  // apply acceleration or deceleration
  if linalg.length(moveVec) > 0 {
    // Accelerate towards desired velocity
    player_velocity = linalg.lerp(player_velocity, desiredVelocity, accel * dt)
  } else {
    // Decelerate when no input
    currentSpeed := linalg.length(player_velocity)
    if currentSpeed > 0 {
      decelAmount := decel * dt
      newSpeed := max(0, currentSpeed - decelAmount)
      player_velocity = norm(player_velocity) * newSpeed
    }
  }

  knockback := float3_zero
  if player.knockback.power > 0.01 do knockback = player.knockback.current_offset

  player.position += knockback + player_velocity * dt


  //trigger dash
  if core_input.ability_triggered && time_now > ts_dash_ready && is_valid_handle(player.target) {
    dashing = true
    targetPos := get_entity(player.target).position
    dirVec := targetPos - player.position
    dashing_start = player.position
    dashing_end = targetPos - norm(dirVec) * 1.5
    ts_dash_start = time_now
  }

  // player rotation
  mousePos := get_mouse_pos_world()
  player.rotation = look_rot(player.position, mousePos, float3_up)
  player.forward = norm(mousePos - player.position)
  player_model.transform = matrix_trs(float3_zero, float3_one, player.rotation)


  if anims_loaded {
    anim := player_anims[animIndex]
    animCurrentFrame = (animCurrentFrame + 1) % anim.frameCount
    rl.UpdateModelAnimation(player_model, anim, animCurrentFrame)
  }
}


draw_player :: proc() 
{
  player := get_entity(player_handle)
  fresnel := rl.ColorNormalize(player_fresnel_color)
  black := rl.ColorNormalize(rl.BLACK)

  rl.SetShaderValue(default_shader, loc_fresnel, &fresnel, .VEC4)
  rl.DrawModel(player_model, player.position, 1, rl.WHITE)
  rl.SetShaderValue(default_shader, loc_fresnel, &black, .VEC4)
}

get_mouse_pos_world :: proc() -> float3 
{
  ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), camera)
  hitInfo: rl.RayCollision
  hitInfo = rl.GetRayCollisionQuad(ray, ground_plane_p1, ground_plane_p2, ground_plane_p3, ground_plane_p4)
  return hitInfo.point
}
