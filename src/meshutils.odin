
package main

import "core:math"
import "core:math/linalg"
import "core:slice"
import rl "vendor:raylib"

// Vertex info for grouping
Vertex_Info :: struct 
{
 position: rl.Vector3,
 normal:   rl.Vector3,
 index:    int,
}

// Hash key for spatial grid
Hash_Key :: struct 
{
 x, y, z: i32,
}

// Ultra-fast version for models that just need basic smoothing
smooth_all_mesh_normals :: proc(mesh: ^rl.Mesh) 
{
 if mesh.vertices == nil || mesh.normals == nil do return

 vertex_count := int(mesh.vertexCount)
 if vertex_count == 0 do return

 vertices := ([^]f32)(mesh.vertices)
 normals := ([^]f32)(mesh.normals)

 // Use smaller grid for tighter grouping
 grid_size: f32 = 0.0005
 vertex_groups := make(map[Hash_Key][dynamic]int, vertex_count, context.temp_allocator)

 // Hash vertices
 for i in 0 ..< vertex_count 
 {
  pos := rl.Vector3{vertices[i * 3], vertices[i * 3 + 1], vertices[i * 3 + 2]}
  key := Hash_Key \
  {
   x = i32(pos.x / grid_size),
   y = i32(pos.y / grid_size),
   z = i32(pos.z / grid_size),
  }

  if key not_in vertex_groups 
  {
   vertex_groups[key] = make([dynamic]int, context.temp_allocator)
  }
  append(&vertex_groups[key], i)
 }

 smoothed_normals := make([]rl.Vector3, vertex_count, context.temp_allocator)

 // Process each group
 for _, group in vertex_groups 
 {
  if len(group) == 1 
  {
   idx := group[0]
   smoothed_normals[idx] = {normals[idx * 3], normals[idx * 3 + 1], normals[idx * 3 + 2]}
   continue
  }

  // Average all normals in this group
  avg_normal := rl.Vector3{0, 0, 0}
  for idx in group 
  {
   normal := rl.Vector3{normals[idx * 3], normals[idx * 3 + 1], normals[idx * 3 + 2]}
   avg_normal += normal
  }
  avg_normal = linalg.normalize(avg_normal / f32(len(group)))

  // Apply to all vertices in group
  for idx in group 
  {
   smoothed_normals[idx] = avg_normal
  }
 }

 // Apply back to mesh
 for i in 0 ..< vertex_count 
 {
  normals[i * 3] = smoothed_normals[i].x
  normals[i * 3 + 1] = smoothed_normals[i].y
  normals[i * 3 + 2] = smoothed_normals[i].z
 }

 rl.UpdateMeshBuffer(mesh^, 2, mesh.normals, i32(vertex_count * 3 * size_of(f32)), 0)
}
