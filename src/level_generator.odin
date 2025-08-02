package main

import "core:c"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:mem"
import rl "vendor:raylib"

ground_mesh: rl.Mesh
model_prop_barrel: rl.Model
//ground_model: rl.Model
vertCount: int
ground_handle: EntityHandle
ground_tiles: [dynamic]EntityHandle
ground_tile_model: rl.Model
scaleFactor: float

PATH_MODELS :: "resources/models/"
PATH_TEXTURES :: "resources/textures/"
PATH_SHADERS :: "resources/shaders/"
floor_mat: rl.Material


//uniform locations
ambientLoc: int
normalLoc: int
loc_light_positions: int
loc_light_colors: int
loc_intensities: int
loc_ranges: int
loc_light_count: int

loc_dirlight_pos: int
loc_dirlight_color: int
loc_dir_light_intensity: int
transforms: [dynamic]rl.Matrix
level_props: [dynamic]EntityHandle

sun_light: Light
synty_mat: rl.Material

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
  transforms = make([dynamic]rl.Matrix)

  atlas_tex := rl.LoadTexture(PATH_TEXTURES + "atlas01a.png")
  //atlas_normal := rl.LoadTexture(PATH_TEXTURES + "atlas01a_Normals.png")
  floor_tex := rl.LoadTexture(PATH_TEXTURES + "Floor_Tiles_01.png")
  floor_normal := rl.LoadTexture(PATH_TEXTURES + "Floor_Tiles_Normals.png")

  floor_mat = rl.LoadMaterialDefault()


  //rl.SetShaderValueTexture(default_shader, normalLoc, floor_normal)

  rl.SetMaterialTexture(&floor_mat, rl.MaterialMapIndex.ALBEDO, floor_tex)
  //rl.SetMaterialTexture(&floor_mat, .NORMAL, floor_normal)

  rl.SetMaterialTexture(&synty_mat, rl.MaterialMapIndex.ALBEDO, atlas_tex)
  //rl.SetMaterialTexture(&synty_mat, rl.MaterialMapIndex.NORMAL, atlas_normal)
  ground_tile_model = rl.LoadModel(PATH_MODELS + "FloorTile.glb")
  idx_prop_barrel := load_entity_model("Prop_Barrel.glb")
  floor_mat.shader = default_shader

  ground_tile_model.materials[0] = floor_mat
  ground_tile_model.materials[1] = floor_mat

  entity_models[idx_prop_barrel].materials[0] = synty_mat
  entity_models[idx_prop_barrel].materials[1] = synty_mat


  rows: int = 4
  cols: int = 4
  scaleFactor = 2
  offset_x: float
  offset_y: float

  spacing: float = 3
  total_spacing := scaleFactor + spacing

  for row in 0 ..< rows {
    for col in 0 ..< cols {
      x := offset_x + float(col) * total_spacing
      y := offset_y + float(row) * total_spacing
      ground_handle = create_entity()
      ground_ent := get_entity(ground_handle)
      ground_ent.flags += {.static}
      ground_ent.flags += {.aabb_dirty}
      ground_ent.position = float3{x, 0, y}
      //ground_ent.yRot = float(rand_range_int(0, 3) * 90)
      append(&ground_tiles, ground_handle)
      //append(&transforms, matrix_trs(ground_ent.position, float3_one * scaleFactor, quaternion_identity))
    }
  }

  level_props = make([dynamic]EntityHandle)
  centroid: float3
  for i in 0 ..< 4 {
    pos := float3_rand_xz(3) + float3{5, 0, 5}
    handle := create_entity()
    ent := get_entity(handle)
    ent.position = pos
    ent.idx_model = idx_prop_barrel
    centroid += pos
    append(&level_props, handle)
  }

  centroid /= 3

  for i in 0 ..< 10 {
    pos := float3_rand_xz(10) + float3{10, 1, 10}
    range := rand_range(3, 10)
    intensity := rand_range(1, 1.5)
    //col := rl.Color{224, 119, 49, 255}
    create_point_light(pos, rl.PURPLE, 1, range)
  }
  append(&draw_procs, draw_ground_mesh)
}


draw_ground_mesh :: proc() 
{
  //TODO: Instancing
  len := len(ground_tiles)
  pos := get_entity(ground_handle).position
  for &handle, i in ground_tiles {
    ent := get_entity(handle)
    pos := ent.position
    rl.DrawModelEx(ground_tile_model, ent.position, float3_up, ent.yRot, float3_one * scaleFactor, rl.WHITE)
  }
  //rl.DrawMeshInstanced(ground_tile_model.meshes[0], floor_mat, raw_data(transforms), int(len))

  //draw props
  for &handle in level_props {
    e := get_entity(handle)
    rl.DrawModel(entity_models[e.idx_model], e.position, 1.3, rl.WHITE)
  }
}
