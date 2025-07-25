package main
import "core:fmt"
import "core:math"

PlayerStats :: struct {
  baseStats:   [dynamic]StatEntry,
  damage:      float,
  critChance:  float,
  critPower:   float,
  reloadSpeed: float,
}


StatEntry :: struct {
  type:    StatType,
  amount:  float,
  modType: StatModifierType,
}

StatModifierType :: enum byte {
  Base,
  Add,
  Mult,
}

StatType :: enum byte {
  Damage,
  ReloadSpeed,
  CritChance,
  CritPower,
}

player_stats: PlayerStats

init_player_stats :: proc() 
{
  player_stats = PlayerStats {
    baseStats = make([dynamic]StatEntry),
  }

  add_player_stat(StatEntry{.Damage, 1, .Base})
  add_player_stat(StatEntry{.Damage, 2, .Mult})
}


add_player_stat :: proc(entry: StatEntry) 
{

  if entry.modType == .Base {
    append(&player_stats.baseStats, entry)
  }

  mod: float = 0
  base: float = 0
  for s in &player_stats.baseStats {
    if s.modType == .Base {
      base = s.amount
    }
    if s.type == entry.type && entry.modType == .Mult {
      mod += entry.amount

    }
  }

  result := base * math.max(1, mod)
  //REFRESH STATS
  switch type := entry.type; type {

  case .CritChance: player_stats.critChance = result
  case .Damage: player_stats.damage = result
  case .CritPower: player_stats.critPower = result
  case .ReloadSpeed: player_stats.reloadSpeed = result

  }
}
