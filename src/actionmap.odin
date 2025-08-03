package main

import "core:log"
import rl "vendor:raylib"

ActionMap :: struct {
  active:            bool,
  shootTriggered:    bool,
  shootHeld:         bool,
  ability_triggered: bool,
  ability_held:      bool,
  type:              ActionMapType,
  moveVertical:      float,
  moveHorizontal:    float,
}

ActionMapType :: enum byte {
  Core,
  Core_UI,
  Menu_UI,
}

core_input: ActionMap
core_ui_input: ActionMap

init_input_handling :: proc() 
{
  core_input = ActionMap {
    type = .Core,
  }
  core_ui_input = ActionMap {
    type = .Core_UI,
  }

  set_action_map(.Core)
  append(&update_procs, update_input)
}

update_input :: proc() 
{
  if core_input.active {

    core_input.ability_held = rl.IsKeyDown(.R)
    core_input.ability_triggered = rl.IsKeyPressed(.R)
    core_input.shootHeld = !rl.IsMouseButtonDown(.RIGHT) && rl.IsMouseButtonDown(.LEFT)
    core_input.shootTriggered = !rl.IsMouseButtonDown(.RIGHT) && rl.IsMouseButtonPressed(.LEFT)
    core_input.moveHorizontal = 0
    core_input.moveVertical = 0

    if rl.IsKeyDown(.W) {
      core_input.moveVertical = 1
    }
    if (rl.IsKeyDown(.S)) {
      core_input.moveVertical = -1
    }
    if (rl.IsKeyDown(.A)) {
      core_input.moveHorizontal = 1
    }
    if (rl.IsKeyDown(.D)) {
      core_input.moveHorizontal = -1
    }
  } else {
    core_input = {}
  }
}

set_action_map :: proc(type: ActionMapType) 
{
  core_input.active = type == .Core
  core_ui_input.active = type == .Core_UI
}
