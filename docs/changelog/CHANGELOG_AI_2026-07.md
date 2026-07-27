# CHANGELOG_AI 2026-07

## 2026-07-26 - Four Peaks summoning altar review fixes (PR #142)

### Summary

- Preserved `UICorner`, `UIStroke`, and other structural children when a weapon preview is refreshed by giving generated preview content a dedicated `GeneratedWeaponContent` owner.
- Rendered every configured `FeaturedWeaponIds` entry in the altar, featured-information panel, and banner cards instead of silently choosing the first weapon.
- Added full featured-name summaries to the altar badge, information panel, and banner cards while retaining the single-feature presentation.
- Anchored the roll summary to a fixed-height strip inside the reveal panel and reset the altar aura to its authored size before every summon tween.

### Files

- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/BannerUI.lua`.
- Updated this monthly changelog.

### Studio and validation

- Active Studio: `Four Peaks`.
- Synchronized the updated `BannerUI` source to `StarterPlayer.StarterPlayerScripts.BannerUI`.
- Temporarily configured the active schedule with `Harvest of the End` and `Excalion, Blade of Kings`, opened the banner through `OpenWeaponBannerUI`, and verified that the altar, information panel, and sidebar each created two generated weapon cells.
- Verified the altar badge and sidebar summary contained both configured weapon names.
- Verified the preview containers retained their pre-existing `UICorner` and `UIStroke` instances after rendering.
- Verified the summary strip remains inside the reveal panel beside the Continue button, and consecutive reveal setup resets the aura from 360 x 360 to 326 x 326 before expanding again.
- Restored `BannerConfigs` and `BannerSchedule` from the repository after the test.
- Play reached the Four Peaks lobby without a `BannerUI` error. The existing unrelated `BlacksmithUI` wait for `PassiveDesc` remained.
- `git diff --check` passed before the changelog update and is rerun in final validation.

### Runtime loops and cleanup

- No new `Heartbeat`, `Stepped`, `RenderStepped`, polling task, remote, persistent-data field, teleport field, or `_G` dependency was added.
- Generated preview frames remain owned by their presentation container and are cleared synchronously before reuse; no connection or long-lived runtime-table lifecycle changed.
- Multi-feature rendering costs O(F) GUI instances per visible banner, where F is the configured featured-weapon count. Current validation covered two featured weapons.

### Not verified

- Studio screenshot and pointer-input tools timed out in this MCP session, so visual pixel quality and physical mouse/touch interaction were not verified.
- Real x1/x10 rolls, skip/continue, pity/guarantee transitions, conversion, insufficient-currency behavior, and persistence were not exercised because this review fix does not change those paths and a live roll would mutate player economy.
- Phone, tablet, and ultrawide visual layouts remain unverified.

### Risks and rollback

- Very large future featured lists can make individual preview cells and name summaries dense; the grid adapts to the configured count but has no explicit content cap.
- Rollback by reverting the PR #142 review-fix commit and restoring the previous `BannerUI` source in Four Peaks Studio. No data migration or server rollback is required.
## 2026-07-26 - Level chest reward presentation and run HUD cleanup (PR #141)

### Summary

- Added a responsive presentation layer to the authored Level chest-opening animation.
- The final reward shows rarity, source, item name, description, exact stat changes, and stack limit.
- Reused the existing server-selected payload and claim controls; reward rolling, granting, pause state, and remotes are unchanged.
- Removed the large `Run Stats` panel shown during pause and chest opening while preserving the compact collected-item icon grid during active runs.
- Added a compact layout for short landscape viewports so the reward header, card, and claim controls remain inside a 568 x 320 viewport.
- Made the wide side-card layout require at least 480 px of height, so short desktop windows such as 1200 x 400 use the bounded compact layout instead.

### Files

- Added `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardPresentation.client.lua`.
- Updated `Level/StarterPlayer/StarterPlayerScripts/LocalScript/RunStatsHud.client.lua`.
- Updated `Level/StarterGUI/ChestOpening/MANIFEST.md`.
- Updated this monthly changelog and removed the non-standard one-off changelog.

### Studio and validation

- Reviewed the complete chest payload contract from `ChestItemService`: item and fallback rewards include display names, descriptions, and formatted modifier lines.
- Verified the presentation controller does not send reward requests or mutate reward data.
- Verified the rewritten run HUD only listens for inventory snapshots and `RunStarted` visibility.
- Synchronized the touched client sources to active Level Studio before Play validation.
- Programmatically exercised the compact layout at 568 x 320 and 1200 x 400 plus the regular desktop threshold; the reward card and action controls remain inside the presentation root with a positive gap.
- `git diff --check` passed in final validation.

### Runtime loops and cleanup

- No `Heartbeat`, `Stepped`, `RenderStepped`, polling loop, remote, persistent-data field, teleport field, or `_G` dependency was added.
- One `AbsoluteSize` signal recalculates O(1) layout properties only when the presentation viewport changes.
- The dynamic action-frame visibility connection is disconnected before rebinding and when the presentation closes or its GUI is removed.
- The controller's existing bounded `task.spawn` waits for the authored action frame and is invalidated by a session identifier.

### Not verified

- Studio screenshot and pointer-input tools timed out in this MCP session, so final pixel quality and physical mouse/touch claim interaction were not verified.
- Device Emulator screenshots remain unavailable; compact bounds were validated programmatically instead.
- A production reward was not claimed because that would mutate run state.

### Risks and rollback

- Extremely long localized reward text may require additional truncation or scrolling beyond the tested payload contract.
- Rollback by reverting PR #141 and restoring the previous Level client sources. No DataStore, remote, teleport, server gameplay, or migration rollback is required.

## 2026-07-26 - Level dry-ground world spawn contract (PR #138)

### Summary

- Changed `WorldBounds.RaycastTerrainAtXZ` so gameplay spawns reject Roblox Terrain water by default.
- Kept water in the default raycast so a water surface rejects the complete sample instead of allowing the seabed beneath it.
- Added the explicit `allowWater = true` opt-in; callers that intentionally need the seabed may combine it with `ignoreWater = true`.
- The shared contract applies to existing random/nearby terrain-point consumers, including chests, reward chests, shrines, statues, monuments, the run portal, bosses, enemies, and random player spawn.

### Files

- Updated `Level/ServerScriptService/ModuleScript/WorldBounds.lua`.
- Updated this monthly changelog.

### Studio and validation

- Active Studio: `Level`.
- Synchronized `ServerScriptService.ModuleScript.WorldBounds` from the branch before Play validation.
- In Play, created a temporary isolated Terrain stack outside the map with water over rock. The default `RaycastTerrainAtXZ` returned `nil`, `allowWater = true` returned `Water`, and `allowWater = true, ignoreWater = true` returned the `Rock` seabed.
- The temporary Terrain region was cleared immediately in the same server test and did not persist after Play stopped.
- Level startup completed world preparation with 358 chests, 16 shrines, 6 statues, and 3 monuments and produced no `WorldBounds` error.
- The existing unrelated `Hybrid Terrain Hex Generator:16` toolbar error and bounded loading preload timeouts remained.
- Repository searches covered every current `WorldBounds` terrain-point call site.
- `git diff --check` passed in final validation.

### Runtime loops and cost

- No loop, scheduler, connection, remote, persistent-data field, teleport field, or `_G` dependency was added.
- Each affected terrain sample still performs one bounded terrain raycast. The new default path adds one boolean option normalization and, for a hit, one material comparison.
- Existing bounded retry counts in `FindRandomTerrainPoint` and `FindNearbyTerrainPoint` are unchanged.

### Not verified

- Studio screenshot and pointer-input tools timed out in this MCP session, so a visual survey of every natural water edge and every spawn category was not performed.
- Multiplayer and a complete production-length run were not exercised.

### Risks and rollback

- Callers that intentionally expected a water surface must now opt in with `allowWater = true`; repository search found no such explicit gameplay requirement among current consumers.
- Maps with too little dry terrain may exhaust their existing bounded candidate retries more often, returning the same existing `nil` failure path instead of spawning in water.
- Rollback by reverting PR #138 and restoring the previous Level `WorldBounds` source. No data migration, remote, or server-state rollback is required.

## 2026-07-24 - Poziom slide animation integration (PR #134)

### Summary

- Added slide animation asset `78771843103599` with configurable fade time and playback speed.
- Added a dedicated client presentation controller that owns the slide `AnimationTrack` lifecycle without changing slide physics.
- Replaced the PR's original `CameraOffset` property signal with the explicit client-local Humanoid attribute `MovementSlideActive`; Play proved that `GetPropertyChangedSignal("CameraOffset")` emitted zero callbacks for two value changes and could not drive the animation.
- Kept `MovementController` as the sole owner of slide gameplay state. It sets the attribute only when a slide starts, clears, or a character binds.

### Files

- Updated `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`.
- Updated `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`.
- Added `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SlideAnimationController.client.lua`.
- Updated `CHANGELOG_AI.md` and this monthly changelog.

### Studio and validation

- Active Studio: `Level`, PlaceId `113361902471683`.
- Created the live `StarterPlayer.StarterPlayerScripts.LocalScript.SlideAnimationController` and synchronized the configuration and equivalent state-owner edits to the active live `MovementController`.
- Normalized source parity passed for `MovementConfig` (length `2848`, checksum `1140370050`) and `SlideAnimationController` (length `3350`, checksum `125086846`).
- The live `MovementController` intentionally retained its pre-existing Studio-specific source; the three slide-state writes were applied at character bind, successful slide start, and motion clear instead of replacing the whole script from the PR branch.
- Level Play reached the loading gate and prepared the world. Animation `rbxassetid://78771843103599` loaded and played looped at `Action` priority and speed `1`.
- Setting the slide state false stopped the track. Killing the local Humanoid while the track was playing also stopped it.
- A server `LoadCharacter()` respawn produced a new Humanoid with the state initialized false; the controller rebound and passed a second start/stop animation test.
- Console output contained no `SlideAnimation` error or warning. The pre-existing unrelated `Hybrid Terrain Hex Generator:16` toolbar error, `RunStatsHud` re-entrancy error, and bounded loading preload timeouts remained.
- `git diff --check` passed before the changelog update; it is rerun in final validation.

### Runtime cost and cleanup

- No `Heartbeat`, `Stepped`, `RenderStepped`, polling loop, remote, persistent-data field, teleport field, `_G` dependency, physics value, cooldown, or slide speed was added or changed.
- The presentation controller uses two lifetime player-character connections and two dynamic Humanoid connections (`GetAttributeChangedSignal` and `Died`) for the single local player.
- Dynamic Humanoid connections are disconnected and the animation track is stopped/destroyed on character removal or rebind.
- `MovementController` adds O(1) attribute writes only at character bind, successful slide start, and motion clear.

### Not verified

- A physical `C`/Control/gamepad slide input could not be automated because Studio denied `VirtualInputManager.SendKeyEvent` to the MCP command thread. The existing slide owner path was inspected, while the owner-to-presentation state contract and full animation lifecycle were tested directly.
- Multiplayer client presentation was not tested; the state and animation are intentionally local to each player's Humanoid and PlayerScripts.

### Risks and rollback

- `MovementSlideActive` is a new client-local presentation contract. Repository and Studio searches found no pre-existing use of that name.
- Future slide-state owners must keep the attribute transition paired with `activeMotion`; polling `CameraOffset` is not a valid fallback in the tested Studio runtime.
- Studio rollback: undo to the `Before PR 134 slide animation sync` waypoint, or delete the live presentation LocalScript and remove the config fields and three attribute writes.
- Repository rollback: revert the PR #134 merge/follow-up commit. No data migration or server rollback is required.

## 2026-07-20 - Poziom ReactiveGrass removal and diagnostics HUD optimization (PR #132)

### Summary

- Squash-merged PR #132 into `main` as `8143c0dacbcd26c57c42a1b509d8170a4a22ec5b`.
- Deleted the live, repo-untracked `StarterPlayer.StarterPlayerScripts.ReactiveGrassClient` LocalScript from the active Level/Poziom place (PlaceId `113361902471683`); no other active copy existed.
- Preserved `Workspace.ReactiveGrass` and all grass models, MeshParts, bones, textures and map decoration, leaving the grass visible and static.
- Synchronized the two FPSCounter LocalScripts from the merged repository revision to Studio with normalized source parity.

### Files

- Updated `Level/StarterGUI/FPSCounter/PerfHudClient.lua`.
- Updated `Level/StarterGUI/FPSCounter/FPSCounterClient.lua`.
- Added `docs/changelog/CHANGELOG_AI_2026-07_REACTIVE_GRASS_REMOVAL.md`.
- Updated `CHANGELOG_AI.md` and this monthly changelog with the completed live validation.

### Studio and validation

- Roblox MCP exposed the sole connected target as `Level`; `game.PlaceId` was `113361902471683`, matching the project Level/Poziom mapping. No Four Peaks Studio instance was connected or modified.
- A full DataModel search after deletion found no `ReactiveGrassClient` scripts and no active source references to `ReactiveGrass`, `GrassBone`, `RenderFidelity` or `WorldToViewportPoint`.
- `Workspace.ReactiveGrass` remained present with 195,755 descendants, including 13,118 MeshParts and 13,118 bones; Play screenshots confirmed the grass remained visible.
- A 12.00-second Play sample in the grass area found zero `Transform` changes across all 13,118 grass bones, confirming the grass remained static and did not react to the player.
- F3 opened and closed the diagnostics HUD. While hidden, all seven displayed values remained unchanged across 2.25 seconds. While visible, changing values emitted at most roughly one text change per second; stable values emitted none.
- The visible-HUD profiler buffer contained one `PerfHudClient.Update` timer and two instances across 2.019 seconds (about 0.99 Hz). The hidden-HUD buffer contained zero instances.
- Both MicroProfiler captures ran for at least 12 seconds with a 256-frame rolling buffer. Hidden HUD: median 9.179 ms, p95 13.756 ms, p99 14.591 ms, worst 17.341 ms at frame 13399 / absolute frame 1937099. Visible HUD: median 9.387 ms, p95 13.634 ms, p99 14.902 ms, worst 16.642 ms at frame 14991 / absolute frame 1944700.
- Neither capture contained a ReactiveGrass timer. The visible capture contained zero frames at or above 20 ms and zero at or above 25 ms, so the previously reported regular 0.2-second, 20–25 ms ReactiveGrass spikes were absent.
- Output contained no new PR-related error or warning and no `Script_ReactiveGrassClient` or `RenderFidelity` error. The existing unrelated `ServerScriptService.Hybrid Terrain Hex Generator:16` `CreateToolbar` error remained.

### Runtime loops and cost

- Removed the ReactiveGrass per-client `PreRender` connection and its 0.20-second active-grass scan without replacement.
- Removed the duplicate `FPSCounterClient` `RenderStepped` FPS loop.
- Retained one `PerfHudClient` `RenderStepped` connection. It returns before sampling while hidden and performs the detailed update at a one-second interval while visible; text assignments are conditional on actual value changes.
- No remote, persistent data, gameplay balance, NPC, pathfinding, drop, movement, map asset, Four Peaks or `_G` change was made.

### Before-data limitation, risks and rollback

- The before result comes from the approved PR's published-client capture: ReactiveGrass scanned roughly every 0.2 seconds and individual scan frames cost about 20–25 ms. The raw pre-change capture was not present in this Studio session, so a directly comparable pre-change p95 and worst-frame ID could not be recomputed.
- Studio reports the target DataModel name as `Level`, while project/user-facing instructions call it `Poziom`; PlaceId `113361902471683` was used to disambiguate the target.
- To roll back repository code, revert the PR #132 squash commit and this validation commit. To roll back Studio during the current session, undo to the `Before PR 132 Studio sync` waypoint; otherwise restore `StarterPlayer.StarterPlayerScripts.ReactiveGrassClient` from the previous place version and restore the previous two FPSCounter sources. Restoring ReactiveGrass also restores its known periodic scan cost.

## 2026-07-20 - PR #128 persistence safety audit and verification

### Summary

- Fixed legacy `coins -> silver` migration, same-server reconnect after failed lease release, fail-closed handling after terminal session loss, exact weapon instance-ID parity in the retained `PlayerState_v2` backup, and duplicate unified-profile writes before dungeon teleport.
- Preserved DataStore names, key formats, public APIs, remotes, `TeleportData` fields and the legacy backup; no production record was read, written or deleted.

### Files

- Updated matching Four Peaks and Level `PlayerData.lua` and `PlayerProfileSchema.lua` modules.
- Updated Four Peaks `PlayerStateStore.lua`.
- Updated `docs/DATA_SAFETY_PHASE_1.md` and the dedicated player-data safety changelog.
- Updated `docs/PROJECT_CODE_GUIDE.md` to describe the unified profile, embedded `PlayerState`, session lease, migration, failure and rollback contract.

### Validation

- 36 fake-store assertions passed for lease lifecycle/contention/retries/failures and legacy profile/weapon migration.
- 12 reconnect-ordering assertions and 13 leave/shutdown failure assertions passed, including retained recovery state for a missing main record.
- Synthetic upgraded profiles encoded to 312,946 bytes for 500 weapon instances and 3,119,948 bytes for 5,000; current content exposes 59 weapon definitions.
- Four Peaks Play passed unified-profile, weapon equip, gacha, remote-class and volatile save probes.
- Level Play reached `RunLoadingState.Phase = running` and `RunStarted = true`; persistence and return-teleport remote probes passed.
- Temporary fake modules and Studio-only volatile guards were removed. Normalized repo/Studio source lengths and checksums match for all synchronized #128 scripts.
- `git diff --check` passed; Four Peaks and Level persistence/schema/lease copies are identical.

### Runtime cost and risks

- The existing profile maintenance loop remains at 60-second cadence. No frame loop, per-object connection or `_G` dependency was added.
- Normal sessions add no reconnect work. Only a reconnect following a failed release waits for the bounded release worker (up to 25 seconds) or fails closed.
- Real staged migration, cross-place round trip and two-live-server contention remain deployment gates; production publish and old-server shutdown were outside this review.

### Rollback

- Before post-migration inventory mutations, revert the #128 persistence files and remove the added schema/lease modules.
- After post-migration inventory mutations, first reverse-migrate embedded `PlayerState` into `PlayerState_v2`; a code-only revert can restore stale weapon data.

## 2026-07-20 - Level automatic Slime grounding (PR #129)

### Summary

- Removed the Slime-only `groundOffset = 2.55` override from `MobConfig` so the shared NPC grounding calculation uses the authored live model bounds.
- Kept Slime stats, navigation profile, facing, visual scale, spawn clearance and every other mob configuration unchanged.

### Files

- Updated `Level/ServerScriptService/ModuleScript/MobConfig.lua`.

### Studio and validation

- The repository and active Level Studio `MobConfig` source match by normalized length 2507 and rolling checksum 59054158.
- The live Slime template computes an automatic root offset of 1.07566 studs; the removed override was 2.55, a 1.47434-stud upward difference.
- Level Play reached `RunStarted=true`; across 52 naturally spawned Slime models, every root was 1.12566 studs above Terrain (automatic offset plus the existing 0.05-stud spawn clearance) and no model carried `NpcGroundOffset`.
- A direct `NpcService.Register` probe recorded the same 1.07566 automatic offset and was despawned after inspection.
- `git diff --check` passed and no conflict markers remain.

### Not verified

- The full range of Slime animation poses was not reviewed frame-by-frame at multiple camera angles.

### Runtime cost, risks and rollback

- No loop, connection, remote, data format or gameplay stat was added or changed.
- The fix reuses the existing O(parts) grounding calculation once during spawn registration and removes a special-case tuning value.
- Future Slime asset-bound changes will now affect grounding automatically, matching other standard ground enemies.
- Revert PR #129 and restore `groundOffset = 2.55` in Studio to recover the old explicit root height; no migration is required.

## 2026-07-20 - Level dry player spawn validation (PR #127)

### Summary

- Rejected Terrain raycast candidates whose material is `Water` for configured markers, `SpawnLocation` objects and random fallback player spawns.
- Preserved the shared `WorldBounds` raycast, slope, clearance and fallback behavior; the new predicate is local to `RandomGroundSpawn`.

### Files

- Updated `Level/ServerScriptService/Script/RandomGroundSpawn.server.lua`.

### Studio and validation

- The repository and active Level Studio source match by normalized length 4386 and rolling checksum 463506401.
- A 200-point raw Terrain sample found 29 water and 171 dry hits.
- A separate 200-point validated sample rejected 40 water callbacks, accepted 160 dry hits and accepted zero water hits.
- A zero-radius nearby lookup centered on an observed water point returned no candidate, confirming the configured/nearby path uses the same predicate.
- The preceding Level Play smoke reached `RunStarted=true`; `git diff --check` passed and no conflict markers remain.

### Not verified

- A real multiplayer respawn and an authored `SpawnLocation` placed directly over water were not exercised.

### Runtime cost, risks and rollback

- No loop, connection, remote, persistent data, `TeleportData` field or shared `WorldBounds` behavior was added.
- Cost is one material comparison per existing candidate raycast.
- Maps containing only water within all configured search radii will fail closed and keep the existing warning path instead of spawning the player in water.
- Revert PR #127 and restore the previous Studio source to accept water Terrain again; no data migration is required.

## 2026-07-20 - Level bounded loading and generation overlap (PR #126)

### Summary

- Started server world preparation after the first ready client while preserving the requirement that every connected client acknowledges the accepted generation before the run starts.
- Removed full-Workspace preloading and exact replicated-object count waits; shared assets, spawn streaming and immediately visible UI/lighting now have separate bounded stages.
- Fixed review and Play blockers: `ClientWorldLoaded` cannot be discarded before the server reaches `prepared`, and a stuck `PreloadAsync`/`RequestStreamAroundAsync` worker is cancelled at its stage deadline instead of freezing the loading overlay.

### Files

- Updated `Level/ServerScriptService/Script/RunReadyGate.server.lua`.
- Updated `Level/StarterPlayer/StarterPlayerScripts/LocalScript/LoadingClient.client.lua`.

### Studio and validation

- The repository `LoadingClient` and active Level Studio source match by normalized length 7646 and rolling checksum 1769584928.
- Level Play prepared 478 chests, 14 shrines, 6 statues and 3 monuments in 0.89 seconds.
- The intentionally problematic shared and interface preloads reached their budgets, logged controlled timeout warnings, were cancelled without an error and did not block the flow.
- The loading gate completed in 10.28 seconds with generation 1, `RunStarted=true`, phase `running` and the overlay released at 100%.
- `git diff --check` passed and no conflict markers remain.

### Not verified

- Lobby-to-Level teleport, a real two-client run, late join and a deliberately forced server preparation longer than 15 seconds were not exercised in this pass.
- The performance comparison is based on loading diagnostics and the observed removed deadlock, not a MicroProfiler capture.

### Runtime loops, cost and cleanup

- The client timeout helper polls at 20 Hz with one worker at a time and hard budgets of 6 seconds for shared assets, 4 seconds for UI/lighting and 3 seconds for initial streaming; a timed-out worker is cancelled.
- Existing client phase/character waits remain bounded at 20 Hz; request-queue drain is 10 Hz for at most 1.25 seconds.
- After local preparation, the client checks the server phase at 10 Hz until `prepared/running`; the LocalScript lifecycle ends this wait when the player session ends.
- Server preparation uses one guarded startup `task.spawn`, runs once per server generation and has no per-object Heartbeat/Stepped/RenderStepped work.

### Risks and rollback

- Assets that exceed a preload budget may finish through normal Roblox streaming and can appear later, but cannot deadlock run start.
- If server preparation genuinely never reaches `prepared`, the overlay intentionally remains instead of entering an incomplete world.
- Revert PR #126 and restore the previous two Studio sources to recover the old serial loading behavior; no data, remote names or `TeleportData` migration is involved.

## 2026-07-20 - Four Peaks spell inventory reference layout (PR #124)

### Summary

- Added a spell-specific inventory view while preserving the existing inventory shell, server remotes and snapshot payload.
- Fixed the review blockers before merge: `TabBar` now has a stable layout contract, `InventoryController` remains the only owner of remote snapshot refreshes, and the `F` shortcut is routed to the active spell search box.
- The spell view consumes the controller-owned snapshot through client-local `BindableEvent`/`BindableFunction` objects and no longer registers a second `InventorySync` listener or invokes `RF_GetInventorySnapshot`.

### Files

- Added `Four Peaks/StarterPlayer/StarterPlayerScripts/InventorySpellTabReference.client.lua`.
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua`.

### Validation

- `git diff --check` passed and no conflict markers remain.
- The repository files match the sources already synchronized in the active Four Peaks Studio place.
- Four Peaks Play booted `InventoryController` and the new LocalScript without a script error; the spell view root and all three bridge objects were created.
- Static search confirms the new LocalScript has no `InventorySync` listener and no `RF_GetInventorySnapshot` call.

### Not verified

- The current headless Studio interaction could not reliably activate the Spell Loadout button, so desktop/mobile visual spacing and the live `F` focus transition were not re-exercised in this pass.
- No inventory mutation was sent to the server during the smoke test.

### Runtime cost and risks

- No `Heartbeat`, `Stepped`, `RenderStepped` or recurring polling loop was added.
- Rendering is event-driven and linear in spell, combination and element-summary rows.
- `InventoryController` is already a large UI coordinator; this change adds only the local bridge required to preserve one snapshot/input owner, while the independent presentation remains in its own LocalScript.
- The view depends on the explicit `RemakePanel`, `ContentColumn`, `DetailsColumn` and `TabBar` names.

### Rollback

- Revert PR #124, remove `InventorySpellTabReference.client.lua` from Studio and restore the previous `InventoryController.lua`; no persistent data or remote migration is required.

## 2026-07-13 - Level authoritative drop synchronization optimization (PR #118)

### Summary

- Rate-limited client full-sync requests to one accepted request per player per second with sanitized request IDs.
- Reused one alive-player snapshot and one raycast blacklist per server frame.
- Stopped settled stationary drops from raycasting continuously and capped active settling checks at 10 Hz.
- Preserved authoritative pickup rewards, attraction ranges, global magnet behavior and visual payload contracts.

### Files

- Updated `Level/ServerScriptService/Script/DropService.lua`.
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`.

### Studio and validation

- Synchronized `game.ServerScriptService.Script.DropService` to active `Level` Studio.
- `Level` Play loaded the service without new errors.
- A burst of ten client `DropSyncRequest` events produced one full-sync response; the first request was accepted immediately.
- An ephemeral Studio probe spawned 300 authoritative drops away from the player, completed a 90-frame loaded sample without script errors, and was removed after Play.
- The loaded sample averaged 6.345 ms per server heartbeat with a 119.668 ms maximum; the startup-contaminated baseline is not suitable for a before/after performance claim.
- `git diff --check` passed.

### Not verified

- A multiplayer soak, MicroProfiler scope-level comparison against the previous implementation, pickup of all 300 probe drops and behavior on moving dynamic platforms were not verified.

### Runtime loops, cost and risks

- `DropService` retains one global `Heartbeat`; it performs one player snapshot and one ground-filter refresh per frame, then iterates active drops once.
- Ground raycasts are limited to drops with `needsGroundSettle == true` and at most 10 Hz per such drop; grounded stationary drops disable further settle checks until attraction moves them.
- Full-sync rebuild cost remains linear in active drop count, but client requests are limited to 1 Hz per player and request state is cleared on player removal.
- At the target scale of 300 drops, player discovery is `O(players)` once per frame and target selection remains `O(active drops * alive players)`; no per-drop connection or new `_G` dependency was added.
- Settled drops assume static ground until attraction re-enables settling, so moving platforms are not followed continuously.

### Rollback

- Revert PR #118 and this changelog entry to restore unrestricted sync requests and per-frame settling. No persistent data migration is required.

## 2026-07-13 - Level consolidated mission, DPS and return flow fixes (PR #120)

### Summary

- Consolidated event mission forwarding, incremental survival-time accounting, final XP mission persistence and persistent weekly win streaks.
- Added a server-authoritative rolling DPS HUD with batched damage delivery.
- Hardened end-run return ordering and per-player teleport locking, including token-scoped timeout/init-failure cleanup and client failure notification.

### Files

- Updated `Level/ServerScriptService/ModuleScript/MissionProgress.lua`.
- Updated `Level/ServerScriptService/ModuleScript/MissionState.lua`.
- Updated `Level/ServerScriptService/ModuleScript/RunProgressApi.lua`.
- Updated `Level/ServerScriptService/Script/ReturnToLobby.lua`.
- Added `Level/StarterPlayer/StarterPlayerScripts/LocalScript/CurrentDpsHud.client.lua`.
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`.

### Studio and validation

- Synchronized all five runtime scripts to active `Level` Studio.
- `Level` Play loaded the mission, progress and return systems without new errors.
- Confirmed creation of the server `DpsDamageEvent` and client `CurrentDpsHud` ScreenGui.
- Confirmed `TeleportOptions` preserves the per-attempt token attribute used to reject stale init failures.
- `git diff --check` passed.

### Not verified

- Real multiplayer DPS batching, three separate weekly wins, DataStore persistence, live teleport success/failure callbacks and a forced 15-second teleport timeout were not exercised.

### Runtime loops, cost and risks

- `MissionProgress` owns one global `Heartbeat` accumulator and sends only pending per-player damage batches at 10 Hz; the pending table removes entries after send and on player removal.
- `CurrentDpsHud` owns one client `Heartbeat` connection with 10 Hz UI work and a two-second bounded sample window; it disconnects camera viewport listeners when rebinding.
- A pending return uses one bounded 20 Hz poll for at most 30 seconds; each teleport attempt has one token-guarded 15-second delayed cleanup.
- No per-NPC, projectile or drop loop and no new `_G` dependency was added.
- Mission XP now performs a final dirty-profile save before immediate return; this favors persistence but adds one DataStore attempt at run completion when XP is positive.
- A teleport that remains genuinely in flight beyond the lock timeout can expose retry after the client receives `teleport_timeout`; attempt tokens prevent stale cleanup from unlocking a newer retry.

### Rollback

- Revert PR #120 and this changelog entry. The added weekly streak fields are backward-compatible and can be ignored; no persistent data migration is required.

## 2026-07-26 - Four Peaks daily login UI review fixes (PR #144)

### Summary

- Rebuilt the daily-login presentation as a responsive seven-day reward calendar without changing `GetDailyLoginState`, `ClaimDailyLoginReward`, reward balance, persistence, or server authority.
- Kept the reset refresh guard active while a RemoteFunction response is rendered and added a bounded shared retry schedule so a stale boundary response cannot create a response-speed polling loop.
- Reused `InventoryIconResolver` for material bundles and resolved the authored bundle through the existing `MaterialIcons.materials_icon` contract; the glyph remains a fallback only when the replicated asset folder or value is unavailable.

### Files

- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/DailyLoginClient.lua`.
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`.

### Studio and validation

- Confirmed the active place and path as `Four Peaks` / `game.StarterPlayer.StarterPlayerScripts.DailyLoginClient`, with `InventoryIconResolver` present beside it.
- Synchronized the reviewed branch source into active Four Peaks Studio and started Play successfully; the output contained no `DailyLoginClient`, daily-login remote, or icon-resolver error.
- Confirmed live `WeaponIconReplicator` creates `MaterialIcons.materials_icon`.
- `git diff --check` and focused static contract checks passed.
- Studio `screen_capture` and `user_mouse_input` both timed out in the current MCP session, so desktop/mobile screenshots, device-emulator measurements, pointer closing, and live claim-day interaction were not represented as completed.

### Runtime loops, connections, and cost

- The existing client countdown task remains at 1 Hz and only works while `DailyLoginGui` is enabled.
- At the UTC boundary there can be only one `GetDailyLoginState` request in flight. A stale or failed response retries after 10, 20, 40, then at most every 60 seconds; the explicit minimum gate is 5 seconds.
- `resetRefreshPending` is cleared only after response rendering and backoff state are complete, preventing `renderState -> updateCountdown` re-entry from scheduling another request.
- The shared icon resolver is created once for the player-session LocalScript. Its folder invalidation connections are not duplicated by UI reopen or character respawn; the ScreenGui has `ResetOnSpawn=false`.
- No server loop, remote, persistent-data field, `_G` dependency, or per-object connection was added.

### Risks and rollback

- Device-specific spacing and days 1/4/7 claim animation still require a working visual/input Studio session before manual merge.
- A client clock substantially ahead of the server can keep showing the boundary refresh state, but requests remain bounded by the 60-second maximum backoff rather than spamming the server.
- Revert the PR commit and restore the previous Studio `DailyLoginClient` source (or use the `Before PR 144 DailyLogin sync` waypoint). No data migration or server rollback is required.

## 2026-07-13 - Four Peaks daily login material bundle prevalidation (PR #116)

### Summary

- Daily login material bundles are fully validated against the canonical `CraftingConfig` before the first material is granted.
- Unknown or empty positive-amount material IDs now reject the whole bundle without advancing the daily claim.
- A post-validation `CraftingService.AddMaterial` failure is propagated instead of being silently ignored.

### Files

- Updated `Four Peaks/ServerScriptService/ModuleScript/DailyLoginService.lua`.
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`.

### Validation

- Confirmed validation uses `CraftingConfig.GetMaterialBucket` for every positive bundle entry before any mutation.
- Confirmed valid bundles still use the existing `CraftingService.AddMaterial` path and toast metadata.
- Confirmed validation failure returns before the daily login claim state is advanced.
- `git diff --check` passed.

### Not verified

- Live daily-login claiming and DataStore-backed persistence were not verified in Studio; testing a real claim could mutate the active test profile.

### Runtime cost and risks

- No runtime loop, connection, remote, persistent schema, reward config format or DataStore key was added or changed.
- Claim cost adds one bounded linear validation pass over the configured material bundle before the existing grant pass.
- A misconfigured material now intentionally blocks the entire bundle until the configuration is corrected; a rare backend failure after some validated grants can still produce a partial grant because `AddMaterial` is not transactional.

### Rollback

- Remove the `CraftingConfig` require and `validateMaterialBundle` helper, restore the previous warn-and-continue material loop, and revert this changelog entry. No data migration is required.

## 2026-07-12 - Poziom PR #99 kierunek spawn NPC i orientacja Golem

### Summary

- Inspected GitHub PR #99, `Fix NPC spawn facing and Ent/Golem orientation`, and applied its changes locally and in active `Level` Studio.
- `NpcReplication` now resolves snapshot direction through a dedicated helper:
  - emerging NPCs face the nearest alive player using `spawnSurfacePosition`;
  - `MobConfig.facingYawDegrees` is used as a replication fallback when the runtime model does not already carry `NpcFacingYawDegrees`;
  - existing model `NpcFacingYawDegrees` is preserved to avoid applying yaw correction twice.
- Added the missing `facingYawDegrees = -90` configuration for `Golem`.
- Merged PR #99 and deleted the remote branch `fix/npc-spawn-facing`.

### Files

- Updated `Level/ServerScriptService/ModuleScript/NpcReplication.lua`
- Updated `Level/ServerScriptService/ModuleScript/MobConfig.lua`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Synchronized:
  - `game.ServerScriptService.ModuleScript.NpcReplication`
  - `game.ServerScriptService.ModuleScript.MobConfig`
- Final repo/Studio source parity before Play:
  - `NpcReplication`: length `3888`, hash `649373220`
  - `MobConfig`: length `2530`, hash `225028423`
- Removed the stale `game.StarterPlayer.StarterPlayerScripts.LocalScript.ChestOpeningRootMotion` Studio-only object from the failed/unmerged PR #98 attempt before validating PR #99.

### Validation

- GitHub PR #99 metadata and diff were inspected. It was open, mergeable, based on current `main`, and changed two NPC config/replication modules.
- `Level` Play server require loaded `NpcReplication` and `MobConfig`.
- Controlled server probe through `NpcReplication.CollectBatchItems` with a real alive player target confirmed:
  - `MobConfig.Mobs.Golem.facingYawDegrees == -90`;
  - a spawning Slime snapshot at the origin produced `dir = (1, 0, 0)` toward the player at `+X`;
  - `spawnSurfacePos` and `spawnEmergeDepth` still replicated for emerging NPCs;
  - a Golem without `NpcFacingYawDegrees` used the config fallback yaw;
  - a Golem already carrying `NpcFacingYawDegrees = -90` preserved the existing model attribute path and did not double-rotate;
  - a spawning Golem combined player-facing direction with the yaw fallback.
- Temporary probe models were destroyed and the player root/attributes were restored after the test.
- `git diff --check` passed with only existing LF-to-CRLF working-copy warnings.
- Static grep found no new runtime loop, `_G`, DataStore, Teleport, `task.spawn`, `task.delay`, `Heartbeat`, `Stepped` or `RenderStepped` in the changed modules. The `RemoteEvent` hits are existing type annotations/signatures in `NpcReplication`.
- GitHub verification after merge showed PR #99 merged at `2026-07-12T20:36:18Z`, merge commit `f2c69a922181cf324bf464e06dcdaf88e5871825`.
- `git ls-remote --heads origin fix/npc-spawn-facing` returned no ref after merge/fetch, confirming branch deletion.

### Not verified

- Full visual camera inspection of real Ent and Golem models emerging in a natural run was not completed.
- Multi-player nearest-target tie behavior was not manually tested; the helper selects the closest alive player by flat X/Z distance.

### Runtime cost and risks

- No new runtime loop or connection was added.
- `NpcReplication` now scans `Players:GetPlayers()` only when building a snapshot for an NPC that still has `spawnSurfacePosition`, i.e. during its underground emergence window. This cost is `spawning NPC count * player count` per replication batch while those NPCs are emerging.
- If future content spawns hundreds of NPCs simultaneously for long emergence windows in larger multiplayer sessions, consider caching alive player roots once per replication batch instead of scanning inside each emerging NPC snapshot.
- The config fallback intentionally skips yaw rotation when the model already has non-zero `NpcFacingYawDegrees`; this avoids double rotation but depends on callers keeping that attribute meaningful.

### Rollback

- Restore the previous `NpcReplication.lua` snapshot direction assignment to `dir = npc.look`.
- Remove `facingYawDegrees = -90` from the `Golem` entry in `MobConfig.lua`.
- Sync both ModuleScripts back to `Level` Studio.
- Revert PR #99 merge commit `f2c69a922181cf324bf464e06dcdaf88e5871825` on GitHub if rollback is needed remotely.
- Revert this changelog entry and the `CHANGELOG_AI.md` index line.

## 2026-07-12 - Poziom PR #97 chesty z ReplicatedStorage.Assets.Chest

### Summary

- Inspected GitHub PR #97, `Use ReplicatedStorage chest model for world chests`, and applied its focused Level bootstrap script locally.
- Added a startup adapter that clones `ReplicatedStorage.Assets.Chest` into the existing `Workspace.skrzynia` runtime template contract consumed by `ChestService`.
- The runtime template is marked with source attributes, parked at `Y=-100000`, stripped of embedded scripts/prompts, anchored, and left as a direct child of `Workspace`.
- Kept `ChestService` ownership of terrain placement, random yaw, ProximityPrompt creation, costs, rewards, recipe rewards, open handling and cleanup unchanged.
- After validating PR #97, merged GitHub PRs #95, #96 and #97 with head-SHA checks and deleted their head branches:
  - #95 `fix/npc-slope-repath-stutter`
  - #96 `fix/spell-wall-collision`
  - #97 `feat/use-replicated-chest-model`

### Files

- Added `Level/ServerScriptService/Script/ChestAssetTemplateBootstrap.server.lua`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created `game.ServerScriptService.Script.ChestAssetTemplateBootstrap`.
- Confirmed `ReplicatedStorage.Assets.Chest` exists in Studio and is a `Model`.
- Final Studio script source parity: length `2465`, hash `275413366` (`repo` has the same source plus the trailing newline).

### Validation

- GitHub PR #97 metadata and diff were inspected. It was open, mergeable, based on current `main`, and added one Level server script.
- Inspected `ChestService.server.lua` and confirmed the existing contract:
  - it reads `Workspace.skrzynia` through `getWorldChestTemplate()`;
  - it clones the template only when spawning a chest;
  - it adds the single server-authoritative `OpenPrompt` itself.
- Edit-time Studio check confirmed `ReplicatedStorage.Assets.Chest` was a `Model` and no stale `Workspace.skrzynia` template existed before runtime.
- `Level` Play validation confirmed the bootstrap created `Workspace.skrzynia` from the ReplicatedStorage asset:
  - direct child of `Workspace`;
  - `ChestAssetRuntimeTemplate = true`;
  - `ChestTemplateSource = "ReplicatedStorage.Assets.Chest"`;
  - pivot `Y = -100000`;
  - `5` BaseParts, `0` unanchored parts, `0` CanTouch parts;
  - `0` embedded `BaseScript` instances and `0` embedded `ProximityPrompt` instances.
- Real run startup spawned `342` world chest models under `Workspace.Chests`; the first inspected chest:
  - inherited `ChestAssetRuntimeTemplate = true`;
  - had exactly `1` ProximityPrompt added by `ChestService`;
  - had `0` embedded scripts;
  - was not the generated blockout fallback.
- `git diff --check` passed with only existing LF-to-CRLF working-copy warnings.
- GitHub verification after merge showed:
  - #95 merged at `2026-07-12T19:54:21Z`, merge commit `9bea78694e41cc1ddc5707ea21f27bc18c6811f0`;
  - #96 merged at `2026-07-12T19:54:27Z`, merge commit `00f6c9d889f4bb048d153b5fca7d02cb5de7e833`;
  - #97 merged at `2026-07-12T19:54:33Z`, merge commit `881ca37ba187e81cb5a05557fe064945c2b0c67e`.
- `git ls-remote --heads origin fix/npc-slope-repath-stutter fix/spell-wall-collision feat/use-replicated-chest-model` returned no refs, confirming branch deletion.
- No new `_G`, remote, DataStore path, teleport data, runtime loop, per-chest event connection or gameplay reward API was added.

### Not verified

- Manual player chest opening and reward UI flow were not repeated with keyboard/mouse input.
- Normal, free and recipe/reward chest opening were not manually exercised end-to-end after the model swap.
- Visual grounding/rotation was validated through real spawned chest instances existing from the asset path, not by screenshot/video review.

### Runtime cost and risks

- The new script is a one-time server startup bootstrap. It performs one bounded `WaitForChild` lookup for `Assets`, one bounded lookup for `Chest`, one clone, and one descendant cleanup pass over the chest template.
- Because startup now asserts if `ReplicatedStorage.Assets.Chest` is missing or not a `Model`, a content regression in that asset will fail loudly and `ChestService` would fall back only if the bootstrap is disabled/restored.
- `Workspace.skrzynia` remains a legacy runtime template contract. Future chest refactors should either preserve that contract or move template ownership into `ChestService` deliberately.

### Rollback

- Delete `Level/ServerScriptService/Script/ChestAssetTemplateBootstrap.server.lua` from repo.
- Delete `game.ServerScriptService.Script.ChestAssetTemplateBootstrap` from `Level` Studio.
- Remove any runtime `Workspace.skrzynia` created by the bootstrap, or restart the server after deleting the script.
- `ChestService` will return to its previous generated blockout fallback if no valid `Workspace.skrzynia` model exists.
- Revert this changelog entry and the `CHANGELOG_AI.md` index line.

## 2026-07-12 - Poziom PR #96 blokowanie targetowania czarow przez sciany

### Summary

- Inspected GitHub PR #96, `Prevent targeted spells from firing through walls`, and applied its spell-wall-collision changes locally. The PR was later merged after validation during the PR #97 cleanup step.
- Added shared world line-of-sight helpers to `SpellTargeting`.
- Priority enemy selection now keeps only enemies with clear line of sight from the spell origin.
- Projectile firing now clamps server-side projectile range and VFX range to the first world obstruction.
- Projectile simulation clamps each movement step to the remaining wall-limited range.
- Beam range and VFX length are clamped to the first world obstruction.
- Beam and sustained-zone damage ticks now require line of sight before damaging an enemy.

### Files

- Updated `Level/ServerScriptService/ModuleScript/SpellTargeting.lua`
- Updated `Level/ServerScriptService/ModuleScript/SpellProjectiles.lua`
- Updated `Level/ServerScriptService/ModuleScript/SpellSustained.lua`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Synchronized:
  - `game.ServerScriptService.ModuleScript.SpellTargeting`
  - `game.ServerScriptService.ModuleScript.SpellProjectiles`
  - `game.ServerScriptService.ModuleScript.SpellSustained`
- Final repo/Studio source parity:
  - `SpellTargeting`: length `4313`, hash `931472151`
  - `SpellProjectiles`: length `3899`, hash `720147422`
  - `SpellSustained`: length `4401`, hash `83617495`

### Validation

- GitHub PR #96 metadata and diff were inspected. It was open, mergeable, based on current `main`, and changed three spell modules.
- Fresh `Level` Play server require loaded `SpellTargeting`, `SpellProjectiles` and `SpellSustained` with no module-load errors.
- Isolated wall probe far from authored map geometry confirmed line-of-sight and obstruction distance:
  - no wall: `openLos=true`, unobstructed distance `80.00`
  - test wall at 20 studs: `blockedLos=false`, unobstructed distance `18.90`
- Priority target probe with two registered temporary NPCs confirmed that the blocked enemy was filtered out while the visible enemy was picked:
  - `blockedLos=false`
  - `visibleLos=true`
  - `picked=PR96Visible`
  - visible list contained only `PR96Visible`
- Temporary probe models, wall parts and folders were removed after each test.
- No new runtime loop, per-projectile connection, remote, `_G`, DataStore path, teleport data or public spell API was added.

### Not verified

- Full manual spell matrix from the PR description was not repeated with real player input, authored walls and live spell VFX.
- Piercing projectile behavior against several real enemies with a wall behind them was not manually exercised.
- Beam and sustained-zone live visual length were validated indirectly through clamped server range logic, not by screenshot/video inspection.

### Runtime cost and risks

- Existing target selection, beam ticks and zone ticks now add world raycasts for relevant candidate enemies. This is bounded by existing spell candidate sets and existing tick rates, but a large encounter spell soak should watch raycast cost.
- `SpellTargeting` builds raycast ignore params per LOS/range query so current player characters and dynamic folders are respected. If spell volume grows substantially, cache/batch the ignore list per spell cast or tick.
- Obstruction checks ignore player characters, enemy folders, drops and `SpellVFX`; unusual map blockers outside normal collidable world geometry may need tagging or hierarchy cleanup if they should not block spells.

### Rollback

- Restore the previous `SpellTargeting.lua`, `SpellProjectiles.lua` and `SpellSustained.lua` sources in repo and Studio.
- Revert this changelog entry and the `CHANGELOG_AI.md` index line.
- No remote, DataStore, teleport data or map-object rollback is required.

## 2026-07-12 - Poziom PR #95 ograniczenie falszywych repathow NPC na zboczach

### Summary

- Inspected GitHub PR #95, `Prevent NPC slope repath stutter`, and applied its `NpcNavigationConfig` change locally. The PR was later merged after validation during the PR #97 cleanup step.
- Added `DIRECT_FAILURE_REPATH_DISABLED = math.huge`.
- Set `DirectFailureThreshold = DIRECT_FAILURE_REPATH_DISABLED` for `GroundSmall` and `GroundLarge`.
- Kept `StepFailureThreshold = 2`, so blocked local `ValidateStep` movement still requests pathfinding immediately.
- No scheduler frequency, movement speed, path queue limit, remote, persistent data, teleport data or public API was changed.

### Files

- Updated `Level/ServerScriptService/ModuleScript/NpcNavigationConfig.lua`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Synchronized `game.ServerScriptService.ModuleScript.NpcNavigationConfig`.
- Final repo/Studio source parity: length `4296`, hash `985882022`.

### Validation

- GitHub PR #95 metadata and diff were inspected. It was open, mergeable, and changed one file.
- Fresh `Level` Play server require confirmed:
  - `GroundSmall.DirectFailureThreshold == math.huge`
  - `GroundLarge.DirectFailureThreshold == math.huge`
  - both ground profiles kept `StepFailureThreshold = 2`
  - `Flying.DirectFailureThreshold` remained unset.
- Controlled server probe on real Terrain sample reproduced repeated false direct-probe failures with no path queue growth: `directFailures=4`, `pendingDelta=0`, `pathRequestsDelta=0`, movement `4.963` studs and status `DirectSuspect`.
- Source audit confirmed `NpcGroundNavigation` still calls `queuePath` immediately when `ValidateStep` fails.
- No new `_G`, remote, DataStore path, teleport data, server loop, per-NPC loop or event connection was added.

### Not verified

- Full manual keyboard/player-position test on multiple authored hills and behind real obstacles was not repeated.
- Large mob live-content movement was validated through shared config only, not a physical Ent/Golem hill traversal run.

### Risks

- Direct probe failures can now remain in `DirectSuspect` indefinitely until a local step, stuck timer, path expiry or other route condition requires pathfinding. This is intended for slope false positives but should be watched around unusual terrain gaps.
- If an obstacle is only detectable by the long-range body corridor and every local step remains valid, the NPC may approach closer before pathing around it.

### Rollback

- Restore `GroundSmall.DirectFailureThreshold = 2` and `GroundLarge.DirectFailureThreshold = 2` in `NpcNavigationConfig.lua`, then sync `game.ServerScriptService.ModuleScript.NpcNavigationConfig`.
- Remove `DIRECT_FAILURE_REPATH_DISABLED` if no longer used.
- Revert this changelog entry and the `CHANGELOG_AI.md` index line.

## 2026-07-12 - Poziom/Four Peaks sterowana predkosc animacji biegania z PR #94

### Summary

- Inspected GitHub PR #94, `Keep run animation speed constant`, and applied its locomotion-animation intent locally without merging the PR on GitHub.
- Added `LocomotionAnimationSpeed` as a client `LocalScript` in `StarterCharacterScripts` for both `Level` and `Four Peaks`, so Roblox clones it into the live player character.
- Corrected the PR's original `StarterCharacter` placement after Play showed that the new script existed on the template but did not appear in `Workspace.Sadroacha`.
- Added script attributes `WalkPlaybackSpeed` and `RunPlaybackSpeed`, defaulting to `1`, so playback can be tuned in Studio without changing movement speed, sprint, slide or momentum behavior.
- Attribute changes update active walk/run `AnimationTrack`s during Play. Playback values are clamped to `0..4`.
- The controller uses one lightweight client `RunService.PreAnimation` guard per player character. No NPC loop, remote, persistent data, teleport data, server authority path or gameplay movement value was changed.

### Files

- Added `Level/StarterPlayer/StarterCharacterScripts/LocomotionAnimationSpeed.client.lua`
- Added `Four Peaks/StarterPlayer/StarterCharacterScripts/LocomotionAnimationSpeed.client.lua`
- Removed `Level/StarterPlayer/StarterCharacter/LocomotionAnimationSpeed.client.lua`
- Removed `Four Peaks/StarterPlayer/StarterCharacter/LocomotionAnimationSpeed.client.lua`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active `Level` and `Four Peaks` Studio places were both updated.
- Created `game.StarterPlayer.StarterCharacterScripts.LocomotionAnimationSpeed` in both places.
- Removed the transient PR-path copies from `game.StarterPlayer.StarterCharacter.LocomotionAnimationSpeed`.
- Set edit-time template attributes in both places:
  - `WalkPlaybackSpeed = 1`
  - `RunPlaybackSpeed = 1`
- Final repo/Studio source parity for the new script in both places: length `3341`, hash `302835954`.

### Validation

- GitHub PR #94 metadata and diff were inspected. It was open, mergeable, and changed two files, originally under `StarterCharacter`.
- `Level` Play smoke passed: the live character received `LocomotionAnimationSpeed`; setting runtime `RunPlaybackSpeed = 0.65` forced a test `Run` track from `2.000` back to `0.650`.
- `Four Peaks` Play smoke passed with the same runtime result: `RunPlaybackSpeed = 0.65`, test `Run` track `2.000 -> 0.650`.
- The original PR placement was explicitly checked in Play and confirmed not to clone into the live character in either place.
- No new `_G` dependency, remote, DataStore path, teleport data, server-side loop or per-NPC update was added.

### Not verified

- Physical manual sprint/slide/momentum feel was not tested with keyboard input; the underlying movement controllers were intentionally left unchanged.
- Non-default edit-time attribute values were not committed as repo metadata because this repo mirror stores script source, not Roblox instance attributes. The script initializes missing attributes to safe defaults at runtime.

### Risks

- If a future sync recreates the LocalScript from the `.lua` file only, edit-time Studio attributes may reset to defaults unless the place file preserves them. Runtime still works and recreates missing defaults.
- The clamp prevents extreme playback values above `4`; if a special animation needs a higher multiplier, adjust `MAX_PLAYBACK_SPEED` deliberately.

### Rollback

- Delete `game.StarterPlayer.StarterCharacterScripts.LocomotionAnimationSpeed` from `Level` and `Four Peaks` Studio places.
- Delete `Level/StarterPlayer/StarterCharacterScripts/LocomotionAnimationSpeed.client.lua` and `Four Peaks/StarterPlayer/StarterCharacterScripts/LocomotionAnimationSpeed.client.lua`.
- Revert this changelog entry and the `CHANGELOG_AI.md` index line.

## 2026-07-12 - Poziom slope-aware ground NPC navigation regression fix

### Summary

- Replaced horizontal full-body Terrain checks with surface-sampled, Y-aware body segments. Direct probes now collect the complete surface route first, validate step/drop/slope/layer continuity, then cast separately between consecutive body centers.
- Added precise uncached sampling for the actual movement step (center, front, left and right) and a separate route-only cache with `0.5`-stud X/Z and expected-Y resolution, `0.4`-stud reuse limits and `0.08`-second TTL.
- Added bounded follow-through for non-walkable probe hits and enabled `RespectCanCollide`, so non-collidable visual effects do not become ground while water, forbidden modifiers and missing surfaces retain explicit failure reasons.
- Added direct/path hysteresis: two consecutive long-corridor failures are required before requesting a path, a safe local step continues while a path is pending, and existing waypoints survive the first failed step validation.
- Split horizontal goal sectors from continuity-based surface-layer tracking. Crossing the former `floor(Y / 8)` boundary on a continuous slope no longer invalidates a route.
- Extended disabled-by-default Studio diagnostics and metrics with direct/step results, body hit, surface normal/slope/Y values, failure counters, pending generation, stalled movement and state transitions.
- Kept the central movement scheduler at 12 Hz. No per-NPC loop, connection, remote/API change, `_G` dependency, persistent-data change or map-object migration was added.

### Files

- Added `Level/ServerScriptService/ModuleScript/NpcGroundSurface.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcGroundNavigation.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcNavigationConfig.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcNavigationDebug.lua`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Root cause and validation

- The old corridor box started about `0.4` studs above the current surface and moved horizontally. Rising Roblox Terrain therefore entered the lower face of the box and was treated as a wall. A second voxel-specific case exposed vertical Terrain faces between otherwise legal surface samples and stopped all ground profiles at repeatable map coordinates.
- On the original Terrain regression point `(120, 97.89, -660) -> (121.5, 98.64, -660)`, the old code returned zero movement, `WaitingPath` and one path request. The final code returned `(1.5, 0.746, 0)`, `Direct`, no stalled tick and no path request.
- On the user-visible shared ground route `(-370.42, -328.44) -> (-314.58, -291.96)`, the intermediate implementation reproduced `121` stopped ticks at a vertical voxel face. The final route covered `66.8` studs with `0` stopped ticks, `0` step failures and `0` path requests.
- A real registered Slime completed five ascents and five descents on the existing hill (`10/10`) with `0` stalled ticks, direct failures, step failures and path requests. Each leg ended in `Direct` with direct and step checks both `clear`.
- Existing Terrain safety cases passed: a `64.3`-degree rock face remained blocked, the canyon-edge width probe returned `missing_surface`, a non-collidable effect was skipped, and temporary Play-only bridge tagging kept under-bridge sampling on Terrain (`Y 3.53 -> 3.74`) and over-bridge sampling on the bridge (`Y 86.89 -> 86.72`).
- Twenty-NPC formation tests completed the existing hill ascent with `0` stopped ticks, path requests and step failures. The descent also had `0` stopped ticks and step failures, with four non-serial path requests across 20 formation routes.
- The corrected 100-NPC, 60-second simulated Terrain pass had `0` stopped ticks and `0` step failures. It issued 100 bounded requests (at most one per NPC across six target reversals); 720 synthetic 100-NPC movement iterations took about `2.0` seconds total in the server probe.
- Continuous Terrain movement across the old Y-sector boundary (`12 -> 11`) retained the active waypoints and navigation generation.
- Slow reduced measured movement, a non-elite freeze produced `0` movement, ability lock and pause produced `0` movement, impulse moved the NPC, damage/death callback/despawn passed, ranged LOS accepted clear/rejected blocked, and melee height accepted same-height/rejected a target 10 studs above.
- Fresh Play startup compiled all touched modules. No navigation/NpcService exception appeared; the existing unrelated `Hybrid Terrain Hex Generator:16` toolbar error and `RunStatsHud` re-entrancy error remained.
- Final checksums matched repo and Studio for the four touched/new modules and remained unchanged for `NpcMovement`, `NpcService`, `WorldBounds` and `NpcPresentation`.

### Risks

- Actual steps now use five precise ground probes plus a body cast; legal voxel faces can trigger one raised retry cast. The 100-NPC probe stayed bounded, but a production encounter profiler pass is still useful if the live cap grows substantially.
- Bridge-over/under validation used the existing bridge with a temporary Play-only `NpcWalkable` tag because the current authored bridge has no persistent walkable tag. No map tag was changed in Edit mode.
- The 100-NPC result is a deterministic server simulation of 60 seconds, not a 60-second wall-clock multiplayer soak.

### Rollback

- Restore the previous `NpcGroundNavigation.lua`, `NpcNavigationConfig.lua` and `NpcNavigationDebug.lua` sources in repo and Studio, then delete `NpcGroundSurface.lua` from both.
- No DataStore, TeleportData, remote, attribute schema or map-object rollback is required.

## 2026-07-11 - Poziom kompletna przebudowa nawigacji NPC

### Summary

- Zachowano kinematyczny `NpcService`, publiczne API, istniejące remotes oraz klientową interpolację.
- Dodano profile `GroundSmall`, `GroundLarge` i `Flying`, lokalne warstwy gruntu, objętościowe sprawdzanie korytarzy, ograniczoną kolejkę `PathfindingService`, cache tras, graf air nodes, no-fly zones i przestrzenną separację.
- Scheduler centralny pracuje z ruchem 12 Hz, targetowaniem 3 Hz, formacjami 2 Hz i replikacją 10 Hz. Pathfinding ma limit 2 aktywnych obliczeń, 15 startów/s i 160 oczekujących żądań.
- Targetowanie używa dystansu 3D i wysokości, formacje grupują według rzeczywistego targetu, melee odrzuca nieskuteczną wysokość, a ranged wymaga LOS.
- `WorldBounds` zachowuje tag `Terrain` i dodaje `NpcWalkable`; profile rozpoznają koszty modifierów oraz przejścia `Jump`, `Climb` i `Drop`.
- Naprawiono istniejący helper odłączonych wizualnych części: wyrównuje wizualne części do rootu bez przesuwania samego serwerowego rootu.

### Files

- Added `Level/ServerScriptService/ModuleScript/NpcNavigationConfig.lua`
- Added `Level/ServerScriptService/ModuleScript/NpcGroundNavigation.lua`
- Added `Level/ServerScriptService/ModuleScript/NpcFlightNavigation.lua`
- Added `Level/ServerScriptService/ModuleScript/NpcNavigationDebug.lua`
- Added `docs/NPC_NAVIGATION.md`
- Updated `Level/ServerScriptService/ModuleScript/NpcService.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcMovement.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcTargeting.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcMelee.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcReplication.lua`
- Updated `Level/ServerScriptService/ModuleScript/WorldBounds.lua`
- Updated `Level/ServerScriptService/ModuleScript/MobConfig.lua`
- Updated `Level/ReplicatedStorage/ModuleScripts/NpcShared.lua`
- Updated `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`
- Updated `Level/ServerScriptService/Script/Model/WaveController.lua`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio and validation

- Active place: `Level`; all active changed sources and four new ModuleScripts were synchronized through MCP.
- Compile/startup smoke passed. The only startup exception remained the pre-existing unrelated `Hybrid Terrain Hex Generator:16` toolbar error.
- Controlled Play arenas verified: flat movement, underground emergence, `NpcWalkable`, Roblox Terrain and BasePart wall avoidance without climbing, canyon rejection, valid bridge crossing, under/over bridge layer retention, water avoidance, high-target melee rejection, ranged LOS, flight clearance, 3D flight, obstacle routing through air nodes, no-fly zone avoidance, slow/freeze/impulse/pause/ability lock, damage, death, despawn and two death callbacks.
- Client validation confirmed `NpcBatchEvent`, interpolation of ground/flying models and non-flattened flying orientation (`LookVector.Y = -1` in the controlled vertical-look probe).
- Final isolated flat stress: 100/120 NPC moved with `0` path requests and an empty queue. Approximate movement tick was `2.87 ms` at 100 and `3.24 ms` for the following 120-NPC interval; maximum observed was `8.21 ms`.
- Controlled 500-NPC test moved all 500 with `0` path requests. After direct-probe staggering/LOD the one-second sample averaged `12.10 ms`, max `20.08 ms`, about `7.3k` navigation/combat casts/s and cleaned active count back to `0`.
- No per-NPC runtime loop or connection was added. The only new `task.spawn` is a bounded single path computation owned by the shared queue.

### Not verified

- Natural multiplayer target switching was not available in the single-client MCP session.
- No production map currently contains authored `PathfindingLink` transitions for a full real-content Jump/Climb/Drop traversal test; label filtering and compile/runtime integration were verified through the shared path pipeline.
- The 500-NPC result is a short controlled stress sample, not a full encounter soak. It shows the architecture remains bounded but that 500 simultaneously near-relevant NPCs are above the comfortable 120-NPC runtime target.
- Existing Slime uses procedural presentation, so the client probe validated interpolation/orientation but did not produce an `AnimationTrack`; existing presentation animation code remained intact.

### Risks

- Navigation mesh quality still depends on correctly authored walkable proxies, modifiers and links. Complex visual meshes should not be used directly as navigation collision.
- `GroundLarge` is a practical gameplay agent envelope, not the full decorative bounds of the largest Ent canopy; oversized content may need a dedicated profile and proxy audit.
- At 500 simultaneously relevant NPCs the measured average movement tick was about 12 ms with 20 ms peaks. Distance LOD and stagger prevent the initial all-at-once probe, but a longer 500-NPC soak should precede raising the live cap.
- Full snapshot replication remains at the compatible 10 Hz contract and can become the next scaling bottleneck even though this change did not alter its cadence.

### Rollback

- Restore the previous versions of all updated active Level scripts listed above.
- Delete the four new navigation ModuleScripts from repo and active Studio.
- Remove `docs/NPC_NAVIGATION.md` and revert this changelog/index entry.
- No DataStore, TeleportData, remote name, persistent schema or map object migration is required.

## 2026-07-08 - God Script refactor final audit

### Summary

- Completed the final audit for the God Script refactor plan after closing stages 3C-3F, 4, 5, 6, and 7.
- Confirmed the plan status table now marks stages 0-7 complete in their approved scopes.
- Kept all gameplay balance, remotes, persistent data, teleport data, and public APIs unchanged during the final audit.

### Files

- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Validation

- `git status --short` was clean before final-audit documentation edits.
- Repo grep found no `_G.ApplyDamageToPlayer`, `_G["ApplyDamageToPlayer"]`, or `rawget(_G, "ApplyDamageToPlayer")` in runtime code.
- Repo grep found no final test markers `Stage7`, `Stage4F`, `VirtualInputManager`, `MouseButton1Click:Fire`, `SendMouse`, or `unlikely-filter` in runtime code.
- Studio marker grep in open `Level`, `Four Peaks`, and `Guild` places returned no matches for final test markers.
- `git diff --check` passed during the final audit workflow.

### Remaining Explicit Risks

- Existing non-goal `_G` contracts remain, including drop/chest/shrine/run-ready/debug/error-reporter/spellbook hooks.
- Legacy weapon templates in `ServerStorage` still contain old frame-loop patterns and were not part of this God Script service/controller refactor.
- `InventoryController` remains large as the active owner of inventory layout, card/detail rendering, remotes, and actions; a future renderer/action split should be planned separately.
- Full external teleport/reconnect, true two-client multiplayer party XP, and exhaustive manual UI matrices remain outside MCP validation coverage.

### Rollback

- Roll back by checkpoint commits in reverse order, using the rollback notes recorded under each stage in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.
- For Studio rollbacks, remove the ModuleScripts added by the reverted checkpoint and resync the active script object from repo.

## 2026-07-08 - Four Peaks UI stage 7 completion audit

### Summary

- Marked Stage 7 complete after checkpoints 7A-7G for active `Four Peaks` UI controllers.
- Confirmed `InventoryController` now delegates icon resolution, snapshot entry building, filter/sort, and character preview to explicit sibling ModuleScripts.
- Confirmed `BlacksmithUI` now delegates icon resolution, craft-entry data helpers, and blacksmith scene lifecycle to explicit sibling ModuleScripts.
- Kept remaining `InventoryController` responsibilities as UI layout, detail/card rendering, inventory actions, remotes, input bindings, and snapshot flow; further card/detail renderer extraction would be a separate larger UI renderer refactor.

### Files

- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Architecture

- Final Stage 7 inventory graph: `InventoryController -> InventoryIconResolver`, `InventoryEntryBuilder`, `InventoryFilterSorter`, `InventoryCharacterPreview`.
- Final Stage 7 blacksmith graph: `BlacksmithUI -> BlacksmithIconResolver`, `BlacksmithEntryBuilder`, `BlacksmithSceneController`.
- No gameplay `_G`, remote, persistent data, teleport data, fallback, or per-object Heartbeat was added.
- Existing runtime behavior stayed event-driven; moved blacksmith scene lifecycle kept the existing camera `BindToRenderStep`, and moved inventory preview kept the existing three viewport input connections.

### Validation

- Stage 7 Play tests covered real inventory open through `InventoryGui.ScreenButtonsAction`, snapshot render, search filtering, preview clone, and close toggle.
- Stage 7 Play tests covered real blacksmith open through `OpenBlacksmithUI:FireClient(player)`, blacksmith render, entry-builder smoke, scene open/close lifecycle, prompt restore, character restore, lobby UI restore, and camera FOV restore.
- Repo/Studio parity was recorded for every active script/module touched in Stage 7.
- `git diff --check` passed on the final Stage 7G checkpoint before commit.

### Not Verified

- Full manual inventory matrix for every tab/filter/sort/action combination was not repeated.
- Physical viewport drag, physical blacksmith ProximityPrompt traversal, BackButton click, craft/upgrade request, and all material tooltip combinations were not repeated.

### Risks

- `InventoryController` remains large because it is still the UI layout/card/detail/action owner; any future extraction should be planned as an explicit renderer/action split.
- Missing new sibling modules fail startup with clear asserts, which is intentional but requires repo/Studio parity when syncing UI controllers.

### Rollback

- Roll back the individual Stage 7 commits in reverse order, or restore inline helpers and remove the corresponding sibling ModuleScripts listed in each 7A-7G entry.
- Revert this audit entry and the Stage 7 status line in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-08 - Four Peaks InventoryController stage 7G character preview extraction

### Summary

- Completed Stage 7G for active `game.StarterPlayer.StarterPlayerScripts.InventoryController` in the `Four Peaks` Studio place.
- Added `InventoryCharacterPreview` to own existing character clone preview, preview camera placement, drag/touch rotation state, and preview drag cancellation.
- Kept `InventoryController` as the owner of UI layout, details rendering, inventory actions, snapshot loading, remotes, input bindings, and calls that refresh the preview.
- Preserved remote names, screen button attributes, inventory action payloads, viewport layout, preview camera values, preview clone cleanup, and visual behavior.

### Files

- Added `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryCharacterPreview.lua`
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Created live `game.StarterPlayer.StarterPlayerScripts.InventoryCharacterPreview`.
- Synchronized active `game.StarterPlayer.StarterPlayerScripts.InventoryController`.
- Repo/Studio parity after sync and Play, measured as UTF-8 byte length plus rolling hash:
  - `InventoryController`: length `72317`, hash `710125476`.
  - `InventoryCharacterPreview`: length `3205`, hash `997130305`.

### Architecture

- Moved `refreshCharacterPreview`, preview model state, preview rotation, and viewport/touch input handlers into `InventoryCharacterPreview`.
- `InventoryCharacterPreview` has no ModuleScript dependencies, no remote, no `_G`, and no fallback path.
- Existing preview runtime work moved with ownership: three input connections for the viewport drag/touch behavior.
- No UI hierarchy, remote, action payload, card rendering, filtering/sorting, or inventory balance data was changed.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no `InventoryController`/`InventoryCharacterPreview` errors.
- Opened inventory through the existing `InventoryGui` attribute contract: `ScreenButtonsAction = "open"` and a new `ScreenButtonsNonce`.
- Runtime inspection confirmed `InventoryCharacterPreview` cloned into `PlayerScripts` as a `ModuleScript` and `require` returned a valid table API.
- Preview inspection found `PreviewWorld.PreviewCharacter` with `16` BasePart descendants and a configured `ViewportFrame.CurrentCamera`.
- Render inspection counted `10` image objects with non-empty images, plus `22` buttons, `81` text labels, and `1` search TextBox.
- Closed inventory through the existing `ScreenButtonsAction = "toggle"` path; `InventoryGui.Enabled=false`.
- Clean Play session Output had no `InventoryController`/`InventoryCharacterPreview` errors.

### Not Verified

- Physical drag/touch rotation of the viewport preview was not executed because the MCP Client execution thread cannot synthesize that input.
- Equip, favorite, spell loadout, sell, and every tab/filter/sort combination were not repeated because Stage 7G changed only character preview ownership.

### Risks

- Missing `InventoryCharacterPreview` now fails `InventoryController` startup with a clear assert instead of silently using inline preview helpers.
- Future changes to viewport preview clone/camera/rotation behavior should update `InventoryCharacterPreview`; inventory UI state and actions should remain in `InventoryController` or dedicated UI modules.

### Rollback

- Restore inline preview model state, `refreshCharacterPreview`, `rotatePreview`, and the three viewport input connections in `InventoryController.lua`.
- Remove `InventoryCharacterPreview.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 7G notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-08 - Four Peaks BlacksmithUI stage 7F scene controller extraction

### Summary

- Completed Stage 7F for active `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI` in the `Four Peaks` Studio place.
- Added `BlacksmithSceneController` to own existing blacksmith scene lifecycle: lobby UI hiding, blacksmith camera, local character hiding, movement state snapshot/restore, and blacksmith prompt hiding.
- Kept `BlacksmithUI` as the owner of UI layout, tooltips, category/entry rendering, crafting requests, remotes, input bindings, and the existing open/close order.
- Preserved remote names, crafting action payloads, prompt behavior, camera FOV/offset, movement restore values, character visibility restore, and visual behavior.

### Files

- Added `Four Peaks/StarterPlayer/StarterPlayerScripts/BlacksmithSceneController.lua`
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/BlacksmithUI.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Created live `game.StarterPlayer.StarterPlayerScripts.BlacksmithSceneController`.
- Synchronized active `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`.
- Repo/Studio parity after sync and Play, measured as UTF-8 byte length plus rolling hash:
  - `BlacksmithUI`: length `35187`, hash `419464323`.
  - `BlacksmithSceneController`: length `8781`, hash `892045071`.

### Architecture

- Moved lobby GUI state, camera bind/restore, local character visibility state, movement state snapshot/restore, blacksmith prompt hide/restore, and prompt ancestry checks into `BlacksmithSceneController`.
- `BlacksmithSceneController` has no ModuleScript dependencies, no remote, no `_G`, and no fallback path.
- Existing scene runtime work moved with ownership: one camera `BindToRenderStep` while the UI is open plus the same character/prompt connections as before.
- No UI hierarchy, remote, action payload, card rendering, tooltip behavior, crafting request, or balance data was changed.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no `BlacksmithUI`/`BlacksmithSceneController` errors.
- Opened blacksmith through the existing server remote path with `OpenBlacksmithUI:FireClient(player)`.
- Runtime inspection confirmed `BlacksmithSceneController` cloned into `PlayerScripts` as a `ModuleScript` and `require` returned a valid table API.
- Render inspection counted `44` image objects, all with non-empty images, plus `13` buttons (`12` visible) and `46` text labels.
- During open, the blacksmith prompt was hidden (`1/1` disabled), `16` local character parts were hidden, camera FOV was `45`, and the UI was enabled.
- Closed via the existing `BlacksmithCloseRequested` BindableEvent; after close the UI was disabled, prompt disabled count returned to `0/1`, hidden local character parts returned to `0`, `ScreenGuiButtons.Enabled=true`, and camera FOV restored to `70`.
- Clean Play session Output had no `BlacksmithUI`/`BlacksmithSceneController` errors.

### Not Verified

- Physical BackButton click and physical ProximityPrompt traversal were not repeated; the test used the existing remote open path and existing `BlacksmithCloseRequested` close path.
- Craft/upgrade request and full material tooltip matrix were not repeated because Stage 7F changed only scene lifecycle ownership.

### Risks

- Missing `BlacksmithSceneController` now fails `BlacksmithUI` startup with a clear assert instead of silently using inline lifecycle helpers.
- Future scene lifecycle changes should update `BlacksmithSceneController`; rendering, tooltips, crafting requests, and remotes should remain in `BlacksmithUI` or dedicated UI modules.

### Rollback

- Restore inline scene lifecycle helpers in `BlacksmithUI.lua`: lobby UI hiding/restoring, blacksmith camera start/stop, local character hide/restore, movement snapshot/restore, prompt hide/restore, and prompt ancestry checks.
- Remove `BlacksmithSceneController.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 7F notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-08 - Four Peaks BlacksmithUI stage 7E entry builder extraction

### Summary

- Completed Stage 7E for active `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI` in the `Four Peaks` Studio place.
- Added `BlacksmithEntryBuilder` to own existing blacksmith craft-entry category grouping, selected entry fallback, weapon display/type text, and stat-line building.
- Kept `BlacksmithUI` as the owner of UI layout, blacksmith camera, prompt hiding, character visibility, tooltips, category/entry rendering, crafting requests, remotes, and input bindings.
- Preserved remote names, crafting action payloads, category order, selected-recipe behavior, material display, card templates, camera flow, and visual behavior.

### Files

- Added `Four Peaks/StarterPlayer/StarterPlayerScripts/BlacksmithEntryBuilder.lua`
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/BlacksmithUI.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Created live `game.StarterPlayer.StarterPlayerScripts.BlacksmithEntryBuilder`.
- Synchronized active `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`.
- Repo/Studio parity after sync and Play, measured as UTF-8 byte length plus rolling hash:
  - `BlacksmithUI`: length `42036`, hash `419752749`.
  - `BlacksmithEntryBuilder`: length `3580`, hash `312108726`.

### Architecture

- Moved `buildEntriesByCategory`, selected category/entry fallback, weapon display name, weapon type label, and stat-line construction into `BlacksmithEntryBuilder`.
- `BlacksmithEntryBuilder` has no ModuleScript dependencies, no runtime loop, no connection, no remote, no `_G`, and no fallback path.
- `BlacksmithUI` passes explicit dependencies into the builder: `WeaponConfigs` and `ClampInt`.
- No UI hierarchy, remote, action payload, camera/prompt flow, input binding, or balance data was changed.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no `BlacksmithUI`/`BlacksmithEntryBuilder` errors.
- Opened blacksmith through the existing server remote path with `OpenBlacksmithUI:FireClient(player)`.
- Runtime inspection confirmed `BlacksmithEntryBuilder` cloned into `PlayerScripts` as a `ModuleScript` and `require` returned a valid table API.
- Render inspection counted `44` image objects, all with non-empty images, plus `13` buttons (`12` visible) and `46` text labels.
- Synthetic builder smoke confirmed category grouping `Sword=1`, `Bow=1`, fallback selected category `Sword`, selected recipe `r1`, and stat line `ATK 12`.
- Clean Play session Output had no `BlacksmithUI`/`BlacksmithEntryBuilder` errors.

### Not Verified

- Craft/upgrade request, material tooltip matrix, manual category clicks, and full camera close/restore flow were not repeated because Stage 7E changed only craft-entry data helper ownership.

### Risks

- Missing `BlacksmithEntryBuilder` now fails `BlacksmithUI` startup with a clear assert instead of silently using inline helpers.
- Future changes to blacksmith craft-entry grouping or display text should update `BlacksmithEntryBuilder`; rendering, tooltips, camera, prompt hiding, and remote calls should remain in `BlacksmithUI` or later dedicated UI modules.

### Rollback

- Restore inline `buildEntriesByCategory`, `getSelectedCategoryEntries`, `getSelectedEntry`, `getWeaponDisplayName`, `getWeaponTypeLabel`, and `buildStatLines` in `BlacksmithUI.lua`.
- Remove `BlacksmithEntryBuilder.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 7E notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-08 - Four Peaks InventoryController stage 7D filter sorter extraction

### Summary

- Completed Stage 7D for active `game.StarterPlayer.StarterPlayerScripts.InventoryController` in the `Four Peaks` Studio place.
- Added `InventoryFilterSorter` to own existing inventory search/filter checks and tab-specific sorting for weapons, spells, materials, and codex rows.
- Kept `InventoryController` as the owner of UI state, layout, details rendering, inventory actions, snapshot loading, remotes, input bindings, and the existing rebuild flow.
- Preserved remote names, screen button attributes, inventory action payloads, entry fields, UI hierarchy, current filter labels, sort modes, and visual behavior.

### Files

- Added `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryFilterSorter.lua`
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Created live `game.StarterPlayer.StarterPlayerScripts.InventoryFilterSorter`.
- Synchronized active `game.StarterPlayer.StarterPlayerScripts.InventoryController`.
- Repo/Studio parity after sync and Play, measured as UTF-8 byte length plus rolling hash:
  - `InventoryController`: length `74327`, hash `316184324`.
  - `InventoryFilterSorter`: length `3760`, hash `478229585`.

### Architecture

- Moved `passesFilters` and `sortEntries` behavior into `InventoryFilterSorter`.
- `InventoryFilterSorter` has no ModuleScript dependencies, no runtime loop, no connection, no remote, no `_G`, and no fallback path.
- `InventoryController` passes explicit dependencies into the sorter: rarity order, text match helper, and spell damage helper.
- No UI hierarchy, remote, action payload, snapshot loading, input binding, or balance data was changed.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no UI/filter sorter errors.
- Opened inventory through the existing `InventoryGui` attribute contract: `ScreenButtonsAction = "open"` and a new `ScreenButtonsNonce`.
- Runtime inspection confirmed `InventoryFilterSorter` cloned into `PlayerScripts` as a `ModuleScript` and `require` returned a valid table API.
- Real snapshot render counted `10` image objects with non-empty images, plus `22` buttons, `81` text labels, and `1` search TextBox.
- Search TextBox filtering through the real `Text` changed event reduced the rendered view to `1` image with asset, `10` buttons, and `32` labels; clearing search restored `10`/`22`/`81`.
- Synthetic sorter smoke confirmed weapon filtering/sort (`syntheticWeapons=1`) and spell damage sort (`syntheticSpells=2`).
- Clean Play session Output had no `InventoryController`/`InventoryFilterSorter` errors.

### Not Verified

- Physical click on the sort button was not executed because the MCP Client execution thread lacks `VirtualInputManager` capability.
- Equip, favorite, spell loadout, sell, and every tab/filter/sort combination were not repeated because Stage 7D changed only list filtering and sorting ownership.

### Risks

- Missing `InventoryFilterSorter` now fails `InventoryController` startup with a clear assert instead of silently using inline helpers.
- Future changes to inventory search/filter/sort semantics should update `InventoryFilterSorter`; UI state, rendering, and action handling should stay in `InventoryController` or a later dedicated UI module.

### Rollback

- Restore inline `passesFilters`, `sortEntries`, and the previous `getFilteredEntries` loop in `InventoryController.lua`.
- Remove `InventoryFilterSorter.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 7D notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-08 - Four Peaks InventoryController stage 7C entry builder extraction

### Summary

- Completed Stage 7C for active `game.StarterPlayer.StarterPlayerScripts.InventoryController` in the `Four Peaks` Studio place.
- Added `InventoryEntryBuilder` to own existing inventory snapshot-to-entry transformations for weapons, spells, materials, and codex rows.
- Kept `InventoryController` as the owner of UI state, layout, filters, sorting, details rendering, inventory actions, snapshot loading, remotes, and input bindings.
- Preserved remote names, screen button attributes, inventory action payloads, entry fields, material usage text, spell loadout interpretation, UI hierarchy, filters, sorting, cards, and visual behavior.

### Files

- Added `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryEntryBuilder.lua`
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Created live `game.StarterPlayer.StarterPlayerScripts.InventoryEntryBuilder`.
- Synchronized active `game.StarterPlayer.StarterPlayerScripts.InventoryController`.
- Repo/Studio parity after sync, measured as UTF-8 byte length plus rolling hash:
  - `InventoryController`: length `76784`, hash `270817220`.
  - `InventoryIconResolver`: length `3898`, hash `377823037`.
  - `InventoryEntryBuilder`: length `7480`, hash `197435266`.

### Architecture

- Moved `materialUses`, `getWeaponDef`, weapon entry build, spell entry build, material definition lookup, material entry build, and codex entry build into `InventoryEntryBuilder`.
- `InventoryEntryBuilder` has no ModuleScript dependencies, no runtime loop, no connection, no remote, no `_G`, and no fallback path.
- `InventoryController` passes explicit config dependencies into the builder and still owns `snapshot`, current tab state, filtering, sorting, rendering, and actions.
- No UI hierarchy, remote, action payload, sorting/filtering logic, or input binding was changed.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no `InventoryController`/`InventoryEntryBuilder` errors.
- Opened inventory through the existing `InventoryGui` attribute contract: `ScreenButtonsAction = "open"` and a new `ScreenButtonsNonce`.
- Runtime inspection confirmed `InventoryGui.Enabled=true`, `Modal=true`, `InventoryEntryBuilder` cloned into `PlayerScripts` as a `ModuleScript`, and `require` returned a table.
- Render inspection counted `10` image objects with non-empty images, plus `22` buttons and `81` text labels after real snapshot load.
- Synthetic builder smoke returned counts `weapons=1`, `spells=0`, `materials=0`, `codex=1`.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Manual clicks across every tab/filter/sort combination were not repeated in this checkpoint.
- Equip, favorite, spell loadout, and sell actions were not executed because Stage 7C changed only entry-building ownership.

### Risks

- Missing `InventoryEntryBuilder` now fails `InventoryController` startup with a clear assert instead of silently using inline helpers.
- Future inventory entry-shape changes should update `InventoryEntryBuilder`; UI state/rendering changes should stay in `InventoryController` or later UI modules.

### Rollback

- Restore the moved entry-builder helper functions inline in `InventoryController.lua`.
- Remove `InventoryEntryBuilder.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 7C notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Four Peaks BlacksmithUI stage 7B icon resolver extraction

### Summary

- Completed Stage 7B for active `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI` in the `Four Peaks` Studio place.
- Added `BlacksmithIconResolver` to own existing blacksmith weapon/element icon folder lookup, apostrophe variants, folder cache, and missing-icon warnings.
- Kept `BlacksmithUI` as the owner of UI layout, blacksmith camera, prompt hiding, character visibility, tooltips, category/entry rendering, crafting requests, remotes, and input bindings.
- Preserved remote names, crafting action payloads, prompt behavior, camera flow, movement restore flow, categories, entry templates, icons, and visual behavior.

### Files

- Added `Four Peaks/StarterPlayer/StarterPlayerScripts/BlacksmithIconResolver.lua`
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/BlacksmithUI.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Confirmed active `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI` is a `LocalScript`.
- Confirmed stale repo duplicate `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua` has no corresponding active Studio object and was not edited.
- Created live `game.StarterPlayer.StarterPlayerScripts.BlacksmithIconResolver`.
- Repo/Studio parity after sync, measured as UTF-8 byte length plus rolling hash:
  - `BlacksmithUI`: length `43556`, hash `278059761`.
  - `BlacksmithIconResolver`: length `4372`, hash `278762766`.

### Architecture

- Moved asset reference reads, unique candidate push, typography variants, folder cache, weapon icon resolution, and element icon resolution into `BlacksmithIconResolver`.
- `BlacksmithIconResolver` has no ModuleScript dependencies, no runtime loop, no connection, no remote, no `_G`, and no fallback path.
- `BlacksmithUI` keeps local aliases for `normalizeElementName`, `resetFolderCache`, `resolveWeaponIconAsset`, and `resolveElementIconAsset`.
- No UI hierarchy, remote, crafting payload, camera flow, movement flow, prompt hiding, or input binding was changed.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no `BlacksmithUI`/`BlacksmithIconResolver` errors.
- Opened blacksmith through the existing server remote path with `OpenBlacksmithUI:FireClient(player)`.
- Runtime inspection confirmed `BlacksmithGui.Enabled=true`, `Modal=true`, `BlacksmithIconResolver` cloned into `PlayerScripts` as a `ModuleScript`, and `require` returned a table.
- Render inspection counted `44` image objects, all with non-empty images, plus `13` buttons (`12` visible) and `46` text labels.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Manual clicks across every blacksmith category were not repeated in this checkpoint.
- Craft/upgrade request, material tooltip matrix, and full camera close/restore flow were not executed because Stage 7B changed only icon resolver ownership.

### Risks

- Missing `BlacksmithIconResolver` now fails `BlacksmithUI` startup with a clear assert instead of silently using inline helpers.
- Future blacksmith icon lookup changes should update `BlacksmithIconResolver`; future UI/camera/prompt changes should remain in `BlacksmithUI` or a dedicated later module.

### Rollback

- Restore the moved icon helper functions and icon cache tables inline in `BlacksmithUI.lua`.
- Remove `BlacksmithIconResolver.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 7B notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Four Peaks InventoryController stage 7A icon resolver extraction

### Summary

- Completed Stage 7A for active `game.StarterPlayer.StarterPlayerScripts.InventoryController` in the `Four Peaks` Studio place.
- Added `InventoryIconResolver` to own existing icon folder indexing and asset resolution for weapon, material, spell, and codex inventory cards.
- Kept `InventoryController` as the owner of UI layout, filters, sorting, details rendering, inventory actions, snapshot loading, remotes, and input bindings.
- Preserved remote names, screen button attributes, inventory action payloads, UI hierarchy, filters, sorting, cards, and visual behavior.

### Files

- Added `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryIconResolver.lua`
- Updated `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Confirmed active `game.StarterPlayer.StarterPlayerScripts.InventoryController` is a `LocalScript`.
- Confirmed stale repo duplicate `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua` has no corresponding active Studio object and was not edited.
- Created live `game.StarterPlayer.StarterPlayerScripts.InventoryIconResolver`.
- Repo/Studio parity after sync, measured as UTF-8 byte length plus rolling hash:
  - `InventoryController`: length `83064`, hash `452095484`.
  - `InventoryIconResolver`: length `3898`, hash `377823037`.

### Architecture

- Moved `readImageReference`, image-index cache construction, `resolveImage`, and item-specific image lookup into `InventoryIconResolver`.
- `InventoryIconResolver` has no ModuleScript dependencies, no runtime loop, no connection, no remote, no `_G`, and no fallback path.
- `InventoryController` requires the sibling module with an asserted active path and keeps local `weaponImage`, `materialImage`, `spellImage`, and `codexImage` aliases for existing call sites.
- No UI hierarchy, remote, action payload, sorting/filtering logic, or input binding was changed.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no `InventoryController`/`InventoryIconResolver` errors.
- Opened inventory through the existing `InventoryGui` attribute contract: `ScreenButtonsAction = "open"` and a new `ScreenButtonsNonce`.
- Runtime inspection confirmed `InventoryGui.Enabled=true`, `Modal=true`, `InventoryIconResolver` cloned into `PlayerScripts` as a `ModuleScript`, and `require` returned a table.
- Render inspection counted `10` image objects, all with non-empty images, plus `22` buttons and `81` text labels after real snapshot load.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Manual clicks across every tab/filter/sort combination were not repeated in this checkpoint.
- Equip, favorite, spell loadout, and sell actions were not executed because Stage 7A changed only icon resolver ownership.

### Risks

- Missing `InventoryIconResolver` now fails `InventoryController` startup with a clear assert instead of silently using inline helpers.
- Future icon lookup changes should update `InventoryIconResolver` while keeping `InventoryController` focused on UI state and interaction.

### Rollback

- Restore the moved icon helper functions inline in `InventoryController.lua`.
- Remove `InventoryIconResolver.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 7A notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Guild refactor stage 6 completion audit

### Summary

- Marked Stage 6 as complete after staged Guild refactors 6A-6E.
- Confirmed active `Guild` place keeps `GuildPlace`, `GuildPlaceRemotes`, and `GuildPlaceLocations` in repo/Studio parity.
- Confirmed active `Four Peaks` place keeps `GuildService`, `GuildRecordState`, and `GuildUpdateBroadcaster` in repo/Studio parity.
- Confirmed both main Guild runtime scripts are now below the 1200-line hard review threshold while preserving public API, remote names, DataStore keys, teleport data, persistent data shape, and gameplay economics.

### Files

- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place checks:
  - `Guild`: `GuildPlace` length `32813`, hash `312367508`; `GuildPlaceRemotes` length `1923`, hash `248263159`; `GuildPlaceLocations` length `11559`, hash `420695235`.
  - `Four Peaks`: `GuildService` length `36581`, hash `45412315`; `GuildRecordState` length `9763`, hash `53470018`; `GuildUpdateBroadcaster` length `1721`, hash `304481289`.

### Architecture

- Final Stage 6 split:
  - `GuildPlaceRemotes`: active Guild place remote factory.
  - `GuildPlaceLocations`: active Guild place location config/status/model/prompt builder.
  - `GuildRecordState`: Four Peaks guild record/state sanitization helpers.
  - `GuildUpdateBroadcaster`: Four Peaks `GuildUpdated` remote fanout.
- `GuildPlace` remains owner of Guild place auth, treasury callbacks, return teleport, and remote handlers.
- `GuildService` remains owner of Four Peaks persistence, membership, join/invite/leave/kick/disband, treasury donate/upgrade, tasks, teleport, and public API.
- No new gameplay `_G`, frame loop, per-object connection, remotes, DataStore keys, teleport data fields, fallback path, or require cycle was introduced.

### Validation

- Repo audit found no new `_G` in active Guild modules.
- Repo audit found no new frame-loop usage in active Guild modules.
- Connection sites after Stage 6 are the existing player/remote/prompt bindings: `GuildPlace` player added/request return/player removing, `GuildPlaceLocations` prompt trigger, and `GuildService` player removing.
- Final line counts: `GuildPlace.server.lua` `1063`, `GuildService.lua` `1159`.
- Prior checkpoint Play smokes covered `Guild` startup/location prompts and `Four Peaks` `GuildService.GetState`, record state, and update broadcast module loading.

### Not Verified

- Full guild create/join/invite/leave/kick/disband flows were not repeated end-to-end during the completion audit.
- Treasury deposit/spend, upgrades, task progress, and teleport to/from guild castle remain covered only by smoke/no-error validation in this stage.

### Risks

- `GuildService` remains a broad owner of persistence and gameplay-facing guild flows, though it is now below the 1200-line threshold.
- Future changes to persistent guild record defaults should update `GuildRecordState`; future `GuildUpdated` payload/fanout changes should update `GuildUpdateBroadcaster`.

### Rollback

- Revert Stage 6 checkpoints 6E, 6D, 6C, 6B, and 6A in reverse order.
- Remove the corresponding live Studio modules if rolling back in Studio.
- Run Play smoke in both `Guild` and `Four Peaks` after rollback.

## 2026-07-07 - Four Peaks GuildService stage 6E update broadcast extraction

### Summary

- Completed Stage 6E for active `game.ServerScriptService.ModuleScript.GuildService` in the `Four Peaks` Studio place.
- Added `GuildUpdateBroadcaster` to own the existing `GuildUpdated` RemoteEvent lookup/creation and guild update fanout.
- Kept `GuildService` as the owner of DataStore load/save, directory updates, PlayerData membership sync, join/invite/leave/kick/disband flows, treasury donation and upgrade behavior, task progress, teleport, and public API.
- Preserved public API, remote name `GuildUpdated`, broadcast payload fields, DataStore names/keys, teleport data, guild treasury math, role rules, task progress rules, and player data shape.

### Files

- Added `Four Peaks/ServerScriptService/ModuleScript/GuildUpdateBroadcaster.lua`
- Updated `Four Peaks/ServerScriptService/ModuleScript/GuildService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Created live `game.ServerScriptService.ModuleScript.GuildUpdateBroadcaster`.
- Synchronized active `game.ServerScriptService.ModuleScript.GuildService`.
- Repo/Studio parity after sync, measured as UTF-8 byte length plus rolling hash:
  - `GuildService`: length `36581`, hash `45412315`.
  - `GuildRecordState`: length `9763`, hash `53470018`.
  - `GuildUpdateBroadcaster`: length `1721`, hash `304481289`.

### Architecture

- Moved `getGuildUpdatedRemote`, `fireGuildUpdated`, and `broadcastGuildUpdated` into `GuildUpdateBroadcaster`.
- `GuildUpdateBroadcaster` has no ModuleScript dependencies, no runtime loop, no connection, no `_G`, and no fallback path.
- `GuildService` keeps a local `broadcastGuildUpdated` alias for existing call sites.
- No new remotes, DataStore keys, teleport data fields, runtime loops, schedulers, gameplay globals, or require cycles were added.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no `GuildService`/`GuildUpdateBroadcaster` errors.
- Runtime smoke required `GuildService` and `GuildUpdateBroadcaster`; `GuildService.GetState` returned `Success=true` with `Config` and `PlayerResources`.
- Synthetic `GuildUpdateBroadcaster.Broadcast` confirmed `ReplicatedStorage.RemoteEvents.GuildUpdated` remains a `RemoteEvent`.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Guild create/join/invite/leave/kick/disband flows were not repeated in this checkpoint.
- Treasury deposit/spend, upgrades, task progress, and teleport to guild castle were not executed because Stage 6E changed only broadcast ownership and avoided DataStore write flows in smoke.

### Risks

- Future changes to guild update payload or fanout should update `GuildUpdateBroadcaster` instead of `GuildService`.
- The smoke test verified the broadcaster directly with a synthetic guild record; real mutation call sites still need broader guild-flow tests in a later validation checkpoint.

### Rollback

- Restore `getGuildUpdatedRemote`, `fireGuildUpdated`, and `broadcastGuildUpdated` inline in `GuildService.lua`.
- Remove `GuildUpdateBroadcaster.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 6E notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Four Peaks GuildService stage 6D record state extraction

### Summary

- Completed Stage 6D for active `game.ServerScriptService.ModuleScript.GuildService` in the `Four Peaks` Studio place.
- Added `GuildRecordState` to own the existing guild record normalization/sanitization helpers, treasury state helpers, task/upgrades defaults, role rebuild, and treasury history helpers.
- Kept `GuildService` as the owner of DataStore load/save, directory updates, PlayerData membership sync, join/invite/leave/kick/disband flows, treasury donation and upgrade behavior, task progress, teleport, remotes, and public API.
- Preserved public API, remote names, DataStore names/keys, teleport data, guild treasury math, role rules, task progress rules, and player data shape.

### Files

- Added `Four Peaks/ServerScriptService/ModuleScript/GuildRecordState.lua`
- Updated `Four Peaks/ServerScriptService/ModuleScript/GuildService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Four Peaks`.
- Created live `game.ServerScriptService.ModuleScript.GuildRecordState`.
- Synchronized active `game.ServerScriptService.ModuleScript.GuildService`.
- Repo/Studio parity after sync, measured as UTF-8 byte length plus rolling hash:
  - `GuildService`: length `37970`, hash `716157583`.
  - `GuildRecordState`: length `9763`, hash `53470018`.

### Architecture

- Moved `clampInt`, `copyMap`, name/privacy/member-key helpers, treasury sanitization/history helpers, task/upgrades default builders, member/request sanitization, role rebuild, and guild record sanitization into `GuildRecordState`.
- `GuildRecordState` depends only on `ReplicatedStorage.ModuleScripts.GuildConfig`; it has no runtime loop, no connection, no remotes, no `_G`, and no fallback path.
- `GuildService` keeps local aliases for the moved helpers so internal call sites and return values remain unchanged.
- No new remotes, DataStore keys, teleport data fields, runtime loops, schedulers, gameplay globals, or require cycles were added.

### Validation

- Studio Play in `Four Peaks` started successfully with normal lobby ready logs and no `GuildService`/`GuildRecordState` errors.
- Runtime smoke required `GuildService` and `GuildRecordState`; `GuildService.GetState` returned `Success=true` with `Config` and `PlayerResources`.
- Public API smoke confirmed `CreateGuild`, `Donate`, and `TeleportToCastle` remain functions.
- Synthetic `GuildRecordState.SanitizeGuildRecord` preserved normalized name `Test Guild`, privacy `Private`, `1` member, owner role `Owner`, level `1`, and treasury Silver `5`.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Guild create/join/invite/leave/kick/disband flows were not repeated in this checkpoint.
- Treasury deposit/spend, upgrades, task progress, and teleport to guild castle were not executed because Stage 6D changed only helper ownership and avoided DataStore write flows in smoke.

### Risks

- `GuildRecordState` now owns record-shape defaults; future changes to persistent guild record shape should update this module and keep `GuildService` call sites read-only.
- `GuildService` remains above 1200 lines and still owns persistence, membership, treasury, upgrades, tasks, teleport, and remotes; further staged extraction is still required.

### Rollback

- Restore the moved record/state helper functions inline in `GuildService.lua`.
- Remove `GuildRecordState.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 6D notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Gildia GuildPlace stage 6C location builder extraction

### Summary

- Completed Stage 6C for active `game.ServerScriptService.Script.GuildPlace` in the `Guild` Studio place.
- Extended `GuildPlaceLocations` to own physical guild location model creation, billboard creation, and existing prompt creation/binding.
- Kept `GuildPlace` as the owner of guild authorization, DataStore profile/guild access, treasury deposit/spend, location-open business callback, return teleport, and remote callback handlers.
- Preserved location ids, positions, sizes, colors, names, prompt attributes, remote names, persistent data, teleport data, and treasury behavior.

### Files

- Updated `Guild/ServerScriptService/ModuleScript/GuildPlaceLocations.lua`
- Updated `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Guild`.
- Synchronized active `game.ServerScriptService.Script.GuildPlace`.
- Synchronized active `game.ServerScriptService.ModuleScript.GuildPlaceLocations`.
- Repo/Studio parity after sync, measured as UTF-8 byte length plus rolling hash:
  - `GuildPlace`: length `32813`, hash `312367508`.
  - `GuildPlaceRemotes`: length `1923`, hash `248263159`.
  - `GuildPlaceLocations`: length `11559`, hash `420695235`.

### Architecture

- Moved `getFlatDirectionToCenter`, `ensurePart`, `ensureLocationBillboard`, `ensureLocationPrompt`, `ensureGuildLocations`, and prompt binding from `GuildPlace` into `GuildPlaceLocations`.
- `GuildPlaceLocations` still has no `require()` dependencies, no frame loop, no `_G`, and no fallback path.
- Existing `ProximityPrompt.Triggered` bindings moved ownership from `GuildPlace` to `GuildPlaceLocations` without adding new prompt count or changing the callback target.
- No remote names, DataStore keys, teleport data fields, runtime loops, schedulers, or require cycles were added.

### Validation

- Studio Play in `Guild` started successfully and logged `[GuildPlace] Ready`.
- Runtime inspection in Play confirmed `7` models under `Workspace.GuildLocations`, `7` `GuildLocationPrompt` prompts, preserved `GuildLocationId`, expected status attributes, and billboard labels including `Skarbiec`, `Łowiska`, and `Sala chwały`.
- Output contained only `[GuildPlace] Ready` during the smoke test.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Guild create/join/invite/leave/kick flows were not repeated in this checkpoint.
- Treasury deposit/spend, upgrades, task progress, and return teleport were not executed because Stage 6C changed only location model/prompt ownership.

### Risks

- `GuildPlaceLocations` now owns existing prompt binding, so future location UI changes should update this module instead of `GuildPlace`.
- `GuildPlace` remains a large script with DataStore, treasury, authorization, and teleport responsibilities; those are left for later staged checkpoints.

### Rollback

- Restore inline location model/prompt builder helpers and `bindGuildLocationPrompts` loop in `GuildPlace.server.lua`.
- Revert `GuildPlaceLocations.lua` to the Stage 6B config/status/state-only version.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 6C notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Gildia GuildPlace stage 6B location config extraction

### Summary

- Completed Stage 6B for active `game.ServerScriptService.Script.GuildPlace` in the `Guild` Studio place.
- Added `GuildPlaceLocations` to own guild location definitions, id lookup, status calculation, and castle-state location list construction.
- Kept `GuildPlace` as the owner of guild authorization, DataStore profile/guild access, treasury deposit/spend, physical location model/prompt construction, return teleport, and remote callback handlers.
- Preserved location ids, positions, sizes, colors, names, descriptions, hints, statuses, prompt attributes, remote names, persistent data, and teleport data.

### Files

- Added `Guild/ServerScriptService/ModuleScript/GuildPlaceLocations.lua`
- Updated `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Guild`.
- Created live `game.ServerScriptService.ModuleScript.GuildPlaceLocations`.
- Synchronized active `game.ServerScriptService.Script.GuildPlace`.
- Repo/Studio parity after sync, measured as UTF-8 byte length plus rolling hash:
  - `GuildPlace`: length `38838`, hash `189744719`.
  - `GuildPlaceRemotes`: length `1923`, hash `248263159`.
  - `GuildPlaceLocations`: length `5273`, hash `950361888`.

### Architecture

- Moved static guild location definitions and status/list helpers from `GuildPlace` into `GuildPlaceLocations`.
- `GuildPlaceLocations` has no `require()` dependencies, no runtime loop, no connection, and no `_G`.
- `GuildPlace` still owns physical model construction and prompt binding for this checkpoint.
- No remote names, DataStore keys, teleport data fields, runtime loops, schedulers, connections, or require cycles were added.

### Validation

- Studio inspection confirmed `GuildPlaceLocations` returns `7` definitions, `Treasury` status `Open`, `Dojo` status `Coming soon`, and preserved label text `Łowiska`.
- Studio Play in `Guild` started successfully and logged `[GuildPlace] Ready`.
- Runtime inspection in Play confirmed `7` models under `Workspace.GuildLocations`, each with `GuildLocationPrompt`, preserved `GuildLocationId`, expected status attributes, and billboard labels including `Skarbiec`, `Łowiska`, and `Sala chwały`.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Guild create/join/invite/leave/kick flows were not repeated in this checkpoint.
- Treasury deposit/spend, upgrades, task progress, and return teleport were not executed because Stage 6B changed only location config ownership.

### Risks

- `GuildPlace` still owns physical location model creation and prompt binding; this checkpoint intentionally did not move connection ownership.
- `GuildPlaceLocations.GetDefinitions()` returns the shared static definition table, matching the previous inline behavior but not protecting callers from mutation.

### Rollback

- Restore inline `LOCATION_STATUS`, `GUILD_LOCATION_DEFINITIONS`, `GUILD_LOCATION_BY_ID`, `getLocationStatus`, and `buildGuildLocationState` in `GuildPlace.server.lua`.
- Remove `GuildPlaceLocations.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 6B notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Gildia GuildPlace stage 6A remote factory extraction

### Summary

- Completed Stage 6A for active `game.ServerScriptService.Script.GuildPlace` in the `Guild` Studio place.
- Added `GuildPlaceRemotes` to own guild place RemoteEvent/RemoteFunction creation.
- Kept `GuildPlace` as the owner of guild authorization, DataStore profile/guild access, treasury deposit/spend, location prompts, return teleport, and remote callback handlers.
- Preserved remote names, persistent data, teleport data, treasury math, authorization checks, location objects, and client contracts.

### Files

- Added `Guild/ServerScriptService/ModuleScript/GuildPlaceRemotes.lua`
- Updated `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Guild`.
- Created live `game.ServerScriptService.ModuleScript.GuildPlaceRemotes`.
- Synchronized active `game.ServerScriptService.Script.GuildPlace`.
- Repo/Studio parity after sync, measured as UTF-8 byte length plus rolling hash:
  - `GuildPlace`: length `43272`, hash `661975836`.
  - `GuildPlaceRemotes`: length `1923`, hash `248263159`.

### Architecture

- Moved remote folder and remote instance creation from `GuildPlace` into `GuildPlaceRemotes.EnsureAll`.
- `GuildPlaceRemotes` has no `require()` dependencies, no runtime loop, no connection, and no `_G`.
- `GuildPlace` now explicitly requires `GuildPlaceRemotes` through an asserted `ServerScriptService.ModuleScript` lookup.
- No new remotes, fallback paths, DataStore keys, teleport data fields, runtime loops, schedulers, or require cycles were added.

### Validation

- Studio inspection confirmed all existing guild remotes still exist with the same classes:
  - `RequestLobbyReturn`, `LobbyReturnStatus`, `GuildLocationOpened`, `GuildTreasuryUpdated` as `RemoteEvent`.
  - `GetGuildCastleState`, `GetTreasury`, `DepositToTreasury`, `SpendFromTreasury` as `RemoteFunction`.
- Studio Play in `Guild` started successfully and logged `[GuildPlace] Ready`.
- Runtime inspection in Play confirmed the same remote classes under `ReplicatedStorage.RemoteEvents` and `ReplicatedStorage.RemoteFunctions`.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Guild create/join/invite/leave/kick flows were not repeated in this checkpoint.
- Treasury deposit/spend, upgrades, task progress, and return teleport were not executed because Stage 6A changed only remote construction.

### Risks

- `GuildPlace` remains a large script with DataStore, treasury, location, and teleport responsibilities; those are left for later staged checkpoints.
- Missing `GuildPlaceRemotes` now fails startup with a clear assert instead of silently creating remotes inline.

### Rollback

- Restore the inline remote helper functions and remote assignments in `GuildPlace.server.lua`.
- Remove `GuildPlaceRemotes.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 6A notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom RunStatsService stage 5A unused global shim removal

### Summary

- Completed Stage 5A for active `game.ServerScriptService.ModuleScript.Stats.RunStatsService`.
- Removed unused global writers `_G.GetRunStat` and `_G.HealRunPlayer`.
- Kept public module API `RunStatsService.GetStat` and `RunStatsService.HealPlayer` unchanged.
- Audited `ShrineService` and left `_G.PrepareRunShrines` untouched because it remains an active `RunReadyGate` contract.

### Files

- Updated `Level/ServerScriptService/ModuleScript/Stats/RunStatsService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Synchronized active `game.ServerScriptService.ModuleScript.Stats.RunStatsService`.
- Repo/Studio parity after sync:
  - `RunStatsService`: length `14191`, hash `403943297`.
- Studio grep found no `_G.GetRunStat`, `_G.HealRunPlayer`, or `Stage5A` markers after cleanup.

### Architecture

- Removed two unused gameplay global shims from `RunStatsService`.
- Did not change `DamageService`, `RunDefenseState`, damage order, HP regen, shield/overheal math, thorns callback registration, public module functions, remotes, persistent data, attributes, or balance.
- Did not change `ShrineService`; `_G.PrepareRunShrines` is still required by `RunReadyGate`.
- No new `_G`, fallback, runtime loop, scheduler, connection, remote, bootstrap, or require cycle was added.

### Validation

- Repo grep and Studio grep before removal found no active caller of `_G.GetRunStat` or `_G.HealRunPlayer`.
- Studio Play startup loaded `RunStatsService`, `DamageService`, and `NpcService` without missing-global errors.
- Runtime smoke required `RunStatsService` directly and confirmed `_G.GetRunStat=false`, `_G.HealRunPlayer=false`, public `GetStat`/`HealPlayer` available.
- `RunStatsService.HealPlayer` healed `5` HP (`57 -> 62`).
- `DamageService.Apply` with a registered NPC attacker dealt `6` HP to the player (`62 -> 56`) and thorns callback damaged the NPC (`1000 -> 996`).
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Full natural long-run with chest item modifiers and shrine completion was not repeated in this checkpoint.
- Multiplayer stat propagation was not available through current MCP Play.

### Risks

- Unknown out-of-repo tools that called `_G.GetRunStat` or `_G.HealRunPlayer` would now need to use `RunStatsService` directly, but repo and active Studio grep found no runtime callers.
- `ShrineService` still exposes `_G.PrepareRunShrines`; this remains intentional until the world-preparation globals are migrated together.

### Rollback

- Restore the two final global assignments in `RunStatsService.lua`:
  - `_G.GetRunStat = function(player, statName) return RunStatsService.GetStat(player, statName) end`
  - `_G.HealRunPlayer = function(player, amount) return RunStatsService.HealPlayer(player, amount) end`
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 5A notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom SpellService stage 4F sustained spell loop extraction

### Summary

- Completed Stage 4F for active `game.ServerScriptService.Script.SpellService`.
- Added `SpellSustained` as the owner of existing zone and beam sustained tick loops.
- Kept `SpellService` as the owner of spell cooldowns, archetype selection, player state, main damage call, `PlayerData`/weapon multipliers, and the single global spell `Heartbeat`.
- Preserved spell damage, cooldowns, tick rates, durations, target selection, VFX payload shape, remotes, persistent data, attributes, and balance.

### Files

- Added `Level/ServerScriptService/ModuleScript/SpellSustained.lua`
- Updated `Level/ServerScriptService/Script/SpellService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.SpellSustained`.
- Synchronized active `game.ServerScriptService.Script.SpellService`.
- Repo/Studio parity after sync:
  - `SpellService`: length `17984`, hash `776218815`.
  - `SpellSustained`: length `4093`, hash `41753248`.
  - `SpellVisuals`: length `2543`, hash `314798517`.
  - `SpellEffects`: length `4120`, hash `920148350`.
  - `SpellProjectiles`: length `3187`, hash `229091311`.
  - `SpellTargeting`: length `2333`, hash `375152092`.
- Temporary `Stage4FSpellSustainedHarness`, heartbeat probe, `ServerStorage.Stage4FResult`, and target folder were removed; Studio grep and repo grep found no `Stage4F` markers.

### Architecture

- Moved the existing `ScorchField`/zone-style `task.spawn` tick loop out of `SpellService` into `SpellSustained.RunZone`.
- Moved the existing `ThunderRay`/beam-style `task.spawn` tick loop out of `SpellService` into `SpellSustained.RunBeam`.
- `SpellSustained` uses callbacks only and has no module `require()`.
- `SpellService` now has no `task.spawn`; it still owns exactly one global `RunService.Heartbeat`.
- No new `_G`, remotes, fallback path, bootstrap, require cycle, scheduler, per-object heartbeat, or connection was added.

### Validation

- Static audit showed `SpellService` now has `0` `task.spawn` calls and still has one global spell `Heartbeat`.
- `SpellSustained` contains the two moved `task.spawn` tick loops with the same `tickRate`, `duration`, damage math, and `isPlayerRunActive` stop condition as before.
- Studio Play startup reached normal `SpellService` ready logs with no `SpellSustained` loading errors.
- A temporary Studio-only server Script harness ran in the same server VM as live `SpellService`.
- Real `ScorchField` called `SpellSustained.RunZone`, emitted a `ring` payload, and dealt zone direct hits through `NpcService.ApplyDamage`: `zoneInvoked=1`, `zoneDirectHits=8`, `tickRate=0.45`, `duration=3.672`.
- Real `ThunderRay` called `SpellSustained.RunBeam`, emitted a `beam` payload, and dealt beam direct hits through `NpcService.ApplyDamage`: `beamInvoked=1`, `beamDirectHits=13`, `tickRate=0.16`, `duration=1.537`, `range=54`, `width=4.32`.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Full natural run with random spell acquisition was not repeated in this checkpoint.
- Multiplayer spell behavior was not available through current MCP Play.
- Client visual rendering was not inspected visually; this checkpoint validated server spell flow and VFX dispatch for real zone/beam call sites.

### Risks

- The moved loops still create one task per active zone or beam cast, matching pre-refactor behavior. This checkpoint does not centralize sustained spell ticking.
- The temporary harness had to set `PauseState=false` during the test because the Play session started paused; it restored the previous value during cleanup.

### Rollback

- Restore inline `runZone` and `runBeam` task loops in `SpellService.lua` from the commit before Stage 4F.
- Remove `SpellSustained.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 4F notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom SpellService stage 4E server visual dead code cleanup

### Summary

- Completed Stage 4E for active `game.ServerScriptService.Script.SpellService`.
- Removed unused server-side spell visual constructors from `SpellService` after audit confirmed their only active call sites live in `SpellVFXClient`.
- Kept `SpellVisuals` as the server VFX dispatch owner and left `SpellVFXClient` visual construction untouched.
- Preserved spell damage, cooldowns, tick rates, target selection, payload shape, remotes, persistent data, attributes, and balance.

### Files

- Updated `Level/ServerScriptService/Script/SpellService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Synchronized active `game.ServerScriptService.Script.SpellService`.
- Repo/Studio parity after cleanup:
  - `SpellService`: normalized length `19498`, hash `431803948`.
  - `SpellVisuals`: normalized length `2543`, hash `314798517`.
  - `SpellEffects`: normalized length `4120`, hash `920148350`.
  - `SpellProjectiles`: normalized length `3187`, hash `229091311`.
  - `SpellTargeting`: normalized length `2333`, hash `375152092`.
- Temporary `Stage4ESpellSmokeHarness` and `ServerStorage.Stage4EResult` were removed; Studio grep and repo grep found no `Stage4E` markers.

### Architecture

- Removed dead local definitions from `SpellService`: `spawnImpactVisual`, `spawnRingVisual`, `spawnNovaVisual`, `spawnBeamVisual`, `createProjectileVisual`, `destroyProjectileVisual`, and their private server-side primitive/tween/emitter helpers.
- Kept `workspace.SpellVFX` folder creation to preserve object presence.
- No new `_G`, remotes, fallback path, bootstrap, require cycle, runtime loop, scheduler, or connection was added.

### Validation

- Static repo audit showed each removed server-side constructor had only its own definition in `SpellService`; active visual call sites remain in `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`.
- Studio Play startup reached normal `SpellService` ready logs with no missing helper errors.
- A temporary Studio-only server Script harness ran in the same server VM as live `SpellService`.
- Real `VoltNeedle` still produced `projectile` and `impact` payloads.
- Real `ScorchField` still produced a `ring` payload.
- Real `ThunderRay` still produced a `beam` payload.
- Captured summary: `ok=true`, `damageCount=25`, `damageDealt=86`.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Full natural run with random spell acquisition was not repeated in this checkpoint.
- Multiplayer spell VFX was not available through current MCP Play.
- Client visual rendering was not inspected visually; this checkpoint validated server dispatch still reaches live call sites after dead code removal.

### Risks

- `SpellService` still owns beam/zone task loops; those remain for a separate checkpoint if the stage continues.
- Visual rendering behavior still depends on `SpellVFXClient`, which was not changed in this checkpoint.

### Rollback

- Restore the removed server-side visual constructors/helpers from the commit before Stage 4E.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 4E notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom SpellService stage 4D visual dispatch extraction

### Summary

- Completed Stage 4D for active `game.ServerScriptService.Script.SpellService`.
- Added `SpellVisuals` for server-side spell VFX payload extraction, transient `SpellVFXEvent:FireAllClients`, `serverTime`, and orbit `FireClient` state sync.
- Kept `SpellService` as the owner of spell archetype flow, cooldowns, main damage call, `PlayerData`/weapon multipliers, and the single global spell `Heartbeat`.
- Preserved spell damage, cooldowns, tick rates, target selection, VFX payload shape, remotes, persistent data, attributes, and balance.

### Files

- Added `Level/ServerScriptService/ModuleScript/SpellVisuals.lua`
- Updated `Level/ServerScriptService/Script/SpellService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.SpellVisuals`.
- Synchronized active `game.ServerScriptService.Script.SpellService` to require/configure `SpellVisuals` and delegate VFX broadcast/orbit sync.
- Repo/Studio parity after cleanup:
  - `SpellService`: normalized length `42309`, hash `706239663`.
  - `SpellVisuals`: normalized length `2543`, hash `314798517`.
  - `SpellEffects`: normalized length `4120`, hash `920148350`.
  - `SpellProjectiles`: normalized length `3187`, hash `229091311`.
  - `SpellTargeting`: normalized length `2333`, hash `375152092`.
- Temporary `Stage4DSpellVisualsHarness` and `ServerStorage.Stage4DResult` were removed; Studio grep and repo grep found no `Stage4D` markers.

### Architecture

- New graph: `SpellService -> SpellVisuals`, `SpellService -> SpellEffects`, `SpellService -> SpellProjectiles`, `SpellService -> SpellTargeting`, `SpellService -> NpcService`, `SpellService -> PlayerData`, `SpellService -> SpellDefinitions`, `SpellService -> WeaponConfigs`; `SpellTargeting -> NpcService`.
- `SpellVisuals` requires no modules and owns only spell VFX dispatch helpers.
- No new `_G`, remotes, fallback path, bootstrap, require cycle, runtime loop, scheduler, or connection was added.
- Legacy unused server-side visual constructors in `SpellService` were left untouched for a separate audit.

### Validation

- Studio Play startup reached normal `SpellService` ready logs with no `SpellVisuals` or missing-module errors.
- A temporary Studio-only server Script harness ran in the same server VM as live `SpellService` and wrapped `SpellVisuals.Broadcast`, `SpellVisuals.SyncOrbit`, and `NpcService.ApplyDamage` while real spell flow ran through `SpellService`.
- Real `VoltNeedle` produced `projectile` and `impact` payloads.
- Real `FlameBurst` produced a `nova` payload.
- Real `ScorchField` produced a `ring` payload.
- Real `ThunderRay` produced a `beam` payload.
- Real `EmberOrbit` produced orbit enable and disable syncs through `SpellVisuals.SyncOrbit`.
- Captured summary: `ok=true`, `damageCount=58`, `damageDealt=716`, `syncEnabled=169`, `syncDisabled=1`; all captured transient payloads had `serverTime`.
- Output showed no `SpellService`, `SpellVisuals`, `SpellEffects`, `SpellProjectiles`, `SpellTargeting`, or `NpcService` errors. Existing unrelated Studio output remained from `Hybrid Terrain Hex Generator`, `ErrorReporter`, and missing TeleportData in Play Solo.
- `git diff --check` passed with only existing CRLF warnings.

### Not Verified

- Full natural run with random spell acquisition was not repeated in this checkpoint.
- Multiplayer spell VFX was not available through current MCP Play.
- Client visual rendering was not inspected visually; this checkpoint validated server dispatch and payload shape.

### Risks

- `SpellVisuals` is configured by `SpellService`; direct use before `Configure` fails with an explicit assert.
- Beam/zone task loops and legacy unused server-side visual constructor functions remain in `SpellService` for later audit/checkpoints.

### Rollback

- Restore inline `extractVisualStats`, `broadcastSpellVisual`, `syncOrbitVFX`, and orbit stop helper behavior in `SpellService.lua`.
- Remove `Level/ServerScriptService/ModuleScript/SpellVisuals.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 4D notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom SpellService stage 4C effects extraction

### Summary

- Completed Stage 4C for active `game.ServerScriptService.Script.SpellService`.
- Added `SpellEffects` for target damage multipliers, vulnerability multiplier, DOT, slow, stun/freeze, vulnerability attributes, knockback, pull, and pullStrength application.
- Kept `SpellService` as the owner of spell archetype flow, cooldowns, main damage call, VFX dispatch/visual construction, and `SpellVFXEvent`.
- Preserved effect formulas, DOT tick cadence, damage, speed, range, cooldown, tick rate, remotes, persistent data, attributes, and balance.

### Files

- Added `Level/ServerScriptService/ModuleScript/SpellEffects.lua`
- Updated `Level/ServerScriptService/Script/SpellService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.SpellEffects`.
- Synchronized active `game.ServerScriptService.Script.SpellService` to require `SpellEffects`, configure callbacks, and delegate effect application.
- Repo/Studio parity after cleanup:
  - `SpellService`: normalized length `43799`, hash `913598721`.
  - `SpellEffects`: normalized length `4120`, hash `920148350`.
  - `SpellProjectiles`: normalized length `3187`, hash `229091311`.
  - `SpellTargeting`: normalized length `2333`, hash `375152092`.
- Temporary `Stage4CSpellEffectsHarness` was removed; Studio grep and repo grep found no `Stage4C` markers.

### Architecture

- New graph: `SpellService -> SpellEffects`, `SpellService -> SpellProjectiles`, `SpellService -> SpellTargeting`, `SpellService -> NpcService`, `SpellService -> PlayerData`, `SpellService -> SpellDefinitions`, `SpellService -> WeaponConfigs`; `SpellTargeting -> NpcService`.
- `SpellEffects` requires no modules and depends on callbacks configured by `SpellService`.
- The existing DOT `task.spawn` loop moved from `SpellService` to `SpellEffects` with the same `0.5s` wait cadence.
- No new `_G`, remotes, fallback damage path, bootstrap, require cycle, or additional runtime scheduler was added.

### Validation

- Studio Play startup reached normal `SpellService` ready logs with no `SpellEffects` or missing-module errors.
- A temporary Studio-only server Script harness ran in the same server VM as live `SpellService` and wrapped `SpellEffects.Apply` plus existing `NpcService` effect APIs during real spell flow.
- Real `VoltNeedle` called `SpellEffects.Apply`, called `NpcService.ApplyFreeze` once with duration `0.22`, and dealt `18` damage.
- Real `FireBolt` called `SpellEffects.Apply`, dealt direct damage `19`, and produced DOT damage calls with `showFloating=false`.
- Real `WaterShard` called `SpellEffects.Apply`, called `NpcService.ApplySlow` once with `slowPct = 0.3` and `duration = 1.3`, and dealt `17` damage.
- Output showed no `SpellService`, `SpellEffects`, `SpellProjectiles`, `SpellTargeting`, or `NpcService` errors. Existing unrelated Studio output remained from `Hybrid Terrain Hex Generator`, `ErrorReporter`, and missing TeleportData in Play Solo.
- Repo grep and Studio grep found no temporary harness/probe markers after cleanup.

### Not Verified

- Full natural run with random spell acquisition was not repeated in this checkpoint.
- Multiplayer spell targeting/effects were not available through current MCP Play.
- Knockback, pull, pullStrength, and vulnerability stacking remain for later Stage 4/final audit; 4C directly validated DOT, stun/freeze, and slow.

### Risks

- `SpellEffects` uses callbacks configured by `SpellService`; direct calls before `SpellEffects.Configure` fail with an explicit assert.
- VFX dispatch/visual construction and beam/zone task loops still live in `SpellService` for later Stage 4 checkpoints.

### Rollback

- Restore the previous inline target damage multiplier, vulnerability multiplier, DOT, and effect-application helpers in `SpellService.lua`.
- Remove `Level/ServerScriptService/ModuleScript/SpellEffects.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 4C notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom SpellService stage 4B targeting extraction

### Summary

- Completed Stage 4B for active `game.ServerScriptService.Script.SpellService`.
- Added `SpellTargeting` for enemy root/position/alive queries, nearest/radius/all enemy queries, priority target picking/listing, and beam segment distance math.
- Kept the existing local helper names in `SpellService` as thin delegates so spell archetype call sites, cooldowns, damage formulas, VFX payloads, and public behavior remained unchanged.
- Preserved projectile/beam damage, speed, range, cooldown, tick rate, pierce, remotes, persistent data, attributes, and balance.

### Files

- Added `Level/ServerScriptService/ModuleScript/SpellTargeting.lua`
- Updated `Level/ServerScriptService/Script/SpellService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.SpellTargeting`.
- Synchronized active `game.ServerScriptService.Script.SpellService` to require `SpellTargeting` and delegate target helpers.
- Repo/Studio parity after cleanup:
  - `SpellService`: normalized length `46264`, hash `18656830`.
  - `SpellProjectiles`: normalized length `3187`, hash `229091311`.
  - `SpellTargeting`: normalized length `2333`, hash `375152092`.
- Temporary `Stage4BSpellTargetingHarness` was removed; Studio grep and repo grep found no `Stage4B` markers.

### Architecture

- New graph: `SpellService -> SpellProjectiles`, `SpellService -> SpellTargeting`, `SpellService -> NpcService`, `SpellService -> PlayerData`, `SpellService -> SpellDefinitions`, `SpellService -> WeaponConfigs`; `SpellTargeting -> NpcService`.
- `SpellTargeting` has no `_G`, remotes, runtime loop, event connection, `task.spawn`, or `task.delay`.
- No require cycle was introduced.

### Validation

- Studio Play startup reached normal `SpellService` ready logs with no `SpellTargeting` or missing-module errors.
- A temporary Studio-only server Script harness ran in the same server VM as live `SpellService` and wrapped `SpellTargeting` methods during real spell flow.
- Real `VoltNeedle` projectile used `PickPriorityEnemyList`, `GetNearestEnemy`, `GetEnemiesInRadius`, and `GetEnemyPosition`; it dealt `18` damage and changed target health `500 -> 482`.
- Real `ThunderRay` beam used `PickPriorityEnemy`, `GetAllEnemies`, `GetEnemyPosition`, and `DistancePointToSegment`; it dealt `2` ticks of `7` damage and changed target health `344 -> 330`.
- Output showed no `SpellService`, `SpellTargeting`, `SpellProjectiles`, or `NpcService` errors. Existing unrelated Studio output remained from `Hybrid Terrain Hex Generator`, `ErrorReporter`, and missing TeleportData in Play Solo.
- Repo grep and Studio grep found no temporary harness/probe markers after cleanup.

### Not Verified

- Full natural run with random spell acquisition was not repeated in this checkpoint.
- Multiplayer spell targeting was not available through current MCP Play.
- Complete orbit/nova/zone/beam matrix remains for later Stage 4/final audit; 4B specifically validated projectile targeting and beam/line distance targeting.

### Risks

- `SpellTargeting` depends on `NpcService`; isolated `execute_luau` requires in Edit can report the existing `NpcService` module-load limitation, while real Play startup loads the graph correctly.
- Other spell responsibilities, including effect application, impact/ring/beam VFX construction, and zone/beam/dot task loops, still live in `SpellService` for later checkpoints.

### Rollback

- Restore the previous inline enemy query, priority target picking, and `distancePointToSegment` helpers in `SpellService.lua`.
- Remove `Level/ServerScriptService/ModuleScript/SpellTargeting.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 4B notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom SpellService stage 4A central projectile simulation

### Summary

- Completed Stage 4A for active `game.ServerScriptService.Script.SpellService`.
- Added `SpellProjectiles` as the owner of active projectile state, movement, range expiry, pierce tracking, and hit detection.
- Replaced the old per-projectile `RunService.Heartbeat` connection in `SpellService.fireProjectile` with a call to `SpellProjectiles.Fire`.
- Kept `SpellService` as the owner of spell cooldowns, target selection, VFX payload shape, damage/effect formulas, `SpellVFXEvent`, and the global spell scheduler.
- Preserved projectile speed, range, damage, cooldown, pierce, target selection, remotes, persistent data, attributes, and balance.

### Files

- Added `Level/ServerScriptService/ModuleScript/SpellProjectiles.lua`
- Updated `Level/ServerScriptService/Script/SpellService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.SpellProjectiles`.
- Synchronized active `game.ServerScriptService.Script.SpellService` to require `SpellProjectiles` and delegate projectile simulation.
- Repo/Studio parity after cleanup:
  - `SpellService`: normalized length `46747`, hash `771417623`.
  - `SpellProjectiles`: normalized length `3187`, hash `229091311`.
- Temporary source probes and the temporary `Stage4ASpellProjectileHarness` Script were removed; Studio grep and repo grep found no `Stage4A` markers.

### Architecture

- New graph: `SpellService -> SpellProjectiles`, `SpellService -> NpcService`, `SpellService -> PlayerData`, `SpellService -> SpellDefinitions`, `SpellService -> WeaponConfigs`.
- `SpellProjectiles` requires no modules and has no dependency on `SpellService`, `NpcService`, `WaveController`, `DamageService`, `RunStatsService`, or `ShrineService`.
- `SpellProjectiles` owns one lazy `RunService.Heartbeat` connection while active projectiles exist, then disconnects when the active list is empty.
- No new `_G`, remotes, fallback damage path, bootstrap, or per-projectile runtime connection was added.

### Validation

- Studio Play startup reached normal `SpellService` ready logs with no `SpellProjectiles` or missing-module errors.
- A temporary Studio-only server Script harness was used so the test ran in the same server VM and shared ModuleScript cache with live `SpellService`.
- Real `VoltNeedle` projectile flow went through `SpellService -> fireProjectile -> SpellProjectiles.Fire -> NpcService.ApplyDamage`.
- Captured projectile config: `spellId = "VoltNeedle"`, `damage = 18`, `speed = 108`, `range = 70.04`, `pierce = 0`, `count = 1`.
- Projectile active count changed `0 -> 1` when fired and returned to `0` after the hit.
- Target `Stage4A_VoltNeedle_Target` health changed `200 -> 182`; captured `NpcService.ApplyDamage` amount was `18`.
- Output showed no `SpellService`, `SpellProjectiles`, or `NpcService` errors. Existing unrelated Studio output remained from `Hybrid Terrain Hex Generator`, `ErrorReporter`, and missing TeleportData in Play Solo.
- Repo grep and Studio grep found no temporary harness/probe markers after cleanup.

### Not Verified

- Full natural run with randomly acquired/projectile spells was not repeated in this checkpoint.
- Multiplayer spell targeting was not available through current MCP Play.
- Orbit, nova, zone, and beam archetypes were not behavior-tested in 4A because their code paths were not changed except for sharing the existing `SpellService`.

### Risks

- `SpellProjectiles` uses callbacks configured by `SpellService`; direct calls before `SpellProjectiles.Configure` fail with an explicit assert.
- Future MCP tests that require `NpcService` state should use a temporary normal server Script or existing gameplay/debug flow, because direct `execute_luau` requires can run outside the live ModuleScript cache used by game scripts.
- Beam, zone, and dot loops still use existing task loops and remain for later Stage 4 checkpoints.

### Rollback

- Restore the previous inline `fireProjectile` implementation in `SpellService.lua`, including its per-projectile `RunService.Heartbeat`.
- Remove `Level/ServerScriptService/ModuleScript/SpellProjectiles.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 4A notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom NpcService stage 3F replication update cleanup

### Summary

- Completed Stage 3F for active `game.ServerScriptService.ModuleScript.NpcService`.
- Added `NpcReplication` for NPC snapshot payloads, full sync responses, broadcast batch payloads, and tombstone inclusion/clear order.
- Kept `NpcService` as the public API facade, remote creation owner, damage indicator dispatcher, MissionProgress damage notifier, and only central scheduler owner.
- Preserved `NpcShared.BatchRate`, `NpcBatchEvent`, `NpcSyncRequest`, public `NpcService` API, targeting cadence, movement tick, and gameplay balance.
- Did not add throttling or spatial partitioning in this checkpoint because that would require a separate measured behavior/performance change.

### Files

- Added `Level/ServerScriptService/ModuleScript/NpcReplication.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.NpcReplication`.
- Synchronized active `game.ServerScriptService.ModuleScript.NpcService` to require `NpcReplication` and delegate batch payload responsibilities.
- Repo/Studio parity for `NpcService`, `NpcRegistry`, `NpcMovement`, `NpcTargeting`, `NpcMelee`, `NpcLifecycle`, and `NpcReplication` was confirmed by normalized length/checksum/line-count metrics.
- Temporary Server/Client harnesses were executed during Play and removed automatically with no script markers left in Studio or repo.

### Architecture

- New graph: `NpcService -> NpcRegistry`, `NpcService -> NpcLifecycle`, `NpcService -> NpcReplication`, `NpcService -> NpcMovement`, `NpcService -> NpcTargeting`, `NpcService -> NpcMelee`, `NpcService -> NpcShared`, optional `NpcService -> MissionProgress`; `NpcReplication` requires no modules.
- `NpcReplication` has no `_G`, `Heartbeat`, event connections, `task.spawn`, `task.delay`, or remotes of its own. It only fires the existing remote passed by `NpcService`.
- `NpcService` still owns the single `NpcSyncRequest.OnServerEvent` connection and single central `RunService.Heartbeat`.

### Validation

- Play startup reached normal service-ready logs with no `NpcService` or `NpcReplication` errors.
- Public `NpcService.Register` created a controlled elite `Slime` for replication validation.
- Client received `NpcBatchEvent` broadcasts through the normal batch path: `broadcastCount=10`.
- Client sent existing `NpcSyncRequest` and received full snapshot responses: `fullCount=2`.
- Broadcast and full snapshot payloads both contained the test `NpcId=2`.
- Full snapshot preserved `requestId=7321`.
- Cleanup removed the test NPC and returned `NpcService.GetActiveCount()` to `0`.
- Repo `rg` and Studio `script_grep` found no temporary harness markers after cleanup.
- `git diff --check` passed.

### Not Verified

- Full natural long-run with 100+ NPC was not repeated in 3F; the 3A 10/25/50 baseline remains the comparison point for a future measured optimization pass.
- True multiplayer target switching remains unverified in current MCP Play.
- Real throttling of formation scans, spatial partitioning, or target cache tuning was intentionally not implemented in 3F.

### Risks

- `NpcReplication` now owns payload construction. Client broadcast/full sync validation covered the active remote path, but large-NPC payload cost still needs a dedicated performance pass before changing cadence or payload shape.
- Stage 3F is a responsibility cleanup, not a gameplay performance tuning change.

### Rollback

- Restore the previous inline snapshot, batch collection, full sync, broadcast, and tombstone batch helpers in `NpcService.lua`.
- Remove `Level/ServerScriptService/ModuleScript/NpcReplication.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 3F notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

## 2026-07-07 - Poziom NpcService stage 3E lifecycle and status extraction

### Summary

- Completed Stage 3E for active `game.ServerScriptService.ModuleScript.NpcService`.
- Added `NpcLifecycle` for runtime attribute cleanup, state/health writers, tombstones, unregister/destroy, kill/despawn, death callback context, status/control effects, incoming damage modifiers, impulse, and ability lock.
- Kept `NpcService` as the public API facade, model registration owner, damage indicator dispatcher, MissionProgress damage notifier, and only central scheduler owner.
- Preserved all public `NpcService` function names, arguments, and return behavior.
- Did not move reward/drop ownership, remotes, persistent data, attributes, balancing, model setup, or the central `Heartbeat`.

### Files

- Added `Level/ServerScriptService/ModuleScript/NpcLifecycle.lua`
- Updated `Level/ServerScriptService/ModuleScript/NpcService.lua`
- Updated `docs/GOD_SCRIPT_REFACTOR_PLAN.md`
- Updated `CHANGELOG_AI.md`
- Updated `docs/changelog/CHANGELOG_AI_2026-07.md`

### Studio

- Active place: `Level`.
- Created live `game.ServerScriptService.ModuleScript.NpcLifecycle`.
- Synchronized active `game.ServerScriptService.ModuleScript.NpcService` to require `NpcLifecycle` and delegate lifecycle/status responsibilities.
- Repo/Studio parity for `NpcService`, `NpcRegistry`, `NpcMovement`, `NpcTargeting`, `NpcMelee`, and `NpcLifecycle` was confirmed by normalized length/checksum/line-count metrics.
- Temporary Server harnesses were executed during Play and removed automatically with no script markers left in Studio or repo.

### Architecture

- New graph: `NpcService -> NpcRegistry`, `NpcService -> NpcLifecycle`, `NpcService -> NpcMovement`, `NpcService -> NpcTargeting`, `NpcService -> NpcMelee`, `NpcService -> NpcShared`, optional `NpcService -> MissionProgress`; `NpcLifecycle -> NpcRegistry`, `NpcLifecycle -> NpcMovement`, `NpcLifecycle -> NpcShared`; `NpcTargeting -> NpcMovement`; `NpcMelee -> DamageService`; `NpcMovement -> WorldBounds`.
- `NpcLifecycle` does not require `NpcService`, `DamageService`, `WaveController`, `RunStatsService`, or `ShrineService`.
- `NpcLifecycle` has no remotes, `_G`, `Heartbeat`, event connections, `task.spawn`, or `task.delay`.
- `NpcService` still owns the single `NpcSyncRequest.OnServerEvent` connection and single central `RunService.Heartbeat`.

### Validation

- Play startup reached normal service-ready logs with no `NpcService` or `NpcLifecycle` errors.
- `SetIncomingDamageModifier` through public `NpcService` changed damage `10 -> 20` and left NPC HP at `80`.
- Config `onDeath` and `BindDeath` each fired exactly once on lethal `ApplyDamage`, with preserved death context.
- Public `Despawn` destroyed the model and did not fire death callbacks.
- Manual `Model:Destroy()` was cleaned up by the central update and reduced active count.
- `ApplyFreeze` and `LockForAbility` held movement at `0` studs during the measured windows.
- `AddImpulse` moved the NPC `3.586` studs through the normal update loop.
- Cleanup through public `NpcService.Despawn` returned `NpcService.GetActiveCount()` to `0`.
- Repo `rg` and Studio `script_grep` found no temporary harness markers after cleanup.
- `git diff --check` passed.

### Not Verified

- Full natural long-run movement/targeting/status behavior with 100+ NPC was not repeated in 3E; the 3A 10/25/50 baseline remains the comparison point until 3F optimization.
- True multiplayer target switching remains unverified in current MCP Play.
- Drop/reward integration from a real `WaveController` kill remains for the next runtime pass.
- Long status stacking matrices beyond the focused slow/freeze/impulse/lock paths remain for final audit.

### Risks

- `NpcLifecycle` now owns death/despawn side effects and status timers. Public facade behavior was validated, but Stage 3F should still monitor active count and tombstone churn under larger NPC counts.
- `NpcService.ApplyDamage` still owns damage indicator and MissionProgress side effects; this is intentional to avoid moving reward/progress ownership in 3E.

### Rollback

- Restore the previous inline runtime attribute cleanup, state/health writers, tombstone/unregister/destroy, kill/despawn, death callback, speed/status/control, incoming damage modifier, impulse, and ability lock helpers in `NpcService.lua`.
- Remove `Level/ServerScriptService/ModuleScript/NpcLifecycle.lua` from repo and live Studio.
- Revert this changelog entry, the `CHANGELOG_AI.md` index line, and the Stage 3E notes in `docs/GOD_SCRIPT_REFACTOR_PLAN.md`.

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
