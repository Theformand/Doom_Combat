package main
import "core:log"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

enemies: [dynamic]EntityHandle
entity_models: [dynamic]rl.Model

init_enemies :: proc() 
{
  idx_skeleton := load_entity_model("skeleton.glb")
  idx_ranger := load_entity_model("skeleton_ranger.glb")

  skeleton := entity_models[idx_skeleton]
  ranger := entity_models[idx_ranger]
  for i in 0 ..< skeleton.meshCount {
    smooth_all_mesh_normals(&skeleton.meshes[i])
  }
  for i in 0 ..< ranger.meshCount {
    smooth_all_mesh_normals(&ranger.meshes[i])
  }
  assign_material_all_mats(&skeleton, synty_mat)
  assign_material_all_mats(&ranger, synty_mat)


  enemyCount := 10
  for i in 0 ..< enemyCount {
    handle := create_entity()
    e := get_entity(handle)
    health: float
    if rand.int_max(3) == 1 {
      e.flags += {.enemy_ranged}
      e.idx_model = idx_ranger
      health = 50
    } else {
      e.flags += {.enemy_fodder}
      e.idx_model = idx_skeleton
      health = 10
    }
    e.stats = EntityStats {
      health = health,
    }
    spread: float = float(enemyCount) / 2
    e.position = float3{10, 0, 10} + float3{rand_range(-spread, spread), 0, rand_range(-spread, spread)}
    e.collisionRadiusSqr = 1
    append(&enemies, handle)
  }

  append(&update_procs, update_enemies)
  append(&late_update_procs, late_update_enemies)
  append(&draw_procs, draw_enemies)
}

update_enemies :: proc() 
{
  player := get_entity(player_handle)
  for &handle in enemies {
    e := get_entity(handle)
    dir_to_player := norm(player.position - e.position)
    e.forward = dir_to_player
    e.rotation = look_rot(e.position, player.position, float3_up)
  }
}

late_update_enemies :: proc() 
{
  for &handle, i in enemies {
    enemy := get_entity(handle)
    if .dead in enemy.flags {
      destroy_entity(enemy.handle)
      unordered_remove(&enemies, i)
    }
  }
}

draw_enemies :: proc() 
{
  for &handle in enemies {
    e := get_entity(handle)
    model := entity_models[e.idx_model]
    for i in 0 ..< model.meshCount {
      rl.DrawMesh(model.meshes[i], model.materials[i + 1], matrix_trs(e.position, float3_one, e.rotation))
    }
  }
}

get_enemies_in_range :: proc(range: float, pos: float3) -> [dynamic]EntityHandle 
{
  list := make([dynamic]EntityHandle, context.temp_allocator)
  for &handle in enemies {
    e := get_entity(handle)
    if linalg.distance(e.position, pos) < range {
      append(&list, e.handle)
    }
  }
  return list
}
