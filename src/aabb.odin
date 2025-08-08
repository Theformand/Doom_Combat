package main
import "core:log"
import rl "vendor:raylib"

update_aabbs :: proc() 
{
  for &e in manager.entities {
    if !e.active || (.static in e.flags && .aabb_dirty not_in e.flags) {
      continue
    }

    bb := rl.GetMeshBoundingBox(entity_models[e.idx_model].meshes[0])
    bb.min += e.position
    bb.max += e.position
    e.aabb = bb
    if .aabb_dirty in e.flags {
      e.flags -= {.aabb_dirty}
    }
  }
}

draw_aabbs :: proc() 
{
  if !PRINT_PERF_METRICS {
    return
  }
  for &e in manager.entities {
    if !e.active || (.static in e.flags && .aabb_dirty not_in e.flags) {
      continue
    }
    rl.DrawBoundingBox(e.aabb, rl.GREEN)
  }
}
