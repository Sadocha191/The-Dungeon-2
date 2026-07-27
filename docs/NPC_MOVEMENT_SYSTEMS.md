# Switchable NPC movement systems

## Safety and rollback

The proven NPC navigation remains the default:

```lua
NpcNavigationConfig.ActiveSystem = "Legacy"
```

Change it to `"MovementV2"` to route newly registered NPCs through the V2 dispatcher. The selection is resolved once during `NpcService.Register`; NPCs that are already alive are not hot-switched.

To roll back immediately, restore `ActiveSystem` to `"Legacy"`. New spawns will use the existing `NpcGroundNavigation` / `NpcFlightNavigation` paths again. A model can also force the old system with the `NpcMovementSystem_Legacy` tag.

Legacy and V2 are never simulated in parallel for one NPC. Both use the existing single `NpcService` Heartbeat scheduler.

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

Unknown or conflicting system tags fail closed to `Legacy`. The selection affects future spawns only.

## Movement tags

Use exactly one movement tag when a model needs tag-driven behavior:

| Tag | Intended NPC | Legacy route | MovementV2 route |
| --- | --- | --- | --- |
| `NpcMove_SurfaceCrawler` | Slime | `GroundSmall` fallback | new surface crawler |
| `NpcMove_GroundWalker` | Zombie | existing `GroundSmall` | compatibility route through existing ground navigation |
| `NpcMove_GroundRunner` | Goblin | existing `GroundSmall` | compatibility route through existing ground navigation |
| `NpcMove_Flying` | Bat | existing `Flying` | compatibility route through existing flight navigation |
| `NpcMove_HeavyWalker` | Ent / Golem | existing `GroundLarge` | compatibility route through existing large-ground navigation |

Movement behavior is not selected by NPC name. A new model can reuse an existing behavior by receiving the corresponding tag.

Models with no movement tag keep their existing `movementProfile`, `movementMode`, `CanFly`, or `MobConfig` registration values. Unknown or multiple `NpcMove_*` tags produce a warning and fail closed to Legacy behavior.

Active `Level` template assignments:

| Templates | System | Movement | Combat |
| --- | --- | --- | --- |
| Slime | `MovementV2` | `SurfaceCrawler` | none |
| Goblin | `MovementV2` | `GroundRunner` | `LeapExplode` |
| Demon, Harp, LandShark, Skeleton, Warewolf, Zombie | `Legacy` | `GroundWalker` | none |
| Grzyb, Ent, Golem, Knight | `Legacy` | `HeavyWalker` | none |

The active place has no production flying template. Do not add a synthetic `NpcMove_Flying` assignment only to satisfy a test matrix.

## Surface crawler

`NpcMove_SurfaceCrawler` only activates the new crawler when its resolved system is `MovementV2`. In Legacy it deliberately falls back to `GroundSmall`.

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

The Terrain exception is floor compatibility, not permission to crawl the whole map. Untagged steep Terrain faces, walls, ceilings and Parts are rejected by default; tag only intended crawler geometry. `NpcSurfaceOffset` can be set on a model to tune its distance from the surface.

## Combat behavior tags

Combat behavior is separate from movement. Supported tag:

- `NpcCombat_LeapExplode`

This enables the server-authoritative Goblin sequence:

`Chase -> Arm -> Leap -> Detonate -> Dead`

The behavior continues an armed/leaping sequence even if the original target disappears, damages each eligible player at most once per detonation, performs line-of-sight validation, creates a non-physical explosion visual, and then kills and deregisters the NPC through the existing lifecycle.

Optional model attributes:

| Attribute | Default |
| --- | ---: |
| `LeapExplodeTriggerRange` | `16` |
| `LeapExplodeArmTime` | `0.45` |
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
5. Test registration warnings and movement in Studio.

Recommended initial setup:

| NPC | System tag | Movement tag | Combat tag |
| --- | --- | --- | --- |
| Slime | `NpcMovementSystem_V2` | `NpcMove_SurfaceCrawler` | none |
| Zombie | optional/global | `NpcMove_GroundWalker` | none |
| Goblin | optional/global | `NpcMove_GroundRunner` | `NpcCombat_LeapExplode` |
| Bat | optional/global | `NpcMove_Flying` | none |
| Ent / Golem | optional/global | `NpcMove_HeavyWalker` | none |

The active `Level` Slime template uses `NpcSurfaceOffset = 1`.

## Studio validation checklist

Before enabling V2 globally:

- confirm untagged NPCs behave exactly as before with `ActiveSystem = "Legacy"`,
- test Slime on floor, wall, inner corner, outer corner, and ceiling,
- tag only intended map geometry as crawlable,
- test Bat pursuit toward players above and below it,
- confirm Goblin telegraphs, leaps, detonates once, and cleans up,
- test pause, freeze, slow, impulse, death, despawn, and full client sync,
- stress-test at least 100 NPCs and review `NpcService.GetNavigationMetrics()`,
- confirm no per-NPC connections or navigation state leaks remain after despawn.
