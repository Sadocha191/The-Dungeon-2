# Native NPC pathfinding refactor — 2026-08-05

## Summary

- Replaced the custom long-range ground routing in `NpcGroundNavigation` with routes computed by Roblox `PathfindingService`.
- All `GroundSmall` and `GroundLarge` NPCs now request native paths immediately and follow native `PathWaypoints` through the existing central `NpcService` movement scheduler.
- Preserved the current server-authoritative anchored NPC records, `NpcBatchEvent` replication, client interpolation, target/formation logic, combat behaviors, damage, death and cleanup contracts.
- Kept `NpcFlightNavigation` and `NpcSurfaceNavigation` for movement that the ground navmesh cannot represent.
- Kept authored attack movement such as Goblin leap/explosion, boss movement and Bat dive outside normal chase routing.

## Removed ground-routing behavior

The ground navigation module no longer:

- uses long-range `NpcGroundSurface.CanTraverse` checks to decide between direct movement and a path,
- invents a local obstacle route,
- automatically creates hop/stride traversal over an obstacle detected by a blocked step,
- treats the custom direct steering path as the primary chase route.

`NpcGroundSurface.ValidateStep` remains only as the final short-step grounding, footprint and body-corridor safety gate for the anchored kinematic model.

## Native path execution

- `PathfindingService:CreatePath()` receives profile radius, height, jump/climb support, waypoint spacing and material/modifier costs.
- `Path:ComputeAsync()` is wrapped in protected execution.
- Successful `Path:GetWaypoints()` results are cached briefly by profile, start sector, goal sector and Y layer.
- Goal movement, path expiry, a blocked local step and stuck detection invalidate the route and request a new one.
- Native jump waypoints are executed as a bounded kinematic arc because the NPC model itself remains anchored and does not use a Humanoid controller.
- While waiting for the bounded path queue, an NPC may take only a locally validated straight step. It cannot steer around an obstacle without a native path.

## Performance safeguards

The existing global limits remain:

- movement tick: `12 Hz`,
- maximum active path computations: `2`,
- maximum path starts: `15/s`,
- maximum queued requests: `160`,
- short shared path cache,
- no persistent per-NPC `Heartbeat`, `MoveToFinished` or `Path.Blocked` connection.

The refactor adds no RemoteEvent, DataStore field, teleport payload or `_G` dependency.

## Repository files

- Updated `Level/ServerScriptService/ModuleScript/NpcGroundNavigation.lua`.
- Updated `docs/NPC_NAVIGATION.md`.
- Updated `docs/NPC_MOVEMENT_SYSTEMS.md`.
- Added this focused changelog.

## Validation performed

- Reviewed the current `NpcService`, movement controller, navigation profiles, ground-surface adapter, flight/surface backends and prior movement documentation before changing the module.
- Preserved every public function consumed by `NpcMovementSystemController`/`NpcService`: `BeginTick`, `StepScheduler`, `BuildSpatialGrid`, `GetSeparation`, `Step`, `ConstrainPosition`, `IsTraversing`, `StepTraversal`, `SetPaused`, `Invalidate`, `Cleanup`, `GetDebug` and `GetMetrics`.
- Preserved profile-driven `PathfindingService` parameters and material/modifier costs.
- Reviewed the branch diff against `main` after the changes.

## Not verified in this pass

The repository connector did not provide a live Roblox Studio session, so the branch has not yet been synchronized into `Level` or run through Studio compile/play/MicroProfiler validation. The PR must remain draft until the following gates pass:

1. fresh `Level` startup with no navigation compile/runtime errors,
2. normal small ground mob pursuit around an obstacle,
3. large mob path around narrow geometry without entering an invalid corridor,
4. native jump waypoint, pause/freeze during jump and landing,
5. bridge plus lower route layer separation,
6. water/lava and unreachable target handling,
7. Goblin/Boss/Bat authored movement returning to chase correctly,
8. SurfaceCrawler and flying behavior regression smoke,
9. multiplayer batch presentation,
10. `100+` NPC MicroProfiler and navigation metrics capture,
11. despawn/end-run cleanup with no growing pending queue or stale navigation state.

## Main risks

- The game map must expose a correct Roblox navigation mesh for both small and large agent dimensions. `NpcWalkable` ground-probe compatibility cannot make geometry available to `PathfindingService` by itself.
- Path-first routing creates more `ComputeAsync` demand than the old direct-first system. Sector cache and the existing token bucket bound the load, but target-scale profiling is required.
- Large agents may legitimately receive `NoPath` in spaces that previously allowed permissive custom stepping.
- Native jump waypoint feel may require tuning after Studio testing because the rig remains kinematic.
- A shared cached route can be locally invalid for another NPC in the same sector; the first blocked step evicts it and recomputes, but this must be observed under density.

## Rollback

- Revert the commits on `refactor/native-npc-pathfinding` that replace `NpcGroundNavigation` and documentation.
- Restore the previous `NpcGroundNavigation` source in the live `Level` Studio place.
- Run a fresh navigation smoke and confirm the previous custom direct/path/traversal metrics return.
- No data migration, remote rollback or teleport compatibility work is required.
