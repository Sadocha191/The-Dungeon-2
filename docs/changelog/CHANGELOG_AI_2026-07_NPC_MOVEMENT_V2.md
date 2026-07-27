# 2026-07-24 - PR #133 active Level integration and runtime validation

## Studio target and synchronization

- Integrated PR #133 into the active `Level` Studio place, PlaceId `113361902471683` (Universe/GameId `9965460435`).
- Confirmed the live active spawner is `ServerScriptService.Script.Model.WaveController`.
- Verified normalized length and two independent checksums match between repo and Studio for all ten synchronized runtime scripts.
- Persisted template tags in Edit mode and verified they survive a Play/Edit cycle and clone correctly:
  - Slime: `NpcMovementSystem_V2`, `NpcMove_SurfaceCrawler`, `NpcSurfaceOffset = 1`.
  - Goblin: `NpcMovementSystem_V2`, `NpcMove_GroundRunner`, `NpcCombat_LeapExplode`.
  - Demon, Harp, LandShark, Skeleton, Warewolf and Zombie: Legacy GroundWalker.
  - Grzyb, Ent, Golem and Knight: Legacy HeavyWalker.
- The place has no production flying template, so no synthetic flying model or tag was added.

## Integration fixes

- Reused one surface `RaycastParams` exclusion set per shared movement tick instead of allocating it and calling `Players:GetPlayers()` for every surface ray.
- Fixed the crawler's outer-corner probe so it wraps onto the adjacent outward face instead of losing adhesion at the edge.
- Limited untagged Terrain compatibility to floor-like normals; intended walls and ceilings still require `NpcCrawlable` or `NpcWalkable`.
- Made unknown/conflicting system tags fail closed even when registration config requests V2, and made V2 without one recognized movement behavior fall back to Legacy.
- Copied movement/combat tags explicitly from the selected WaveController template to its clone.
- Marked LeapExplode self-destruction as reward-suppressed, added explicit Detonate/Dead phases and bounded Explosion cleanup through Debris.

## Runtime validation

- Legacy parity:
  - in the forced-Legacy harness, all 12 production templates resolved the intended Legacy profile;
  - every model moved, including an isolated Golem sample of `10.44` studs;
  - freeze held position (`0` studs), post-freeze movement resumed (`2.34` studs), impulse moved `8.61` studs and global pause held position (`0` studs);
  - cleanup ended with zero active NPCs.
- Surface crawler:
  - direct floor -> wall -> ceiling traversal recorded two inner transitions, zero adhesion failures and correct normals;
  - the corrected outer-corner case recorded one outer transition and zero adhesion failures;
  - an actual tagged Slime registered through `NpcService` traversed wall and ceiling with `133` surface rays, two inner transitions, one outer transition and no acquire/adhesion failure;
  - client orientation matched the ceiling normal with dot product `0.9993`;
  - an untagged Terrain floor policy probe acquired Terrain and moved with zero acquisition failures.
- LeapExplode:
  - open line of sight armed, leapt and detonated exactly once, damaged once and passed `suppressRewards = true` to the death callback;
  - a blocking wall, target loss and despawn prevented player damage;
  - pause and freeze deferred the sequence; it resumed once and cleaned up;
  - no Explosion/VFX or registered NPC remained after cleanup.
- Layered navigation:
  - cached lower-ground and bridge samples remained separated by expected Y;
  - a cross-layer zero-horizontal step did not teleport upward;
  - a small profile passed correct bridge/tunnel clearance;
  - GroundLarge was blocked by the bridge body and GroundSmall was blocked by a deliberately low roof.
- Surface stress with real V2 Slimes:

| Active NPCs | Average movement tick | Surface rays/second | Failures |
| ---: | ---: | ---: | ---: |
| 1 | `0.055 ms` | `25` | 0 |
| 20 | `0.271 ms` | `486` | 0 |
| 50 | `0.668 ms` | `1,114` | 0 |
| 100 | `1.350 ms` | `1,867` | 0 |
| 120 | `1.396 ms` | `2,454` | 0 |

- The cumulative session maximum movement tick was `8.101 ms`. At 120 NPCs the client received 120/120 models, all positions/orientations were finite and all up vectors had unit magnitude.
- Final cleanup reported zero active NPCs, zero stress models, zero debug objects and zero lingering Explosion/VFX objects.
- Startup produced no MovementV2 error. The unrelated pre-existing `Hybrid Terrain Hex Generator:16` `CreateToolbar` error remained.

## Remaining deployment gates

- The active production map currently has no persistent `NpcCrawlable`/`NpcWalkable` map tags. Slime can use untagged floor-like Terrain, but production wall/ceiling routes need an intentional map-authoring pass.
- No production flying template exists, so live Flying parity could not be exercised.
- Natural wave reward/drop accounting after Goblin self-detonation was covered by the death-context contract and direct callback but not by a complete organic wave reward run.
- Stairs and a true no-route PathfindingService scenario were not completed beyond the direct layered/clearance/cache tests.
- Keep PR #133 in draft until these remaining map-specific runtime gates are completed.

## Runtime cost, risks and rollback

- No new Heartbeat, Stepped, RenderStepped or per-NPC connection was added. Movement remains owned by the existing shared `NpcService` scheduler at `12 Hz`.
- The stress result is a Studio sample, not a production server budget guarantee; representative map geometry and multiple players may add targeting/path cost.
- Studio template tags are place metadata and are not represented by the source-only repo snapshot, so publishing/restoring the place must preserve them.
- Immediate behavior rollback: replace the Slime/Goblin V2 system tags with `NpcMovementSystem_Legacy` or keep `NpcNavigationConfig.ActiveSystem = "Legacy"` for untagged future templates.
- Full Studio rollback: undo to `Before PR 133 MovementV2 integration` or restore the previous place version.
- Repo rollback: revert the PR branch changes and this integration commit. Do not delete the shared legacy navigation modules.

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
- The dispatcher preserves the original Flying clamp rule: an additional altitude clamp is only applied when an external impulse is present.

## Main files

- Added `NpcMovementSystemResolver.lua`.
- Added `NpcMovementSystemController.lua`.
- Added `NpcSurfaceNavigation.lua`.
- Added `NpcCombatBehaviorService.lua`.
- Added `LeapExplodeBehavior.lua`.
- Updated `NpcNavigationConfig.lua`, `NpcService.lua`, `NpcReplication.lua`, `WaveController.lua` and `NpcPresentation.client.lua`.
- Added `docs/NPC_MOVEMENT_SYSTEMS.md` with setup, rollback and Studio validation instructions.

## Validation completed outside Studio

- Deterministic integration patches asserted every expected source replacement.
- `git diff --check` passed during the large-file integration steps.
- Temporary patch scripts and GitHub workflows removed themselves after use.
- Branch diff was reviewed for preservation of the central scheduler, Legacy default and existing flight semantics.

## Original deployment gates

- Roblox Studio runtime validation is required before enabling `MovementV2` globally.
- Validate Slime surface transitions on representative map geometry.
- Validate Goblin telegraph timing, damage, target loss, pause/freeze and cleanup.
- Validate full-sync orientation on clients and stress-test at least 100 NPCs.
