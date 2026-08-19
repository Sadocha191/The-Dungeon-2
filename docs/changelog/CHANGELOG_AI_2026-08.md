# Changelog AI — 2026-08

## 2026-08-19 — Multi-level dungeon runtime and Roblox Packages

### Summary

- Migrated the dungeon runtime from a single Ashen Wastes layout to five explicit package roots: `DungeonShared`, `DungeonMovement`, `DungeonNPC`, `DungeonCombat`, and `DungeonRun`.
- Published the five roots under Pinecone Industries and recorded package asset IDs, schema/ownership attributes, dependency graph and deterministic bootstrap order.
- Added per-place `LevelConfig` modules for Ashen Wastes and Hollow Marsh plus a shared `DungeonLevelContext` that validates PlaceId, owns LevelKey and safely resolves mismatched teleport payloads in favor of the destination Place.
- Removed Ashen-specific encounter content from `EncounterScheduler` and `WaveController`; enemy pools, elite/boss order, run/swarm timing and chest/shrine/statue population now come from LevelConfig.
- Added Hollow Marsh to the Four Peaks level registry with `PlaceId 86815986698401` and alias `Level2`, then created a full `Level2/` repo snapshot without copying Ashen Wastes map geometry.

### Package architecture and runtime cost

- Package dependency graph is acyclic: Shared; Movement → Shared; NPC → Shared; Combat → Shared+NPC; Run → Shared+NPC+Combat.
- `DungeonPackageBootstrap` performs one startup installation of 146 source roots, keeps cloned scripts disabled during installation and starts `RunReadyGate` last. It adds no `Heartbeat`, `Stepped`, `RenderStepped`, polling task or persistent write loop.
- Existing central schedulers and performance contracts remain unchanged, including the single NPC scheduler rather than per-NPC Heartbeats. No new `_G` dependency was added.
- Shared remote definitions have one owner in `DungeonShared`; public remote names, persistent data shape and TeleportData format remain unchanged.

### Studio synchronization and validation

- `Poziom` fresh Play installed 146 roots/enabled 107 scripts, set `DungeonLevelKey=AshenWastes`, started the run, spawned the configured world population and NPCs, and preserved movement/combat startup.
- `level2` fresh Play installed the same 146 roots/enabled 107 scripts, set `DungeonLevelKey=HollowMarsh`, started the run on the independent map and spawned/attacked with shared runtime.
- Four Peaks contract lookup returned both exact PlaceIds, resolved the `Level2` alias to Hollow Marsh and opened the live portal UI showing both dungeon entries.
- Direct-play fallback passed in both dungeon Places. A real TeleportService hop and return cannot be completed inside Studio and were not represented as verified.
- Single-client smoke tests passed. A fresh two-client server session was not repeated, so RunMode Multi and party teleport remain a release-gate smoke test despite unchanged payload fields and shared code.
- Five package assets were successfully published. Poziom has linked instances; Roblox Toolbox/API group indexing still returned an empty/404 result while attaching those same links to level2, so level2 remains on byte-equivalent package-ready roots until the published assets become insertable through `Creations → Group Packages`.

### Repository files and documentation

- Reorganized the `Level/` snapshot under `ServerScriptService/DungeonPackages/*/Templates` and added `ServerStorage/DungeonLevel/LevelConfig.lua`.
- Added `Level2/` with Hollow Marsh config, shared package contents, early loading adapter and map-contract manifests.
- Updated `Four Peaks/ReplicatedStorage/ModuleScripts/Levels.lua`, `docs/PROJECT_CODE_GUIDE.md`, `docs/ROBLOX_REPO_SYNC.md`, package manifests and the changelog index.
- Preserved the user's pre-existing authored-weapon changes as uncommitted modifications at their new package paths and in the Level2 mirror.

### Risks and rollback

- Release must wait for level2 to contain actual `PackageLink` children for all five recorded asset IDs and for a cross-Place package update probe to pass.
- Because the repo does not serialize full Terrain/object state, the Hollow Marsh map remains Studio-owned and is documented through its World contract manifest.
- Roll back by restoring the pre-migration package checkpoint in Git, restoring the previous flat Studio roots/config consumers, and reverting the Five Package roots through Roblox package version history. All dungeon Places must use one compatible package set before production servers reopen.

### Checkpoint commits

- `62488b2` — migrate Ashen Wastes runtime into shared dungeon packages.
- `cdfd173` — add Hollow Marsh dungeon place snapshot.

## 2026-08-05 — Integration of PR #160 native ground NPC pathfinding

### Summary

- Integrated Roblox `PathfindingService` as the route owner for all `GroundSmall` and `GroundLarge` NPCs while preserving the central 12 Hz anchored simulation, `NpcBatchEvent` replication, combat authority and specialized flying/surface movement.
- Kept the global limits at two active `ComputeAsync` calls, 15 path starts per second and 160 queued requests, with no per-NPC `Heartbeat`, `MoveToFinished` or `Path.Blocked` connection.
- Added an integration hardening follow-up after Studio tests exposed native corner paths that the final square body-corridor probe rejected. Native path radius now covers that corridor, waypoint completion no longer cuts large-agent corners, queued starts are resampled before computation, and the NPC waits only during an active calculation.
- Removed fixed-timer replacement of active routes. Repaths remain driven by target movement, blocked steps, stuck detection and route completion, preventing refresh demand from exceeding the shared budget at horde scale.

### Repository files

- Updated `Level/ServerScriptService/ModuleScript/NpcGroundNavigation.lua`.
- Updated `docs/NPC_NAVIGATION.md` and `docs/NPC_MOVEMENT_SYSTEMS.md`.
- Updated `docs/changelog/CHANGELOG_AI_2026-08_NATIVE_NPC_PATHFINDING.md`, this monthly changelog and `CHANGELOG_AI.md`.

### Studio synchronization and validation

- Synchronized the final module to the active `Level` Studio place and confirmed successful Edit-mode `require()` plus fresh Play startup.
- `GroundSmall` and `GroundLarge` both routed around a controlled wall with `2/2` successful native paths, zero blocked steps/failures, and zero active or pending requests after cleanup.
- A 100-NPC open-floor run produced `100/100` successful path computations, zero failures, queue-full events or blocked steps, and `98/100` arrivals within 18 seconds. The controlled 12 Hz navigation sample averaged `4.11 ms` per tick and peaked at `6.38 ms` in Studio.
- The real level-up `PauseState` contract produced exactly zero movement during a two-second pause and resumed movement afterward. The public native-jump traversal contract resumed without advancing paused time and landed with zero positional error.
- The player naturally died during the extended test. `Health=0` and `RunEnded=true` left zero living/targeted NPCs and zero active/pending paths. A controlled `RunEnded` postcondition probe also stopped movement, cleared the target, and cleaned the probe completely.
- `git diff --check` passed. No standalone Luau analyzer, Selene or StyLua binary was available. The existing unrelated `Hybrid Terrain Hex Generator:16` plugin-context error remained in Studio output.

### Runtime loops, cost and cleanup

- No new runtime loop or persistent event connection was added. The existing shared movement tick remains 12 Hz, target refresh 3 Hz, formations 2 Hz and client batching 10 Hz.
- At most two asynchronous path calculations run at once. Queued records are bounded at 160 and dead/despawned records are rejected by generation/lifecycle checks.
- The integration follow-up reduces steady-state path demand by removing unconditional 3–4 second route replacement. The validated 100-NPC run issued one path request per agent.
- Cleanup tests ended with zero registered probes, zero pending paths and zero active calculations.

### Not verified and risks

- No full 500-NPC MicroProfiler capture was performed; the 100-NPC controlled scheduler timing is evidence, not proof of the target ceiling.
- A production-map authored `PathfindingLink` jump, every bridge/layer, water/lava and unreachable layout were not exhaustively traversed.
- Goblin/Boss/Bat authored attack transitions, SurfaceCrawler, flying behavior and real multiplayer interpolation were not repeated end-to-end because those specialized modules/contracts are unchanged by this diff.
- Map navmesh coverage for the effective large-agent radius remains the main content risk; narrow areas may correctly return `NoPath` where the previous permissive custom stepping passed.

### Rollback

- Revert the PR #160 merge and its integration-hardening commit, then restore the previous `NpcGroundNavigation` source in `Level` Studio.
- Repeat startup and the small/large obstacle smoke. No DataStore, remote, teleport or migration rollback is required.

## 2026-08-01 — Integration of PR #158 high-impact chest item bonuses

### Summary

- Merged the exact head of PR #158 into local `main` and preserved its rarity-based bonus multipliers: Common `2.00x`, Uncommon `2.25x`, Rare `2.50x`, Epic `2.75x`, and Legendary `3.00x`.
- Preserved authored drawbacks and `Difficulty` values while rounding integer stats to whole numbers and percentage-style modifiers to three decimal places.
- Enforced rarity stack caps of `4/3/2/1/1` for Common through Legendary items; `ChestItemService` continues to own availability, rolling, granting, and inventory state.
- Replaced the PR's independent startup mutator Script with deterministic scaling inside the canonical `ChestItemConfig` construction path. This removes a race with `ChestService`/`ChestItemService` startup while keeping the requested gameplay values unchanged.

### Repository files

- Updated `Level/ReplicatedStorage/ModuleScripts/Items/ChestItemConfig.lua` with the rarity tuning and deterministic per-definition normalization.
- Removed the merged `Level/ServerScriptService/Script/ChestItemPowerBalance.server.lua` in the integration follow-up because its responsibility now belongs to the config module and its execution order was not guaranteed.
- Updated `CHANGELOG_AI.md` and this monthly changelog.

### Studio synchronization and validation

- Set `Level` as the active Studio instance and confirmed the canonical live path `game.ReplicatedStorage.ModuleScripts.Items.ChestItemConfig` matched the pre-change repository source.
- Synchronized the updated config and confirmed exact normalized source parity (`17,152` characters) between Studio and the repository.
- Edit-mode contract validation loaded a fresh clone of the updated module and confirmed 54 unique items, all rarity stack caps, preserved negative trade-offs, and both Legendary special-effect contracts.
- Confirmed representative scaled values: Bent Dagger Damage `0.08 -> 0.16`, Ogre Tooth Damage `0.30 -> 0.75`, Black Sun Pendant Damage `0.42 -> 1.155`, Meteor Spine Damage `0.75 -> 2.25`, and Heart of the Dungeon MaxHP/Shield `90 -> 270`.
- A fresh Play server and client both loaded the same scaled config. A controlled live `RunStatsService` probe applied Black Sun Pendant as `+1.155 Damage` and `+0.12 Difficulty`, then removed the test modifier and confirmed both stats returned to their original values.
- `ChestService`, `ChestDropBalance`, authored weapon setup, and `RunReadyGate` reached ready state. No PR-specific error appeared; the existing unrelated `Hybrid Terrain Hex Generator:16` plugin-context error remained in output.
- `git diff --check` passed. No standalone Luau analyzer, Selene, or StyLua binary was available; Studio module loading and fresh Play supplied the compile/runtime checks.

### Runtime loops, cost, and cleanup

- No `Heartbeat`, `Stepped`, `RenderStepped`, polling loop, connection, remote, DataStore field, teleport payload, `_G` dependency, or task was added.
- Scaling and validation remain O(54) once per client/server module load. Item lookup remains O(1) through `ItemsById`, and reward selection continues through the existing service paths.
- The change creates no new runtime state requiring cleanup. The controlled stat probe used one temporary modifier source and removed it before Play ended.

### Not verified and risks

- Every rarity was validated through configuration contracts, but one natural chest reveal per rarity was not forced and visually inspected during this pass.
- Repeated natural chest drops were not played until each item reached its cap; the cap data and the existing `ChestItemService` `totalStacks < MaxStacks` gate were verified instead.
- The requested multipliers intentionally create very large late-rarity bonuses. Their gameplay feel and long-run balance under many item combinations remain a design risk even though the application path is verified.

### Rollback

- Revert the PR #158 integration follow-up and merge commits together, restore the previous `ChestItemConfig` source in `Level` Studio, and confirm the old authored bonuses and stack caps in a fresh Play session.

## 2026-08-01 — Integration of open PRs #155–#157

### Summary

- Merged the exact heads of PR #155, PR #156, and draft PR #157 into local `main` and synchronized all affected runtime modules to the active `Level` Studio place.
- PR #155 rebuilds the 54 existing chest item IDs around modifiers consumed by the current run runtime, strengthens rarity rewards, lowers excessive stack caps, validates IDs and modifier values, and increases XP/gold/silver fallback rewards to `140`/`120`/`55`.
- PR #156 caps post-miniboss ambient spawn debt at 8 and releases at most one catch-up enemy at a time over a bounded 12-second window.
- PR #157 preserves the computed ground offset after externally positioned ground-NPC abilities, rejects Boss/MiniBoss pull impulse, and adds the Bat `DiveAttack` behavior to the existing central NPC scheduler.
- The integration follow-up keeps a constant catch-up rate after an encounter and clamps retained accumulator credit so a capacity-blocked catch-up cannot resume as a multi-frame burst.
- The integration follow-up also caches Bat dive tuning per NPC behavior state and creates one reusable `RaycastParams` per attack instead of rebuilding configuration and player exclusion lists at every 12 Hz movement step.

### Repository files

- Updated `Level/ReplicatedStorage/ModuleScripts/Items/ChestItemConfig.lua`.
- Updated `Level/ServerScriptService/ModuleScript/{EncounterScheduler,RunSpawnConfig}.lua`.
- Added `Level/ServerScriptService/ModuleScript/{DiveAttackBehavior,NpcExternalPositioning}.lua`.
- Updated `Level/ServerScriptService/ModuleScript/{MobConfig,NpcCombatBehaviorService,NpcLifecycle,NpcMovementSystemController,NpcMovementSystemResolver}.lua`.
- Added `docs/changelog/CHANGELOG_AI_2026-08_BOSS_BAT_FIX.md` from PR #157 and updated `CHANGELOG_AI.md` plus this monthly changelog.

### Studio synchronization

- Set the active Studio instance to `Level`.
- Updated the eight existing ModuleScripts and created `game.ServerScriptService.ModuleScript.DiveAttackBehavior` plus `game.ServerScriptService.ModuleScript.NpcExternalPositioning`.
- Confirmed exact normalized source parity for all 10 affected runtime modules after synchronization.
- Existing authored-weapon changes in repo and Studio remained isolated from this integration.

### Validation

- `git diff --check` passed before Studio synchronization.
- Edit-mode contract tests required the integrated modules successfully and confirmed 54 unique chest items: 12 Common, 12 Uncommon, 12 Rare, 10 Epic, and 8 Legendary.
- Confirmed only whitelisted finite modifiers, the preserved `void_duplicator` ID with `Void Engine` display name, both Legendary special-effect contracts, and fallback values `140` XP, `120` gold, and `55` silver.
- A deterministic scheduler test capped debt at 8, emitted all 8 catch-up spawns with a maximum budget of 1, finished at `12.133s` under a simulated 60 Hz heartbeat, and retained only one spawn credit after 20 seconds of blocked capacity.
- Contract tests kept Boss/MiniBoss impulse at zero while a Normal NPC retained the full test impulse.
- A controlled Edit-mode ground probe applied a 5-stud NPC offset exactly (`Y=256`).
- `Level` startup completed with `SpellService`, `ChestService`, `HordeController`, `RunReadyGate`, all authored weapon templates, and the integrated modules ready.
- A controlled authored Golem registered as Boss retained its computed `18.1224`-stud ground offset after `NpcService.SetPosition`; measured grounding error was below `0.00001` stud and pull impulse remained zero.
- A controlled authored Bat completed `windup -> dive -> hit -> recovery`; final behavior metrics recorded two windups, two dives, two hits, and two recoveries. Pausing during an active dive produced zero positional movement.
- The observed central 12 Hz movement scheduler averaged `0.0062ms` per tick and peaked at `0.4892ms` during the focused one-player probes. This is a smoke measurement, not a target-scale profile.
- No integrated-script error appeared. Existing unrelated output remained from `Hybrid Terrain Hex Generator:16`; two earlier failed AssistantCommand probes were test-harness errors and did not originate from game scripts.

### Runtime loops, cost, and cleanup

- No new `Heartbeat`, `Stepped`, `RenderStepped`, polling loop, remote, DataStore field, or teleport payload was added.
- Spawn-debt work remains O(1) inside the existing `WaveController` Heartbeat and emits at most one catch-up spawn budget at a time.
- DiveAttack runs only through the existing central `NpcService` movement scheduler at 12 Hz. Behavior state and cached tuning are owned by the NPC record and cleared by `NpcCombatBehaviorService.Cleanup` on death/despawn.
- Each Bat attack builds one reusable world-raycast filter at windup. Raycasts are limited to active dive obstacle checks, a candidate hit line-of-sight check, and one recovery ground probe.
- Chest config validation is O(54) once when the module loads; reward lookup remains O(1) through `ItemsById`.
- No per-NPC connection, new `_G` dependency, or unbounded task was added.

### Not verified and risks

- The rebalance was contract-tested but not played through every chest item, rarity reveal, modifier combination, fallback reward, Angel's Debt trigger, or Blood Moon Contract trigger in a natural run.
- Post-miniboss scheduling was tested deterministically, but the original high-density MicroProfiler scenario was not repeated with a natural miniboss fight and target-scale enemy population.
- Boss grounding was verified on the live map with a controlled authored Golem, but 30 natural `ChargeCrush` casts across flat terrain, slopes, overhangs, bridges, and map edges were not repeated.
- Bat validation covered a standing single-player target, one successful authored-rig hit cycle, pause, and cleanup. Misses, obstacle aborts, player death, multiple Bats, moving/sliding/jumping targets, and multiplayer targeting remain unverified.
- No 100–500 NPC target-scale MicroProfiler capture was performed.

### Rollback

- Revert the integration follow-up commit first, then revert the merge commits for PR #157, PR #156, and PR #155 in reverse order.
- In `Level` Studio, restore the previous eight existing module sources and delete `DiveAttackBehavior` plus `NpcExternalPositioning` when rolling back all three PRs.
- PR #155 can be rolled back independently by restoring only `ChestItemConfig`; PR #156 by restoring `EncounterScheduler` and `RunSpawnConfig`; PR #157 by restoring its five existing NPC modules and deleting its two new modules.

## 2026-08-01 — Integration of open PRs #149–#154

### Summary

- Finalized all six open pull requests for the game and prepared the combined result on `main`.
- Kept the controlled PR #149 integration already present on remote `main` and the local PR #150 integration that contains the finalized runtime delta without the temporary patch/workflow artifacts from the stacked branches.
- Merged the exact heads of PR #151, PR #152, PR #153, and the newly opened draft PR #154 into local `main`.
- Finished PR #154 for multiplayer safety by extending the existing `WeaponSwingVFX` payload with server-authored `attackerUserId` and `element`; local weapon motion now accepts only the exact attacking user while impact VFX remains visible to all clients.
- Synchronized the affected runtime sources and object removals to the active `Level` and `Four Peaks` Studio places before publishing Git.

### Repository files

- Updated `Level/ReplicatedStorage/ModuleScripts/NpcShared.lua`.
- Updated `Level/ServerScriptService/ModuleScript/{MobConfig,NpcService}.lua`.
- Updated `Level/ServerScriptService/Script/ChestService.server.lua` and `Level/ServerScriptService/Script/Model/WaveController.lua`.
- Updated `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`.
- Updated `Four Peaks/ServerScriptService/ResetDefaultAnimations.lua`.
- Added `Four Peaks/StarterGui/ScreenGuiButtons/ScreenButtonsHoverClient.lua`.
- Added `Four Peaks/StarterGui/Currency/CurrencyClient.lua` and removed `Four Peaks/StarterPlayer/StarterPlayerScripts/PlayerHubLobby.lua`.
- Updated `Level/ServerScriptService/Script/WeaponCombat.server.lua` and both `Level/StarterPlayer/StarterPlayerScripts/LocalScript/{WeaponClient,WeaponVFX.client}.lua` presentation clients.
- Removed the now-unused `Level/ServerScriptService/Script/WeaponVFXTemplates.server.lua` bootstrap after repo and live Studio searches confirmed that the new code-generated impact VFX has no template-folder consumer.
- Updated `roblox/CzterySzczyty/StarterGui/MANIFEST.md`, `CHANGELOG_AI.md`, and the July/August monthly changelogs.
- Updated the `WeaponSwingVFX` contract and removed the obsolete VFX-template entry in `docs/PROJECT_CODE_GUIDE.md`.

### Studio synchronization

- `Level`: all 21 runtime sources touched by PR #149/#150 matched the repository by normalized length and rolling checksum; `ChestAssetTemplateBootstrap` remained absent.
- `Four Peaks`: synchronized `game.ServerScriptService.ResetDefaultAnimations`, added `game.StarterGui.ScreenGuiButtons.ScreenButtonsHoverClient`, and added `game.StarterGui.Currency.CurrencyClient` with exact repository source parity.
- Removed the obsolete `game.StarterPlayer.StarterPlayerScripts.PlayerHubLobby` LocalScript.
- After a successful migration playtest, removed the obsolete `game.StarterGui.PlayerHudGui_Lobby` and its two descendants; the authored `game.StarterGui.Currency` hierarchy remains the sole lobby currency HUD.
- `Level`: synchronized `game.ServerScriptService.Script.WeaponCombat`, `game.StarterPlayer.StarterPlayerScripts.LocalScript.WeaponClient`, and `game.StarterPlayer.StarterPlayerScripts.LocalScript.WeaponVFX` with exact repository source parity.
- Enabled the previously disabled live `WeaponClient`, removed `game.ServerScriptService.Script.WeaponVFXTemplates`, and confirmed no generated `game.ReplicatedStorage.WeaponVFXTemplates` folder remains.

### Validation

- `Level` startup smoke completed with `SpellService`, `ChestService`, `HordeController`, and `RunReadyGate` ready; the authored enemy rank folders and both new rank/reward modules were present.
- `Four Peaks` completed two startup smokes, including a second run after legacy HUD removal.
- Lobby character `WalkAnim` and `RunAnim` both resolved to `rbxassetid://89814244152772`.
- The authored currency labels rendered live values as `111 040` and `9 440`; a controlled modal probe hid/restored both Currency and Chat, while Backpack remains controlled by the replacement client.
- The Events button reached scale `1.2` and raised `ZIndex` during hover, then returned to scale `1.0` and its original `ZIndex`. Rapid transitions across Events, Inventory, Guild, Party, and Profile left every tested scale and `ZIndex` restored.
- PR #154 automatically created the floating Scythe model and Trail after the late Backpack/loadout attributes arrived; the real Tool stayed out of the character model.
- A wrong `attackerUserId` was rejected by the local weapon handler, while the exact local `UserId` was accepted and enabled the Trail during the curved slash.
- A paused accepted attack remained frozen with Trail disabled, then resumed and enabled Trail after unpause; the previous pause state was restored.
- Fire, Water, and Light impact probes each created exactly three code-generated parts in the expected element color, and cleanup left zero impact parts after `0.3s`.
- A controlled character respawn rebuilt the floating weapon model and Trail without placing the Tool in the character's hand.
- All temporary client probes and attributes were removed.
- `git diff --check origin/main...HEAD` passed.
- No PR-specific error appeared. Existing unrelated output remained from `Hybrid Terrain Hex Generator:16` in Level and the `BlacksmithUI` wait for `PassiveDesc` in Four Peaks.

### Runtime loops, cost, and cleanup

- PR #149 continues to use the existing central `WaveController` Heartbeat; Elite scheduling starts at two minutes and repeats every 90 seconds, and shared chest work is O(players) with one bounded expiry task per chest.
- PR #150 adds no runtime loop; configured animation tracks are created once through the existing presentation setup.
- PR #151 adds one finite `task.spawn` only for a character that already exists when the server script starts; ongoing work is owned by the player's `CharacterAdded` signal.
- PR #152 is mouse/property/event-driven and adds no polling or frame loop. Active tweens and completion connections are cancelled before replacement and on button destruction.
- PR #153 removes the legacy `RenderStepped` modal scan. Currency rendering and modal visibility now update only on remote, GUI property, attribute, and hierarchy events, with ancestry cleanup for observed ScreenGuis.
- PR #154 replaces the existing local floating-weapon `RenderStepped` connection rather than adding another loop. There is exactly one connection for the local visual model, disconnected by `cleanupVisual`; character, Backpack, Tool attribute, and Tool destruction work is event-driven and deduplicated with weak-key tables.
- Each confirmed weapon attack creates three client-only neon parts, three short tweens, and three bounded `Debris` cleanup records lasting at most `0.22s`; the obsolete replicated weapon-template catalog and per-hit Tool cloning were removed.
- No new `_G` dependency, persistent-data field, DataStore contract, teleport payload, or remote name was added.

### Not verified and risks

- The natural two-minute Elite-to-death-to-shared-chest path, true two-player claiming, and reward persistence were not repeated in this final pass; their component contracts and prior controlled Studio tests remain documented in the July PR #149 entry.
- Animation asset ownership metadata and frame-by-frame rig deformation were not re-audited; active tracks and startup remained error-free.
- The modal test used the live Daily Login modal plus a controlled generic modal. Every listed lobby modal was not manually opened through its user-facing button.
- The connected test profile did not have a currency value above one million, so live event rendering above that threshold was not exercised without mutating persistent player data; the formatter path and authored labels retain the documented `1 000 000` representation.
- PR #154 ownership filtering was tested with wrong and correct user IDs in one client session, but a real two-client simultaneous attack session was not available.
- No target-scale MicroProfiler run was performed.

### Rollback

- Revert the integration commits in reverse order: PR #154, PR #153, PR #152, PR #151, then the PR #150 integration commit if Level animation/identity cleanup must also be removed. PR #149 can be rolled back separately from its controlled integration commit.
- In `Four Peaks` Studio, restore `PlayerHubLobby` and `PlayerHudGui_Lobby`, remove `CurrencyClient` and `ScreenButtonsHoverClient`, and restore the previous `ResetDefaultAnimations` source.
- In `Level` Studio, restore the 21 affected sources from the chosen pre-integration commit and recreate `ChestAssetTemplateBootstrap` only when rolling back PR #149 itself.
- For a PR #154-only Studio rollback, restore the previous `WeaponCombat`, `WeaponClient`, and `WeaponVFX` sources, disable `WeaponClient` to its prior property state, restore `WeaponVFXTemplates`, and allow it to recreate `ReplicatedStorage.WeaponVFXTemplates` during Play.

## 2026-08-01 — Authored lobby currency counters

### Changes

- Removed the legacy `Four Peaks/StarterPlayer/StarterPlayerScripts/PlayerHubLobby.lua` client that restyled and populated `PlayerHudGui_Lobby.coinsBox` at runtime.
- Added `Four Peaks/StarterGui/Currency/CurrencyClient.lua` for the authored `Currency` ScreenGui.
- Bound the counters to `Currency.Frame.Silver.Silver` and `Currency.Frame.Souls.Souls`, with a safe descendant fallback for the text labels.
- Silver and Souls now display complete integer values with spaces as thousands separators, for example `1 000 000`; compact `K`, `M`, and `B` formatting is not used.
- Preserved `PlayerProgressEvent` synchronization and added an explicit `requestSync` after the client connects.
- Preserved lobby Backpack hiding, Chat hiding while a modal is open, and currency-HUD hiding while modal UI is active.
- Disabled the legacy `PlayerHudGui_Lobby` if an old Studio copy is still present, preventing duplicate currency counters during migration.
- Replaced the previous per-frame modal visibility check with event-driven GUI property and hierarchy listeners.
- Updated the Four Peaks StarterGui manifest to use `Currency` instead of `PlayerHudGui_Lobby`.

### Runtime cost

- No `RenderStepped`, `Heartbeat`, polling loop, or per-object update loop was added.
- Currency text updates only when `PlayerProgressEvent` sends a progress payload.
- Modal visibility recalculates only when relevant ScreenGui state, modal attributes, hierarchy, or Party overlay visibility changes.

### Validation

- Reviewed the current `LobbyProgress.lua` contract and confirmed it sends `silver`, `coins`, and `souls` and accepts `requestSync`.
- Reviewed the replacement script for full-value formatting, legacy HUD suppression, modal visibility handling, and event cleanup paths.
- Confirmed the authored Currency hierarchy and exact replacement source in the active `Four Peaks` Studio place.
- Completed client playtests for live counter rendering, modal hide/restore behavior, Chat restoration, and startup after legacy HUD removal.

### Studio validation completed

- Confirmed `StarterGui.Currency.Frame.Silver.Silver`, `StarterGui.Currency.Frame.Souls.Souls`, and `StarterGui.Currency.CurrencyClient`.
- Removed the obsolete `StarterPlayerScripts.PlayerHubLobby` and `StarterGui.PlayerHudGui_Lobby` after the first successful playtest.
- Confirmed live values use spaces as thousands separators and that Currency and Chat restore after a modal closes.
- Values above one million were not injected into persistent player data during the playtest; that threshold remains covered by the formatter implementation and authored `1 000 000` labels.

### Risks

- The replacement depends on the authored `Currency` hierarchy shown in Studio. A renamed `Frame`, `Silver`, or `Souls` object will stop initialization with a clear error.
- The repository still has partial full-object parity with Studio, so the authored visual object properties are not recreated by this code-only change.

### Rollback

- Restore `PlayerHubLobby.lua`, remove `CurrencyClient.lua`, restore `PlayerHudGui_Lobby` in the StarterGui manifest, and re-enable the old lobby HUD object in Studio.
