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

- `PathfindingService:CreatePath()` receives profile height, jump/climb support, waypoint spacing and material/modifier costs. Its effective radius also covers the square footprint of the final body-corridor validation, preventing native corner segments that the kinematic safety gate must reject.
- `Path:ComputeAsync()` is wrapped in protected execution.
- Successful `Path:GetWaypoints()` results are cached briefly by profile, start sector, goal sector and Y layer.
- Goal movement, a blocked local step, stuck detection and route completion request a fresh route. Active routes are not replaced on a fixed timer because timer refreshes exceed the `15/s` budget at horde scale and can hand off from a stale position.
- Native jump waypoints are executed as a bounded kinematic arc because the NPC model itself remains anchored and does not use a Humanoid controller.
- While waiting in the bounded path queue, an NPC may continue only locally validated straight movement. The start is resampled immediately before `ComputeAsync`, and the NPC holds position during the active calculation so the returned route begins at its real location.

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

## Studio integration validation

- Synchronized the exact PR source into the active `Level` Studio place and loaded the module successfully in Edit mode.
- Fresh Play reached the normal startup-ready state with no navigation-specific compile/runtime error. The existing unrelated `Hybrid Terrain Hex Generator:16` plugin-context error remained.
- The first controlled wall route exposed a mismatch between Roblox's circular native radius and the project's square body-corridor `Blockcast`, plus stale timer-based route handoffs. The integration follow-up aligned the effective radius, tightened waypoint completion, removed timer refreshes, and resampled queued starts when `ComputeAsync` actually begins.
- After the follow-up, `GroundSmall` and `GroundLarge` both routed around the wall with `2/2` successful paths, zero blocked steps, zero failures, and an empty active/pending queue.
- A 100-NPC open-floor run completed `100/100` path computations with zero failures, queue-full events or blocked steps; `98/100` agents reached their goal within 18 seconds. The controlled scheduler sample averaged `4.11 ms` per 12 Hz navigation tick and peaked at `6.38 ms` in Studio.
- The level-up pause contract used the real `ReplicatedStorage.PauseState`: movement was exactly `0` during a two-second pause and resumed afterward. A native-jump clock probe resumed without a time jump and landed with zero positional error.
- The player naturally died during the longer Play session. The post-death state had `Health=0`, `RunEnded=true`, zero living/targeted NPCs and zero active/pending paths. A controlled `RunEnded` postcondition probe also produced zero NPC drift, cleared its target, and left no runtime records after despawn.
- `git diff --check` passed. No standalone Luau analyzer, Selene or StyLua binary was available, so Studio module loading and fresh Play supplied compile/runtime coverage.

## Not verified in this pass

- A real authored native `PathfindingLink` jump was not generated on the production map; pause/resume and landing were verified through the same public traversal state contract.
- Bridge/under-bridge, water/lava and every unreachable target layout were not exhaustively traversed on the production map.
- Goblin/Boss/Bat authored attack transitions, SurfaceCrawler, flying behavior and multiplayer interpolation were not repeated end-to-end because their specialized modules and batch contracts are unchanged by this diff.
- The 100-NPC sample measured the controlled scheduler duration and navigation metrics, not a captured MicroProfiler trace or the full 500-NPC target ceiling.

## Main risks

- The game map must expose a correct Roblox navigation mesh for both small and large agent dimensions. `NpcWalkable` ground-probe compatibility cannot make geometry available to `PathfindingService` by itself.
- Path-first routing creates more `ComputeAsync` demand than the old direct-first system. Removing timer refreshes keeps the validated 100-NPC sample to one request per agent, but a full 500-NPC MicroProfiler capture is still required before claiming the target ceiling.
- Large agents may legitimately receive `NoPath` in spaces that previously allowed permissive custom stepping.
- Native jump waypoint feel may require tuning after Studio testing because the rig remains kinematic.
- A shared cached route can be locally invalid for another NPC in the same sector; the first blocked step evicts it and recomputes, but this must be observed under density.

## Rollback

- Revert the commits on `refactor/native-npc-pathfinding` that replace `NpcGroundNavigation` and documentation.
- Restore the previous `NpcGroundNavigation` source in the live `Level` Studio place.
- Run a fresh navigation smoke and confirm the previous custom direct/path/traversal metrics return.
- No data migration, remote rollback or teleport compatibility work is required.
