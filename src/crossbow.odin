package main
import "core:log"
import "core:math/linalg"
import rl "vendor:raylib"

Crossbow :: struct {
  flags:          Entity_Flags,
  bulletSpeed:    float,
  bulletLifetime: float,
  damage:         float,
  shotInterval:   float,
  spread:         float,
  tsReady:        float,
  recoil_t:       float, //0-1
  idx_model:      int,
  recoil:         Recoil,
}

crossbow: Crossbow
crossbow_model: rl.Model

create_crossbow :: proc() 
{
  crossbow = Crossbow {
    bulletLifetime = .5,
    bulletSpeed = 20,
    damage = 10,
    shotInterval = 0.2,
    spread = 0.25,
    recoil = Recoil{recoilKick = 0.3, spring = 5},
  }

  modelIdx := load_entity_model("crossbow.glb")
  crossbow.idx_model = modelIdx
  crossbow_model = entity_models[modelIdx]
  assign_material_all_mats(&crossbow_model, synty_mat)
  append(&update_procs, update_crossbow)
  append(&draw_procs, draw_crossbow)
}

update_crossbow :: proc() 
{
  player := get_entity(player_handle)
  child_pos := float3_up + entity_right(player) * 0.25

  //SHOOTING
  if core_input.shootHeld && time_now > crossbow.tsReady {
    forward := entity_fwd(player)
    crossbow.tsReady = time_now + crossbow.shotInterval

    handle := make_projectile()
    bullet := get_entity(handle)
    bullet.position = player.position + child_pos + float3_up * 0.3 + forward * 0.5 //muzzle position
    right := entity_right(bullet)
    spread := crossbow.spread * 0.1
    forward = rl.Vector3RotateByAxisAngle(forward, float3_up, rand_range(-spread, spread))
    bullet.forward = -forward
    crossbow.recoil_t = 1
    bullet.collisionRadiusSqr = 1

    bullet.stats = EntityStats {
      speed     = crossbow.bulletSpeed,
      lifetime  = crossbow.bulletLifetime,
      damage    = crossbow.damage,
      speedMode = .Cubic,
    }
  }

  //RECOIL ANIMATION
  t, kick_offset := weapon_recoil(crossbow.recoil)
  crossbow.recoil.t = t
  crossbow_model.transform = matrix_trs(
    linalg.mul(player.rotation, kick_offset) + child_pos,
    float3_one * 2,
    linalg.mul(player.rotation, rl.QuaternionFromMatrix(rl.MatrixRotateY(RAD_180))),
  )
}

draw_crossbow :: proc() 
{
  player := get_entity(player_handle)
  fresnel := rl.ColorNormalize(player_fresnel_color)
  black := rl.ColorNormalize(rl.BLACK)
  rl.SetShaderValue(default_shader, loc_fresnel, &fresnel, .VEC4)
  rl.DrawModel(crossbow_model, player.position, 1, rl.WHITE)
  rl.SetShaderValue(default_shader, loc_fresnel, &black, .VEC4)
}
