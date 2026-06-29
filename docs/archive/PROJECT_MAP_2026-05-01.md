# PROJECT_MAP

Current state snapshot based on MCP inspection of the active Roblox Studio places and filesystem analysis on `2026-05-01`.

Primary rule: Studio is the current source of truth. The repo is not yet a clean 1:1 mirror.

## Place Summary

| Place | Studio name | Current repo mirror | Studio script count | High-level status |
|---|---|---|---:|---|
| Poziom | `Poziom` | `Level/` | 152 | Close to parity, but not 1:1 |
| Cztery szczyty | `Cztery szczyty` | `Four Peaks/` | 139 | Clear drift vs repo |

## Główne systemy

- Lobby/NPC/Tutorial/CharacterCreation
- Portal/Teleport/LevelSelect
- Combat/Weapons/Spells
- NPC AI/Waves/Run progression
- Inventory/Crafting/Save/Profile/Currency
- Missions/Bounties/Daily/Event
- UI/HUD/Settings/Overlays
- Remotes/Error reporting
- Legacy weapon asset scripts
- World/Environment/Map generation

## Poziom

### Główne systemy

- Combat, weapon auto-attack, spell casting, and combat VFX.
- NPC spawning, wave control, run progression, drops, shrines, statues, and chest rewards.
- HUD, pause flow, loading, mission summary, run stats, and reward presentation.
- Teleport return flow back to lobby.
- Daily missions and seasonal event definitions.
- Legacy weapon template scripts in `ServerStorage`.
- World bounds and terrain-tag-based ground logic.

### Najważniejsze foldery Roblox Studio

- `ServerScriptService`
- `ReplicatedStorage`
- `StarterPlayer`
- `StarterGui`
- `ServerStorage`
- `ReplicatedFirst`

### Najważniejsze foldery w repo

- `Level/ServerScriptService/`
- `Level/ReplicatedStorage/`
- `Level/StarterPlayer/`
- `Level/StarterGUI/`
- `Level/ServerStorage/`
- `Level/ReplicatedFirst/`
- `src/` and `default.project.json` exist, but they are not the current 1:1 workflow baseline.

### Systemy wrażliwe na zmianę ścieżek

- `WaveController`, `ProgressService`, `NpcService`, `WeaponCombat`, `SpellService`, `ChestService`, `WeaponService`
- `RunTeleportOverlay`, `RunStatsHud`, `NpcPresentation`, `MissionSummary`, `PauseClient`
- `ReplicatedStorage.Remotes`
- `ReplicatedStorage.ModuleScript` and `ReplicatedStorage.ModuleScripts`
- `ServerStorage.WeaponTemplates`

### Krytyczne foldery i obiekty, których nie wolno ruszać bez osobnego planu

- `ReplicatedStorage.Remotes`
- `ReplicatedStorage.ModuleScript`
- `ReplicatedStorage.ModuleScripts`
- `ServerScriptService.ModuleScript`
- `ServerStorage.WeaponTemplates`
- `StarterPlayer.StarterCharacter.Animate`
- `ServerStorage.EnemyRigBackup`
- `ServerStorage.IslandGeneratorFolder`
- `WaveController`
- `ProgressService`
- `NpcService`
- `WeaponCombat`

## Cztery szczyty

### Główne systemy

- Lobby NPC flow: Blacksmith, Witch, Character Creator, Knight tutorial path, banner NPC.
- Character creation, race flow, tutorial progression, and lobby progression.
- Portal-to-dungeon level selection and teleport preparation.
- Inventory, crafting, currencies, profile state, party flow, and save scheduler.
- Lobby UI, settings, profile stats, missions, banners, mine, party, blacksmith, witch shop.
- Legacy weapon template scripts in `ServerStorage`.
- Extra environment scripts like `DayNightCycle` and animation overrides.

### Najważniejsze foldery Roblox Studio

- `ServerScriptService`
- `ReplicatedStorage`
- `StarterPlayer`
- `StarterGui`
- `Workspace`
- `ServerStorage`

### Najważniejsze foldery w repo

- `Four Peaks/ServerScriptService/`
- `Four Peaks/ReplicatedStorage/`
- `Four Peaks/StarterPlayer/`
- `Four Peaks/StarterGui/`
- `Four Peaks/Workspace/`
- `Four Peaks/ServerStorage/`

### Systemy wrażliwe na zmianę ścieżek

- `PortalToDungeon`, `TutorialService`, `InventoryController`, `BlacksmithService`, `WitchNPC`, `MissionService`, `ProfilesManager`
- `PortalUIController`, `PortalUIClient`, `ProfileStatsClient`, `SettingsClient`, `PartyClient`
- `Workspace.NPCs`
- `ReplicatedStorage.RemoteEvents`
- `ReplicatedStorage.RemoteFunctions`
- `ReplicatedStorage.ModuleScripts`
- `ServerStorage.WeaponTemplates`

### Krytyczne foldery i obiekty, których nie wolno ruszać bez osobnego planu

- `ReplicatedStorage.RemoteEvents`
- `ReplicatedStorage.RemoteFunctions`
- `ReplicatedStorage.ModuleScripts`
- `ServerScriptService.ModuleScript`
- `ServerStorage.WeaponTemplates`
- `Workspace.NPCs`
- `Portal`, `PortalModel`, `PortalTeleport`
- `StarterPlayer.StarterCharacter.Animate`
- `ResetDefaultAnimations`
- `TutorialService`
- `PortalToDungeon`
- `InventoryController`
- `PortalUIController`

## Critical Roblox objects

- `ReplicatedStorage.Remotes`
- `ReplicatedStorage.RemoteEvents`
- `ReplicatedStorage.RemoteFunctions`
- `ReplicatedStorage.ModuleScript`
- `ReplicatedStorage.ModuleScripts`
- `ServerScriptService.ModuleScript`
- `ServerStorage.WeaponTemplates`
- `Workspace.NPCs`
- `Portal / PortalModel / PortalTeleport`
- `StarterCharacter.Animate`
- `ResetDefaultAnimations`
- legacy `Animate` scripts
- `WaveController`
- `ProgressService`
- `NpcService`
- `WeaponCombat`
- `PortalUIController`
- `InventoryController`
- `TutorialService`
- `PortalToDungeon`

### Critical Attributes

- `RunMode`
- `RunEnded`
- `Paused`
- `TutorialActive`
- `TutorialStep`
- `TutorialComplete`
- `Race`
- `Class`
- `StarterWeaponName`
- `WeaponType`
- `WeaponInstanceId`
- `WeaponLevel`
- `Modal`
- `ScreenButtonsNonce`
- `ScreenButtonsAction`

### CollectionService tags

- `Terrain`
- `Puppet`

## Known Drift Summary

### Poziom

- Studio contains both `ReplicatedStorage.ModuleScript` and `ReplicatedStorage.ModuleScripts`.
- Studio contains `ReplicatedStorage.ModuleScripts.EventDefinitions`, but the repo does not.
- Studio contains `StarterPlayer.StarterCharacter.Animate`, but the repo does not.
- Studio contains `ServerStorage.EnemyRigBackup` animate scripts and `IslandGeneratorFolder.TerrainMaterialModule`, but the repo does not.
- Studio contains extra `Blackpowder Flintlock` scripts, but the repo mirror is incomplete.
- Repo contains `Level/Workspace/Rig/LocalScript/Animate.lua`, while Studio currently has no matching `Workspace.Rig`.

### Cztery szczyty

- Studio contains `DayNightCycle` and `ResetDefaultAnimations`, but the repo does not.
- Studio contains `StarterPlayer.StarterCharacter.Animate`, but the repo does not.
- Studio contains multiple `Workspace` or `ServerStorage` animate scripts and deeper `WeaponTemplates` subtrees that the repo does not mirror.
- Repo contains `Workspace/NPCs` scripts (`Blacksmith.lua`, `MissionNPC.lua`, `Witch.lua`) that are not visible in the current Studio place state.
- Studio has only partial parity in `Workspace`, while the repo still stores older per-model script snapshots.

## Unknowns / do sprawdzenia

- Whether `ReplicatedStorage.ModuleScript` in `Poziom` is an intentional live compatibility layer or stale duplication.
- Whether repo-only `Workspace` scripts in `Four Peaks/Workspace/NPCs/` should be restored to Studio or archived as stale snapshots.
- Whether repo-only `Level/Workspace/Rig/LocalScript/Animate.lua` should return to Studio or stay marked stale.
- Whether both `Workspace.Rig.Animate` instances in `Cztery szczyty` are intentional duplicates.
- Whether all missing `ServerStorage.WeaponTemplates` sub-scripts are still actively used in live gameplay or just inherited asset internals.
- Whether apostrophe normalization in some weapon names differs between Studio and filesystem and needs a naming policy before parity work.
- Which non-script `Folder`, `Model`, `Tool`, `RemoteEvent`, `RemoteFunction`, `ScreenGui`, `ProximityPrompt`, and `ValueBase` objects need `MANIFEST.md` coverage first.
- Whether `src/` and `default.project.json` should remain as legacy artifacts, be documented only, or eventually be retired from the main workflow.
- Whether `Lighting` has important non-script content that should be captured in future manifests even though no scripts live there now.
