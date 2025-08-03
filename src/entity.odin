package main

import "core:log"
import "core:reflect"
import "core:slice"
import rl "vendor:raylib"


// Entity struct, stored directly in a dynamic array
Entity :: struct {
  stats:              EntityStats,
  rotation:           quaternion,
  position:           float3,
  forward:            float3,
  idx_model:          int,
  target:             EntityHandle,
  handle:             EntityHandle,
  yRot:               float,
  collisionRadiusSqr: float,
  active:             bool,
  flags:              bit_set[Entity_Flags],
  aabb:               rl.BoundingBox,
  knockback:          Knockback,
}

Entity_Flags :: enum {
  player,
  bullet,
  dead,
  enemy_fodder,
  enemy_ranged,
  static,
  aabb_dirty,
}

EntityStats :: struct {
  health:    float,
  speed:     float,
  lifetime:  float,
  damage:    float,
  shield:    float,
  speedMode: SpeedDecreaseMode,
}


SpeedDecreaseMode :: enum byte {
  None = 0,
  Linear,
  Cubic,
  Circ,
}

EntityHandle :: struct {
  index:      u32, // Index into the entity array
  generation: i32, // Generation to ensure handle validity
}

EntityManager :: struct {
  entities:     [dynamic]Entity,
  free_indices: [dynamic]u32,
}

entity_debug_names: map[EntityHandle]string

zero_handle :: EntityHandle{0, -1}

init_entity_manager :: proc() -> EntityManager 
{
  entity_debug_names = make(map[EntityHandle]string)
  reserve(&entity_debug_names, MAX_ENTITIES)
  return EntityManager{entities = make([dynamic]Entity, 0, MAX_ENTITIES), free_indices = make([dynamic]u32)}
}

destroy_entity_manager :: proc() 
{
  delete(manager.entities)
  delete(manager.free_indices)
}

create_and_get_entity :: proc() -> ^Entity 
{
  handle := create_entity()
  return get_entity(handle)
}

set_entity_debug_name :: proc(name: string, handle: EntityHandle) 
{
  if handle not_in entity_debug_names {
    entity_debug_names[handle] = name
  }
}

get_entity_debug_name :: proc(name: string, handle: EntityHandle) -> string 
{
  if handle in entity_debug_names {
    return entity_debug_names[handle]
  }
  return "DEBUG NAME NOT FOUND"
}

create_entity :: proc() -> EntityHandle 
{
  index: u32
  generation: i32

  // Reuse a free index if available
  if len(manager.free_indices) > 0 {
    index = pop(&manager.free_indices)
    generation = manager.entities[index].handle.generation
  } else {
    // Append a new entity
    index = u32(len(manager.entities))
    generation = 0
    append(&manager.entities, Entity{})
  }

  manager.entities[index] = Entity {
    handle = EntityHandle{index = index, generation = generation},
    active = true,
  }

  return EntityHandle{index, generation}
}

destroy_entity :: proc(handle: EntityHandle) -> bool 
{
  if !is_valid_handle(handle) {
    return false
  }
  manager.entities[handle.index].active = false
  manager.entities[handle.index].handle.generation += 1
  manager.entities[handle.index].flags = {}
  append(&manager.free_indices, handle.index)
  return true
}

is_valid_handle :: proc(handle: EntityHandle) -> bool 
{
  if handle.index >= u32(len(manager.entities)) {
    return false
  }
  entity := manager.entities[handle.index]
  return entity.active && entity.handle.generation == handle.generation
}

get_entity :: proc(handle: EntityHandle) -> ^Entity 
{
  if !is_valid_handle(handle) {
    return nil
  }
  return &manager.entities[handle.index]
}


set_entity :: proc(entity: Entity) 
{
  manager.entities[entity.handle.index] = entity
}
