# 2026-07-23 - Switchable NPC MovementV2 foundation

## Summary

- Preserved the current ground and flight navigation as the default `Legacy` system.
- Added a spawn-time `Legacy` / `MovementV2` resolver with global, per-model tag, attribute and registration-config selection.
- Added reusable movement tags instead of NPC-name conditionals.
- Added a V2 surface crawler with server-authoritative floor, wall, corner and ceiling adhesion.
- Added replicated surface normals and client-side surface orientation.
- Added a separate tagged `LeapExplode` combat behavior for Goblin-style chase, telegraph, leap and one-shot detonation flow.

## Safety

- `NpcNavigationConfig.ActiveSystem` remains `Legacy` by default.
- Existing NPCs are not hot-switched.
- Invalid or conflicting tags fail closed to Legacy.
- Legacy and V2 do not run in parallel for one NPC.
- The existing single `NpcService` Heartbeat scheduler remains authoritative; no per-NPC Heartbeat connection was added.
- GroundWalker, GroundRunner, HeavyWalker and Flying use compatibility routes through the proven current navigation modules until dedicated V2 implementations replace them.

## Main files

- Added `NpcMovementSystemResolver.lua`.
- Added `NpcMovementSystemController.lua`.
- Added `NpcSurfaceNavigation.lua`.
- Added `NpcCombatBehaviorService.lua`.
- Added `LeapExplodeBehavior.lua`.
- Updated `NpcNavigationConfig.lua`, `NpcService.lua`, `NpcReplication.lua` and `NpcPresentation.client.lua`.
- Added `docs/NPC_MOVEMENT_SYSTEMS.md` with setup, rollback and Studio validation instructions.

## Validation completed outside Studio

- Deterministic integration patches asserted every expected source replacement.
- `git diff --check` passed during both large-file integration steps.
- Temporary patch scripts and GitHub workflows removed themselves after use.
- Branch diff was reviewed for preservation of the central scheduler and Legacy default.

## Remaining deployment gates

- Roblox Studio runtime validation is required before enabling `MovementV2` globally.
- Validate Slime surface transitions on representative map geometry.
- Validate Goblin telegraph timing, damage, target loss, pause/freeze and cleanup.
- Validate full-sync orientation on clients and stress-test at least 100 NPCs.
