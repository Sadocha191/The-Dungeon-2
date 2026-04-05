# The Dungeon 2

The Dungeon 2 is a Roblox survivors action RPG built around two connected experiences: a persistent lobby and high-pressure dungeon runs. Players prepare in town, enter a hostile biome, survive escalating enemy pressure, collect materials and rewards, then bring that progress back into the long-term meta loop.

The project takes inspiration from Vampire Survivors, Megabonk, and dark fantasy dungeon crawlers, but leans harder into exploration, loot routing, portal progression, and account-based progression between runs.

## Core Pillars

- A lobby that matters, with progression systems that persist beyond a single match
- Auto-attack combat focused on movement, positioning, upgrades, and survival pressure
- Dark fantasy runs built around exploration, scaling enemy density, and boss finishes
- Weapon progression through crafting, upgrading, recipes, and long-term collection
- A connected loop where success in the dungeon feeds directly back into the lobby

## Current Gameplay Slice

### Lobby (`Four Peaks`)

The lobby is the backbone of the game's meta progression. The current project includes systems for:

- tutorial and onboarding flow
- character creation and race selection
- inventory, weapon ownership, and equipment syncing
- blacksmith crafting, recipe unlocks, upgrades, and selling
- rotating daily and weekly missions
- mining routes and material gathering
- party flow, level selection, and dungeon teleporting
- banner and NPC-driven shop systems

### Dungeon (`Level`)

The combat place is built around survivors-style pressure and automatic attacking. The current project includes systems for:

- time-based enemy escalation instead of fixed waves
- weapon archetypes across swords, scythes, halberds, bows, pistols, and staves
- level-up offers with reroll, skip, banish, and spell selection
- elite pressure spikes and late-run boss flow
- chests, shrines, pickups, reward reveals, and mission tracking
- persistent drops and progression hooks that feed rewards back to the lobby

## World And Content

Current level definitions include:

- Ashen Wastes
- Hollow Marsh
- Blightmoor
- Shattered Highlands
- Dreadwood

The current enemy roster in the combat place includes:

- Slime
- Zombie
- Skeleton
- Goblin
- Warewolf
- Harp
- Demon
- LandShark
- Golem
- Knight
- Ent

Example weapon lineup currently present in the repo includes:

- Knight's Oath
- Hunter's Longbow
- Warden's Halberd
- Reaper's Crescent
- Excalion, Blade of Kings
- Harvest of the End
- Archmage's Worldstaff
- Kingslayer Handcannon

## Repo Layout

This repository is organized around place snapshots, not a single Rojo-first source tree.

- `Four Peaks/` - lobby place snapshot with meta progression, NPC systems, missions, crafting, and teleport flow
- `Level/` - combat place snapshot with enemy spawning, run systems, combat logic, rewards, and mission hooks
- `src/` - minimal Rojo bootstrap/example source tree
- `default.project.json` - lightweight Rojo project file for `src/`, not the primary workflow for the full game

If you are looking for the main gameplay code, start in `Four Peaks` for lobby systems and `Level` for run systems.

## Good Entry Points

Useful files for understanding the current architecture:

- `Four Peaks/ServerScriptService/Script/BlacksmithService.lua`
- `Four Peaks/ServerScriptService/ModuleScript/CraftingService.lua`
- `Four Peaks/ServerScriptService/ModuleScript/MissionService.lua`
- `Four Peaks/ServerScriptService/Script/PortalToDungeon.lua`
- `Level/ServerScriptService/Script/Model.model/WaveController.lua`
- `Level/ServerScriptService/Script/ProgressService.lua`
- `Level/ServerScriptService/Script/WeaponCombat.server.lua`
- `Level/ServerScriptService/Script/SpellService.lua`

## Development Notes

- `Four Peaks` and `Level` are separate place snapshots and should be treated as different sides of the same game
- `src/` is not a full mirror of the live project
- When making changes, verify that you are editing the correct side:
  - `Four Peaks` for lobby and meta systems
  - `Level` for combat and run logic

## Status

The Dungeon 2 is an active in-development Roblox project. The current codebase already contains the backbone for the lobby-to-run loop, and ongoing work is focused on combat pacing, progression depth, content expansion, and polish.
