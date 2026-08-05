# Switchable NPC movement behaviors

## Important distinction

`NpcNavigationConfig.ActiveSystem` still selects the behavior/tag dispatcher for newly registered NPCs:

```lua
NpcNavigationConfig.ActiveSystem = "Legacy"
```

It no longer selects between two different ground-routing implementations. Every `GroundSmall` and `GroundLarge` NPC now uses the same `NpcGroundNavigation` adapter backed by Roblox `PathfindingService`.

The `Legacy`/`MovementV2` choice remains relevant for behaviors that are genuinely different, especially `SurfaceCrawler`, and for the existing tag-validation/rollback contract. It does not restore the removed custom direct-probe ground routing.

## System selection

Optional system tags:

- `NpcMovementSystem_Legacy`
- `NpcMovementSystem_V2`

Resolution order:

1. reject unknown or conflicting `NpcMovementSystem_*` tags,
2. explicit registration config (`movementSystem`),
3. one system tag on the NPC model,
4. `MovementSystem` attribute,
5. `NpcNavigationConfig.ActiveSystem`,
6. fail-safe `Legacy`.

The selection is resolved once during `NpcService.Register`; already living NPCs are not hot-switched. Legacy and V2 are never simulated in parallel for one NPC, and both use the same central `NpcService` Heartbeat.

## Movement tags

Use exactly one movement tag when a model needs tag-driven behavior:

| Tag | Intended NPC | Legacy behavior | MovementV2 behavior | Routing backend |
| --- | --- | --- | --- | --- |
| `NpcMove_SurfaceCrawler` | Slime | `GroundSmall` fallback | surface crawler | Legacy fallback: `PathfindingService`; V2: custom surface navigation |
| `NpcMove_GroundWalker` | Zombie | `GroundSmall` | `GroundSmall` compatibility | `PathfindingService` |
| `NpcMove_GroundRunner` | Goblin | `GroundSmall` | `GroundSmall` compatibility | `PathfindingService` |
| `NpcMove_Flying` | Bat | flying | flying compatibility | custom 3D flight navigation |
| `NpcMove_HeavyWalker` | Ent / Golem | `GroundLarge` | `GroundLarge` compatibility | `PathfindingService` |

Movement behavior is not selected by NPC name. Models with no movement tag retain their existing `movementProfile`, `movementMode`, `CanFly` or `MobConfig` values. Unknown or multiple `NpcMove_*` tags produce a warning and fail closed to Legacy behavior.

## Ground movement

All ground walkers and heavy walkers use native Roblox path computation:

- `PathfindingService:CreatePath()` receives the active profile plus an effective radius that covers the final square body-corridor probe,
- `Path:ComputeAsync()` produces the route,
- `Path:GetWaypoints()` is the only source of long-range ground routing,
- the existing server scheduler advances anchored NPC records along those waypoints,
- the existing client batch interpolates the result.

This is deliberately not `Humanoid:MoveTo()`. The survivors-scale architecture keeps NPC rigs anchored/non-queryable and avoids one physics controller plus persistent movement connections per enemy.

While a path waits in the bounded global queue, an NPC may continue only locally validated straight movement. Its start surface is resampled when `ComputeAsync` actually begins, and movement pauses during that active calculation so the returned route does not start from a stale position. It cannot use the removed custom obstacle steering, long direct-route probe or automatic local hop/stride.

An active native corridor is not replaced on a fixed timer. Repaths are owned by meaningful state changes: the goal moved far enough, the next step was blocked, progress stalled, or the current waypoint list completed. This keeps path demand within the shared `15/s` budget at horde scale.

## Surface crawler

`NpcMove_SurfaceCrawler` activates the crawler only when its resolved system is `MovementV2`. In Legacy it deliberately falls back to `GroundSmall`, which now means the native `PathfindingService` ground adapter.

The crawler:

- projects pursuit onto the current surface tangent plane,
- adheres with server raycasts,
- can transition across inner and outer corners,
- stores and replicates a surface normal,
- lets the client orient the model with that normal as its up vector,
- runs inside the shared movement tick and creates no per-NPC Heartbeat connections.

Crawlable geometry must be one of:

- an instance or ancestor tagged `NpcCrawlable`,
- an instance or ancestor tagged `NpcWalkable`,
- an untagged Roblox Terrain face whose upward normal meets `TerrainFloorNormalMinDot` (`0.65` by default).

The Terrain exception is floor compatibility, not permission to crawl the whole map. Untagged steep Terrain faces, walls, ceilings and Parts are rejected by default.

## Flying movement

Flying NPCs remain on `NpcFlightNavigation`. Standard Roblox ground pathfinding does not describe free 3D flight, altitude selection, no-fly volumes or air-node routing. This is an intentional specialized backend, not a partial migration.

## Combat behavior tags

Combat behavior remains separate from movement. Supported tag:

- `NpcCombat_LeapExplode`

This enables the server-authoritative Goblin sequence:

`Chase -> Leap -> Detonate -> Dead`

The LeapExplode ability still owns its attack movement and external positioning for the duration of the behavior. After the sequence/interrupt, normal pursuit returns to the native ground path adapter. Boss charges, Bat dives and other authored ability movement follow the same rule: ability movement is not replaced by chase pathfinding.

Optional Goblin attributes:

| Attribute | Default |
| --- | ---: |
| `LeapExplodeTriggerRange` | `16` |
| `LeapExplodeLeapTime` | `0.5` |
| `LeapExplodeArcHeight` | `8` |
| `LeapExplodeRadius` | `10` |
| `LeapExplodeDamage` | `1.75 x base damage` |

## Adding a new NPC

Adding only a model is not enough to make it spawn. Complete all applicable steps:

1. Place the template in `ReplicatedStorage/Enemies/Normal` or `ReplicatedStorage/Enemies/Elite`.
2. Add one movement tag and optionally one combat tag.
3. Add its stats to `MobConfig.Mobs`.
4. Add its name and weight to the applicable `EncounterScheduler` pool.
5. Confirm the correct agent radius/height against the Studio navigation mesh.
6. Test registration warnings, routing, attack movement, pause/freeze, death and cleanup.

Recommended initial setup:

| NPC | System tag | Movement tag | Combat tag |
| --- | --- | --- | --- |
| Slime | `NpcMovementSystem_V2` | `NpcMove_SurfaceCrawler` | none |
| Zombie | optional/global | `NpcMove_GroundWalker` | none |
| Goblin | optional/global | `NpcMove_GroundRunner` | `NpcCombat_LeapExplode` |
| Bat | optional/global | `NpcMove_Flying` | `DiveAttack` from config |
| Ent / Golem | optional/global | `NpcMove_HeavyWalker` | authored behavior if applicable |

## Rollback

Changing `ActiveSystem` to `Legacy` is still a quick rollback for SurfaceCrawler/V2 behavior selection. It is not a rollback of the native ground pathfinding refactor.

To roll back ground routing, revert the commit that replaces `NpcGroundNavigation.lua`, synchronize that previous source back to the `Level` Studio place and repeat the NPC navigation smoke tests. No RemoteEvent, DataStore or teleport payload migration is involved.

## Studio validation checklist

- enable Studio `Navigation mesh` and `Pathfinding modifiers`,
- test `GroundSmall` and `GroundLarge` around walls, bridges, slopes, stairs, water/lava and unreachable targets,
- confirm native jump waypoints for small agents and rejected jump paths for large agents,
- test Slime on floor, wall, inner corner, outer corner and ceiling,
- test Bat pursuit toward players above and below it,
- confirm Goblin, boss charges and Bat dives return cleanly to chase routing,
- test pause, freeze, slow, impulse, external positioning, death, despawn and client sync,
- stress-test at least `100` NPCs and review `NpcService.GetNavigationMetrics()`,
- confirm path queue/cache state does not grow after despawn or run end.
