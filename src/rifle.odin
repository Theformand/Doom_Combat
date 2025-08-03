package main
import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

Rifle :: struct {
  flags:          Entity_Flags,
  bulletSpeed:    float,
  bulletLifetime: float,
  damage:         float,
  shotInterval:   float,
  spread:         float,
  tsReady:        float,
  recoil_t:       float, //0-1
}


rifle: Rifle
rifle_model: rl.Model
synty_tex1: rl.Texture

create_rifle :: proc() 
{
  rifle = Rifle {
    bulletSpeed    = 70,
    damage         = 10,
    shotInterval   = 0.1,
    spread         = 0.025,
    bulletLifetime = rand_range(.7, .8),
  }

  synty_tex1 = rl.LoadTexture("tex1.png")
  rifle_model = rl.LoadModel("rifle.glb")
  rifle_model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = synty_tex1

  append(&update_procs, update_rifle)
  append(&draw_procs, draw_rifle)
}

update_rifle :: proc() 
{
  player := get_entity(player_handle)
  child_pos := float3_up + entity_right(player) * 0.55

  //SHOOTING
  if core_input.shootHeld && time_now > rifle.tsReady {
    forward := entity_fwd(player)
    rifle.tsReady = time_now + rifle.shotInterval

    handle := make_projectile()
    bullet := get_entity(handle)
    bullet.position = player.position + child_pos + float3_up * 0.3 + forward * 0.5 //muzzle position
    right := entity_right(bullet)
    forward = rl.Vector3RotateByAxisAngle(forward, float3_up, rand_range(-rifle.spread, rifle.spread))
    bullet.forward = -forward
    rifle.recoil_t = 1
    bullet.collisionRadiusSqr = 2

    bullet.stats = EntityStats {
      speed     = rifle.bulletSpeed,
      lifetime  = rifle.bulletLifetime,
      damage    = rifle.damage,
      speedMode = .Cubic,
    }
  }

  //RIFLE ANIMATION

  kickMax := float3{0, 0, .5}
  ease := ease_cubic_in(rifle.recoil_t)
  kick_offset := linalg.lerp(float3_zero, kickMax, ease)
  rifle.recoil_t = linalg.clamp(rifle.recoil_t - dt * 5, 0, 1)
  rifle_model.transform = matrix_trs(
    linalg.mul(player.rotation, kick_offset) + child_pos,
    float3_one * 2,
    linalg.mul(player.rotation, rl.QuaternionFromMatrix(rl.MatrixRotateY(RAD_180))),
  )
}


draw_rifle :: proc() 
{
  player := get_entity(player_handle)
  rl.DrawModel(rifle_model, player.position, 1, rl.WHITE)
}
