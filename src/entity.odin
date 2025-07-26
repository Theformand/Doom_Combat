package main

import "core:fmt"
import "core:slice"
import rl "vendor:raylib"


// Entity struct, stored directly in a dynamic array
Entity :: struct {
  rotation:           quaternion,
  position:           float3,
  forward:            float3,
  handle:             EntityHandle,
  flags:              bit_set[Entity_Flags],
  stats:              EntityStats,
  target:             EntityHandle,
  yRot:               float,
  collisionRadiusSqr: float,
  active:             bool,
}

Entity_Flags :: enum {
  player,
  bullet,
  dead,
  enemy_fodder,
  enemy_heavy,
}

EntityStats :: struct {
  health:    float,
  speed:     float,
  lifetime:  float,
  damage:    float,
  speedMode: SpeedDecreaseMode,
}

SpeedDecreaseMode :: enum byte {
  None = 0,
  Linear,
  Cubic,
  Circ,
}

// EntityHandle to reference entities
EntityHandle :: struct {
  index:      u32, // Index into the entity array
  generation: i32, // Generation to ensure handle validity
}

// EntityManager to manage the collection of entities
EntityManager :: struct {
  entities:     [dynamic]Entity,
  free_indices: [dynamic]u32,
  next_id:      u32,
}

zero_handle :: EntityHandle{0, -1}

// Initialize the entity manager
init_entity_manager :: proc() -> EntityManager 
{
  return EntityManager{entities = make([dynamic]Entity, 0, MAX_ENTITIES), free_indices = make([dynamic]u32), next_id = 1}
}

// Destroy the entity manager
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

// Create a new entity and return its handle
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

  // Initialize the entity
  manager.entities[index] = Entity {
    handle = EntityHandle{index = manager.next_id, generation = generation},
    active = true,
  }
  manager.next_id += 1

  return EntityHandle{index, generation}
}

// Destroy an entity by handle
destroy_entity :: proc(handle: EntityHandle) -> bool 
{
  if !is_valid_handle(handle) {
    return false
  }
  // Mark entity as inactive and increment generation
  manager.entities[handle.index].active = false
  manager.entities[handle.index].handle.generation += 1
  manager.entities[handle.index].flags = {}
  append(&manager.free_indices, handle.index)
  return true
}

// Check if a handle is valid
is_valid_handle :: proc(handle: EntityHandle) -> bool 
{
  if handle.index >= u32(len(manager.entities)) {
    return false
  }
  entity := manager.entities[handle.index]
  return entity.active && entity.handle.generation == handle.generation
}

// Get an entity by handle (returns nil if invalid)
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
