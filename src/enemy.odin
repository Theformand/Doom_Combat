package main
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

enemies: [dynamic]EntityHandle

init_enemies :: proc() 
{
  // for i in 0 ..< 100 {
  //   handle := create_entity()
  //   e := get_entity(handle)
  //   health: float
  //   if rand.int_max(3) == 1 {
  //     e.flags += {.enemy_heavy}
  //     health = 50
  //   } else {
  //     e.flags += {.enemy_fodder}
  //     health = 10
  //   }

  //   e.stats = EntityStats {
  //     health = health,
  //   }
  //   spread: float = 50
  //   e.position = float3{50, 0, 50} + float3{rand_range(-spread, spread), 0, rand_range(-spread, spread)}
  //   e.collisionRadiusSqr = 1
  //   append(&enemies, handle)
  // }

  append(&draw_procs, draw_enemies)
  append(&late_tick_procs, late_tick_enemies)
}

late_tick_enemies :: proc() 
{
  for &handle, i in enemies {
    enemy := get_entity(handle)
    if .dead in enemy.flags {
      destroy_entity(handle)
      unordered_remove(&enemies, i)
    }
  }
}

draw_enemies :: proc() 
{
  for &handle in enemies {
    e := get_entity(handle)
    color := .enemy_fodder in e.flags ? rl.GREEN : rl.RED
    rl.DrawCapsule(e.position, e.position + float3_up * 2, e.collisionRadiusSqr / e.collisionRadiusSqr, 10, 10, color)
  }
}

get_enemies_in_range :: proc(range: float, pos: float3) -> [dynamic]EntityHandle 
{
  list := make([dynamic]EntityHandle, context.temp_allocator)
  for &handle in enemies {
    if linalg.distance(get_entity(handle).position, pos) < range {
      append(&list, handle)
    }
  }
  return list
}
