package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:sort"
import rl "vendor:raylib"

player_handle: EntityHandle

//ground plane
q1 :: float3{-1000, 0, -1000}
q2 :: float3{-1000, 0, 1000}
q3 :: float3{1000, 0, 1000}
q4 :: float3{1000, 0, -1000}


PlayerInput :: struct {
  vertical:   float,
  horizontal: float,
  shoot:      bool,
}

animCurrentFrame: i32
animCount: i32
animIndex: i32

player_input: PlayerInput
player_model: rl.Model
player_anims: [^]rl.ModelAnimation
player_shader: rl.Shader
anims_loaded: bool
player_accel: float
synt_atlas_1: rl.Texture

init_player :: proc() 
{
  //player_model = rl.LoadModelFromMesh(rl.GenMeshCube(1, 2, 1))
  //player_model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].color = rl.WHITE

  player_handle = create_entity()
  player := get_entity(player_handle)
  player.flags = {.player}
  player.position = float3_zero
  player.rotation = quaternion_identity
  init_player_stats()
  append(&update_procs, update_player)
  append(&draw_procs, draw_player)

  //animation test
  animCount = 0
  animIndex = 0
  animCurrentFrame = 0

  //material and shader setup
  player_model = rl.LoadModel(PATH_MODELS + "player.glb")

  //player_model.materials[0] = synty_mat
  //player_model.materials[1] = synty_mat
  //player_model.materials[2] = synty_mat
  if animCount != 0 {
    anims_loaded = true
  }
}

dashing: bool
dashing_end: float3
dashing_start: float3
ts_dash_start: float
dash_cd :: 1
dash_speed :: 100.0
ts_dash_ready: float
player_velocity: float3

update_player :: proc() 
{
  //TODO: Remove this, it should go in actionmap.odin
  player_input = {}
  if rl.IsKeyDown(.W) {
    player_input.vertical = 1
  }
  if (rl.IsKeyDown(.S)) {
    player_input.vertical = -1
  }
  if (rl.IsKeyDown(.A)) {
    player_input.horizontal = 1
  }
  if (rl.IsKeyDown(.D)) {
    player_input.horizontal = -1
  }
  if core_input.shootHeld {
    player_input.shoot = true
  }

  player := get_entity(player_handle)
  player.stats.speed = 5
  accel: float = 40
  decel: float = 50
  // read input, construct move vector and transform move vector by camera rotation so its camera relative
  moveVec := norm(float3{player_input.horizontal, 0, player_input.vertical})
  moveVec = rl.Vector3RotateByAxisAngle(moveVec, float3_up, RAD_45)
  // Calculate desired velocity based on input
  desiredVelocity := moveVec * player.stats.speed

  // Apply acceleration or deceleration
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


  player.position += player_velocity * dt

  //scan for dash targets
  if core_input.shield_held && now > ts_dash_ready {
    targets := get_enemies_in_range(24, player.position)
    #reverse for &handle, i in targets {
      enemy := get_entity(handle)
      dir := norm(enemy.position - player.position)
      dot := linalg.dot(player.forward, dir)
      if (dot < 0.98 || enemy == player || !is_valid_handle(handle)) {
        unordered_remove(&targets, i)
      }
    }

    //sort by distance to player
    slice.sort_by(targets[:], proc(a, b: EntityHandle) -> bool 
    {
      posA := get_entity(a).position
      posB := get_entity(b).position
      player := get_entity(player_handle)
      return linalg.distance(posA, player.position) < linalg.distance(posB, player.position)
    })

    if len(targets) > 0 && !dashing {
      player.target = targets[0]
    }
  } else {
    player.target = zero_handle
  }

  //trigger dash
  if core_input.shield_dash_triggered && now > ts_dash_ready && is_valid_handle(player.target) {
    dashing = true
    targetPos := get_entity(player.target).position
    dirVec := targetPos - player.position
    dashing_start = player.position
    dashing_end = targetPos - norm(dirVec) * 1.5
    ts_dash_start = now
  }

  // player rotation
  mousePos := get_mouse_pos_world()
  player.rotation = look_rot(player.position, mousePos, float3_up)
  player.forward = norm(mousePos - player.position)
  player_model.transform = matrix_trs(float3_zero, float3_one, player.rotation)


  //execute dash
  if dashing {
    distCovered := (now - ts_dash_start) * dash_speed
    t := distCovered / linalg.length(dashing_end - dashing_start)
    player.position = linalg.lerp(dashing_start, dashing_end, t)

    //Dash End
    if t >= 1.0 {
      dashing = false
      ts_dash_ready = now + dash_cd
      if is_valid_handle(player.target) {
        e := get_entity(player.target)
        in_range := get_enemies_in_range(3, e.position)

        for handle in in_range {
          enemy := get_entity(handle)
          dmg := .enemy_fodder in enemy.flags ? enemy.stats.health : 10
          enemy.stats.health -= dmg
          if enemy.stats.health <= 0 {
            enemy.flags += {.dead}
          }
        }

        camera_shake(.small)
        //player.target = zero_handle
      }
    }
  }

  if anims_loaded {
    anim := player_anims[animIndex]
    animCurrentFrame = (animCurrentFrame + 1) % anim.frameCount
    rl.UpdateModelAnimation(player_model, anim, animCurrentFrame)
  }
}


draw_player :: proc() 
{
  player := get_entity(player_handle)
  rl.DrawModel(player_model, player.position, 1, rl.WHITE)

  if is_valid_handle(player.target) {
    rl.DrawSphere(get_entity(player.target).position + float3_up * 3, 0.5, rl.BLUE)
  }
}

get_mouse_pos_world :: proc() -> float3 
{
  ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), camera)
  hitInfo: rl.RayCollision
  hitInfo = rl.GetRayCollisionQuad(ray, q1, q2, q3, q4)
  return hitInfo.point
}
