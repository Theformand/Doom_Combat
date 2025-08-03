package main

import "core:log"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Divine_Weapons :: struct {
  shield_stat:      float,
  current_rotation: float,
  rotation_speed:   float,
  ts_swords_active: float,
  ts_ready:         float,
  attack_range:     float,
  attack_t:         float, //lerp from attack position to attack target 0-1
  num_swords:       int,
  state:            Divine_Weapons_State,
  idx_model:        int,
  mouse_pos:        float3,
  type:             AbilityType,
  positions:        [dynamic]float3,
}

Divine_Weapons_State :: enum byte {
  READY = 0,
  COOLDOWN,
  ROTATING_SHIELDS,
  CHARGING,
  ATTACKING,
}

@(private = "file")
ability: Divine_Weapons

create_divine_weapons :: proc() 
{

  ability = Divine_Weapons {
    attack_range   = 3,
    rotation_speed = 6,
    state          = .READY,
    num_swords     = 6,
  }

  //this is stupid
  ability.positions = make([dynamic]float3)
  for i in 0 ..< ability.num_swords {
    append(&ability.positions, float3_zero)
  }

  append(&update_procs, update_divine_weapons)
  append(&draw_procs, draw_divine_weapons)
}


update_divine_weapons :: proc() 
{
  player := get_player()

  //trigger
  if ability.state == .READY && core_input.ability_triggered && time_now > ability.ts_ready {
    ability.state = .ROTATING_SHIELDS
    ability.ts_swords_active = time_now + 3
    player.stats.shield += ability.shield_stat

    for i in 0 ..< ability.num_swords {
      ability.positions[i] = player.position + float3_up
    }
  }

  if ability.state == .ROTATING_SHIELDS {

    ability.current_rotation += dt
    interval := (math.PI * 2) / float(ability.num_swords)
    for i in 0 ..< ability.num_swords {
      angle := float(i) * interval + ability.current_rotation
      offset := float3{math.cos(angle), 0, math.sin(angle)}
      ability.positions[i] = linalg.lerp(ability.positions[i], player.position + offset * 2 + float3_up, dt * 30)
    }

    if time_now > ability.ts_swords_active && core_input.ability_triggered {
      ability.state = .CHARGING
      ability.attack_t = 0
    }
  }

  if ability.state == .CHARGING {

    charge_dur: float = 0.4
    ability.attack_t += dt / charge_dur

    //calculate the positions behind the player, and lerp towards them
    end_positions := make([dynamic]float3, context.temp_allocator)
    arc: float = math.PI / 2.0
    interval := arc / float(ability.num_swords)

    for i in 0 ..< ability.num_swords {
      angle := float(i) * interval
      offset := float3{math.cos(angle), 0, math.sin(angle)}
      append(&end_positions, player.position + offset + float3_up)
      ability.positions[i] = linalg.lerp(ability.positions[i], end_positions[i], dt * 30)
    }


    if ability.attack_t > 1 {
      ability.state = .ATTACKING
      ability.attack_t = 0
      ability.mouse_pos = get_mouse_pos_world()
    }
  }

  if ability.state == .ATTACKING {
    attack_dur: float = 0.5
    ability.attack_t += dt / attack_dur
    if ability.attack_t > 1 {
      ability.state = .COOLDOWN
    }
  }
}


draw_divine_weapons :: proc() 
{
  player := get_player()
  model := entity_models[ability.idx_model]
  if ability.state == .ROTATING_SHIELDS || ability.state == .CHARGING || ability.state == .ATTACKING {
    for pos in ability.positions {
      rl.DrawSphereWires(pos, 0.2, 2, 10, rl.RED)
    }
  }
}
