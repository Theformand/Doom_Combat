package main

import rl "vendor:raylib"

ActionMap :: struct {
  active:                bool,
  shootTriggered:        bool,
  shootHeld:             bool,
  shield_dash_triggered: bool,
  shield_held:           bool,
  type:                  ActionMapType,
}

ActionMapType :: enum byte {
  Core,
  Core_UI,
  Menu_UI,
}


core_input: ActionMap
core_ui_input: ActionMap
maps: [2]ActionMap


init_input_handling :: proc() 
{
  core_input = ActionMap{}
  core_ui_input = ActionMap{}
  maps = [2]ActionMap{core_input, core_ui_input}
  set_action_map(.Core)
  append(&update_procs, update_input)
}

update_input :: proc() 
{
  core_input.shield_held = rl.IsMouseButtonDown(.RIGHT)
  core_input.shield_dash_triggered = rl.IsMouseButtonDown(.RIGHT) && rl.IsMouseButtonPressed(.LEFT)
  core_input.shootHeld = !rl.IsMouseButtonDown(.RIGHT) && rl.IsMouseButtonDown(.LEFT)
  core_input.shootTriggered = !rl.IsMouseButtonDown(.RIGHT) && rl.IsMouseButtonPressed(.LEFT)
}

set_action_map :: proc(type: ActionMapType) 
{
  for &m in maps {
    m.active = m.type == type
  }
}
