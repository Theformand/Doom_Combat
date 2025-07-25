package main

import "core:fmt"
import "core:math"
import alg "core:math/linalg"
import rl "vendor:raylib"

projectiles: [dynamic]EntityHandle

projectileModel: rl.Model
projectileMat: rl.Material
white: rl.Color


init_projectiles :: proc() 
{
  projectiles = make([dynamic]EntityHandle, context.allocator)
  projectileModel = rl.LoadModelFromMesh(rl.GenMeshSphere(0.125, 6, 6))

  white = rl.PURPLE

  projectileMat = rl.LoadMaterialDefault()
  shader := rl.LoadShader(nil, "resources/shaders/unlit.fs")

  projectileMat.shader = shader
  projectileModel.materials[0] = projectileMat
  rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "colDiffuse"), &white, rl.ShaderUniformDataType.VEC4)


  append(&tick_procs, tick_projectiles)
  append(&late_tick_procs, late_tick_projectiles)
  append(&draw_procs, draw_projectiles)
}

make_projectile :: proc() -> EntityHandle 
{
  handle := create_entity()
  get_entity(handle).flags = {.bullet}
  append(&projectiles, handle)
  return handle
}


BulletHit :: struct {
  bullet: EntityHandle,
  target: EntityHandle,
  pos:    float3,
}

tick_projectiles :: proc() 
{
  hits := make([dynamic]BulletHit, context.temp_allocator)
  for &handle in projectiles {
    bullet := get_entity(handle)

    bullet.stats.lifetime -= dt
    bullet.position += bullet.forward * dt * bullet.stats.speed

    modify_bullet_speed(bullet)

    if bullet.stats.lifetime < 0 {
      bullet.flags += {.dead}
    }

    //COLLISION CHECK
    for &bullet_handle in enemies {
      enemy := get_entity(bullet_handle)
      distToEnemy := alg.vector_length2(bullet.position - enemy.position)
      if distToEnemy - bullet.collisionRadiusSqr - enemy.collisionRadiusSqr < 0 {
        bullet.flags += {.dead}

        append(&hits, BulletHit{bullet = handle, target = bullet_handle, pos = enemy.position})
        //TODO: damage code
      }
    }
  }


  //RESOLVE HITS
  for hit in hits {
    enemy := get_entity(hit.target)
    bullet := get_entity(hit.bullet)
    enemy.stats.health -= bullet.stats.damage
    if enemy.stats.health < 0 {
      enemy.flags += {.dead}
    }
  }
}


@(private = "file")
modify_bullet_speed :: proc(e: ^Entity) 
{
  #partial switch e.stats.speedMode {
  case .Linear: e.stats.speed = math.clamp(e.stats.speed - (dt * 50), 20, 100)
  case .Cubic: e.stats.speed = math.clamp(e.stats.speed - ease_cubic_out(e.stats.speed * .005), 20, 100)
  case .Circ: e.stats.speed = math.clamp(e.stats.speed - ease_circ_out(e.stats.speed * .0025), 20, 100)
  }
}

late_tick_projectiles :: proc() 
{
  #reverse for &handle, i in projectiles {
    e := get_entity(handle)
    if .dead in e.flags {
      destroy_entity(handle)
      unordered_remove(&projectiles, i)
    }
  }
}

draw_projectiles :: proc() 
{
  for &h in projectiles {
    ent := get_entity(h)
    rl.DrawModel(projectileModel, ent.position, 1.5, rl.WHITE)
  }
}
