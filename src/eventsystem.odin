package main

import "core:log"


evt_buffer_enemy_death: [dynamic]DeathEvent



DeathEvent :: struct {
  weaponId:  int,
  pos:       float3,
  damage:    float,
  direction: float3,
  flags:     bit_set[Entity_Flags]
}

SpawnEvent :: struct{
  handle : EntityHandle,
  pos : float3
}

init_eventsystems :: proc() 
{
  evt_buffer_enemy_death = make([dynamic]DeathEvent)
  reserve(&evt_buffer_enemy_death, 100)
  append(&update_procs, update_eventsystems)
  append(&late_update_procs, late_update_eventsystems)
}

update_eventsystems :: proc() 
{
  for evt in evt_buffer_enemy_death {
    //TODO: react to death events here
    log.debug("enemy died!")
  }
}

fire_event :: proc{fire_event_deathinfo,fire_event_spawninfo}

fire_event_deathinfo :: proc(evt: DeathEvent) 
{
  append(&evt_buffer_enemy_death, evt)
}

fire_event_spawninfo :: proc(evt : SpawnEvent){

}

late_update_eventsystems :: proc() 
{
  clear(&evt_buffer_enemy_death)
}
