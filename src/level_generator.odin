package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:mem"
import rl "vendor:raylib"

ground_mesh: rl.Mesh
//ground_model: rl.Model
ground_mat: rl.Material
vertCount: int
ground_handle: EntityHandle
ground_tiles: [dynamic]EntityHandle
ground_tile_model: rl.Model
scaleFactor: float

PATH_MODELS :: "resources/models/"
PATH_TEXTURES :: "resources/textures/"
PATH_SHADERS :: "resources/shaders/"
synty_mat: rl.Material
default_shader: rl.Shader
color_scene_ambient: rl.Color

init_level_gen :: proc() 
{
  width: float = 100.0
  height: float = 100.0
  grid_size_x: int = 100
  grid_size_y: int = 100
  noise_scale: float = 10.0
  threshold: float = 0.65
  use_two_layers: bool = true
  seed: i64 = 1337
  ground_tiles = make([dynamic]EntityHandle)

  color_scene_ambient = rl.Color{100 / 255, 100 / 255, 100 / 255, 255}

  default_shader = rl.LoadShader(PATH_SHADERS + "lighting.vs", PATH_SHADERS + "lighting.fs")
  default_shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(default_shader, "viewPos")
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "ambient"), &color_scene_ambient, rl.ShaderUniformDataType.VEC4)

  synty_mat = rl.LoadMaterialDefault()
  synty_mat.shader = default_shader
  tex := rl.LoadTexture(PATH_TEXTURES + "atlas_01a.png")
  rl.SetMaterialTexture(&synty_mat, rl.MaterialMapIndex.ALBEDO, tex)

  //ground_tile_model = rl.LoadModel(PATH_MODELS + "FloorTile1.glb")
  //fmt.println("model", ground_tile_model)
  //ground_tile_model.materials[0] = synty_mat
  //ground_tile_model.materials[1] = synty_mat
  //ground_tile_model.materials[2] = synty_mat
  ground_mesh = rl.GenMeshPlane(3, 3, 1, 1)


  rows: int = 20
  cols: int = 20
  scaleFactor = 2
  offset_x: float
  offset_y: float

  spacing: float = 5.9
  total_spacing := scaleFactor + spacing


  for row in 0 ..< rows {
    for col in 0 ..< cols {

      x := offset_x + float(col) * total_spacing
      y := offset_y + float(row) * total_spacing
      ground_handle = create_entity()
      ground_ent := get_entity(ground_handle)
      ground_ent.position = float3{x, rand_range(0, 0.8), y}
      //ground_ent.yRot = float(rand_range_int(0, 3) * 90)
      append(&ground_tiles, ground_handle)
    }
  }

  append(&draw_procs, draw_ground_mesh)
}


draw_ground_mesh :: proc() 
{
  rl.SetShaderValue(
    default_shader,
    default_shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW],
    &camera.position,
    rl.ShaderUniformDataType.VEC3,
  )
  rl.SetShaderValue(default_shader, rl.GetShaderLocation(default_shader, "ambient"), &color_scene_ambient, rl.ShaderUniformDataType.VEC4)

  pos := get_entity(ground_handle).position
  for &handle in ground_tiles {
    ent := get_entity(handle)
    rl.DrawMesh(
      ground_mesh,
      synty_mat,
      rl.MatrixTranslate(ent.position.x, ent.position.y, ent.position.z) *
      rl.MatrixRotateY(radians(ent.yRot)) *
      rl.MatrixScale(scaleFactor, scaleFactor, scaleFactor),
    )
  }
}

// Procedure to generate a flat mesh with holes
generate_flat_mesh_with_holes :: proc(
  width, height: f32, // Mesh dimensions in world units
  grid_size_x, grid_size_y: i32, // Number of grid cells
  noise_scale: f32, // Perlin noise scale (controls feature size)
  threshold: f32, // Noise threshold for holes (0 to 1)
  use_two_layers: bool, // Use two layers of noise?
  seed: i64, // Random seed for noise
) -> rl.Mesh 
{
  mesh: rl.Mesh
  cell_width := width / f32(grid_size_x)
  cell_height := height / f32(grid_size_y)

  // Count valid quads (non-hole cells)
  quad_count: int = 0
  for i in 0 ..< grid_size_y {
    for j in 0 ..< grid_size_x {
      x := f32(j) * cell_width
      y := f32(i) * cell_height
      // Sample Perlin noise at cell center
      nx := f64(x / width * noise_scale)
      ny := f64(y / height * noise_scale)
      noise1 := noise.noise_2d(seed, noise.Vec2{nx, ny})
      noise_term := noise1
      if use_two_layers {
        // Second layer with different scale and seed
        noise2 := noise.noise_2d(seed + 1, noise.Vec2{nx * 0.5, ny * 0.5})
        noise_term = (noise1 + noise2) * 0.5 // Average the two layers
      }
      // Normalize noise to [0, 1]
      noise_term = (noise_term + 1) * 0.5
      if noise_term < threshold {
        quad_count += 1
      }
    }
  }

  // Each quad is 2 triangles (6 indices), 4 vertices
  mesh.vertexCount = quad_count * 4
  mesh.triangleCount = quad_count * 2

  // Allocate memory for Raylib mesh
  vertices := make([]f32, mesh.vertexCount * 3)
  texcoords := make([]f32, mesh.vertexCount * 2)
  normals := make([]f32, mesh.vertexCount * 3)
  indices := make([]u16, mesh.triangleCount * 3)

  // Fill mesh data
  vertex_idx := 0
  index_idx := 0
  for i in 0 ..< grid_size_y {
    for j in 0 ..< grid_size_x {
      x := f32(j) * cell_width
      y := f32(i) * cell_height
      // Sample noise at cell center
      nx := f64(x / width * noise_scale)
      ny := f64(y / height * noise_scale)
      noise1 := noise.noise_2d(seed, noise.Vec2{nx, ny})
      noise_term := noise1
      if use_two_layers {
        noise2 := noise.noise_2d(seed + 1, noise.Vec2{nx * 0.5, ny * 0.5})
        noise_term = (noise1 + noise2) * 0.5
      }
      noise_term = (noise_term + 1) * 0.5
      if noise_term >= threshold {
        continue // Skip holes
      }

      // Define quad vertices (bottom-left origin)
      vert0 := vertex_idx * 3
      vert1 := vert0 + 3
      v2 := vert0 + 6
      v3 := vert0 + 9

      vertCount += 3
      // Vertices (x, y, z=0)
      vertices[vert0 + 0] = x
      vertices[vert0 + 1] = 0
      vertices[vert0 + 2] = y
      vertices[vert1 + 0] = x + cell_width
      vertices[vert1 + 1] = 0
      vertices[vert1 + 2] = y
      vertices[v2 + 0] = x + cell_width
      vertices[v2 + 1] = 0
      vertices[v2 + 2] = y + cell_height
      vertices[v3 + 0] = x
      vertices[v3 + 1] = 0
      vertices[v3 + 2] = y + cell_height

      // Texture coordinates
      u0 := f32(j) / f32(grid_size_x)
      v0 := f32(i) / f32(grid_size_y)
      u1 := f32(j + 1) / f32(grid_size_x)
      v1 := f32(i + 1) / f32(grid_size_y)
      texcoords[vertex_idx * 2 + 0] = u0
      texcoords[vertex_idx * 2 + 1] = v0
      texcoords[vertex_idx * 2 + 2] = u1
      texcoords[vertex_idx * 2 + 3] = v0
      texcoords[vertex_idx * 2 + 4] = u1
      texcoords[vertex_idx * 2 + 5] = v1
      texcoords[vertex_idx * 2 + 6] = u0
      texcoords[vertex_idx * 2 + 7] = v1

      // Normals (pointing up)
      for n in 0 ..< 4 {
        normals[vertex_idx * 3 + n * 3 + 0] = 0
        normals[vertex_idx * 3 + n * 3 + 1] = 1
        normals[vertex_idx * 3 + n * 3 + 2] = 0
      }

      // Indices for two triangles per quad (counter-clockwise)
      i0 := u16(vertex_idx)
      indices[index_idx + 0] = i0
      indices[index_idx + 1] = i0 + 1
      indices[index_idx + 2] = i0 + 2
      indices[index_idx + 3] = i0
      indices[index_idx + 4] = i0 + 2
      indices[index_idx + 5] = i0 + 3

      vertex_idx += 4
      index_idx += 6
    }
  }

  // Assign pointers to mesh
  mesh.vertices = raw_data(vertices)
  mesh.texcoords = raw_data(texcoords)
  mesh.normals = raw_data(normals)
  mesh.indices = raw_data(indices)
  rl.UploadMesh(&mesh, false)
  return mesh
}
