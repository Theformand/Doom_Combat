package main

import "core:log"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"


Shotgun :: struct {
  damage:        float,
  shot_interval: float,
  cone_angle:    float,
  range:         float,
  tsReady:       float,
  idxModel:      int,
  recoil:        Recoil,
}

Recoil :: struct {
  t:          float,
  recoilKick: float,
  spring:     float,
}

ConeVFX :: struct {
  lifetime: float,
  center:   float3,
  forward:  float3,
  range:    float,
  angle:    float,
}

shotgun: Shotgun
shotgunvfxses: [dynamic]ConeVFX

create_shotgun :: proc() 
{
  shotgun = Shotgun {
    damage = 50,
    shot_interval = 1.5,
    cone_angle = 15,
    range = 3,
    recoil = Recoil{recoilKick = 0.4, spring = 1},
  }

  shotgun.idxModel = load_entity_model("crossbow.glb")
  assign_material_all_mats(&entity_models[shotgun.idxModel], synty_mat)

  append(&update_procs, update_shotgun)
  append(&draw_procs, draw_shotgun)
  shotgunvfxses = make([dynamic]ConeVFX)
}

update_shotgun :: proc() 
{
  player := get_entity(player_handle)
  child_pos := float3_up + entity_right(player) * 0.25


  if core_input.shootTriggered && now > shotgun.tsReady {
    shotgun.tsReady = now + shotgun.shot_interval
    targets := get_enemies_in_cone(player.position, player.forward, shotgun.cone_angle, shotgun.range)
    shotgun.recoil.t = 1
    for h in targets {
      target := get_entity(h)
      target.stats.health -= shotgun.damage
      if target.stats.health <= 0 {
        target.flags += {.dead}
      }
    }
    camera_shake(.small)
    cone := ConeVFX {
      lifetime = 1.0,
      center   = player.position,
      forward  = player.forward,
      range    = shotgun.range,
      angle    = shotgun.cone_angle,
    }
    append(&shotgunvfxses, cone)
  }

  //RECOIL ANIMATION
  t, kick_offset := weapon_recoil(shotgun.recoil)
  shotgun.recoil.t = t
  entity_models[shotgun.idxModel].transform = matrix_trs(
    linalg.mul(player.rotation, kick_offset) + child_pos,
    float3_one * 2,
    linalg.mul(player.rotation, rl.QuaternionFromMatrix(rl.MatrixRotateY(RAD_180))),
  )
}

weapon_recoil :: proc(recoil: Recoil) -> (t: float, kick_offset: float3) 
{
  kickMax := float3{0, 0, recoil.recoilKick}
  ease := ease_cubic_in(recoil.t)
  offset := linalg.lerp(float3_zero, kickMax, ease)
  return linalg.clamp(recoil.t - dt * recoil.spring, 0, 1), offset
}

draw_shotgun :: proc() 
{
  player := get_player()
  rl.DrawModel(entity_models[shotgun.idxModel], player.position, 1, rl.WHITE)

  for &v, i in shotgunvfxses {
    v.lifetime -= dt
    half_angle := radians(v.angle / 2)
    fwd := v.forward
    p1 := v.center + rl.Vector3RotateByAxisAngle(fwd, float3_up, half_angle) * v.range
    p2 := v.center + rl.Vector3RotateByAxisAngle(fwd, float3_up, -half_angle) * v.range
    rl.DrawLine3D(v.center + float3_up, p1 + float3_up, rl.RED)
    rl.DrawLine3D(v.center + float3_up, p2 + float3_up, rl.RED)

    if v.lifetime < 0 {
      unordered_remove(&shotgunvfxses, i)
    }
  }
}


get_enemies_in_cone :: proc(pos, forward: float3, angle, range: float) -> [dynamic]EntityHandle 
{
  list := make([dynamic]EntityHandle, context.temp_allocator)
  half_angle := radians(angle / 2)
  cos_half_angle := math.cos(half_angle)
  for h in enemies {
    e := get_entity(h)
    dir := e.position - pos
    dot := linalg.dot(norm(dir), forward)
    if dot >= half_angle && linalg.length(dir) < range {
      append(&list, h)
    }
  }
  return list
}
