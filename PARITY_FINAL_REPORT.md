# PARITY_FINAL_REPORT

Final parity report for the Roblox Studio ↔ repo sync work completed on `2026-05-02`.

## Podsumowanie

- `Script parity`: achieved at repo-coverage level for the last known Studio snapshot.
- `Full object parity`: not achieved yet.
- In this project, `script parity` means every known live `Script`, `LocalScript`, and `ModuleScript` from the verified Studio snapshot has a corresponding source file in the repo.
- In this project, `script parity` does not automatically mean that `roblox/` by itself is already a full standalone export of Studio.
- In this project, `full object parity` means the repo covers scripts plus the critical non-script hierarchy they depend on: `Tool` structure, `Model` layout, `Folder` layout, remotes, UI hierarchy, important values/attributes/tags, and duplicate-instance edge cases.
- Evidence collected for this report:
  - all previously identified Studio-only script gaps were mirrored into the repo
  - all recent parity mirrors were verified as exact matches against live Studio by byte-length plus rolling checksum
  - all `53` planned parity mirror paths from the documented Studio-only batches currently exist on disk under `roblox/`

## Zakres sprawdzonych place

- `Poziom`
- `Cztery szczyty`

## Script parity

### Poziom

- Studio scripts in the last known snapshot: `152`
- Logically covered by the repo now: `152 / 152`
- Scripts added in parity batches:
  - `ReplicatedStorage/ModuleScript`: `ClientLoadingOverlay`, `CraftingConfig`, `NpcShared`, `SpellDefinitions`, `WeaponConfigs`
  - `ReplicatedStorage/ModuleScripts`: `EventDefinitions`
  - `StarterPlayer/StarterCharacter`: `Animate`
  - `ServerStorage/EnemyRigBackup/Elite`: `Ent/Animate`, `Golem/Animate`, `Knight/Animate`
  - `ServerStorage/EnemyRigBackup/Normal`: `Demon/Animate`, `Goblin/Animate`, `Harp/Animate`, `LandShark/Animate`, `Skeleton/Animate`, `Slime/Animate`, `Warewolf/Animate`, `Zombie/Animate`
  - `ServerStorage/IslandGeneratorFolder`: `TerrainMaterialModule`
  - `ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock`: `Script`, `qPerfectionWeld`
- Remaining known script gaps: none in the planned Studio-only parity set.
- Status: `COMPLETE`

### Cztery szczyty

- Studio scripts in the last known snapshot: `139`
- Logically covered by the repo now: `139 / 139`
- Scripts added in parity batches:
  - `ServerScriptService`: `Script/DayNightCycle`, `ResetDefaultAnimations`
  - `StarterPlayer/StarterCharacter`: `Animate`
  - `Workspace/NPCs/Blacksmith`: `Animate`
  - `Workspace/Rig`: canonical source mirror for `Animate`
  - `ServerStorage/Modele/Rig`: `Animate`
  - `ServerStorage/WeaponTemplates/Bow/Stormwind Recurve`: `Projectile`
  - `ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock`: `Script`, `qPerfectionWeld`
  - `ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain`: `BulletScript`, `GravityShield`, `GravityShieldLocal`
  - `ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff`: `Burn/BurnScript`, `EnergyNameScript`, `StaffCore/Attachment/BillboardGui/SpinningScript`, `StaffCore/IdleScript`, `StaffCore/LightningScript`
  - `ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain`: `BigBulletScript`, `MeteorStormScript`, `MeteorStormScript/BulletScript`
  - `ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings`: `DeathSouls/SoulScript`, `Fireball/Despawn`, `Handle/Light/Fire_Effect`, `Server/AfterImageScript`, `Server/AfterImageScript/Decimate`, `Server/AfterImageScript/SlowScript`, `Server/Decimate`, `Server/SoulHunt`, `Server/SoulHunt/SoulHunt_Client`, `Server/SoulHunt/SoulHunt_Seeker`, `Server/SoulScript`, `Server/SoulScript/Decimate`
- Remaining known script gaps: none in the planned Studio-only parity set.
- Status: `COMPLETE`

## Full object parity

`Full object parity` is still `PARTIAL`.

To reach it safely, the repo still needs manifest coverage and explicit decisions for:

- `Tools`
  - especially full `ServerStorage/WeaponTemplates/**` structure beyond just embedded scripts
- `Models`
  - NPC models, portal models, rig models, backup rigs, and other script-dependent containers
- `Folders` used by code
  - especially `Remotes`, `RemoteEvents`, `RemoteFunctions`, `ModuleScript`, `ModuleScripts`, and weapon subfolders
- important non-script objects
  - sounds, particles, attachments, prompts, values, UI objects, and any code-relevant descendants not represented by `.lua` files
- `WeaponTemplates` structure
  - script parity exists, but tool/object parity still needs structural manifests
- NPC models
  - especially `Workspace/NPCs/**`
- portal and teleport objects
  - `Portal`, `PortalModel`, `PortalTeleport`, related lobby/level-select layout
- UI hierarchy
  - `StarterGui` and GUI descendants that scripts depend on by name/path

Until those are documented, the project has script parity but not full object parity.

## Repo-only snapshoty

| Repo path | Obecny status | Ryzyko | Rekomendacja |
|---|---|---|---|
| `Level/Workspace/Rig/LocalScript/Animate.lua` | `stale_snapshot` | `HIGH` | zostawić jako `stale_snapshot` |
| `Four Peaks/Workspace/NPCs/Blacksmith/Blacksmith.lua` | `candidate_for_removal_later` | `HIGH` | usunąć później po decyzji |
| `Four Peaks/Workspace/NPCs/MissionNPC/MissionNPC.lua` | `candidate_to_restore_to_studio` | `HIGH` | wymaga ręcznego sprawdzenia |
| `Four Peaks/Workspace/NPCs/Witch/Witch.lua` | `candidate_for_removal_later` | `HIGH` | usunąć później po decyzji |

## Duplikaty / konflikty

- `Cztery szczyty`: `Workspace.Rig.Animate`
  - Earlier parity analysis found two identical live instances with the same path text.
  - A quick recheck for this final report saw one visible `Workspace.Rig.Animate` descendant in the active Studio session.
  - Because parity batches did not modify Studio, this should be treated as unresolved object-parity ambiguity rather than as a resolved rename/move.
- Repo consequence:
  - the repo can safely keep one canonical file at `roblox/CzterySzczyty/Workspace/Rig/Animate.lua`
  - the filesystem cannot represent duplicate sibling instance count by path alone
- Recommended handling:
  - keep the canonical mirror
  - add a local `MANIFEST.md` when full object parity work starts
  - do not invent suffixes or guess object identity without a manual decision

## Następny bezpieczny krok

1. Zrobić `MANIFEST.md` dla nieskryptowych krytycznych struktur.
2. Domknąć decyzję o repo-only snapshotach.
3. Dopiero potem przygotować plan reorganizacji folderów po systemach.
4. Reorganizację robić tylko `LOW` risk, etapami.

## Rekomendacja

- Można już commitować `script mirrors` plus dokumentację parity.
- Nie należy jeszcze zaczynać reorganizacji folderów po systemach.
- Przed reorganizacją powinny być spełnione te warunki:
  - krytyczne nieskryptowe struktury mają `MANIFEST.md` albo równoważną dokumentację
  - repo-only snapshoty mają decyzję: zostają, wracają do Studio, albo są kandydatami do późniejszego usunięcia
  - polityka dla `Workspace.Rig.Animate` i podobnych kolizji jest jawnie zapisana
  - jest osobny plan migracji dla reorganizacji po systemach, z podziałem na małe etapy `LOW` risk
