package main

import "core:log"
import "core:math"


Knockback :: struct {
  direction:      float3, // Should be normalized
  initial_power:  float,
  current_offset: float3,
  power:          float, // Current power
  spring:         float, // How fast the knockback completes (duration)
  time:           float, // Elapsed time
}

init_knockback :: proc() 
{
  append(&update_procs, update_knockback)
}

update_knockback :: proc() 
{
  for &e in manager.entities {
    if !e.active || e.knockback.power <= 0 do continue
    e.knockback.time += dt

    progress := math.clamp(e.knockback.time / (1 / e.knockback.spring), 0, 1)

    ease_factor := 1 - ease_cubic_out(progress)
    current_power := e.knockback.initial_power * ease_factor
    e.knockback.current_offset = e.knockback.direction * current_power * dt
    e.knockback.power = current_power

    // End knockback when complete
    if progress >= 1.0 {
      e.knockback.power = 0
      e.knockback.time = 0
    }
  }
}
