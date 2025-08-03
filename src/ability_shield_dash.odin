package main

import "core:math/linalg"
import "core:slice"

create_shield_dash :: proc() 
{
  append(&update_procs, update_shield_dash)
}

dashing: bool
dashing_end: float3
dashing_start: float3
ts_dash_start: float
dash_cd :: 1
dash_speed :: 50.0
dash_range :: 15.0
ts_dash_ready: float
player_velocity: float3

update_shield_dash :: proc() 
{
  player := get_player()

  //scan for dash targets
  if core_input.ability_held && time_now > ts_dash_ready {
    targets := get_enemies_in_range(dash_range, player.position)
    for &handle, i in targets {
      enemy := get_entity(handle)
      dir := norm(enemy.position - player.position)
      dot := linalg.dot(player.forward, dir)
      if (dot < 0.98 || enemy == player || !is_valid_handle(handle)) {
        unordered_remove(&targets, i)
      }
    }

    if len(targets) > 1 {
      //sort by distance to player
      slice.sort_by(targets[:], proc(a, b: EntityHandle) -> bool 
      {
        posA := get_entity(a).position
        posB := get_entity(b).position
        player := get_entity(player_handle)
        return linalg.distance(posA, player.position) < linalg.distance(posB, player.position)
      })
    }

    if len(targets) > 0 && !dashing {
      player.target = targets[0]
    }
  } else {
    player.target = zero_handle
  } //execute dash
  if dashing {
    distCovered := (time_now - ts_dash_start) * dash_speed
    t := distCovered / linalg.length(dashing_end - dashing_start)
    player.position = linalg.lerp(dashing_start, dashing_end, t)

    //Dash End
    if t >= 1.0 {
      dashing = false
      ts_dash_ready = time_now + dash_cd
      if is_valid_handle(player.target) {
        e := get_entity(player.target)
        in_range := get_enemies_in_range(3, e.position)

        for &handle in in_range {
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
}
