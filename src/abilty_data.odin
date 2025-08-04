package main

AbilityType :: enum {
  Shield_Dash,
  Divine_Weapons,
}

AbilityLibraryData :: struct {
  title: string,
  desc:  string,
}

ability_library :: [AbilityType]AbilityLibraryData {
  .Divine_Weapons = {
    title = "Divine Weapons",
    desc = "Summons shields around you, granting extra shield value. If the shields are still alive after a few seconds, activate the ability again to turn them into swords and fire them towards the enemy",
  },
  .Shield_Dash = {title = "Shield Dash", desc = "Lock onto a target, left click to dash towards the target, dealing AOE damage on impact"},
}
