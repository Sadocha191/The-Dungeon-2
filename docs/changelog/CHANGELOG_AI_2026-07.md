# CHANGELOG_AI 2026-07

## 2026-07-07 - Poziom NpcService stage 3D targeting and melee extraction

### Summary

- Completed Stage 3D for active `game.ServerScriptService.ModuleScript.NpcService`.
- Added `NpcTargeting` for alive player snapshots, engagement slots, targetability, target priority metrics, distance despawn checks, and target cache scan cadence.
- Added `NpcMelee` for contact damage dispatch through `DamageService.Apply` and the existing vertical/3D melee validation.
- Kept `NpcService` as the public API facade and the only central scheduler owner.
- Preserved all public `NpcService` function names, arguments, and return behavior.
- Did not move status effects, death callbacks, despawn side effects, rewards, remotes, persistent data, attributes, or balancing.

### Files

- Added `Level/ServerScriptService/ModuleScript/NpcTargeting.lua`
- Added `Level/ServerScriptService/ModuleScript/NpcMelee.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.NpcTargeting`.
- Created live `game.ServerScriptService.ModuleScript.NpcMelee`.
- Synchronized active `game.ServerScriptService.ModuleScript.NpcService` to require the new modules and delegate targeting/melee responsibilities.
- Repo/Studio parity for `NpcService`, `NpcRegistry`, `NpcMovement`, `NpcTargeting`, and `NpcMelee` was confirmed by normalized length/checksum/line-count metrics.
- Temporary Server harnesses were executed during Play and removed automatically with no script markers left in Studio or repo.

### Architecture

- New graph: `NpcService -> NpcRegistry`, `NpcService -> NpcMovement`, `NpcService -> NpcTargeting`, `NpcService -> NpcMelee`, `NpcService -> NpcShared`, optional `NpcService -> MissionProgress`; `NpcTargeting -> NpcMovement`; `NpcMelee -> DamageService`; `NpcMovement -> WorldBounds`.
- `NpcTargeting` does not require `NpcService`, `NpcRegistry`, `DamageService`, `WaveController`, `RunStatsService`, or `ShrineService`.
- `NpcMelee` requires only `DamageService` through an explicit ModuleScript assert and does not call `Humanoid:TakeDamage` or `_G`.
- No module added a `Heartbeat`, event connection, task scheduler, remote, gameplay `_G`, or fallback damage path.

### Validation

- Play startup reached normal service-ready logs with no `NpcService`, `NpcTargeting`, `NpcMelee`, or `DamageService` errors.
- Public targeting query validation used controlled normal/elite/boss `Slime` models registered through public `NpcService.Register`.
- `GetNearestEnemy` preferred boss priority over closer normal/elite candidates.
- `GetEnemiesInRadius` returned boss, elite, normal in the expected effective-distance/priority order.
- `GetTargetingMetrics` for the boss returned `effective=6`, `actual=30`, `priority=3`.
- Real contact melee through the central `Heartbeat` damaged the player for `36` HP in the first harness.
- Invalid height contact damaged the player for `0` HP.
- After requiring existing `RunStatsService` so the thorns callback was registered, real contact melee damaged the player for `45` HP and thorns dealt `20` HP to the attacking NPC with `RunStat_Thorns=4`.
- Cleanup through public `NpcService.Despawn` returned `NpcService.GetActiveCount()` to `0`.
- Repo `rg` and Studio `script_grep` found no temporary harness markers after cleanup.
- `git diff --check` passed.

### Not Verified

- Full natural long-run movement/targeting with 100+ NPC was not repeated in 3D; the 3A 10/25/50 baseline remains the comparison point until 3F optimization.
- True multiplayer target switching remains unverified in current MCP Play.
- Full death/drop/reward/status matrices remain for Stage 3E/3F.
- Thorns before any runtime load of `RunStatsService` remains a load-order caveat; direct diagnostics showed `DamageService` had no thorns callback until the existing stats module was required.

### Risks

- `NpcTargeting` now owns target scan cadence and engagement slot formation ordering. Values were moved unchanged, but Stage 3F should re-measure formation scan cost before optimizing.
- `NpcMelee` now owns contact damage context construction. Validation confirmed the attacker model is preserved for thorns once the existing callback is active.
- Existing thorns callback registration depends on `RunStatsService` being loaded; Stage 3D did not change bootstrap order.

### Rollback

- Restore the previous inline alive player snapshot, engagement slot, targetability, target metric, target scan, melee validation, and contact damage helpers in `NpcService.lua`.
- Remove `Level/ServerScriptService/ModuleScript/NpcTargeting.lua` and `Level/ServerScriptService/ModuleScript/NpcMelee.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 3D notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom NpcService stage 3C movement extraction

### Summary

- Completed Stage 3C for active `game.ServerScriptService.ModuleScript.NpcService`.
- Added `NpcMovement` as a neutral ModuleScript for NPC movement math, ground sampling, spawn emerge, visual repair, model translation, ground-adjusted positions, orbit target math, and obstacle steering.
- Kept `NpcService` as the public API facade and the only central scheduler owner.
- Preserved all public `NpcService` function names, arguments, and return behavior.
- Did not move targeting, melee damage, status effects, death callbacks, despawn side effects, rewards, remotes, persistent data, attributes, or balancing.

### Files

- Added `Level/ServerScriptService/ModuleScript/NpcMovement.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.NpcMovement`.
- Synchronized active `game.ServerScriptService.ModuleScript.NpcService` to require `NpcMovement` and delegate movement/grounding/steering helpers to it.
- Repo/Studio parity for `NpcService`, `NpcRegistry`, and `NpcMovement` was confirmed by normalized length/checksum/line-count metrics.
- A temporary Studio-only movement validation harness was created for Play validation and removed afterward; no test script or marker was left in Studio or repo.

### Architecture

- New graph: `NpcService -> NpcRegistry`, `NpcService -> NpcMovement`, `NpcService -> NpcShared`, `NpcService -> DamageService`, optional `NpcService -> MissionProgress`; `NpcMovement -> WorldBounds`.
- `NpcMovement` does not require `NpcService`, `NpcRegistry`, `DamageService`, `WaveController`, `RunStatsService`, or `ShrineService`.
- `NpcMovement` has no remotes, no `_G`, no `Heartbeat`, no event connections, no `task.spawn`, and no `task.delay`.
- `NpcService` still owns the single `NpcSyncRequest.OnServerEvent` connection and single central `RunService.Heartbeat`.

### Validation

- Play startup reached normal service-ready logs with no `NpcService` or `NpcMovement` errors.
- Controlled Play validation used a real `ReplicatedStorage.Enemies.Normal.Slime` template registered through public `NpcService.Register`.
- Spawn emerge moved the controlled NPC from initial server position `Y=6.25` to surface position `Y=12`.
- Open chase moved the NPC `8.678` studs during the measured window.
- Obstacle steering moved the NPC `11.525` studs with `1.322` studs of lateral `Z` displacement around a temporary collidable blocker.
- Cleanup through public `NpcService.Despawn` returned `NpcService.GetActiveCount()` to `0`.
- Studio `script_search`, Studio `script_grep`, and repo `rg` found no temporary harness markers after cleanup.
- Repo grep confirmed `NpcMovement` has no runtime loop, connection, `_G`, remotes, or `Humanoid:TakeDamage`; active `NpcService` still has only the existing remote connection and central `Heartbeat`.

### Not verified

- Full natural long-run movement with 100+ NPC was not repeated in 3C; the 3A 10/25/50 baseline remains the comparison point until 3F optimization.
- True multiplayer target switching remains unverified in current MCP Play.
- Full melee/death/drop/thorns matrices remain for Stage 3D/3E.

### Risks

- `NpcMovement` now owns raycast ignore construction for movement and ground sampling. It preserves the previous folders and player-character exclusions, but later optimization should measure allocation/raycast cost before changing behavior.
- The Play harness used elevated test NPC HP so existing auto-attacks would not kill the NPC before movement measurement; this did not change production balance.

### Rollback

- Restore the previous inline movement, grounding, spawn emerge, visual repair, model translation, orbit target, and obstacle steering helpers in `NpcService.lua`.
- Remove `Level/ServerScriptService/ModuleScript/NpcMovement.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 3C notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom NpcService stage 3B registry lifecycle extraction and validation

### Summary

- Completed Stage 3B for active `game.ServerScriptService.ModuleScript.NpcService`.
- Added `NpcRegistry` as a neutral ModuleScript that owns NPC ids, model/id lookup maps, tombstones, registration/removal helpers, and reset/count helpers.
- Kept `NpcService` as the only public facade and central scheduler owner.
- Preserved all public `NpcService` function names, arguments, and return behavior.
- Did not move movement, targeting, melee, status effects, death callbacks, despawn side effects, damage, rewards, remotes, or balancing.

### Files

- Added `Level/ServerScriptService/ModuleScript/NpcRegistry.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.NpcRegistry`.
- Synchronized active `game.ServerScriptService.ModuleScript.NpcService` to require `NpcRegistry` and use it for registry iteration, lookup, add/remove, and tombstones.
- Studio grep after sync showed old `npcById`, `npcByModel`, and `tombstones` storage only inside `NpcRegistry`; active `NpcService` uses `NpcRegistry.Pairs`, `Resolve`, `GetByModel`, `Add`, `Remove`, and tombstone helpers.
- A temporary Studio-only Stage 3B validation harness was created for Play validation and removed afterward; no test script or marker was left in Studio or repo.

### Architecture

- New graph: `NpcService -> NpcRegistry`, `NpcService -> WorldBounds`, `NpcService -> NpcShared`, `NpcService -> DamageService`, optional `NpcService -> MissionProgress`.
- `NpcRegistry` has no `require()` calls, no Roblox service fetches, no remotes, no `_G`, no `Heartbeat`, and no event connections.
- `NpcService` still owns the single `NpcSyncRequest.OnServerEvent` connection and single central `RunService.Heartbeat`.
- Player damage still uses `DamageService.Apply(player, amount, { source = npcModel, sourceType = "npc", damageType = "contact", attacker = npcModel })`.

### Validation

- Play startup reached normal service-ready logs with no `NpcService` or `NpcRegistry` errors.
- Natural runtime spawned real Slime models through the active wave/NPC flow; inspected `Workspace.Enemies.Slime` models had `NpcId`, `NpcType`, `MobType`, `Damage`, `AttackRange`, and normal `IsElite=false`/`IsBoss=false` attributes.
- Character navigation to a real Slime completed, and subsequent Output showed no registry, movement, or damage-path errors.
- Controlled Studio-only validation covered normal registration, duplicate registration, elite registration, boss-style registration using an existing elite template with boss config, manual `Destroy`, death callback once-only behavior, despawn without death callback, explicit registry reset, and 20 register/remove cycles.
- Duplicate registration preserved the previous contract: the same model returned the existing id, did not allocate a second id, did not increase registry count, and did not invoke an extra death callback.
- Death flow through public `NpcService.ApplyDamage` invoked the registered callback exactly once and removed the registry entry once.
- Despawn flow removed the registry entry without invoking the death callback.
- `NpcRegistry.Reset()` cleared maps and tombstones but did not reset `nextNpcId`, preserving the previous monotonic id behavior.
- Studio grep found no Stage 3B probe markers.
- Studio grep found no player-damage `Humanoid:TakeDamage` fallback in `NpcService`; existing matches are outside this substage and include `DamageService` and legacy weapon templates.
- Studio grep showed no new `_G` in `NpcService` or `NpcRegistry`.
- Repo grep confirmed `NpcRegistry` has no `require`, `RunService`, `Heartbeat`, `Connect`, `_G`, or `Humanoid:TakeDamage`.

### Not verified

- Exact native `RBXScriptConnection` counts were not measurable in Studio; callback counters, cleanup state, and static grep confirmed no growth symptoms, no per-NPC connection additions, one central `Heartbeat`, and one `NpcSyncRequest.OnServerEvent`.
- Manual `Destroy` cleanup removed the registry entry, but the tombstone was not always observable after Heartbeat because the existing batch broadcast can clear tombstones in the same frame.
- True multiplayer lifecycle under repeated spawn/despawn remains for later Stage 3 passes.

### Risks

- `NpcRegistry.Pairs()` preserves direct table iteration semantics from the previous `pairs(npcById)` loops. This intentionally avoids behavior changes, but Stage 3F may still need measured iteration/cleanup optimization.
- `NpcRegistry.Reset()` is available for future lifecycle work but is not wired into `NpcService` public API in 3B to avoid adding behavior.
- The repo diff still includes the Stage 3A parity sync because Stage 3A and 3B share the current uncommitted Stage 3 worktree.

### Rollback

- Revert `Level/ServerScriptService/ModuleScript/NpcService.lua` to inline `nextNpcId`, `npcById`, `npcByModel`, and `tombstones`.
- Remove `Level/ServerScriptService/ModuleScript/NpcRegistry.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 3B notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom NpcService stage 3A runtime audit and baseline

### Summary

- Completed Stage 3A audit and baseline for active `game.ServerScriptService.ModuleScript.NpcService`.
- Confirmed Stage 2 checkpoint before starting Stage 3: clean worktree at `3780841 Refactor dungeon NPC and reward systems`.
- Audited public `NpcService` API, local helpers, per-NPC state tables, runtime loops, remotes, raycasts, target scans, ground handling, obstacle steering, melee damage, status effects, death/despawn flow, and active callers.
- Detected repo/Studio drift before Stage 3 edits: active Studio `NpcService` had live ground/visual repair logic not present in repo. Mirrored those live changes into `Level/ServerScriptService/ModuleScript/NpcService.lua` without changing Studio behavior.
- Captured temporary Studio-only baseline metrics for 10, 25, and 50 controlled Slime NPCs, then removed all probes.

### Files

- Updated `Level/ServerScriptService/ModuleScript/NpcService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Active module path confirmed: `game.ServerScriptService.ModuleScript.NpcService`.
- Temporary probes were inserted only in Studio, used no new `_G` and no RemoteEvents, and were removed after measurement.
- Studio `script_grep` found no `Stage3ABaseline` or `stage3Profile` markers after cleanup.
- Clean Play startup after probe removal reached the normal service ready logs with no `NpcService` errors.

### Audit

- Active Studio `NpcService` line count: `1739`; repo mirror after parity sync: `1738` lines, equivalent content aside from final newline.
- Repo public API count: `20` functions:
  - `GetRoot`, `GetPosition`, `IsAlive`, `GetHealth`, `GetLivingModels`, `GetActiveCount`, `DespawnOldestFarNormal`, `GetNearestEnemy`, `GetEnemiesInRadius`, `GetTargetingMetrics`, `ApplySlow`, `ApplyFreeze`, `AddImpulse`, `BindDeath`, `ApplyDamage`, `Register`, `SetIncomingDamageModifier`, `LockForAbility`, `SetPosition`, `Despawn`.
- Repo local helper count after sync: `65`.
- Persistent state tables:
  - `npcById`
  - `npcByModel`
  - `tombstones`
  - per-record `deathCallbacks`
- Runtime connections:
  - `NpcSyncRequest.OnServerEvent`
  - one central `RunService.Heartbeat`
- Runtime loop:
  - one central `Heartbeat` updates alive players, engagement slots, all active NPCs, and 10 Hz batch replication through `NpcShared.BatchRate = 0.1`.
- No per-NPC `Heartbeat`, no per-NPC RBXScriptConnection, and no gameplay `_G` in `NpcService`.
- Player damage path remains `DamageService.Apply(player, amount, { source = npcModel, sourceType = "npc", damageType = "contact", attacker = npcModel })`.

### Callers

- Active/repo callers requiring `NpcService`:
  - `WaveController`
  - `WeaponCombat`
  - `SpellService`
  - `StatueService`
  - `RunStatsService`
  - `AbilityExecutor`
- Main public API usage:
  - `WaveController`: register, active counts, boss/elite health/position, death callbacks, despawn.
  - `WeaponCombat`: nearest/radius queries, position/alive checks, `ApplyDamage`, impulse.
  - `SpellService`: target queries, position/alive/root checks, damage, slow/freeze/impulse.
  - `RunStatsService`: thorns calls `IsAlive` and `ApplyDamage`.
  - `AbilityExecutor`: ability locks, position, alive/health, incoming damage modifier.
  - `StatueService`: death callback for spawned mobs.

### Baseline

Controlled baseline used cloned Slime templates registered through public `NpcService.Register`, with auto mob spawning disabled during the probe. Measurements are from Studio Play and should be treated as local baseline, not production profiler data.

| NPCs | Avg update ms | Max update ms | Ground raycasts/s | Obstacle raycasts/s | Target scans/s | Formation scans/s | Formation comparisons/s |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 | 0.081 | 0.686 | 80.0 | 95.0 | 0.0 | 1625.0 | 1625.0 |
| 25 | 0.135 | 0.444 | 212.5 | 25.0 | 0.0 | 6000.0 | 6000.0 |
| 50 | 0.260 | 1.459 | 425.0 | 100.0 | 0.0 | 12025.0 | 12025.0 |

Notes:

- Target scans were near zero during the measured windows because targets were already cached during warmup; engagement slot formation scans ran every frame.
- Active counts during each measured sample matched requested count for 10, 25, and 50 NPCs.
- Cleanup removed probe NPCs, but one non-probe active entry/extra enemy-folder children reappeared in Play even with auto mob spawns disabled; this is recorded as residual runtime noise, not a proven NpcService leak.
- Memory readings from `collectgarbage("count")` varied enough to be useful only as a rough local signal.

### Validation

- Studio probe removed after baseline.
- Studio grep found no probe markers.
- Repo grep found no probe markers.
- Clean Play startup after cleanup showed no `NpcService` errors.
- Existing unrelated Output remained from `Hybrid Terrain Hex Generator`, error reporter config, and missing TeleportData in Play Solo.
- No new gameplay `_G`, remotes, runtime loops, or fallback `Humanoid:TakeDamage` path was added.

### Not verified

- No true multiplayer target switching baseline; MCP Play used one local player.
- No natural long-run 100+ NPC baseline in this pass.
- Status/death/drop/thorns gameplay matrices are scheduled for later Stage 3 substeps and were not revalidated by 3A.

### Risks

- Stage 3B must preserve the live ground/visual repair behavior now mirrored into repo.
- Formation slot building currently scans every active NPC every frame and sorts each target group; this is a likely Stage 3F optimization candidate, but it should not be changed before lifecycle/movement/combat behavior is preserved.
- Baseline probes affected Play-only runtime state while measuring; all probe code was removed afterward.

### Rollback

- Revert the `NpcService.lua` repo parity sync if it must return to the previous stale repo copy, but note that doing so would diverge from active Studio and risk losing live ground/visual repair behavior.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 3A notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom WaveController stage 2E portal and debug API extraction

### Summary

- Completed Stage 2E for active `game.ServerScriptService.Script.Model.WaveController`.
- Added `RunPortalController` as a server ModuleScript for run portal model creation, prompt state, activation state, boss-defeated state, and portal trigger callbacks.
- Added `WaveDebugApi` as a Studio-only debug hook registrar so active `WaveController` no longer writes debug `_G.Debug*` functions directly.
- Kept boss spawning execution, boss combat registration, rewards, `RunProgressApi` calls, remotes, spawn values, damage, cooldowns, and the single `Heartbeat` owner unchanged.
- Did not touch `DamageService`, `NpcService`, `RunStatsService`, ability configs, hazard timing, remotes, persistent data, or the already-removed stale duplicate `Model.model/WaveController.lua`.

### Files

- Added `Level/ServerScriptService/ModuleScript/RunPortalController.lua`
- Added `Level/ServerScriptService/ModuleScript/WaveDebugApi.lua`
- Updated `Level/ServerScriptService/Script/Model/WaveController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Active script path remained `game.ServerScriptService.Script.Model.WaveController`.
- Created live `game.ServerScriptService.ModuleScript.RunPortalController`.
- Created live `game.ServerScriptService.ModuleScript.WaveDebugApi`.
- Synchronized active `WaveController`, `RunPortalController`, and `WaveDebugApi` with repo.
- Removed temporary Stage 2E probe code after validation; Studio `script_grep` and repo grep found no Stage 2E probe markers.

### Validation

- Dependency graph for 2E: `WaveController -> RunPortalController`; `WaveController -> WaveDebugApi` only inside `RunService:IsStudio()`. Neither new module requires `WaveController`.
- Play startup without probes reached `[HordeController] Ready (time-based)` with no `WaveController`, `RunPortalController`, or `WaveDebugApi` errors.
- Temporary Studio-only probe validated real portal/debug paths through the active `WaveController` and was removed afterward:
  - Portal exists under `workspace` with prompt action `Awaken Boss` and enabled initial prompt state.
  - Studio debug hook registration was present (`DebugForceBossSpawn` function registered through `WaveDebugApi`).
  - Debug boss spawn returned `Boss_Golem`, active boss count became `1`, portal prompt changed to disabled `Boss Active`.
  - Setting boss defeated changed prompt to enabled `Enter Portal`.
  - Debug cleanup removed the spawned boss and active boss count returned to `0`.
- Studio grep after sync showed no direct `_G.Debug*` writer in active `WaveController`; debug writers are centralized in `WaveDebugApi`, and `WaveDebugApi.Register` asserts `RunService:IsStudio()`.
- Existing gameplay `_G.SpawnEnemyBurst` in `WaveController` and other unrelated project globals were not changed in this substage.
- No new remotes, fallback damage path, Heartbeat, scheduler loop, gameplay `_G`, or bootstrap was added.
- Output showed no missing-module or portal/debug errors. Existing unrelated Studio output remained from `Hybrid Terrain Hex Generator`, error reporter configuration, and missing TeleportData in Play Solo.

### Not verified

- Full manual ProximityPrompt click by a player and full victory end-run through entering the portal after a real boss kill were not manually completed in this pass; prompt states and callbacks were validated through the active controller path.
- Non-Studio published-server absence of debug hooks was verified statically by the `RunService:IsStudio()` registration gate and `WaveDebugApi.Register` assertion, not by a published server run.

### Risks

- `RunPortalController` owns portal prompt state but still delegates actual boss spawn and victory end-run to `WaveController`; later stages must not move reward/end-run ownership casually.
- `WaveDebugApi` still writes debug `_G.Debug*` hooks in Studio for `DebugCommandService` compatibility. It is intentionally Studio-only and should be removed or replaced only in a dedicated debug API migration.

### Rollback

- Restore the previous portal creation/state block and direct debug hook registration in `WaveController.lua`.
- Delete `Level/ServerScriptService/ModuleScript/RunPortalController.lua` and live `game.ServerScriptService.ModuleScript.RunPortalController`.
- Delete `Level/ServerScriptService/ModuleScript/WaveDebugApi.lua` and live `game.ServerScriptService.ModuleScript.WaveDebugApi`.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 2E notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom WaveController stage 2D encounter scheduler extraction

### Summary

- Completed Stage 2D for active `game.ServerScriptService.Script.Model.WaveController`.
- Added `EncounterScheduler` as a server ModuleScript that owns encounter timing state and spawn-planning calculations for normal spawns, elite cadence, swarm windows, catch-up debt, max-alive caps, spawn pools, spawn interval math, and important-encounter normal-trim decisions.
- Kept actual mob cloning, spawn positioning, `NpcService.Register`, reward/drop handling, boss portal spawn execution, ability controllers, portal/end state, debug hooks, remotes, and the single `Heartbeat` owner in `WaveController`.
- Kept spawn formulas, constants, pools, elite interval, swarm event times, swarm duration, catch-up behavior, caps, damage, ability values, remotes, and persistent data unchanged.

### Files

- Added `Level/ServerScriptService/ModuleScript/EncounterScheduler.lua`
- Updated `Level/ServerScriptService/Script/Model/WaveController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Active script path remained `game.ServerScriptService.Script.Model.WaveController`.
- Created live `game.ServerScriptService.ModuleScript.EncounterScheduler`.
- Synchronized active `WaveController` and `EncounterScheduler` with repo.
- Removed temporary Stage 2D probe code after validation; Studio `script_grep` and repo grep found no Stage 2D probe markers.

### Validation

- Dependency graph for 2D: `WaveController -> EncounterScheduler`; `EncounterScheduler` has no `require()` dependencies and no dependency back to `WaveController`.
- Play startup without probes reached `[HordeController] Ready (time-based)` with no `WaveController` or `EncounterScheduler` errors.
- Temporary Studio-only probe validated real scheduler-driven paths through the active `WaveController` and was removed afterward:
  - Normal spawn startup under existing debug stress: `normalAfterStartup=24`, `activeAfterStartup=24`, `maxAlive=24`, `cap=100`, `normalWithinCap=true`.
  - Elite scheduler trigger: `eliteAfterTrigger=1`, `eliteAfterSecondWindow=1`, `eliteIndexAfterTrigger=2`, `eliteNoDouble=true`.
  - Boss spawn path through the existing debug hook: `bossSpawned=true`.
  - Swarm scheduler: `swarmActive=true`, `swarmSourceCount=120`, `swarmActiveCount=120`, `swarmCap=120`, `swarmWithinCap=true`.
  - Cleanup after disabling auto-spawn/run: `cleared=120`, `afterClearActive=0`.
- Values preserved before/after refactor:
  - `ELITE_INTERVAL_SECONDS = 300`.
  - `SWARM_EVENT_TIMES = {240, 720}` and `SWARM_DURATION = 60`.
  - Initial spawn cap observed as `100`; initial desired normal alive observed as `24`.
  - Active swarm cap observed as `120`.
  - Existing spawn pool thresholds, interval formula, burst formula, overtime formula, catch-up debt formula, and important-encounter trim formula were moved without balance edits.
- Output showed no missing-module, fallback, or scheduler errors. Existing unrelated Studio output remained from `Hybrid Terrain Hex Generator`, `RunStatsHud` reentrancy in one probe run, error reporter configuration, and missing TeleportData in Play Solo.
- No new `_G`, remotes, fallback damage path, Heartbeat, scheduler loop, or bootstrap was added.

### Not verified

- Natural wall-clock wait to the 4:00 swarm, 5:00 elite, and 12:00 swarm timings was not performed; the probe advanced scheduler state through existing debug/test-only controls to keep validation short.
- Long-run random encounter progression over the full 15-minute run remains unverified in this pass.

### Risks

- `EncounterScheduler` now owns mutable scheduling state. Future Stage 2E or later work must keep mob spawning execution and portal/end ownership in `WaveController` or a dedicated spawn owner, not grow scheduler into a God Module.
- Existing gameplay `_G` debug hooks in `WaveController` remain for Stage 2E; they were not expanded in 2D.

### Rollback

- Restore the previous `WaveController.lua` scheduling/state helpers and Heartbeat spawn block.
- Delete `Level/ServerScriptService/ModuleScript/EncounterScheduler.lua` and live `game.ServerScriptService.ModuleScript.EncounterScheduler`.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 2D notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Lobby and level UI ScreenGui toggles and mobile camera fallback

### Summary

- Changed `Four Peaks` portal UI state so `PortalUI` opens and closes through `ScreenGui.Enabled`; the `UI` and `Background` frames remain visible containers instead of being the open/closed state.
- Changed active `Level` `UpgradesGUI` state so upgrade offers open and close through `ScreenGui.Enabled`; `Main` remains a visible container.
- Updated level modal checks in `ModalUiState` and `PauseClient` to treat enabled `UpgradesGUI` as the blocking state.
- Updated lobby and level camera controllers to keep Roblox's default `CameraType.Custom` camera on touch-only devices, avoiding the custom lagged `Scriptable` orbit camera on phones.

### Files

- Updated `Four Peaks/StarterGui/PortalUI/PortalUIClient.lua`
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/CameraMouseLock.lua`
- Updated `Level/StarterGUI/UpgradesGUI/UpgradesClient.lua`
- Updated `Level/StarterGUI/Pause/PauseClient.lua`
- Updated `Level/ReplicatedStorage/ModuleScripts/ModalUiState.lua`
- Updated `Level/StarterPlayer/StarterPlayerScripts/LocalScript/CameraMouseLock.lua`

### Studio

- Active `Four Peaks` scripts synchronized:
  - `game.StarterGui.PortalUI.PortalUIClient`
  - `game.StarterPlayer.StarterPlayerScripts.CameraMouseLock`
- Active `Level` scripts synchronized:
  - `game.StarterGui.UpgradesGUI.UpgradesClient`
  - `game.StarterGui.Pause.PauseClient`
  - `game.ReplicatedStorage.ModuleScripts.ModalUiState`
  - `game.StarterPlayer.StarterPlayerScripts.LocalScript.CameraMouseLock`

### Validation

- Studio grep confirmed `PortalUIClient` now initializes `screenGui.Enabled = false` and sets `currentRefs.gui.Enabled = isVisible`.
- Studio grep confirmed active `Level` `UpgradesClient` opens with `gui.Enabled = true`, no longer uses `main.Visible == true` or `main.Visible = false` as the menu state, and level blocking checks now key off `UpgradesGUI.Enabled`.
- Studio grep confirmed `USE_DEFAULT_TOUCH_CAMERA` exists in both active camera controllers.
- `git diff --check` passed for the changed UI and camera files.
- Play-tested `Level` startup in Studio. No errors were reported from the changed UI or camera scripts.
- Play-tested `Four Peaks` startup in Studio. `PortalUIClient` reached `Ready`, and no errors were reported from the changed UI or camera scripts.

### Runtime loops

- No new `Heartbeat`, `Stepped`, `RenderStepped`, `while`, `task.spawn`, or `task.delay` loop was added.
- Existing camera `BindToRenderStep` loops remain one per place; on touch-only devices they now return early after preserving default Roblox camera behavior.

### Not verified

- Real phone input was not physically tested; the phone path was verified by code path and Studio source grep only.
- Opening the portal prompt and selecting an upgrade were not manually clicked in this pass.
- `Level` Play output still contained unrelated pre-existing errors from `Hybrid Terrain Hex Generator` and the currently dirty `WaveController`.

### Risks

- Touch-only detection uses `UserInputService.TouchEnabled and not KeyboardEnabled and not MouseEnabled`; hybrid touch devices with keyboard or mouse still use the custom desktop camera.
- Lobby modal UI movement locking on phones still depends on the existing camera controller render step, but the controller no longer writes camera CFrames on that path.

### Rollback

- Restore the previous versions of the six updated UI/camera scripts in repo and Studio.
- Revert this changelog entry.

## 2026-07-02 - Poziom WaveController stage 2C ability executor extraction

### Summary

- Completed Stage 2C for active `game.ServerScriptService.Script.Model.WaveController`.
- Added `AbilityExecutor` as a server ModuleScript for elite and boss ability archetype execution.
- Moved target impact, ground slam, dash, line strike, cone, TripleCombo, armor up, volley, teleport step, hazard cast, summon, shockwave sequence, meteor rain, arena pressure, enrage, VFX telegraphs/bursts, ability damage calls, ability cooldown writes, and ability windup scheduling out of `WaveController`.
- Kept ability configuration tables in `WaveController` and preserved WaveController ownership of encounter selection, phase decisions, spawn scheduling, portal/end state, rewards, and debug hooks.
- Kept all player damage through `DamageService`; hazards continue through `AbilityHazards`; hit geometry continues through `AbilityGeometry`.
- Replaced the new `AbilityHazards` module dependency `WaitForChild()` chain with explicit `FindFirstChild`/`assert` loading to keep Stage 2 modules from adding an unbounded module wait.

### Files

- Added `Level/ServerScriptService/ModuleScript/AbilityExecutor.lua`
- Updated `Level/ServerScriptService/ModuleScript/AbilityHazards.lua`
- Updated `Level/ServerScriptService/Script/Model/WaveController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Active script path remained `game.ServerScriptService.Script.Model.WaveController`.
- Created live `game.ServerScriptService.ModuleScript.AbilityExecutor`.
- Synchronized active `WaveController`, `AbilityExecutor`, `AbilityGeometry`, and `AbilityHazards` with repo.
- Repo/Studio source parity after cleanup:
  - `WaveController`: length `71596`, hash `155116688`
  - `AbilityExecutor`: length `23359`, hash `228098505`
  - `AbilityGeometry`: length `2056`, hash `905137855`
  - `AbilityHazards`: normalized source length `5232`

### Validation

- Dependency graph for 2C: `WaveController -> AbilityExecutor`; `AbilityExecutor -> AbilityGeometry`, `AbilityHazards`, `DamageService`, and `NpcService`; no dependency back to `WaveController`.
- Play test used temporary non-persistent probes and removed them after validation.
- Real elite/boss flow through `WaveController -> AbilityExecutor` validated:
  - `RockToss` target impact: `1` hit, radius `5.5`, windup about `1.4` s in controlled probe.
  - `DashThrust` dash/line: `1` hit, width `4`, windup `0.8` s.
  - `ShieldCone`: cast observed and hit in the combined Knight probe.
  - `TripleCombo`: sequence `ShieldCone -> TripleCombo`, `3` hits, hit intervals about `0.26/0.28` s.
  - `RootCage`: hazard still produced `3` ticks through `AbilityHazards`, intervals `0.8/0.8`.
  - `BoulderRain` meteor archetype: boss cast produced hits with windup `1.1` s.
  - `Shockwave` sequence: boss cast reached `DamagePlayersInRadius`; final diagnostic recorded `1` Shockwave hit with player distance `3.2` inside radius `17`.
  - Caster cleanup/despawn before delayed `RockToss` damage produced `0` damage events and no remaining VFX in the probe.
- Output showed no `WaveController`, `AbilityExecutor`, `AbilityHazards`, `AbilityGeometry`, `DamageService`, missing-module, or fallback-damage errors. Existing unrelated Studio output remained from `Hybrid Terrain Hex Generator`, `RunStatsHud`, error reporter configuration, and missing TeleportData in Play Solo.
- `script_grep` and repo grep found no temporary Stage 2C probe markers after cleanup.
- No new `_G`, remotes, Heartbeat, fallback damage path, or bootstrap was added.
- New Stage 2 module dependency loading contains no unbounded `WaitForChild()` calls in `AbilityGeometry`, `AbilityHazards`, or `AbilityExecutor`.

### Not verified

- `FlamePool` and `TeleportStep` were not runtime-tested because the active Studio Elite folder did not expose a `Demon` elite through the existing debug spawn path.
- Natural random run progression was not used; validation forced real elite/boss spawns and controlled positions through existing debug hooks.
- Full long-run cooldown matrix was not exhaustively replayed for every ability; cooldown gating was observed through no early RockToss recast and repeated boss ability casts in diagnostic sequences.

### Risks

- `AbilityExecutor` is intentionally a single archetype executor; future Stage 2D/2E work must not let it absorb spawn scheduling, rewards, portal state, or run end ownership.
- `AbilityExecutor` now depends on `NpcService` for ability locks, movement, health, and status effects. `NpcService` must not add a reverse dependency to ability modules.

### Rollback

- Restore the previous `WaveController.lua` ability helper/cast functions.
- Delete `Level/ServerScriptService/ModuleScript/AbilityExecutor.lua` and live `game.ServerScriptService.ModuleScript.AbilityExecutor`.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 2C notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-02 - Poziom WaveController stage 2B ability hazard extraction

### Summary

- Completed Stage 2B for active `game.ServerScriptService.Script.Model.WaveController`.
- Added `AbilityHazards` as a server ModuleScript that owns enemy ability hazard zone parts, tick loops, player-in-radius checks for hazard ticks, DamageService calls for hazard damage, and active-zone cleanup.
- Kept ability configs, hazard damage, duration, tick rate, telegraph visuals, context payloads, remotes, spawn timing, boss/elite ability selection, and public WaveController behavior unchanged.
- Preserved the existing per-hazard task-loop model instead of adding a new central scheduler in this substage.

### Files

- Added `Level/ServerScriptService/ModuleScript/AbilityHazards.lua`
- Updated `Level/ServerScriptService/Script/Model/WaveController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Active script path remained `game.ServerScriptService.Script.Model.WaveController`.
- Created live `game.ServerScriptService.ModuleScript.AbilityHazards`.
- Synchronized active `WaveController`, `AbilityGeometry`, and `AbilityHazards` with repo.
- Repo/Studio parity hashes after cleanup:
  - `WaveController`: length `91396`, hash `344334420`
  - `AbilityGeometry`: length `2056`, hash `905137855`
  - `AbilityHazards`: length `4920`, hash `725243347`

### Validation

- Dependency graph for 2B: `WaveController -> AbilityHazards`, `AbilityHazards -> AbilityGeometry`, and `AbilityHazards -> DamageService`; no reverse dependency to `WaveController`.
- Play test used temporary non-persistent probes and removed them after validation.
- `RootCage` real hazard flow through `WaveController -> AbilityHazards -> DamageService.Apply`:
  - Tick count: `3`.
  - Tick intervals: `0.8`, `0.8`.
  - Config tick rate: `0.8`; duration: `3.6`.
  - Thorns did not damage the Ent when hazard context had no `source` or `attacker`.
  - Moving outside the hazard produced `0` hits; moving back inside produced `2` hits.
  - Player death produced `0` post-death hits.
- `RunStarted=false` cleanup now leaves `AbilityHazards.GetActiveCount() == 0` and destroys the hazard part (`partAlive=false`).
- `ArenaPressure` real boss hazard flow produced `3` ticks with intervals `0.8`, `0.8`, config tick rate `0.8`, duration `4.5`, and context without `source`/`attacker`.
- Output showed no `WaveController`, `AbilityHazards`, `AbilityGeometry`, `DamageService`, missing-module, or fallback-damage errors. Existing unrelated Studio output remained from `Hybrid Terrain Hex Generator`, `RunStatsHud`, and missing TeleportData in Play Solo.
- `script_grep` and repo grep found no temporary Stage 2B probe markers after cleanup.
- No new `_G`, remotes, fallback damage path, Heartbeat, or bootstrap was added.

### Not verified

- `FlamePool` was not runtime-tested because the active Studio Elite folder did not expose a `Demon` elite through the existing debug spawn path.
- Full natural run progression to randomly selected hazards was not used; validation forced real elite/boss spawns through existing debug hooks.

### Risks

- `AbilityHazards` still preserves the existing per-hazard `task.spawn` tick loop; Stage 2D can decide whether scheduling should be centralized without changing gameplay.
- `WaveController` still owns ability selection/execution, spawn scheduling, portal state, and debug hooks until later Stage 2 substages.

### Rollback

- Restore the previous `WaveController.lua` hazard helper implementation.
- Delete `Level/ServerScriptService/ModuleScript/AbilityHazards.lua` and live `game.ServerScriptService.ModuleScript.AbilityHazards`.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 2B notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-02 - Poziom WaveController stage 2A ability geometry extraction

### Summary

- Completed Stage 2A for active `game.ServerScriptService.Script.Model.WaveController`.
- Added `AbilityGeometry` as a small server ModuleScript for pure ability hit geometry.
- Moved radius, line segment distance, cone, flat-vector, and groundify math out of `WaveController` without changing ability configs, damage values, cooldowns, tick rates, remotes, spawn timing, or hazard lifecycle.
- Left `WaveController` as the owner of player iteration, ability execution, VFX, hazards, scheduling, damage application, and encounter state.

### Files

- Added `Level/ServerScriptService/ModuleScript/AbilityGeometry.lua`
- Updated `Level/ServerScriptService/Script/Model/WaveController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Confirmed active script path: `game.ServerScriptService.Script.Model.WaveController`.
- Confirmed stale duplicate `Level/ServerScriptService/Script/Model.model/WaveController.lua` is not present.
- Created live `game.ServerScriptService.ModuleScript.AbilityGeometry`.
- Synchronized active `WaveController` and `AbilityGeometry` with repo.
- Repo/Studio parity hashes after cleanup:
  - `WaveController`: length `91540`, hash `132201092`
  - `AbilityGeometry`: length `2056`, hash `184505519`

### Validation

- Dependency graph for 2A: `WaveController -> AbilityGeometry`; `AbilityGeometry` has no `require()` dependencies.
- Controlled before/after geometry baseline matched for radius edge/outside/height, line edge/outside/behind/height, cone inside/behind/55-degree edge/55.1-degree outside/height-ignored, and groundify hit/miss.
- Play test used temporary non-persistent probes and removed them after validation.
- Real ability call-site validation through `WaveController -> AbilityGeometry`:
  - `GroundSlam` radius hit: geometry true `1`, damage call `1`.
  - `GroundSlam` radius out-of-range miss: geometry false `1`, damage call `0`.
  - `DashThrust` line hit: geometry true `1`, damage call `1`.
  - `DashThrust` width miss: geometry false `1`, damage call `0`.
  - `DashThrust` height miss: geometry false `1`, damage call `0`.
  - `ShieldCone` cone hit near edge: geometry true `1`, damage call `1`.
  - `ShieldCone` angle miss, behind miss, and range miss: geometry false `1` each, damage call `0`.
- Output showed no `WaveController`, `AbilityGeometry`, `DamageService`, or missing-module errors.
- `script_grep` and repo grep found no temporary Stage 2A probe markers after cleanup.
- No new `_G`, remotes, fallback damage path, runtime loop, scheduler, or infinite `WaitForChild` was added.

### Not verified

- 2B hazard lifecycle was not changed in this substage.
- Full natural run progression to random elite/boss ability usage was not used; validation forced real elite ability casts through existing debug spawn hooks in Studio.

### Risks

- `WaveController` still owns ability execution and hazard lifecycle; Stage 2B/2C must keep using `AbilityGeometry` without adding reverse dependencies.
- The existing `WaveController` debug `_G` hooks remain unchanged and are still scheduled for later Stage 2E cleanup.

### Rollback

- Restore the previous `WaveController.lua` source.
- Delete `Level/ServerScriptService/ModuleScript/AbilityGeometry.lua` and live `game.ServerScriptService.ModuleScript.AbilityGeometry`.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 2A notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-02 - Poziom ProgressService party XP declaration-order fix

### Summary

- Fixed the Stage 1 party XP startup error caused by local function declaration order in `ProgressService`.
- Added forward declarations for `rollNextRunXp`, `getRun`, and `syncHud`, then assigned the existing implementations later in the file so earlier party helpers capture the intended locals instead of resolving nil globals.
- Kept XP formulas, party XP math, level-up thresholds, spell offer flow, run state, remotes, persistent data, and `RunProgressApi` contracts unchanged.

### Files

- Updated `Level/ServerScriptService/Script/ProgressService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Synchronized `game.ServerScriptService.Script.ProgressService` with the repo copy.
- Removed temporary Play-test probe objects from Studio after validation.
- Repo/Studio parity for `ProgressService` matched after cleanup: length `46996`, hash `233256071`.

### Validation

- Play test covered the party XP branch by forcing `RunMode = "Multi"` in a temporary probe and awarding XP through the public `RunProgressApi.AwardPlayer` path.
- Multi branch award `160` XP from initial party state `level=1`, `xp=0`, `nextXp=141` produced `level=2`, `xp=19`, `nextXp=198`.
- Solo branch award `200` XP from the same run produced `level=3`, `xp=21`, `nextXp=261`.
- Party award emitted one progress update for the controlled award, matching the no-double-award expectation.
- Spell offers opened and picks completed in both the Multi branch and Solo follow-up.
- `script_grep` and repo grep found no temporary probe markers after cleanup.
- Repo grep found no active progress `_G` names under `Level/ServerScriptService`.
- `git diff --check` passed.

### Not verified

- Full two-client multiplayer was not available through the current MCP Play controls, so a true two-player party session remains unverified runtime.
- Natural kill-driven party XP for normal, elite, and boss enemies was not fully verified as real combat in this pass; the public award contract and party branch were validated directly through `RunProgressApi`.
- External teleport/reconnect lifecycle remains unverified runtime in Studio, with only static contract review from the Stage 1 migration.

### Risks

- `ProgressService` remains a large coordinator until later approved stages split ownership into smaller modules.
- Future edits near party helpers must keep forward-declared locals and later assignments aligned; reintroducing `local function` there would recreate shadowing.

### Rollback

- Revert the forward declarations and assignment-form replacements in `ProgressService.lua`.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 1 status note in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-01 - Poziom ProgressService RunProgressApi migration

### Summary

- Added `RunProgressApi` as the explicit required API boundary for run rewards/progress/lifecycle calls that previously went through ProgressService/WaveController `_G` hooks.
- Migrated active Level callers away from `_G.AwardPlayer`, `_G.AwardSouls`, `_G.TrySpendRunCoins`, `_G.GetRunCoins`, `_G.RegisterEnemyKill`, `_G.NotifyBossSpawn`, `_G.GetAverageRunLevel`, `_G.GetRunSeconds`, and `_G.EndRunForPlayer`.
- Removed live/repo caller usage of legacy `_G.EndRun` and `_G.SetGlobalRunPause` fallbacks.
- Preserved WaveController InfoUI kill/coin counters through `RunProgressApi.Wrap` instead of wrapping `_G` functions.

### Files

- Added `Level/ServerScriptService/ModuleScript/RunProgressApi.lua`
- Updated `Level/ServerScriptService/Script/ProgressService.lua`
- Updated `Level/ServerScriptService/Script/Model/WaveController.lua`
- Updated `Level/ServerScriptService/Script/DropService.lua`
- Updated `Level/ServerScriptService/ModuleScript/Items/ChestItemService.lua`
- Updated `Level/ServerScriptService/Script/ChestService.server.lua`
- Updated `Level/ServerScriptService/Script/RunDeathHandler.lua`
- Updated `Level/ServerScriptService/Script/ReturnToLobby.lua`
- Updated `Level/ServerScriptService/Script/StatueService.server.lua`
- Updated `Level/ServerScriptService/Script/DebugCommandService.server.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.RunProgressApi`.
- Synchronized matching source changes to all updated active Level scripts listed above.
- Studio grep confirmed no active matches for the migrated `_G` names after sync.

### Validation

- `Level` Play startup smoke passed after fixing a `WaveController` local-register limit regression by avoiding a new top-level local in that script.
- The only console error after the passing startup smoke was the pre-existing unrelated `ServerScriptService.Hybrid Terrain Hex Generator:16` toolbar error.
- Repo grep found no matches for the migrated `_G` names.
- Studio grep found no matches for `_G.AwardPlayer`, `_G.AwardSouls`, `_G.TrySpendRunCoins`, `_G.GetRunSeconds`, `_G.GetAverageRunLevel`, `_G.RegisterEnemyKill`, `_G.NotifyBossSpawn`, `_G.EndRunForPlayer`, `_G.EndRun`, or `_G.SetGlobalRunPause`.
- `git diff --check` passed.
- No remotes, persistent data, teleport data, damage values, XP values, drop values, cooldowns, tick rates, or spawn rates were intentionally changed.
- No new `Heartbeat`, `Stepped`, `RenderStepped`, or long-running `while` loop was added; an old finite `task.spawn` wait around `_G.AwardPlayer` in `WaveController` was removed.

### Not verified

- Full gameplay call-site tests were not completed in this pass: kill XP, elite/boss kill, drop pickup, chest reward fallback, chest coin spend, statue battle timing, manual return, defeat end-run, and victory end-run.
- Because those required tests were not completed, stage 2 should not begin until they are verified.

### Risks

- `RunProgressApi` is an explicit boundary, but several implementations still live inside `ProgressService`; later refactor steps should move ownership into smaller domain modules instead of letting the API become a new God Service.
- `WaveController` is at Roblox's local-register limit; future changes should avoid adding top-level locals to that file before it is split.
- If a gameplay call happens before `ProgressService` configures `RunProgressApi`, the API warns and returns the same kind of nil/false result that the old missing `_G` path would have produced.

### Rollback

- Restore the previous versions of all updated Level scripts and delete `Level/ServerScriptService/ModuleScript/RunProgressApi.lua`.
- Delete live Studio `game.ServerScriptService.ModuleScript.RunProgressApi` and restore previous live source for synchronized scripts.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the stage-1 update in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-01 - God Script refactor audit and migration plan

### Summary

- Completed stage 0 audit for the requested staged God Script and gameplay `_G` refactor.
- Added `docs/GOD_SCRIPT_REFACTOR_PLAN.md` with file metrics, active Studio paths, gameplay global writers/callers, current `require()` graph, migration order, risks, tests, and rollback notes.
- Confirmed active Studio paths for `Level` and `Four Peaks`; `Guild` Studio was not open and is marked as blocked before the guild refactor stage.

### Files

- Added `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active Studio instances found: `Level`, `Four Peaks`.
- Set active Studio to `Level` and confirmed key active scripts:
  - `ServerScriptService.Script.ProgressService`
  - `ServerScriptService.Script.Model.WaveController`
  - `ServerScriptService.ModuleScript.NpcService`
  - `ServerScriptService.ModuleScript.Stats.RunStatsService`
  - `ServerScriptService.Script.SpellService`
  - `ServerScriptService.Script.ShrineService`
- Set active Studio to `Four Peaks` and confirmed key active scripts:
  - `ServerScriptService.ModuleScript.GuildService`
  - `ServerScriptService.ModuleScript.CraftingService`
  - `ServerScriptService.Script.BlacksmithService`
  - `StarterPlayer.StarterPlayerScripts.InventoryController`
  - `StarterPlayer.StarterPlayerScripts.BlacksmithUI`
- `Guild` Studio was not available.

### Validation

- Repository scan found no `shared.`, `getfenv`, `setfenv`, `rawget(_G`, or `rawset(_G` matches.
- Active Studio grep confirmed current `Level` gameplay `_G` callers/writers for rewards, run timing, end run, drops, world preparation, and debug hooks.
- Active Studio grep confirmed current `Four Peaks` `_G` hooks are spellbook helpers and error reporter debug hooks.
- No runtime scripts were changed in this stage.
- No remotes, persistent data, teleport data, runtime loops, or gameplay balance values were changed.

### Risks

- `Guild/` could only be audited from repo because Studio `Gildia` was not open.
- `script_grep` line numbers do not always match repository line numbers, so future stages must verify concrete script snippets before editing.
- Stage 1 can create require cycles if caller migration simply points systems at the current `ProgressService` Script instead of a small domain ModuleScript.

### Rollback

- Delete `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.
- Revert this changelog entry and the `CHANGELOG_AI.md` index line.

## 2026-07-01 - Poziom DamageService global shim removal

### Summary

- Removed the temporary `_G.ApplyDamageToPlayer` compatibility bootstrap after active `NpcService`, active `WaveController`, and `RunStatsService.ApplyDamageToPlayer` all used `DamageService.Apply` directly.
- Deleted the confirmed stale repo-only duplicate `Level/ServerScriptService/Script/Model.model/WaveController.lua` instead of modernizing inactive code.
- Removed the corresponding live Studio bootstrap object `game.ServerScriptService.Script.DamageService`; the remaining live `DamageService` is only `game.ServerScriptService.ModuleScript.DamageService`.

### Files

- Deleted `Level/ServerScriptService/Script/DamageService.server.lua`
- Deleted `Level/ServerScriptService/Script/Model.model/WaveController.lua`
- Updated `CHANGELOG_AI.md`
- Added `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Deleted `game.ServerScriptService.Script.DamageService`.
- Confirmed `game.ServerScriptService.Script.Model.WaveController` remains the only live `WaveController`.
- Confirmed no live `game.ServerScriptService.Script.Model.model` object exists.

### Validation

- Repository search for `_G.ApplyDamageToPlayer` now reports documentation/changelog history only.
- Repository search for `_G["ApplyDamageToPlayer"]` and `rawget(_G, "ApplyDamageToPlayer")` found no matches.
- Active Studio grep for `ApplyDamageToPlayer` reports only `ServerScriptService.ModuleScript.Stats.RunStatsService.ApplyDamageToPlayer`.
- Play test used a temporary non-persistent server probe and removed it after the run.
- In Play, `_G.ApplyDamageToPlayer` was `nil`, while existing debug spawn hooks were available.
- Verified real `NpcService` contact damage from a spawned Slime reached `DamageService.Apply` with `sourceType = "npc"`, `source` and `attacker` present.
- Verified armor/shield handling on the Slime hit: `amount = 5`, `ShrineDifficultyPct = 0.25`, `RunStat_Armor = 0.5`, expected post-difficulty/armor damage `3.125`, shield changed `30 -> 26.875`, HP stayed unchanged.
- Verified thorns for contact damage: Slime source health changed `14 -> 0`.
- Verified real `WaveController` ability damage from Golem `RockToss` reached `DamageService.Apply` with `sourceType = "ability"`, `abilityId = "RockToss"`, no `source`, and no `attacker`.
- Verified real `WaveController` hazard damage from Ent `RootCage` reached `DamageService.Apply` with `sourceType = "hazard"`, `abilityId = "RootCage"`, no `source`, and no `attacker`.
- Verified two `RootCage` hazard ticks: tick records at approximately `0.80s` spacing, matching the configured `0.80` tick rate.
- Verified ability/hazard damage did not provide a thorns source or attacker, so it did not newly thorns-damage NPCs.
- Checked Studio log history after Play; no errors referenced missing `_G.ApplyDamageToPlayer` or `DamageService`. The existing `Hybrid Terrain Hex Generator` toolbar error was unrelated and pre-existing in the session.
- `git diff --check` passed.

### Risks

- Historical changelog and audit docs still mention `_G.ApplyDamageToPlayer`; those are intentionally retained as history.
- Other unrelated `_G` globals still exist in the project, but this change did not add any new `_G`, runtime loop, fallback, or bootstrap.

### Rollback

- Restore `Level/ServerScriptService/Script/DamageService.server.lua` and the live Studio object `game.ServerScriptService.Script.DamageService` from the previous revision.
- Restore `Level/ServerScriptService/Script/Model.model/WaveController.lua` only if the stale duplicate must be kept for archival parity.
- Revert this changelog entry and the `CHANGELOG_AI.md` index update.
