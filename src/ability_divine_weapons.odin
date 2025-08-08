package main

import "core:log"
import "core:math"
import "core:math/linalg"
import "core:slice"
import rl "vendor:raylib"

Divine_Weapons :: struct 
{
 shield_stat:      float,
 current_rotation: float,
 rotation_speed:   float,
 ts_swords_active: float,
 ts_ready:         float,
 attack_t:         float, //lerp from attack position to attack target 0-1
 num_swords:       int,
 state:            Divine_Weapons_State,
 idx_model:        int,
 mouse_pos:        float3,
 positions:        [dynamic]float3,
 hit_list:         [dynamic]EntityHandle,
 data:             AbilityData,
}

Damage_Source :: enum 
{
 WEAPON = 0,
 ABILITY,
 ENVIRONMENTAL,
}

AbilityData :: struct 
{
 type:     AbilityType,
 cooldown: float,
 range:    float,
 damage:   float,
}

Divine_Weapons_State :: enum byte 
{
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

 ability = Divine_Weapons \
 {
  rotation_speed = 6,
  state = .READY,
  num_swords = 6,
  data = AbilityData{cooldown = 3, range = 5, type = .Divine_Weapons, damage = 40},
  hit_list = make([dynamic]EntityHandle),
 }

 //this is stupid
 ability.positions = make([dynamic]float3)
 for i in 0 ..< ability.num_swords 
 {
  append(&ability.positions, float3_zero)
 }

 append(&update_procs, update_divine_weapons)
 append(&draw_procs, draw_divine_weapons)
}

// Summon spinning shields, after x seconds, click again to turn shields into swords.
// Swords fly behind you, and then quickly attacks in front of you
update_divine_weapons :: proc() 
{
 player := get_player()

 //==================COOLDOWN
 if ability.state == .COOLDOWN 
 {
  if time_now > ability.ts_ready 
  {
   ability.state = .READY
  }
 }

 //==================TRIGGER
 if ability.state == .READY && core_input.ability_triggered 
 {
  ability.ts_swords_active = time_now + 2
  player.stats.shield += ability.shield_stat

  for i in 0 ..< ability.num_swords 
  {
   ability.positions[i] = player.position + float3_up
  }
  clear(&ability.hit_list)
  ability.state = .ROTATING_SHIELDS
 }

 //==================ROTATING
 if ability.state == .ROTATING_SHIELDS 
 {

  ability.current_rotation += dt
  interval := (math.PI * 2) / float(ability.num_swords)
  for i in 0 ..< ability.num_swords 
  {
   angle := float(i) * interval + ability.current_rotation
   offset := float3{math.cos(angle), 0, math.sin(angle)}
   ability.positions[i] = linalg.lerp(ability.positions[i], player.position + offset * 2 + float3_up, dt * 30)
  }

  if time_now > ability.ts_swords_active && core_input.ability_triggered 
  {
   ability.state = .CHARGING
   ability.attack_t = 0
  }
 }

 //==================CHARGE UP
 if ability.state == .CHARGING 
 {
  charge_dur: float = 0.4
  ability.attack_t += dt / charge_dur

  //calculate the positions behind the player, and lerp towards them
  target_positions := make([dynamic]float3, context.temp_allocator)
  arc: float = math.PI / 1.1
  interval := arc / float(ability.num_swords - 1)
  player_rads := math.atan2(-player.forward.x, player.forward.z) - math.PI

  for i in 0 ..< ability.num_swords 
  {
   angle := float(i) * interval + player_rads
   offset := float3{math.cos(angle), 0, math.sin(angle)} * 2
   append(&target_positions, player.position + offset + float3_up)
   ability.positions[i] = linalg.lerp(ability.positions[i], target_positions[i], dt * 30)
  }

  if ability.attack_t > 1 
  {
   ability.state = .ATTACKING
   ability.attack_t = 0
   mouse_pos := mouse_pos_world() + float3_up
   dir := mouse_pos - player.position
   length := linalg.length(dir)
   if length > ability.data.range 
   {
    mouse_pos = player.position + norm(dir) * ability.data.range
   }
   ability.mouse_pos = mouse_pos
  }
 }

 //================== ATTACKING
 if ability.state == .ATTACKING 
 {
  attack_dur: float = 1
  ability.attack_t += dt / attack_dur
  lerp := ease_inout_quint(ability.attack_t)

  for &p in ability.positions 
  {
   p = linalg.lerp(p, ability.mouse_pos, lerp)
  }
  if ability.attack_t > 1 
  {
   ability.state = .COOLDOWN
   ability.ts_ready = time_now + ability.data.cooldown
  }

  RADIUS: float = 1.2
  RADIUS *= RADIUS

  for &handle in enemies 
  {
   e := get_entity(handle)
   for p in ability.positions 
   {
    if linalg.length2(p - e.position) < RADIUS && !slice.contains(ability.hit_list[:], handle) 
    {
     append(&ability.hit_list, handle)
     e.stats.health -= ability.data.damage
     if e.stats.health <= 0 
     {
      e.flags += {.dead}
     }
    }
   }
  }
 }
}


draw_divine_weapons :: proc() 
{
 player := get_player()
 model := entity_models[ability.idx_model]
 if ability.state == .ROTATING_SHIELDS || ability.state == .CHARGING || ability.state == .ATTACKING 
 {
  for pos in ability.positions 
  {
   rl.DrawSphereWires(pos, 0.2, 2, 10, rl.RED)
  }
 }
}
