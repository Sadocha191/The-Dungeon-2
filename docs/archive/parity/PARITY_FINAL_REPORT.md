# PARITY_FINAL_REPORT

Final parity report for the Roblox Studio <-> repo sync work completed on `2026-05-02`.

## Podsumowanie

- `Script parity`: achieved at repo-coverage level for the last known Studio snapshot.
- `Full object parity`: still `PARTIAL`.
- In this project, `script parity` means every known live `Script`, `LocalScript`, and `ModuleScript` from the verified Studio snapshot has a corresponding source file in the repo.
- In this project, `script parity` does not automatically mean that `roblox/` by itself is already a full standalone export of Studio.
- In this project, `full object parity` means the repo covers scripts plus the critical non-script hierarchy they depend on: `Tool` structure, `Model` layout, `Folder` layout, remotes, UI hierarchy, important values, attributes, tags, and duplicate-instance edge cases.
- Evidence collected for this report:
  - all previously identified Studio-only script gaps were mirrored into the repo
  - all recent parity mirrors were verified as exact matches against live Studio by byte length plus rolling checksum
  - all `53` planned parity mirror paths from the documented Studio-only batches exist on disk under `roblox/`
  - a first `MANIFEST.md` layer now documents the critical non-script structures most likely to block safe reorganization

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

The repo now has a first object-parity manifest layer for these critical live structures:

- `roblox/Poziom/ReplicatedStorage/Remotes/MANIFEST.md`
- `roblox/Poziom/StarterGui/MANIFEST.md`
- `roblox/Poziom/ServerStorage/WeaponTemplates/MANIFEST.md`
- `roblox/CzterySzczyty/ReplicatedStorage/RemoteEvents/MANIFEST.md`
- `roblox/CzterySzczyty/ReplicatedStorage/RemoteFunctions/MANIFEST.md`
- `roblox/CzterySzczyty/StarterGui/MANIFEST.md`
- `roblox/CzterySzczyty/Workspace/NPCs/MANIFEST.md`
- `roblox/CzterySzczyty/Workspace/Rig/MANIFEST.md`
- `roblox/CzterySzczyty/Workspace/Budynki/Portal/MANIFEST.md`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/MANIFEST.md`
- `roblox/CzterySzczyty/ServerStorage/Modele/Rig/MANIFEST.md`

This improves object-level documentation, but does not make object parity complete by itself.

To reach full object parity safely, the repo still needs explicit coverage and decisions for:

- deeper `Tool` structure
  - especially `ServerStorage/WeaponTemplates/**` parts, attachments, sounds, particles, prompts, and other non-script descendants
- deeper `Model` layout
  - especially NPC model internals, portal internals beyond the current root manifest, and any future rig clones or backup rigs that matter to migration
- deeper `Folder` layout used by code
  - especially any path-sensitive child folders below the current manifest boundaries
- important non-script objects
  - values, prompts, attachments, particles, sounds, and UI widgets not yet described in detail
- UI hierarchy below the top layer
  - `StarterGui` roots are documented, but nested frames, buttons, modal flows, and value holders are not fully documented yet
- `Poziom` workspace-side object coverage
  - a targeted recheck in the active session did not find live `Workspace.NPCs` or portal-named descendants, so those structures remain `UNKNOWN` rather than documented
- duplicate-instance ambiguity
  - `Cztery szczyty/Workspace.Rig.Animate` still needs a final manual decision if instance-count parity becomes important
- repo-only historical snapshots
  - they are documented, but still not resolved as live, stale, restore, or later-removal decisions

Until those are resolved, the project has script parity but not full object parity.

## Repo-only snapshoty

| Repo path | Obecny status | Ryzyko | Rekomendacja |
|---|---|---|---|
| `Level/Workspace/Rig/LocalScript/Animate.lua` | `stale_snapshot` | `HIGH` | zostawic jako `stale_snapshot` |
| `Four Peaks/Workspace/NPCs/Blacksmith/Blacksmith.lua` | `candidate_for_removal_later` | `HIGH` | usunac pozniej po decyzji |
| `Four Peaks/Workspace/NPCs/MissionNPC/MissionNPC.lua` | `candidate_to_restore_to_studio` | `HIGH` | wymaga recznego sprawdzenia |
| `Four Peaks/Workspace/NPCs/Witch/Witch.lua` | `candidate_for_removal_later` | `HIGH` | usunac pozniej po decyzji |

## Duplikaty / konflikty

- `Cztery szczyty`: `Workspace.Rig.Animate`
  - earlier parity analysis found two identical live instances with the same path text
  - a later recheck for the final parity pass saw one visible `Workspace.Rig.Animate` descendant in the active Studio session
  - because parity work did not modify Studio, this should still be treated as unresolved object-parity ambiguity rather than a resolved move or rename
- Repo consequence:
  - the repo can safely keep one canonical file at `roblox/CzterySzczyty/Workspace/Rig/Animate.lua`
  - the filesystem cannot represent duplicate sibling instance count by path alone
- Recommended handling:
  - keep the canonical mirror
  - keep the local `MANIFEST.md` note for duplicate history
  - do not invent suffixes or guess object identity without a manual decision

## Nastepny bezpieczny krok

1. Domknac decyzje o repo-only snapshotach.
2. Uzupelnic glebsze manifesty tylko tam, gdzie beda potrzebne do pierwszego etapu reorganizacji.
3. Potwierdzic recznie przypadek `Workspace.Rig.Animate` jako canonical mirror albo nadal aktywny duplikat.
4. Dopiero potem przygotowac plan reorganizacji folderow po systemach.
5. Reorganizacje robic tylko `LOW` risk, etapami.

## Rekomendacja

- Mozna commitowac `script mirrors` plus dokumentacje parity.
- Mozna tez commitowac obecna warstwe `MANIFEST.md` jako bezpieczne rozszerzenie dokumentacji parity.
- Nie nalezy jeszcze zaczynac reorganizacji folderow po systemach.
- Przed reorganizacja powinny byc spelnione te warunki:
  - krytyczne nieskryptowe struktury maja `MANIFEST.md` albo rownowazna dokumentacje na poziomie potrzebnym dla pierwszego batcha migracji
  - repo-only snapshoty maja decyzje: zostaja, wracaja do Studio, albo sa kandydatami do pozniejszego usuniecia
  - polityka dla `Workspace.Rig.Animate` i podobnych kolizji jest jawnie zapisana
  - jest osobny plan migracji dla reorganizacji po systemach, z podzialem na male etapy `LOW` risk
