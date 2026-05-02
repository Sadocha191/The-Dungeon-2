# STUDIO_REPO_PARITY_PLAN

This plan defines how to bring the repo to 1:1 parity with Roblox Studio without changing gameplay logic or reorganizing by systems yet.

## Etap 0 - Backup i zasady

- Nic nie kasowac.
- Nic nie przenosic w Studio.
- Najpierw tylko kopiowac brakujace skrypty ze Studio do repo.
- Repo-only pliki oznaczac, ale nie usuwac.
- Kazda zmiana musi miec rollback.
- Studio pozostaje zrodlem prawdy, chyba ze uzytkownik powie inaczej.
- Nie zmieniac nazw obiektow, remote'ow, modulow, folderow, attributes ani tagow.
- Nie rozpoczynac reorganizacji po systemach przed parity 1:1.

## Etap 1 - Studio-only do repo

Canonical target paths below use the proposed future mirror root `roblox/`. The first parity mirror batch is now present on disk for selected Studio-only scripts.

### Batch status

- Script parity status:
  - `COMPLETE` at repo-coverage level for the last known Studio snapshot.
- Full object parity status:
  - `PARTIAL` because non-script hierarchy, manifests, duplicate-instance handling, and repo-only snapshot decisions are still pending.
- Completed in parity batches:
  - `Poziom/ReplicatedStorage`: `ClientLoadingOverlay`, `CraftingConfig`, `NpcShared`, `SpellDefinitions`, `WeaponConfigs`, `EventDefinitions`
  - `Poziom/StarterPlayer/StarterCharacter`: `Animate`
  - `Poziom/ServerStorage/EnemyRigBackup`: exact mirrors created for `Elite/{Ent,Golem,Knight}/Animate` and `Normal/{Demon,Goblin,Harp,LandShark,Skeleton,Slime,Warewolf,Zombie}/Animate`
  - `Poziom/ServerStorage/IslandGeneratorFolder`: exact mirror created for `TerrainMaterialModule`
  - `Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock`: exact mirrors created for `qPerfectionWeld` and `Script`
  - `Cztery szczyty/ServerScriptService`: `Script.DayNightCycle`, `ResetDefaultAnimations`
  - `Cztery szczyty/StarterPlayer/StarterCharacter`: `Animate`
  - `Cztery szczyty/Workspace/NPCs/Blacksmith`: `Animate`
  - `Cztery szczyty/Workspace/Rig`: one canonical `Animate.lua` source mirror created
  - `Cztery szczyty/ServerStorage/Modele/Rig`: exact mirror created for `Animate`
  - `Cztery szczyty/ServerStorage/WeaponTemplates/Bow/Stormwind Recurve`: exact mirror created for `Projectile`
  - `Cztery szczyty/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock`: exact mirrors created for `Script` and `qPerfectionWeld`
  - `Cztery szczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain`: exact mirrors created for `BulletScript`, `GravityShield`, and `GravityShieldLocal`
  - `Cztery szczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff`: exact mirrors created for `Burn/BurnScript`, `EnergyNameScript`, `StaffCore/Attachment/BillboardGui/SpinningScript`, `StaffCore/IdleScript`, and `StaffCore/LightningScript`
  - `Cztery szczyty/ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain`: exact mirrors created for `BigBulletScript`, `MeteorStormScript`, and `MeteorStormScript/BulletScript`
  - `Cztery szczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings`: exact mirrors created for `DeathSouls/SoulScript`, `Fireball/Despawn`, `Handle/Light/Fire_Effect`, `Server/AfterImageScript`, `Server/AfterImageScript/Decimate`, `Server/AfterImageScript/SlowScript`, `Server/Decimate`, `Server/SoulHunt`, `Server/SoulHunt/SoulHunt_Client`, `Server/SoulHunt/SoulHunt_Seeker`, `Server/SoulScript`, and `Server/SoulScript/Decimate`
- Remaining before full object parity:
  - add `MANIFEST.md` coverage for critical non-script `Tool`, `Model`, `Folder`, `RemoteEvent`, `RemoteFunction`, UI, and portal structures
  - resolve repo-only snapshot decisions under `Level/Workspace` and `Four Peaks/Workspace/NPCs`
  - document the `Workspace.Rig.Animate` duplicate/collision history in a stable manifest policy
  - decide whether the long-term canonical mirror should remain split across historical `Level/` and `Four Peaks/` plus `roblox/`, or whether the full live hierarchy should eventually be mirrored under `roblox/`
- Special note:
  - `Cztery szczyty` currently contains two live `Workspace.Rig.Animate` instances with the same Studio path text and identical source. The repo can mirror the source file once at `roblox/CzterySzczyty/Workspace/Rig/Animate.lua`, but cannot represent duplicate sibling instance count 1:1 on disk without a separate manifest policy.
  - A quick recheck on `2026-05-02` returned one visible `Workspace.Rig.Animate` descendant in the active Studio session. Because parity batches did not modify Studio, treat the earlier duplicate finding as unresolved object-parity ambiguity that still requires manual verification.
  - `Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script` was retried on `2026-05-02` with chunked MCP extraction and exact rolling-checksum verification, and the exact mirror is now present at `roblox/Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script.lua`.

### Poziom

| Place | Roblox path | Typ | Proponowany repo path 1:1 | System | Ryzyko | Uwagi |
|---|---|---|---|---|---|---|
| Poziom | `game.ReplicatedStorage.ModuleScript.ClientLoadingOverlay` | `ModuleScript` | `roblox/Poziom/ReplicatedStorage/ModuleScript/ClientLoadingOverlay.lua` | UI/Loading | MEDIUM | Duplicate compatibility folder exists in Studio and should be mirrored as-is first |
| Poziom | `game.ReplicatedStorage.ModuleScript.CraftingConfig` | `ModuleScript` | `roblox/Poziom/ReplicatedStorage/ModuleScript/CraftingConfig.lua` | Crafting | MEDIUM | Duplicate compatibility folder |
| Poziom | `game.ReplicatedStorage.ModuleScript.NpcShared` | `ModuleScript` | `roblox/Poziom/ReplicatedStorage/ModuleScript/NpcShared.lua` | NPC | HIGH | Used by client/server path fallbacks |
| Poziom | `game.ReplicatedStorage.ModuleScript.SpellDefinitions` | `ModuleScript` | `roblox/Poziom/ReplicatedStorage/ModuleScript/SpellDefinitions.lua` | Combat/Spells | MEDIUM | Duplicate compatibility folder |
| Poziom | `game.ReplicatedStorage.ModuleScript.WeaponConfigs` | `ModuleScript` | `roblox/Poziom/ReplicatedStorage/ModuleScript/WeaponConfigs.lua` | Combat/Weapons | HIGH | Central config module |
| Poziom | `game.ReplicatedStorage.ModuleScripts.EventDefinitions` | `ModuleScript` | `roblox/Poziom/ReplicatedStorage/ModuleScripts/EventDefinitions.lua` | Events | MEDIUM | Studio-only seasonal/event config |
| Poziom | `game.StarterPlayer.StarterCharacter.Animate` | `LocalScript` | `roblox/Poziom/StarterPlayer/StarterCharacter/Animate.lua` | Character | HIGH | Animation path is sensitive |
| Poziom | `game.ServerStorage.EnemyRigBackup.Elite.*.Animate` | `Script x3` | `roblox/Poziom/ServerStorage/EnemyRigBackup/Elite/<MobName>/Animate.lua` | NPC/Legacy | HIGH | Exact mirrors created on `2026-05-01`; covers `Ent`, `Golem`, `Knight` |
| Poziom | `game.ServerStorage.EnemyRigBackup.Normal.*.Animate` | `Script x8` | `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/<MobName>/Animate.lua` | NPC/Legacy | HIGH | Exact mirrors created on `2026-05-01`; covers `Demon`, `Goblin`, `Harp`, `LandShark`, `Skeleton`, `Slime`, `Warewolf`, `Zombie` |
| Poziom | `game.ServerStorage.IslandGeneratorFolder.TerrainMaterialModule` | `ModuleScript` | `roblox/Poziom/ServerStorage/IslandGeneratorFolder/TerrainMaterialModule.lua` | World/Map generation | HIGH | Exact mirror created on `2026-05-01` |
| Poziom | `game.ServerStorage.WeaponTemplates.Pistol.Blackpowder Flintlock.Script` | `Script` | `roblox/Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` after chunked MCP extraction and full rolling-checksum verification |
| Poziom | `game.ServerStorage.WeaponTemplates.Pistol.Blackpowder Flintlock.qPerfectionWeld` | `Script` | `roblox/Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/qPerfectionWeld.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-01` |

### Cztery szczyty

| Place | Roblox path | Typ | Proponowany repo path 1:1 | System | Ryzyko | Uwagi |
|---|---|---|---|---|---|---|
| Cztery szczyty | `game.ServerScriptService.Script.DayNightCycle` | `Script` | `roblox/CzterySzczyty/ServerScriptService/Script/DayNightCycle.lua` | Lobby/World | MEDIUM | Studio-only server script |
| Cztery szczyty | `game.ServerScriptService.ResetDefaultAnimations` | `Script` | `roblox/CzterySzczyty/ServerScriptService/ResetDefaultAnimations.lua` | Character | HIGH | Sensitive animation override |
| Cztery szczyty | `game.StarterPlayer.StarterCharacter.Animate` | `LocalScript` | `roblox/CzterySzczyty/StarterPlayer/StarterCharacter/Animate.lua` | Character | HIGH | Missing from repo |
| Cztery szczyty | `game.Workspace.NPCs.Blacksmith.Animate` | `LocalScript` | `roblox/CzterySzczyty/Workspace/NPCs/Blacksmith/Animate.lua` | Lobby/NPC | HIGH | Live Studio model currently has animate only |
| Cztery szczyty | `game.Workspace.Rig.Animate` | `LocalScript` | `roblox/CzterySzczyty/Workspace/Rig/Animate.lua` | Legacy/Workspace | HIGH | Studio currently shows duplicate instances; verify exact model layout while mirroring |
| Cztery szczyty | `game.ServerStorage.Modele.Rig.Animate` | `LocalScript` | `roblox/CzterySzczyty/ServerStorage/Modele/Rig/Animate.lua` | Legacy | HIGH | Exact mirror created on `2026-05-02` after chunked MCP extraction and full rolling-checksum verification |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Bow.Stormwind Recurve.Projectile` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Bow/Stormwind Recurve/Projectile.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Pistol.Blackpowder Flintlock.Script` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` after chunked MCP extraction and full rolling-checksum verification |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Pistol.Blackpowder Flintlock.qPerfectionWeld` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/qPerfectionWeld.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Scythe.Reaper’s Crescent.ScytheMain.{BulletScript,GravityShield,GravityShieldLocal}` | `Script/LocalScript` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain/<ScriptName>.lua` | Combat/Weapons | HIGH | Exact mirrors created on `2026-05-02`; Unicode folder name `Reaper’s Crescent` was mirrored directly without fallback mapping |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Staff.Apprentice Arcstaff.{Burn.BurnScript,EnergyNameScript,StaffCore.Attachment.BillboardGui.SpinningScript,StaffCore.IdleScript,StaffCore.LightningScript}` | `Script x5` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/...` | Combat/Weapons | HIGH | Exact mirrors created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Staff.Archmage’s Worldstaff.StaffMain.{BigBulletScript,MeteorStormScript,MeteorStormScript.BulletScript}` | `Script x3` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain/...` | Combat/Weapons | HIGH | Exact mirrors created on `2026-05-02`; Unicode folder name was mirrored directly without fallback mapping |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.DeathSouls.SoulScript` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/DeathSouls/SoulScript.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.Fireball.Despawn` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Fireball/Despawn.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.Handle.Light.Fire_Effect` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Handle/Light/Fire_Effect.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.Server.{AfterImageScript,AfterImageScript.Decimate,AfterImageScript.SlowScript}` | `Script x3` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/AfterImageScript/...` | Combat/Weapons | HIGH | Exact mirrors created on `2026-05-02`; `SlowScript` required preserving a trailing newline from Studio |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.Server.Decimate` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/Decimate.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.Server.SoulHunt` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulHunt.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.Server.SoulHunt.{SoulHunt_Client,SoulHunt_Seeker}` | `LocalScript x2` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulHunt/<ScriptName>.lua` | Combat/Weapons | HIGH | Exact mirrors created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.Server.SoulScript` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulScript.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |
| Cztery szczyty | `game.ServerStorage.WeaponTemplates.Sword.Excalion, Blade of Kings.Server.SoulScript.Decimate` | `Script` | `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulScript/Decimate.lua` | Combat/Weapons | HIGH | Exact mirror created on `2026-05-02` |

## Etap 2 - Repo-only do oznaczenia

Do not remove these files yet.

| Repo path | Oczekiwany Roblox path | Status | Propozycja | Ryzyko | Uwagi |
|---|---|---|---|---|---|
| `Level/Workspace/Rig/LocalScript/Animate.lua` | `game.Workspace.Rig.Animate` | `stale_snapshot` | Keep and mark as repo-only until the user decides whether to restore or archive it | HIGH | Current `Poziom` Studio state has no matching `Workspace.Rig` |
| `Four Peaks/Workspace/NPCs/Blacksmith/Blacksmith.lua` | `game.Workspace.NPCs.Blacksmith.Blacksmith` | `candidate_for_removal_later` | Keep for now and review only after parity plus manual Studio testing | HIGH | Current Studio uses `ServerScriptService.Script.BlacksmithService` and only shows `Workspace.NPCs.Blacksmith.Animate` |
| `Four Peaks/Workspace/NPCs/MissionNPC/MissionNPC.lua` | `game.Workspace.NPCs.MissionNPC.MissionNPC` | `candidate_to_restore_to_studio` | Keep and investigate whether the model/script should return to live Studio | HIGH | Current Studio inspection did not show `MissionNPC` under `Workspace.NPCs` |
| `Four Peaks/Workspace/NPCs/Witch/Witch.lua` | `game.Workspace.NPCs.Witch.Witch` | `candidate_for_removal_later` | Keep for now and decide only after parity plus manual Studio verification | HIGH | Current Studio uses `ServerScriptService.Script.WitchNPC`; live model currently has no matching script visible |

## Etap 3 - Ujednolicenie dokumentacji

After missing Studio scripts are copied into the repo:

- update `PROJECT_MAP.md`
- update `ROBLOX_REPO_SYNC.md`
- update `CHANGELOG_AI.md`
- add `MANIFEST.md` files for important non-script objects and containers
- document repo-only status for old snapshots

## Etap 4 - Dopiero potem reorganizacja po systemach

Reorganizacja folderow po systemach, np. `Combat`, `NPC`, `UI`, `Lobby`, `Level`, moze byc planowana dopiero po parity 1:1.

Before that point:

- do not merge artificial mirror trees
- do not collapse compatibility folders
- do not rename paths just to make the repo prettier
- do not move scripts between services or models
