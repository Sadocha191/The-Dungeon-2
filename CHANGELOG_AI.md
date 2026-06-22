# CHANGELOG_AI

This file tracks AI-made repo changes and the intended rollback path.

## 2026-06-22 - Poziom visible enemy ground offset

### Scope

- Fixed enemy grounding for templates whose invisible root part sits below the visible mesh bottom, including floating Slime cases observed in live Play mode.
- Changed the shared `WaveController` spawn grounding offset and `NpcService` runtime ground-follow offset to use the lowest visible BasePart first, falling back to all parts only if no visible parts exist.
- This allows the NPC root to sit below terrain when imported geometry requires it, so the visible model bottom rests on the surface instead of the invisible root touching the surface.
- Changed server-side `NpcService` emerge/SetPosition movement to translate every BasePart by the same root delta, preventing imported rigs from moving only `RootPart` while visible MeshParts remain at stale world coordinates.
- Added a guarded `NpcService` repair for truly detached visible mesh clusters, with a large flat-distance threshold so intentional boss offsets like Golem are preserved.
- Kept the underground emerge spawn behavior, spawn pools, map bounds, remotes, folders, and enemy stats unchanged.

### Files updated

- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ServerScriptService.Script.Model.WaveController`
- `Poziom`: `game.ServerScriptService.ModuleScript.NpcService`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.NpcPresentation`

### Verification

- In live Play mode before the fix, real `WaveController` Slime spawns included a client-visible floating case with `bottomGap = 4.25` studs while terrain under the same X/Z was `Workspace.Terrain`.
- Found that those bad real spawns had `RootPart` moved to the map while visible Slime MeshParts remained at stale template-space coordinates; `GeneratedSmoothDuneMap` was not the direct final ground hit in the active `WorldBounds` path.
- Synced `WaveController`, `NpcService`, and `NpcPresentation` into the active `Level` Studio through local read-only HTTP plus Roblox MCP.
- Ran live Studio `loadstring(...)` compile checks for `WaveController`, `NpcService`, and `NpcPresentation`; all returned `ok`.
- Verified real `WaveController` Play spawns after the final sync: 12 Slimes, `high = 0`, `low = 0`, visible bottom gap `0.079` studs against `Workspace.Terrain`.
- Verified controlled live `NpcService` probes for Slime, Skeleton, Zombie, Goblin, Warewolf, LandShark, Demon, and boss Golem:
  - start below ground at about `-5.67` studs for normal enemies and `-5.81` for Golem
  - finish grounded at `0.079..0.08` studs after emergence
- Verified slope samples: Slime on a `0.515` stud local terrain delta finished at `0.109` studs; Skeleton on a `0.448` stud local terrain delta finished at `0.08` studs.
- Checked the `GeneratedSmoothDuneMap` suspicion: raw raycasts from `Y=420` hit `Workspace.GeneratedSmoothDuneMap.InvisibleCollision.HeightLimitCeiling` at `Y=322`, but `WorldBounds.RaycastTerrainAtXZ` skipped it and hit `Workspace.Terrain` at center/edge samples (`Y=12.8`, `Y=36.2`); border samples outside terrain returned no ground instead of using the ceiling.

### Risks

- Enemy templates with intentionally unusual visible geometry now follow their visible bottom rather than forcing the root above terrain; this is desired for ground enemies but flying enemies should keep using `CanFly` or `IgnoreGroundSnap`.
- The detached-visual repair intentionally only triggers after a large flat separation (`64` studs) so oversized/imported bosses keep their authored root offset.

### Rollback

- Restore the previous all-parts root-ground offset and `Model:PivotTo` movement logic in `WaveController` and `NpcService`, then revert this changelog entry.

## 2026-06-22 - Poziom enemy underground emerge spawn

### Scope

- Changed `NpcService` so newly registered enemies start below their grounded spawn surface, hold briefly, rise up to the grounded root position, and only then enter normal chase/attack AI.
- Scaled the underground start depth from model height and root-to-ground offset, with optional model attributes for `SpawnEmergeDepth`, `SpawnEmergeHoldDuration`, `SpawnEmergeRiseDuration`, and `DisableSpawnEmerge`.
- Preserved root-to-pivot offsets when server-side NPC placement paths pivot models, so imported enemy pivots do not shift visual height.
- Kept emerging enemies counted for spawn caps but excluded them from weapon/spell targeting APIs until the emerge phase finishes.
- Updated `NpcPresentation` so server-driven emerge spawns play ground dust at the real surface position and no longer apply the older extra client-side downward offset on top of the server path.
- Left enemy spawn pools, stats, remotes, folders, and object names unchanged.

### Files updated

- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ServerScriptService.ModuleScript.NpcService`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.NpcPresentation`

### Verification

- Confirmed and re-set the active Roblox Studio instance to `Level`.
- Synced the updated `NpcService` and `NpcPresentation` repo sources into live Studio through local read-only HTTP plus Roblox MCP.
- Ran live Studio `loadstring(...)` compile checks for `NpcService` and `NpcPresentation`; both returned `ok`.
- Started Play mode and ran server-side spawn-emerge probes using real enemy templates registered through live `NpcService`.
- Verified Slime, Skeleton, Zombie, Goblin, Warewolf, LandShark, Demon, and Golem:
  - start below ground with negative initial bottom gaps (`-5.70` studs for normal probes, `-8.05` for Golem)
  - hold without horizontal movement (`holdXZDrift = 0`)
  - are not returned by `GetNearestEnemy` during the underground/hold phase
  - finish grounded at `finalBottomGap = 0.05`
- Stopped Play mode after the probe.

### Risks

- Spawned enemies are intentionally untargetable for roughly the hold-plus-rise duration, so first contact is delayed by about one second.
- Very tall future enemy models may need a per-model `SpawnEmergeDepth` attribute if the default depth does not fully hide them before rising.

### Rollback

- Restore the previous live sources for `NpcService` and `NpcPresentation`.
- Revert the files listed above and this changelog entry.

## 2026-06-22 - Backend local artifact gitignore

### Scope

- Added repository ignore rules for backend-local generated artifacts under `backend/**`, including `node_modules/`, `.wrangler/`, `.dev.vars`, log files, and `.local` files.
- Left tracked backend source and documentation files visible to git.
- Kept the existing specific `roblox-error-bridge` `node_modules` ignore line for compatibility with the current dirty worktree.

### Files updated

- `.gitignore`
- `CHANGELOG_AI.md`

### Verification

- Confirmed the active Roblox Studio instance was `Level`; no Studio objects were changed for this repo-only gitignore update.
- Verified `backend/roblox-error-bridge/node_modules/` is ignored by the new backend `node_modules` rule.
- Ran `git diff --check` after the change; only existing LF-to-CRLF warnings were reported.

### Risks

- `.gitignore` does not hide files that are already tracked, so the currently tracked `backend/roblox-error-bridge/wrangler.toml` remains visible if it has local modifications.
- Future backend source files under `backend/` remain trackable unless they match one of the local/generated artifact rules.

### Rollback

- Remove the backend local/generated artifact rules from `.gitignore` and revert this changelog entry.

## 2026-06-22 - Poziom grounded spawns, chest yaw variety, and drop settling

### Scope

- Reused the enemy root/feet grounding calculation in `WaveController` through shared `WorldBounds` helper methods so normal, elite, and portal boss spawns use terrain surface plus model bottom offset instead of raw pivot height.
- Replaced the portal boss direct `base.CFrame * CFrame.new(0, 0, -18)` placement with terrain raycast/nearby terrain grounding for the boss model.
- Added random per-spawn Y yaw for cloned `Workspace.skrzynia` chests and generated fallback chests, with optional yaw override support through chest config.
- Kept generated fallback chests grounded with the same small clearance while applying random yaw.
- Added server and client drop settling so XP, coins, and souls that stop attracting before pickup fall vertically back to their grounded idle height instead of remaining at player-height.
- Left remote names, folder names, enemy pools, spawn pacing, and stale `Level/ServerScriptService/Script/Model.model/WaveController.lua` unchanged.

### Files updated

- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `Level/ServerScriptService/Script/ChestService.server.lua`
- `Level/ServerScriptService/Script/DropService.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/DropPresentation.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ServerScriptService.Script.Model.WaveController`
- `Poziom`: `game.ServerScriptService.Script.ChestService`
- `Poziom`: `game.ServerScriptService.Script.DropService`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.DropPresentation`

### Verification

- Confirmed and re-set the active Roblox Studio instance to `Level`.
- Synced the four updated repo sources into live Studio through local read-only HTTP plus Roblox MCP.
- Ran live Studio `loadstring(...)` compile checks for `WaveController`, `ChestService`, `DropService`, and `DropPresentation`; all returned `ok`.
- Ran controlled Studio enemy placement probes and measured `bottomGap = 0.05` for Slime, Skeleton, Zombie, Goblin, Warewolf, LandShark, Demon, and boss Golem on flat terrain.
- Rechecked Slime and Skeleton on a sampled slope (`10.53` degrees); both measured `bottomGap = 0.05`.
- Ran Studio chest placement probes for five cloned `Workspace.skrzynia` chests and five generated fallback chests; each had a prompt, unique yaw coverage across the sample, and `bottomGap = 0.05`.
- Ran Studio drop-settle probes for XP, coins, and souls; each rose during attraction, then settled back to ground height with `finalYDelta = 0` and `xzDrift = 0`.
- Ran `git diff --check` on touched files; only LF-to-CRLF warnings were reported.

### Risks

- No full Play Solo visual/combat pass was run, so final camera-visible feel still benefits from one in-game check.
- The new portal boss grounding retries if terrain cannot be found near the portal boss offset; if a future portal location is invalid, the boss may delay spawning instead of appearing in the air.

### Rollback

- Restore the previous live sources for `WaveController`, `ChestService`, `DropService`, and `DropPresentation`.
- Revert the files listed above and this changelog entry.

## 2026-06-21 - Poziom ChestOpening follow-up and world chest model swap

### Scope

- Delayed the `ChestOpening` chest animation start by `0.5` seconds after the reward GUI opens.
- Changed the chest animation flow to wait for the actual `AnimationTrack.Length` when available, play the full animation, then freeze the chest model at the final frame.
- Made `ChestOpening.Frame.Item` force-visible at reveal time, resolve the rolled item icon, and fall back to Roblox's placeholder image only if no icon can be resolved.
- Added a runtime transparent `TakeRewardButton` over `Item` so clicking/tapping the revealed item claims the reward reliably.
- Changed `ChestService` so spawned world chests prefer clones of live `Workspace.skrzynia` instead of the old generated Part-based chest.
- Anchored spawned `skrzynia` chest clones, put their `OpenPrompt` on a visible mesh part, and positioned the model with a small ground clearance.
- Left the generated Part chest path as a fallback if `Workspace.skrzynia` is missing.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `Level/ServerScriptService/Script/ChestService.server.lua`
- `Level/StarterGUI/ChestOpening/MANIFEST.md`
- `Level/Workspace/skrzynia/MANIFEST.md`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.ChestRewardClient`
- `Poziom`: `game.ServerScriptService.Script.ChestService`

### Verification

- Confirmed and re-set the active Roblox Studio instance to `Poziom`.
- Verified live `Workspace.skrzynia` exists as a `Model` with `PrimaryPart = RootPart`.
- Ran live Studio compile checks for `ChestRewardClient` and `ChestService`; both returned `ok`.
- Ran a live Studio clone-placement probe for `Workspace.skrzynia`; the clone used `RootPart` as primary, parented `OpenPrompt` to visible `Cylinder.001`, anchored its parts, and measured `bottomGap = 0.050`.
- Verified the live `ChestRewardClient` source contains `CHEST_OPEN_ANIMATION_DELAY = 0.5`, `TakeRewardButton`, and `getChestOpeningTrackDuration`.
- Verified the live `ChestService` source contains `WORLD_CHEST_TEMPLATE_NAME = "skrzynia"` and the `createChestFromWorldTemplate` path.
- Ran `git diff --check` on tracked touched files; only LF-to-CRLF warnings were reported.
- Checked the new `Level/Workspace/skrzynia/MANIFEST.md` for trailing whitespace; no matches were returned.

### Risks

- No full Play Solo chest-opening click-through was run in this pass, so the actual on-screen animation/reveal/claim flow still benefits from a manual test.
- Existing already-spawned chest instances in a running session are not retroactively replaced; newly spawned chests use the new template path.

### Rollback

- Restore the previous live sources for `ChestRewardClient` and `ChestService`.
- Revert the files listed above and this changelog entry.

## 2026-06-21 - Poziom ChestOpening animated chest reward UI

### Scope

- Switched the chest reward client to prefer the authored `StarterGui.ChestOpening` ScreenGui during level chest opening.
- Added support for playing the `skrzynia` model animation `rbxassetid://128606196135074` for `2.02` seconds, then freezing the chest pose instead of auto-hiding the GUI.
- Hid `ChestOpening.Frame.Item` while the animation plays, then populated it with the rolled item icon after the animation duration.
- Kept the old generated `ChestRewardGui` as a fallback only if `ChestOpening` is missing from `PlayerGui`.
- Updated modal UI and run stats visibility checks so `ChestOpening.Enabled` counts as an active chest reward UI.
- Added a manifest documenting the live `StarterGui.ChestOpening` object contract because the full imported GUI/model hierarchy is not mirrored on disk.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `Level/ReplicatedStorage/ModuleScripts/ModalUiState.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/RunStatsHud.client.lua`
- `Level/StarterGUI/ChestOpening/MANIFEST.md`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.ChestRewardClient`
- `Poziom`: `game.ReplicatedStorage.ModuleScripts.ModalUiState`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.RunStatsHud`
- `Poziom`: `game.StarterGui.ChestOpening`
- `Poziom`: `game.StarterGui.ChestOpening.ViewportFrame.WorldModel.skrzynia.OpenAnimation`

### Verification

- Confirmed and re-set the active Roblox Studio instance to `Poziom`.
- Verified `StarterGui.ChestOpening` contains `ViewportFrame.WorldModel.skrzynia`, `AnimationController.Animator`, `Camera`, and `Frame.Item`.
- Added/updated live `OpenAnimation.AnimationId = rbxassetid://128606196135074`.
- Set live `ChestOpening.Enabled = false`, `ResetOnSpawn = false`, `DisplayOrder = 92`, and hid `Frame.Item` at startup.
- Synced the updated live client/module scripts through Roblox MCP.
- Ran live Studio compile checks for `ChestRewardClient`, `ModalUiState`, and `RunStatsHud`; all returned `ok`.
- Verified sample item icon resolution for `Sharp Splinter`, `Giant's Button`, and `Angel's Debt`, including apostrophe-name matching against live `ReplicatedStorage.Assets.Items`.
- Ran `git diff --check` on the tracked touched files; only LF-to-CRLF warnings were reported.
- Checked untracked `ModalUiState.lua` and `ChestOpening/MANIFEST.md` for trailing whitespace; no matches were returned.

### Risks

- No full Play Solo chest-opening click-through was run in this pass, so final animation timing and visual framing should still be checked in-game.
- If a rolled item icon is missing from `ReplicatedStorage.Assets.Items`, the `Item` ImageLabel will become visible but blank for that reward.

### Rollback

- In live Studio, restore the previous sources for `ChestRewardClient`, `ModalUiState`, and `RunStatsHud`.
- Remove `OpenAnimation` from `StarterGui.ChestOpening.ViewportFrame.WorldModel.skrzynia` if the old GUI contract should be restored.
- Revert the files listed above and this changelog entry.

## 2026-06-21 - Poziom simple mob config module

### Scope

- Added `MobConfig` as the simple place to tune mob stats and model presentation values.
- Moved the enemy stat table out of `WaveController` into `ServerScriptService.ModuleScript.MobConfig`.
- Added explicit per-mob config fields for `visualScale` and `facingYawDegrees` so mob size and visual facing can be controlled from one script.
- Kept `WaveController` spawn pools, spawn timing, elite scheduling, boss portal flow, and combat systems unchanged.
- Preserved compatibility aliases (`range`, `cd`, `dmg`) inside `MobConfig` so the existing `WaveController` stat reads still work.

### Files updated

- `Level/ServerScriptService/ModuleScript/MobConfig.lua`
- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ServerScriptService.ModuleScript.MobConfig`
- `Poziom`: `game.ServerScriptService.Script.Model.WaveController`

### Verification

- Confirmed active Roblox Studio instance was `Poziom`.
- Synced the new `MobConfig` module into live Studio and pointed live `WaveController` at it.
- Ran live Studio compile checks for `MobConfig` and `WaveController`; both returned `ok`.
- Required live `MobConfig` and verified `Ent.visualScale = 3.3`, `Goblin.facingYawDegrees = -90`, and `Grzyb.facingYawDegrees = -90`.

### Risks

- No full Play Solo spawn/visual pass was run; verification covered source sync, config loading, and compile checks.
- Future mob tuning should happen in `MobConfig`; changing legacy aliases generated at the bottom of the module is not needed for normal balancing.

### Rollback

- Remove `game.ServerScriptService.ModuleScript.MobConfig` from live Studio and restore the previous `WaveController` source with its inline `ENEMY_CONFIGS` table.
- Revert `Level/ServerScriptService/ModuleScript/MobConfig.lua`, `Level/ServerScriptService/Script/Model/WaveController.lua`, and this changelog entry.

## 2026-06-21 - Poziom enemy model facing and Ent scale follow-up

### Scope

- Set `NpcFacingYawDegrees = -90` on the live `Ent`, `Goblin`, and `Grzyb` enemy templates so runtime NPC presentation rotates them 90 degrees clockwise around the vertical axis.
- Mirrored the same facing attribute onto their `ServerStorage.EnemyRigBackup` copies.
- Added an `Ent`-specific `visualScale = 3.3` in `WaveController`, making it slightly larger than the default elite visual scale of `3`.
- Left spawn pools, stats other than Ent visual scale, remote names, and enemy folder names unchanged.

### Files updated

- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `Level/ReplicatedStorage/Enemies/Elite/Ent/MANIFEST.md`
- `Level/ReplicatedStorage/Enemies/Normal/Goblin/MANIFEST.md`
- `Level/ReplicatedStorage/Enemies/Normal/Grzyb/MANIFEST.md`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.Enemies.Elite.Ent.Attributes.NpcFacingYawDegrees`
- `Poziom`: `game.ReplicatedStorage.Enemies.Normal.Goblin.Attributes.NpcFacingYawDegrees`
- `Poziom`: `game.ReplicatedStorage.Enemies.Normal.Grzyb.Attributes.NpcFacingYawDegrees`
- `Poziom`: `game.ServerStorage.EnemyRigBackup.{Elite.Ent,Normal.Goblin,Normal.Grzyb}.Attributes.NpcFacingYawDegrees`
- `Poziom`: `game.ServerScriptService.Script.Model.WaveController`

### Verification

- Confirmed active Roblox Studio instance was `Poziom`.
- Verified live `Ent`, `Goblin`, and `Grzyb` templates and backups now report `NpcFacingYawDegrees = -90`.
- Ran a live Studio `loadstring(...)` compile check for the updated `WaveController`; it returned `ok`.
- Verified the live `WaveController` source includes the Ent `visualScale = 3.3` override path.

### Risks

- No full Play Solo visual pass was run, so final facing/scale feel still benefits from an in-game look.
- The rotation is implemented through the existing runtime presentation attribute, not by rewriting imported mesh transforms on disk.

### Rollback

- Clear `NpcFacingYawDegrees` from the six live template/backup models listed above.
- Restore the previous `WaveController` source without the Ent `visualScale` override.
- Revert the files listed above and this changelog entry.

## 2026-06-21 - Poziom Ent Goblin Grzyb enemy model templates

### Scope

- Replaced the live `Poziom` enemy templates for `Ent` and `Goblin` with clones of the matching models from `Workspace`.
- Added `Grzyb` as a new normal enemy template from `Workspace.Grzyb`.
- Added a transparent `RootPart` to the live `Grzyb` template because the source model had only one mesh part.
- Added `Run [Animation]` to the live `Goblin` template with `AnimationId = rbxassetid://97052990382415`.
- Added `Grzyb` to `WaveController` enemy stats and normal spawn pools from the early/mid run onward.
- Added manifest notes for the live `Ent`, `Goblin`, and `Grzyb` templates because the repo does not fully mirror imported model hierarchies.
- Added the `Grzyb` legacy backup `Animate` placeholder mirror.

### Files updated

- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `Level/ReplicatedStorage/Enemies/Elite/Ent/MANIFEST.md`
- `Level/ReplicatedStorage/Enemies/Normal/Goblin/MANIFEST.md`
- `Level/ReplicatedStorage/Enemies/Normal/Grzyb/MANIFEST.md`
- `Level/ServerStorage/EnemyRigBackup/Normal/Grzyb/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/Grzyb/Animate.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.Enemies.Elite.Ent`
- `Poziom`: `game.ReplicatedStorage.Enemies.Normal.Goblin`
- `Poziom`: `game.ReplicatedStorage.Enemies.Normal.Grzyb`
- `Poziom`: `game.ServerScriptService.Script.Model.WaveController`
- `Poziom`: `game.ServerStorage.EnemyRigBackup.{Elite.Ent,Normal.Goblin,Normal.Grzyb}.Animate`

### Verification

- Confirmed and re-set the active Roblox Studio instance to `Poziom`.
- Verified live `ReplicatedStorage.Enemies` now contains `Elite.Ent`, `Normal.Goblin`, and `Normal.Grzyb` with `PrimaryPart = RootPart`.
- Verified live `Goblin.Run.AnimationId = rbxassetid://97052990382415`.
- Ran a live Studio `loadstring(...)` compile check for the updated `WaveController`; it returned `ok`.
- Verified live `WaveController` contains the `Grzyb` config entry and the updated spawn pools.
- Started Play mode and confirmed `WaveController` reached `[HordeController] Ready (time-based)` without a new enemy setup error in Studio Output.
- The existing `ServerScriptService.Hybrid Terrain Hex Generator` `CreateToolbar` error still appears during Play and is unrelated to this pass.

### Risks

- No full Play Solo combat pass was run; an attempted forced `Grzyb` spawn through `_G.DebugForceSpawnMob` could not be completed because that debug hook was not available from the MCP server command context.
- The repo manifests document the imported model state, but the full MeshPart/Bone hierarchy is still not mirrored 1:1 on disk.
- `Ent` and `Grzyb` do not have explicit run/idle/attack animation assets from this pass, so their visible motion depends on the existing NPC presentation movement path rather than authored animation clips.

### Rollback

- In live `Poziom`, restore the previous enemy templates for `ReplicatedStorage.Enemies.Elite.Ent` and `ReplicatedStorage.Enemies.Normal.Goblin`, delete `ReplicatedStorage.Enemies.Normal.Grzyb`, and restore the previous `WaveController` source.
- Revert the files listed above and this changelog entry.

## 2026-06-18 - Cztery szczyty mission list state sorting

### Scope

- Sorted lobby mission cards by stable mission state on every mission UI refresh.
- State priority is `claimable = 1`, `inProgress = 2`, `completed = 3`.
- Preserved existing mission/config order inside each state group unless a mission payload provides an explicit order field.
- Added `LayoutOrder` values to mission rows and set the mission list `UIListLayout` to `LayoutOrder`.
- Left mission progress, reward claiming, save data, server validation, and unrelated lobby/combat systems unchanged.
- Synced the updated `MissionsUI` source into the active live Studio place `Cztery szczyty`.

### Files updated

- `Four Peaks/StarterPlayer/StarterPlayerScripts/MissionsUI.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/MissionsUI.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Cztery szczyty`: `game.StarterPlayer.StarterPlayerScripts.MissionsUI`

### Verification

- Confirmed and re-set the active Roblox Studio instance to `Cztery szczyty`.
- Read back the live `MissionsUI` source and verified the state-priority helper, `UIListLayout.SortOrder`, row `LayoutOrder`, and sorted refresh loops are present.
- Ran an Edit-mode Studio logic probe with synthetic claimable, in-progress, and claimed mission payloads; result order was claimable first, in-progress second, claimed last.
- Did not mutate live mission save data or manually claim/progress missions during this pass.

### Risks

- Full click-through validation with real player mission save states was not performed; the change is limited to client-side row ordering during refresh.
- The repo contains both a top-level `MissionsUI.lua` and a nested `LocalScript/MissionsUI.lua`; both were updated to prevent mirror drift, while live Studio currently has the top-level script.

### Rollback

- Revert the two `Four Peaks/.../MissionsUI.lua` files and this changelog entry.
- In live `Cztery szczyty`, restore the previous source for `game.StarterPlayer.StarterPlayerScripts.MissionsUI` if needed.

## 2026-06-18 - Poziom shared enemy spawn grounding fix

### Scope

- Fixed shared normal/elite enemy spawn placement in `WaveController` so ground mobs are placed by root/feet offset from the terrain hit instead of treating the ground hit as the model pivot height.
- Removed the final spawn fallback that reused the player/anchor Y position when spawn sampling failed; fallback now searches nearby/random terrain and returns no spawn if no valid ground is found.
- Expanded spawn raycast ignores to include the enemy model being positioned, existing enemies, players, drops/chests/shrines/statues/portal, `SpellVFX`, and `EnemyAbilityVFX`.
- Kept spawn pacing, enemy selection, elite scheduling, swarm logic, and max-alive caps unchanged.
- Synced the updated `WaveController` source into the active live Studio place `Poziom`.

### Files updated

- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ServerScriptService.Script.Model.WaveController`

### Verification

- Confirmed and re-set the active Roblox Studio instance to `Poziom`.
- Ran a live Studio `loadstring(...)` compile check for `WaveController`; it returned `ok`.
- In Play mode, let live `WaveController` naturally spawn 24 Slimes with accelerated existing debug spawn settings; all measured at `bottomGap=0.05` from terrain.
- Ran controlled server-side placement checks using the same root/feet grounding math for live normal templates:
  - Slime flat and slope: `bottomGap=0.05`
  - Skeleton flat and slope: `bottomGap=0.05`
  - Goblin flat: `bottomGap=0.05`
  - Zombie flat: `bottomGap=0.05`
  - Warewolf flat: `bottomGap=0.05`
  - LandShark flat: `bottomGap=0.05`
  - Demon flat: `bottomGap=0.05`
- Verified the persisted live source contains the model-aware `pickSpawnCFrame(...)`, effect-folder raycast ignores, root offset grounding, and no player-Y anchor fallback.

### Risks

- Manual visual inspection on every map slope was not performed; the server-side measurements covered one sampled slope for Slime/Skeleton and flat/low-slope samples for the other templates.
- Boss portal spawn placement uses its existing separate path and was not changed in this pass.

### Rollback

- Revert `Level/ServerScriptService/Script/Model/WaveController.lua` and this changelog entry.
- In live `Poziom`, restore the previous source for `game.ServerScriptService.Script.Model.WaveController` if needed.

## 2026-06-18 - Poziom melee and movement regression follow-up

### Scope

- Fixed the melee regression where grounded enemies could stop damaging because the server hit validation compared the player against the anchored model root instead of the simulated NPC position used by `NpcService`.
- Tightened `EnemyMeleeIgnoreVerticalValidation` so it only skips vertical-overlap rejection; missing-root checks and 3D reach validation still apply unless an enemy explicitly disables 3D distance checks.
- Restored movement steering paths in `MovementController` so slide start/steer and airborne momentum use the controller's current input intent fallback instead of relying only on raw `Humanoid.MoveDirection`.
- Synced the targeted `NpcService` and `MovementController` fixes into the active live Studio place `Poziom`.
- Left the existing post-elite spawn debt smoother in `WaveController` untouched.

### Files updated

- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ServerScriptService.ModuleScript.NpcService`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`

### Verification

- Confirmed and re-set the active Roblox Studio instance to `Poziom`.
- Ran live Studio `loadstring(...)` compile checks for `NpcService`, `MovementController`, and `MovementConfig`; all returned `ok`.
- In Play mode with ambient spawns disabled and enemies cleared, ran a controlled server-side contact test through `NpcService`:
  - Slime at `+9` studs vertical separation: no health loss.
  - Slime at normal contact height: player health dropped.
  - Goblin at `+9` studs vertical separation: no health loss.
  - Goblin at normal contact height: player health dropped.
- Verified the running client and persisted Edit source contain the restored movement call sites for `getCurrentMoveIntent(...)`, slide steering, airborne steering, and slide/air movement-facing.

### Risks

- Movement verification confirmed the live source and runtime hooks, but did not include a hands-on Studio movement feel pass for slide steering, air steering, or slide-jump chaining.
- Enemies that intentionally hit across unusual height differences should use the existing melee override attributes with an explicit 3D reach choice.

### Rollback

- Revert `Level/ServerScriptService/ModuleScript/NpcService.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`, and this changelog entry.
- In live `Poziom`, restore the previous sources for `game.ServerScriptService.ModuleScript.NpcService` and `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController` if needed.

## 2026-06-18 - Poziom P1 melee height and post-elite spawn hardening

### Scope

- Hardened enemy melee/contact damage validation in `NpcService` so only real `HumanoidRootPart` base parts are tracked and melee damage is skipped if either the player root or NPC root disappears before the server hit check.
- Kept the vertical melee validation server-authoritative with default height/3D distance constants plus model attributes for special-case overrides.
- Added optional pass-through melee override attributes from the existing enemy config table in `WaveController`, without changing current Slime/Goblin/basic melee values.
- Fixed the post-elite/swarm spawn cap helper in `WaveController` so `spawnBurst` captures the local `getMaxLivingEnemyCap` function instead of resolving a missing global.
- Synced the updated `NpcService` and `WaveController` sources into the active live Studio place `Poziom`.

### Files updated

- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `CHANGELOG_AI.md`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom` before live edits.
- Ran live Studio `loadstring(...)` compile checks for `NpcService`, `RunSpawnConfig`, and `WaveController`; all returned `ok`.
- Re-read live Studio snippets for `NpcService` and `WaveController` to confirm the HRP `BasePart` guard, optional melee attributes, and `getMaxLivingEnemyCap` forward declaration are present.
- In Play mode, ran a contained server-side Slime/Goblin contact check through `NpcService`: both mobs dealt no damage at `+9` studs vertical separation and dealt damage again at ground-level contact range.
- Ran `git diff --check` on the touched Level scripts; only LF/CRLF conversion warnings were reported.

### Risks

- This pass verified source sync and compilation, but did not complete a manual Play Solo jump-over test or a full elite-defeat pacing playtest.
- Any enemy meant to damage from unusual vertical separation should use the `EnemyMeleeIgnoreVerticalValidation`, `EnemyMeleeMaxVerticalDelta`, `EnemyMeleeMaxHitHeightAboveEnemy`, or `EnemyMeleeUse3DDistance` model/config override path.

### Rollback

- Revert `Level/ServerScriptService/ModuleScript/NpcService.lua`, `Level/ServerScriptService/Script/Model/WaveController.lua`, and this changelog entry.
- In live `Poziom`, restore the previous sources for `game.ServerScriptService.ModuleScript.NpcService` and `game.ServerScriptService.Script.Model.WaveController` if needed.

## 2026-06-16 - Poziom P1 gameplay responsiveness and spawn pacing fixes

### Scope

- Added central modal UI state helpers so gameplay input locks use one shared source of truth for pause, reward, chest, and other blocking UI states.
- Stopped camera snap after modal UI close by making `CameraMouseLock` ignore look delta while blocking UI is open and briefly swallowing the first mouse delta after release.
- Restored run movement after chest reward flow by making `MovementController` resync held sprint state and rebuild held movement intent from current keyboard input instead of treating the chest UI open/close as a permanent stop.
- Shortened chest reward reveal timing and removed chest prompt hold time so chest interaction starts immediately while keeping existing server-side chest-open validation.
- Added shrine/statue charge decay with a short grace period after leaving the area so objective progress falls gradually instead of resetting to zero, and kept the visible progress billboard alive while any progress remains.
- Added melee hit validation in `NpcService` so grounded enemies respect vertical separation and optional 3D reach checks before dealing damage, with per-enemy attribute overrides for exceptions such as flying or special mobs.
- Raised swarm-only enemy pressure to `120` by adding a swarm cap override and preserved the normal `MAX_LIVING_ENEMIES` cap outside swarm windows.
- Reworked post-elite normal spawn catch-up in `WaveController` so paused ambient spawns become spawn debt that drains over roughly `10` seconds with a per-tick cap instead of flushing instantly after the elite ends.
- Removed portal hold time so portal activation starts immediately once server-side conditions are satisfied.
- Synced the updated gameplay scripts into the active live Studio place `Poziom`.

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/ModalUiState.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/CameraMouseLock.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `Level/ServerScriptService/ModuleScript/RunSpawnConfig.lua`
- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `Level/ServerScriptService/Script/ChestService.server.lua`
- `Level/ServerScriptService/Script/ShrineService.server.lua`
- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.ModuleScripts.ModalUiState`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.CameraMouseLock`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.ChestRewardClient`
- `Poziom`: `game.ServerScriptService.ModuleScript.RunSpawnConfig`
- `Poziom`: `game.ServerScriptService.ModuleScript.NpcService`
- `Poziom`: `game.ServerScriptService.Script.ChestService`
- `Poziom`: `game.ServerScriptService.Script.ShrineService`
- `Poziom`: `game.ServerScriptService.Script.Model.WaveController`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom` and re-set it active before the live sync and compile pass.
- Synced the updated repo sources into live Studio for all touched gameplay scripts listed above.
- Ran a live `loadstring(...)` compile check in Studio for:
  - `ModalUiState`
  - `CameraMouseLock`
  - `MovementController`
  - `ChestRewardClient`
  - `RunSpawnConfig`
  - `NpcService`
  - `ChestService`
  - `ShrineService`
  - `WaveController`
  - all returned `ok` after the final `WaveController` register-limit fix.
- Fresh-required a clone of live `RunSpawnConfig` and confirmed:
  - `SWARM.targetMaxAlive = 120`
  - `SWARM.maxLivingEnemies = 120`
  - `POST_ELITE_SPAWN.catchupDuration = 10`
  - `POST_ELITE_SPAWN.maxPerTick = 4`
- Verified live sources contain the expected hooks:
  - `CameraMouseLock` uses `ModalUiState` and the `ignoreLookDeltaUntil` release cooldown
  - `MovementController` uses `ModalUiState` and `applyHeldMovementIntent(...)`
  - `ChestRewardClient` uses `ROLL_DURATION = 0.6`
  - `ChestService` sets `prompt.HoldDuration = 0`
  - `ShrineService` contains charge decay and exit-grace handling
  - `NpcService` contains `canApplyMeleeDamage(...)` and melee height caps
  - `WaveController` contains `spawnLimitConfig`, spawn debt catch-up, and `prompt.HoldDuration = 0` for the portal
- Ran `git diff --check` on the touched files earlier in the pass; the only output was LF/CRLF conversion warnings and no trailing-whitespace or patch-shape errors.

### Risks

- The chest movement-resume fix reconstructs held keyboard intent on the client; if gamepad or mobile input needs the same resume behavior, those input paths may need a follow-up pass.
- Melee height validation is applied generically to enemy melee hits, so any enemy that intentionally attacks from below should use the per-model override attributes added in `NpcService`.
- Swarm pressure now has a dedicated `120` cap path in `WaveController`; if performance degrades in dense scenes, the safest next step is tuning spawn cadence or pathing load rather than reverting the whole system.
- This pass verified live source sync and compilation, but it did not include a manual in-session playtest for chest flow, shrine charge decay, swarm saturation, or elite catch-up pacing.

### Rollback

- Revert `Level/ReplicatedStorage/ModuleScripts/ModalUiState.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/CameraMouseLock.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`, `Level/ServerScriptService/ModuleScript/RunSpawnConfig.lua`, `Level/ServerScriptService/ModuleScript/NpcService.lua`, `Level/ServerScriptService/Script/ChestService.server.lua`, `Level/ServerScriptService/Script/ShrineService.server.lua`, `Level/ServerScriptService/Script/Model/WaveController.lua`, and this changelog entry in the repo.
- In live Studio, restore the previous source of the same objects under `game.ReplicatedStorage`, `game.StarterPlayer`, and `game.ServerScriptService` in the `Poziom` place, or mirror the reverted repo sources back into Studio.

## 2026-06-16 - Poziom slide steering and movement-facing tuning

### Scope

- Tuned slide steering and slope acceleration without rewriting the movement controller:
  - `SlideSteerStrength = 0.42`
  - `SlideSteerResponsiveness = 0.16`
  - `SlideMaxTurnRate = 7.5`
  - `SlopeAcceleration = 22`
  - `DownhillSpeedGainMultiplier = 0.65`
  - `FlatSlideFriction = 0.9965`
  - `SlideSurfaceTransitionFriction = 0.9985`
  - `MaxSlideSlopeSpeed = 150`
- Tuned regular and chain airborne steering:
  - `AirControlStrength = 0.04`
  - `AirTurnResponsiveness = 0.025`
  - `MomentumChainAirControlStrength = 0.018`
  - `MomentumChainAirTurnResponsiveness = 0.012`
  - `MomentumChainAirDrag = 1.0`
- Added `FaceMovementDirectionEnabled`, `SlideFaceTurnSpeed`, and `AirFaceTurnSpeed` so the character faces actual horizontal movement during slide and airborne momentum.
- Added slide steering in the existing slide update by gently lerping `activeMotion.direction` toward projected `Humanoid.MoveDirection`, with reduced turn strength for near-opposite input.
- Added `faceMovementDirection(...)` and preserved current assembly velocity while rotating `HumanoidRootPart` so facing updates do not wipe horizontal momentum.
- Added debug logs for `slide_steer`, `slide_accel`, `air_steer`, and `face_movement`.
- Left slide jump, landing slide resume, dash, sprint, multijump, UI locks, RunStarted / RunEnded, and weapon scripts untouched.

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.ModuleScripts.MovementConfig`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Synced the repo movement sources into live `Poziom` after `loadstring(...)` compilation succeeded for both fetched sources.
- Fresh-required a clone of live `MovementConfig` and confirmed:
  - `SlideSteerStrength = 0.42`
  - `SlideSteerResponsiveness = 0.16`
  - `SlideMaxTurnRate = 7.5`
  - `SlopeAcceleration = 22`
  - `DownhillSpeedGainMultiplier = 0.65`
  - `FlatSlideFriction = 0.9965`
  - `SlideSurfaceTransitionFriction = 0.9985`
  - `MaxSlideSlopeSpeed = 150`
  - `MaxMomentumChainSpeed = 160`
  - `AirControlStrength = 0.04`
  - `AirTurnResponsiveness = 0.025`
  - `AirDrag = 0.999`
  - `MomentumChainAirControlStrength = 0.018`
  - `MomentumChainAirTurnResponsiveness = 0.012`
  - `MomentumChainAirDrag = 1`
  - `FaceMovementDirectionEnabled = true`
  - `SlideFaceTurnSpeed = 14`
  - `AirFaceTurnSpeed = 10`
- Verified live `MovementController` contains `faceMovementDirection`, `slide_steer`, `slide_accel`, `air_steer`, and both slide/air face-direction call sites.
- Compared live Studio sources against the `Level/` repo mirror with matching rolling checksums:
  - `MovementConfig` length `2693`, checksum `767423173`
  - `MovementController` length `58721`, checksum `271530354`
- Started Play Solo and confirmed the runtime client sees:
  - `SlideSteerStrength = 0.42`
  - `SlopeAcceleration = 22`
  - `AirControlStrength = 0.04`
  - `MomentumChainAirControlStrength = 0.018`
  - `FaceMovementDirectionEnabled = true`
  - the cloned `MovementController`
  - a spawned character with `HumanoidRootPart`
- Studio Output did not show a new movement-controller error during this sanity check.
- Noted the existing unrelated runtime error from `ServerScriptService.Hybrid Terrain Hex Generator` at line `16` (`CreateToolbar`) during Play Solo.
- Ran `git diff --check` on the touched movement/changelog files; the only output was LF/CRLF conversion warnings for edited files.

### Rollback

- Revert `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`, and this changelog entry.
- In live `Poziom`, restore the previous sources for `game.ReplicatedStorage.ModuleScripts.MovementConfig` and `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController` if needed.

## 2026-06-16 - Poziom airborne chain momentum preservation

### Scope

- Added explicit chain-momentum air tuning to `MovementConfig`:
  - `MomentumChainMinSpeed = 3`
  - `MomentumChainAirDrag = 1.0`
  - `MomentumChainAllowAirControl = true`
  - `MomentumChainAirControlStrength = 0.008`
  - `MomentumChainAirTurnResponsiveness = 0.004`
- Updated airborne chain momentum so slide-jump carry uses the stronger of current X/Z velocity and stored `chainMomentum.velocity`, clamps only to `MaxMomentumChainSpeed`, and uses `MomentumChainAirDrag` instead of regular `AirDrag`.
- Updated chain air control so input can slowly steer the trajectory without cutting horizontal speed or immediately reversing direction.
- Updated multijump carry so active chain momentum uses the stronger current/stored X/Z velocity, clamps to `MaxMomentumChainSpeed`, and refreshes `chainMomentum.velocity` after the air jump.
- Updated movement debug logs for `air_momentum`, `air_jump_carry`, `low_gravity`, and `chain_clear`.
- Kept dash, sprint, RunStarted / RunEnded, PauseState, UI locks, weapon scripts, and landing slide resume behavior outside the chain-compatibility path untouched.

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.ModuleScripts.MovementConfig`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Synced the repo movement sources into live `Poziom` after `loadstring(...)` compilation succeeded for both fetched sources.
- Fresh-required a clone of live `MovementConfig` and confirmed:
  - `MaxMomentumChainSpeed = 160`
  - `MomentumChainAirDrag = 1`
  - `MomentumChainAirControlStrength = 0.008`
  - `MomentumChainAirTurnResponsiveness = 0.004`
  - `SlideJumpGravityScale = 0.48`
  - `SlideJumpLowGravityDuration = 0.45`
  - `MomentumChainGravityScale = 0.55`
  - `SlideJumpEnabled = true`
  - `SlideJumpHorizontalMultiplier = 1.12`
  - `SlideJumpExtraUpVelocity = 6`
  - `SlideJumpMinCarrySpeed = 3`
  - `SlideJumpMaxCarrySpeed = 160`
- Verified live `MovementController` contains the chain air drag path, `air_jump_carry` debug, `chain_clear reason` debug, and low-gravity reason selection.
- Compared live Studio sources against the `Level/` repo mirror with matching rolling checksums:
  - `MovementConfig` length `2514`, checksum `603935661`
  - `MovementController` length `55255`, checksum `988958357`
- Started Play Solo and confirmed the runtime client sees:
  - `MaxMomentumChainSpeed = 160`
  - `MomentumChainAirDrag = 1`
  - `SlideJumpEnabled = true`
  - the cloned `MovementController`
  - a spawned character with `HumanoidRootPart`
- Studio Output did not show a new movement-controller error during this sanity check.
- Noted an unrelated existing runtime error from `ServerScriptService.Hybrid Terrain Hex Generator` at line `16` (`CreateToolbar`) during Play Solo.
- Ran `git diff --check` on the touched movement/changelog files; the only output was LF/CRLF conversion warnings for edited files.

### Rollback

- Revert `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`, and this changelog entry.
- In live `Poziom`, restore the previous sources for `game.ReplicatedStorage.ModuleScripts.MovementConfig` and `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController` if needed.

## 2026-06-16 - Poziom slide jump hang-time tuning

### Scope

- Tuned `MovementConfig` so slide jump starts carrying momentum at medium slide speeds:
  - `SlideJumpMinCarrySpeed = 3`
  - `SlideJumpHorizontalMultiplier = 1.12`
  - `SlideJumpExtraUpVelocity = 6`
  - `SlideJumpMaxCarrySpeed = 160`
  - `MaxMomentumChainSpeed = 160`
  - `MaxSlideSlopeSpeed = 160`
- Tuned airborne chain feel with weaker air steering and slower fall:
  - `AirGravityScale = 0.52`
  - `LowGravityMinYVelocity = -140`
  - `AirControlStrength = 0.02`
  - `AirTurnResponsiveness = 0.01`
  - `AirDrag = 0.999`
- Added slide-jump-specific gravity tuning without changing global `workspace.Gravity`:
  - `SlideJumpGravityScale = 0.48`
  - `SlideJumpLowGravityDuration = 0.45`
  - `MomentumChainGravityScale = 0.55`
- Added `slideJumpLowGravityUntil` state so the existing character-local `VectorForce` low gravity uses slide-jump scale first, then chain momentum scale, then normal air scale.
- Updated debug logs for slide jump carry, slide-jump low-gravity scale, and slide-jump low-gravity expiry.
- Left dash, sprint, landing slide resume, UI locks, RunStarted / RunEnded, and weapon scripts untouched.

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.ModuleScripts.MovementConfig`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Synced the patched `MovementConfig` and `MovementController` sources into live `Poziom`.
- Verified live `loadstring(...)` compilation for:
  - `game.ReplicatedStorage.ModuleScripts.MovementConfig`
  - `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`
- Fresh-required a clone of live `MovementConfig` and confirmed:
  - `SlideJumpMinCarrySpeed = 3`
  - `SlideJumpHorizontalMultiplier = 1.12`
  - `SlideJumpExtraUpVelocity = 6`
  - `SlideJumpMaxCarrySpeed = 160`
  - `MaxMomentumChainSpeed = 160`
  - `AirGravityScale = 0.52`
  - `LowGravityMinYVelocity = -140`
  - `SlideJumpGravityScale = 0.48`
  - `SlideJumpLowGravityDuration = 0.45`
  - `MomentumChainGravityScale = 0.55`
  - `AirControlStrength = 0.02`
  - `AirTurnResponsiveness = 0.01`
  - `AirDrag = 0.999`
  - `MaxSlideSlopeSpeed = 160`
- Verified live `MovementController` contains `slideJumpLowGravityUntil`, `slide_jump_blocked carrySpeed`, active low-gravity scale debug, and slide-jump low-gravity expiry debug.
- Compared live Studio sources against the `Level/` repo mirror with matching rolling checksums:
  - `MovementConfig` length `2332`, checksum `229534118`
  - `MovementController` length `52406`, checksum `914719137`

### Rollback

- Revert `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`, and this changelog entry.
- In live `Poziom`, restore the previous sources for `game.ReplicatedStorage.ModuleScripts.MovementConfig` and `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController` if needed.

## 2026-06-16 - Poziom strict slide jump carry threshold

### Scope

- Narrowed `doSlideJump` so slide jump only fires when the real carried horizontal velocity from `motion.lastSlideVelocity` or `HumanoidRootPart.AssemblyLinearVelocity` meets `SlideJumpMinCarrySpeed`.
- Removed the fallback that could synthesize slide-jump carry from slide direction / move direction and raise it to the minimum speed.
- Kept velocity assignment before `clearMotion()` and left dash, sprint, UI blocking, RunStarted / RunEnded, and movement upgrade attributes untouched.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Synced the patched `MovementController` source into live `Poziom`.
- Verified live `MovementController` contains `doSlideJump`.
- Verified live `MovementConfig` contains `SlideJumpEnabled = true`, `SlideJumpMaxCarrySpeed = 140`, and `MaxMomentumChainSpeed = 140`.
- Verified live `loadstring(...)` compilation for:
  - `game.ReplicatedStorage.ModuleScripts.MovementConfig`
  - `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`
- Compared live Studio sources against the `Level/` repo mirror with matching rolling checksums:
  - `MovementConfig` length `2230`, checksum `209857942`
  - `MovementController` length `51463`, checksum `608303684`

### Rollback

- Revert `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua` and this changelog entry.
- In live `Poziom`, restore `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController` to the previous source if needed.

## 2026-06-16 - Poziom movement slope speed cap alignment

### Scope

- Aligned the `Level` movement config with the requested momentum-chain tuning by raising `MaxSlideSlopeSpeed` from `85` to `140`.
- Kept the existing chain momentum, slide jump, landing slide resume, terrain ground grace, air control, dash, sprint, multijump, and movement upgrade compatibility code intact.

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.ModuleScripts.MovementConfig`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Synced the patched `MovementConfig` source into live `Poziom`.
- Verified live `loadstring(...)` compilation for:
  - `game.ReplicatedStorage.ModuleScripts.MovementConfig`
  - `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`
- Fresh-required a clone of live `MovementConfig` and confirmed:
  - `MaxMomentumChainSpeed = 140`
  - `MaxSlideSlopeSpeed = 140`
  - `SlideJumpEnabled = true`
  - `SlideLandingResumeEnabled = true`
  - `SlidePreserveYVelocity = true`
  - `SlideHardMaxDurationEnabled = false`
  - `SlideGroundGraceTime = 0.16`
- Compared live Studio sources against the `Level/` repo mirror with matching rolling checksums:
  - `MovementConfig` length `2230`, checksum `209857942`
  - `MovementController` length `51569`, checksum `124290970`

### Rollback

- Revert `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua` and this changelog entry.
- In live `Poziom`, restore `game.ReplicatedStorage.ModuleScripts.MovementConfig` to the previous source value if needed.

## 2026-06-16 - Sync open Studio instances into git mirrors

### Scope

- Synced both open Roblox Studio instances into the historical repo mirrors:
  - `Poziom` -> `Level/`
  - `Cztery szczyty` -> `Four Peaks/`
- Exported current `Script`, `LocalScript`, and `ModuleScript` sources from the active Studio data models without deleting repo-only files.
- Preserved the existing historical mirror naming where a matching repo file already existed, and created missing `.lua` mirrors for live Studio scripts that did not yet have a repo file.
- Left non-Studio work outside the sync scope unstaged, including `backend/roblox-error-bridge/node_modules/`.

### Verification

- Confirmed both Roblox Studio instances were available through MCP.
- Exported `159/159` script sources from `Poziom` with `0` errors.
- Exported `163/163` script sources from `Cztery szczyty` with `0` errors.
- Local export summary: `322` script requests, `227` written files, `163` newly created files, `95` unchanged files, `0` errors.

### Rollback

- Revert the sync commit to restore the previous repo mirror state.
- Live Studio was only read during this pass; no Studio object sources were modified.

## 2026-06-16 - Poziom chain movement slide jump and landing slide resume

### Scope

- Extended the existing `Level` movement controller with chain momentum instead of replacing the movement system.
- Added slide-jump support so pressing jump during an active grounded slide transfers the stronger current/slide horizontal velocity, applies jump Y velocity, ends the slide with reason `slide_jump`, and marks the player as carrying chain momentum.
- Added chain-aware speed limits through `MaxMomentumChainSpeed` so slide jump, air jumps after slide jump, airborne momentum, landing momentum, and landing slide resume do not clamp back to normal `MaxAirHorizontalSpeed` / `MaxHorizontalSpeed`.
- Added landing slide resume so holding slide while landing from chain momentum can automatically restart slide without requiring a fresh input press or normal slide cooldown.
- Landing slide resume uses carried horizontal velocity projected over the ground normal, applies `SlideLandingFriction`, and does not grant the normal fresh slide boost when `SlideLandingNoFreshBoost = true`.
- Added debug logs gated by `DebugMovement = true` for `slide_jump`, `landing_slide_resume`, air jump carry speed, and normalized slide-end reasons:
  - `slide_jump`
  - `input_released`
  - `speed_low`
  - `lost_ground`
  - `blocked_state`
  - `hard_max`
- Kept dash, sprint, multijump, low gravity, UI blocking, RunStarted / PauseState / RunEnded guards, and existing movement upgrade attributes intact.

### Config added

- `MaxMomentumChainSpeed = 140`
- `SlideJumpEnabled = true`
- `SlideJumpHorizontalMultiplier = 1.0`
- `SlideJumpExtraUpVelocity = 0`
- `SlideJumpMinCarrySpeed = 8`
- `SlideJumpMaxCarrySpeed = 140`
- `SlideJumpCountsAsJump = true`
- `SlideLandingResumeEnabled = true`
- `SlideLandingResumeGraceTime = 0.25`
- `SlideLandingMinCarrySpeed = 10`
- `SlideLandingBypassCooldown = true`
- `SlideLandingNoFreshBoost = true`
- `SlideLandingFriction = 0.995`

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.ModuleScripts.MovementConfig`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Fetched the patched repo sources into Studio through a temporary local HTTP server and verified `loadstring(...)` compiles for both movement files before assigning live `Source`.
- Synced the patched sources into live `Poziom`.
- Fresh-required a clone of live `MovementConfig` and confirmed all new chain movement config values.
- Verified live `MovementController` source contains:
  - `doSlideJump`
  - `tryStartLandingSlide`
  - `getMaxMomentumChainSpeed`
  - `getSlideSpeedLimit`
- Live post-sync checksums:
  - `MovementConfig` length `2229`, checksum `209712992`
  - `MovementController` length `51569`, checksum `124290970`

### Not tested

- Did not complete a hands-on Play Solo movement route across real Terrain slopes for the full chain:
  - downhill slide
  - slide jump
  - multijump
  - held-slide landing resume
  - continued downhill acceleration

### Risks

- The exact feel of chain speed retention still needs live tuning on the real `Poziom` terrain.
- `MaxMomentumChainSpeed = 140` allows much higher horizontal speed than regular movement, so collision, camera feel, and terrain edge cases should be playtested.
- Landing slide resume currently clears the chain if landing speed is below `SlideLandingMinCarrySpeed`; that prevents sticky auto-slide starts but may need tuning if slow downhill chains should continue.

### Rollback

- Revert `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`, and this changelog entry.
- In live `Poziom`, restore the previous sources for `game.ReplicatedStorage.ModuleScripts.MovementConfig` and `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`.

## 2026-06-16 - Poziom terrain slide grace, smoother slope tuning, and air momentum limits

### Scope

- Tuned the existing `Level` movement config for smoother Terrain sliding and weaker Megabonk-style air steering.
- Added slide config keys:
  - `SlideGroundGraceTime = 0.16`
  - `SlideHardMaxDurationEnabled = false`
  - `SlidePreserveYVelocity = true`
- Updated active slide ground checks so transient `Freefall` does not count as lost ground while the slide raycast still sees valid ground.
- Added slide ground-loss grace handling with debug logs for temporary loss and recovery.
- Changed slide velocity application to preserve current Y velocity by default and only drive horizontal X/Z movement.
- Removed the default hard hold-duration cutoff for held slides unless `SlideHardMaxDurationEnabled` is explicitly enabled.
- Adjusted slope and friction tuning:
  - `SlopeAcceleration = 35`
  - `DownhillSpeedGainMultiplier = 1.0`
  - `UphillDeceleration = 18`
  - `UphillSlowdownMultiplier = 0.65`
  - `FlatSlideFriction = 0.999`
  - `SlideSurfaceTransitionFriction = 0.9995`
  - `MinSlideEndSpeed = 3`
  - `MaxSlideSlopeSpeed = 85`
- Adjusted air momentum tuning:
  - `AirControlStrength = 0.025`
  - `AirTurnResponsiveness = 0.012`
  - `AirDrag = 0.998`
- Kept existing movement upgrade hooks, UI blocking, run/pause/end guards, and slide/dash/sprint binds intact.

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ReplicatedStorage.ModuleScripts.MovementConfig`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Verified the pre-change repo and live Studio movement source checksums matched.
- Synced the patched movement sources into live `Poziom` through Roblox MCP after `loadstring(...)` compiled both fetched repo files successfully.
- Live post-sync checksums:
  - `MovementConfig` length `1807`, checksum `136640403`
  - `MovementController` length `41632`, checksum `457259256`

### Not tested

- Did not run a hands-on Play Solo traversal across real Terrain slopes, ramps, and ledges in this pass.

### Risks

- The new slide grace and higher downhill acceleration should smooth Terrain contact jitter, but the exact feel still needs live tuning on the real `Poziom` map.
- `SlideEdgeLaunchEnabled` remains active, so losing ground beyond grace may still transition into the existing edge-launch behavior.
- Air control is intentionally much weaker; players may need a small tuning pass if it feels too locked-in after jump.

### Rollback

- Revert `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`, and this changelog entry.
- In live `Poziom`, restore the previous sources for `game.ReplicatedStorage.ModuleScripts.MovementConfig` and `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`.

## 2026-06-08 - Poziom raycast movement with slope slide, multi-jump, and air momentum

### Scope

- Added `Level`-only movement configuration in `ReplicatedStorage.ModuleScripts.MovementConfig`.
- Reworked `MovementController` slide handling to use `HumanoidRootPart.AssemblyLinearVelocity` for forward boost, slope-aware velocity projection, horizontal momentum preservation, friction-based decay, and horizontal speed clamping instead of relying on `WalkSpeed` alone.
- Bound slide to `LeftControl`, `C`, and the pre-existing controller `ButtonX` path.
- Added raycast-based grounded checks with slope validation through `GroundCheckDistance` and `MaxSlopeAngle`.
- Added configurable multi-jump with a default of `2` total jumps, responsive `JumpRequest` handling, air-jump cooldown, grounded reset, and X/Z momentum preservation.
- Added Megabonk-like air momentum and drag with configurable turn responsiveness, air control strength, max air speed, and landing momentum carry.
- Tightened multi-jump state tracking with `jumpsUsed`, `lastJumpTime`, `lastAirJumpTime`, `leftGroundTime`, `CanAirJumpAfterGroundLeaveDelay`, and `LandingResetDelay` so short raycast ground contacts cannot refresh infinite air jumps.
- Increased the air-jump-to-air-jump cooldown to `1.0` second while keeping the initial ground-leave debounce responsive.
- Added character-local low gravity through a HumanoidRootPart `VectorForce` named `LowGravityForce`, gated by airborne state and `LowGravityMinYVelocity`, without changing `workspace.Gravity`.
- Extended slide behavior with hold-to-continue timing, slope-plane projection, downhill acceleration, uphill slowdown, flat friction, minimum end speed, and slope speed clamping.
- Tuned slide feel so slope-to-flat transitions carry momentum longer, downhill acceleration is softer, slide off an edge launches with preserved X/Z momentum, and holding slide while standing on a valid slope starts a slow downhill slide.
- Added respawn-safe movement state cleanup plus character-specific connection cleanup so slide/jump state does not get stuck after death or respawn.
- Preserved existing `Level` movement progression hooks by keeping compatibility with `MoveSlideLevel`, `MoveDashLevel`, `MoveSprintLevel`, `RunStat_ExtraJumps`, and `RunStat_JumpHeight`.
- Did not touch `Four Peaks/` or unrelated combat, enemy, spell, reward, mission, inventory, lobby, or blacksmith logic.

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.ModuleScripts.MovementConfig`
- `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`

### Verification

- Confirmed the active Studio instance was `Poziom` and re-set it active before live edits.
- Created the live `ReplicatedStorage.ModuleScripts.MovementConfig` module in `Poziom` and synced the updated `MovementController` source into `StarterPlayer.StarterPlayerScripts.LocalScript`.
- Verified `loadstring(script.Source)` compiles for:
  - `ReplicatedStorage.ModuleScripts.MovementConfig`
  - `StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`
- Fresh-required the live `MovementConfig` module through a temporary clone and confirmed the expected values were returned, including:
  - `SlideKeyCodes = 3`
  - `MaxJumps = 2`
  - `MaxHorizontalSpeed = 75`
  - `AirJumpCooldown = 1.0`
  - `LowGravityEnabled = true`
  - `SlideHoldEnabled = true`
  - `FlatSlideFriction = 0.997`
  - `SlopeAcceleration = 18`
  - `DownhillSpeedGainMultiplier = 0.6`
  - `MaxSlideSlopeSpeed = 78`
  - `SlideEdgeLaunchEnabled = true`
  - `SlopeAutoSlideStartSpeed = 4`
- Verified the live movement source now contains the raycast ground-check path, slope projection helper, strict jump tracking variables, low gravity `VectorForce` path, slide hold, and air momentum heartbeat updates.
- Compared live Studio sources against the `Level/` repo mirror with matching rolling checksums for:
  - `MovementConfig` length `1704`, checksum `40890859`
  - `MovementController` length `38901`, checksum `616545619`
- Ran `git diff --check` on the touched movement/changelog files; the only output was existing LF/CRLF conversion warnings for edited files.

### Risks

- This pass verified source sync and compile safety, but it did not include a full in-session movement playtest with manual ramp/slope traversal, repeated air-jump timing, dash interaction, or respawn during an active slide in a live player runtime.
- The new raycast ground check, air drag, and landing carry are intentionally conservative defaults, but they still need a quick hands-on pass in Studio to tune feel on the real `Poziom` terrain and ramps.

### Rollback

- Revert `Level/ReplicatedStorage/ModuleScripts/MovementConfig.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua`, and this changelog entry in the repo.
- In live Studio, remove or restore `game.ReplicatedStorage.ModuleScripts.MovementConfig` and restore the previous source of `game.StarterPlayer.StarterPlayerScripts.LocalScript.MovementController`.

## 2026-06-08 - Poziom mob overhead names and HP bars removed

### Scope

- Disabled the client-side NPC overhead `BillboardGui` creation in `NpcPresentation`, which removes the mob name label and HP bar shown above enemies.
- Added a server-side `Humanoid` display shutdown in `NpcService.Register(...)` so Roblox built-in humanoid names and health UI also stay hidden for registered mobs.
- Kept combat stats, boss bar behavior, and NPC identity attributes unchanged.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`
- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.StarterPlayer.StarterPlayerScripts.LocalScript.NpcPresentation`
- `game.ServerScriptService.ModuleScript.NpcService`

### Verification

- Confirmed the active Studio instance was `Poziom` and re-set it active before live edits.
- Verified the live `NpcPresentation` source now contains `SHOW_NPC_NAMEPLATES = false` and an early return in `ensureHealthbar(...)`.
- Verified the live `NpcService` source now sets:
  - `Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None`
  - `Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff`
  - `Humanoid.NameDisplayDistance = 0`
  - `Humanoid.HealthDisplayDistance = 0`
- Confirmed the repo mirrors the same changes in `Level/...`.

### Risks

- This pass updates the runtime sources that create overhead UI, but it did not include a full in-session playtest with spawned enemies visible on screen after the change.
- If any future system intentionally expects per-mob overhead UI from `NpcPresentation`, it will now need a separate explicit toggle instead of assuming the billboard is always present.

### Rollback

- Revert `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`, `Level/ServerScriptService/ModuleScript/NpcService.lua`, and this changelog entry in the repo.
- In live Studio, restore the previous source of `game.StarterPlayer.StarterPlayerScripts.LocalScript.NpcPresentation` and `game.ServerScriptService.ModuleScript.NpcService`.

## 2026-06-07 - Gildia real Guild Treasury

### Scope

- Turned the physical `Treasury` / `Skarbiec` location in the `Guild` place from a placeholder into a real server-authoritative treasury panel.
- Added real treasury remotes in the `Guild` place:
  - `RemoteFunctions.GetTreasury`
  - `RemoteFunctions.DepositToTreasury`
  - `RemoteFunctions.SpendFromTreasury`
  - `RemoteEvents.GuildTreasuryUpdated`
- Kept `RemoteEvents.GuildLocationOpened`; the `Treasury` prompt now sends `Location.Panel = "Treasury"` and opens the real panel instead of a `Coming soon` placeholder.
- Added treasury resource mapping to `GuildConfig`:
  - `Silver -> profile.silver`
  - `Souls -> profile.souls`
  - `Tickets -> profile.tickets`
  - `WeaponPoints -> profile.weaponPoints`
  - `MobMaterial:<id> -> profile.crafting.mobMaterials[id]`
  - `UpgradeMaterial:<id> -> profile.crafting.upgradeMaterials[id]`
  - `MineResource:<id> -> profile.crafting.mineResources[id]`
- Added server-side deposit validation:
  - guild membership
  - allowed resource id
  - positive integer amount
  - sufficient player resource balance
  - DataStore-backed profile deduction
  - DataStore-backed guild treasury increment
  - contribution and guild XP increase
- Added server-side spend validation:
  - guild membership
  - Owner/Officer role
  - allowed resource id
  - positive integer amount
  - sufficient guild treasury balance
  - DataStore-backed guild treasury decrement
- Added treasury history entries with:
  - `userId`
  - `username`
  - `resourceId`
  - `amount`
  - `createdAt`
  - plus `action` and `reason`
- Added same-server live refresh through `GuildTreasuryUpdated`; open treasury panels refresh without closing and the main Guild UI refreshes too.
- Updated lobby `GuildService` compatibility so future lobby saves preserve:
  - `guild.treasury.resources`
  - `guild.memberContributions`
  - `guild.totalContribution`
  - `guild.treasuryHistory`
- Kept existing lobby Donate behavior compatible and updated it to maintain the new treasury metadata.
- Did not touch `Level/`.

### Data fields added or preserved

- `guild.treasury.resources[resourceId] = amount`
- `guild.memberContributions[userId] = contribution`
- `guild.totalContribution`
- `guild.treasuryHistory[]`

Currency treasury values are still also kept on the existing top-level keys (`guild.treasury.Silver`, `Souls`, `Tickets`, `WeaponPoints`) for existing lobby UI compatibility.

### Files updated

- `Guild/ReplicatedStorage/ModuleScripts/GuildConfig.lua`
- `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- `Guild/StarterPlayer/StarterPlayerScripts/LocalScript/GuildCastleClient.lua`
- `Guild/Workspace/GuildLocations/MANIFEST.md`
- `Four Peaks/ServerScriptService/ModuleScript/GuildService.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Gildia`: `game.ReplicatedStorage.ModuleScripts.GuildConfig`
- `Gildia`: `game.ServerScriptService.Script.GuildPlace`
- `Gildia`: `game.StarterPlayer.StarterPlayerScripts.GuildCastleClient`
- `Gildia`: `game.ReplicatedStorage.RemoteFunctions.GetTreasury`
- `Gildia`: `game.ReplicatedStorage.RemoteFunctions.DepositToTreasury`
- `Gildia`: `game.ReplicatedStorage.RemoteFunctions.SpendFromTreasury`
- `Gildia`: `game.ReplicatedStorage.RemoteEvents.GuildTreasuryUpdated`
- `Cztery szczyty`: `game.ServerScriptService.ModuleScript.GuildService`

### Verification

- Confirmed active Studio was `Gildia` for Guild-place work and `Cztery szczyty` for the lobby compatibility sync.
- Enabled Studio `HttpService.HttpEnabled` for the session and synced local sources into live Studio through a temporary local HTTP server.
- Verified live `loadstring` compilation for:
  - `GuildConfig`
  - `GuildPlace`
  - `GuildCastleClient`
  - lobby `GuildService`
- Ran Play Solo in `Gildia` as the saved `Pinecone` guild Owner:
  - `GetTreasury` returned `Success = true`
  - role was `Owner`
  - `CanSpend = true`
  - player resources included real `Silver` and material resources
  - physical `Treasury` prompt returned `Location.Panel = "Treasury"`
  - treasury panel opened with title `Skarbiec [Owner]`
  - `Donate` button existed
  - spend section was visible for Owner
  - donate amount `0` returned `Amount must be positive.`
  - donate greater than player balance returned `Not enough Silver.`
  - fake resource id returned `Unknown treasury resource.`
  - spend amount `0` returned `Amount must be positive.`
  - valid `Silver` donate decreased player Silver and increased guild Silver
  - valid donate increased player contribution and total contribution
  - valid Owner spend decreased guild Silver
  - treasury history count increased for deposit/spend
  - open treasury panel stayed visible after donate/spend refresh
  - after respawn, counts stayed stable: one `GuildCastleGui`, one return button, seven location buttons, one Donate button, one Spend button, and seven prompts
  - after stop/start Play, the saved treasury state persisted
  - return-to-lobby flow still emitted `Teleporting`, then the expected Studio `TeleportFailed`
- Checked Output after Play; only the existing StyleRule `CornerRadius` warnings appeared.

### Live test data touched

- The `Pinecone` guild test record received small live-test changes:
  - successful treasury deposits of `Silver`
  - successful test spends of `Silver`
  - treasury history entries for those actions

### Not tested

- A true second client/member role test was not available through the current MCP surface. Member spend denial was source-verified in `SpendFromTreasury`: the server requires `Owner` or `Officer` before spending.
- A successful cross-place teleport still cannot complete in this Studio session; Studio returns `TeleportFailed`, as before.
- Cross-server live refresh is not implemented; `GuildTreasuryUpdated` refreshes same-server Guild-place members.

### Risks

- Deposit is split across player profile and guild DataStores. If the guild update fails after profile deduction, the server attempts a profile refund.
- Material resource display uses saved material ids because the `Guild` place does not currently mirror `CraftingConfig` display metadata.
- Existing lobby Donate remains supported, but future full cross-place treasury refresh would need MessagingService fanout.

### Rollback

- Revert the files listed above and this changelog entry.
- In live `Gildia`, restore previous sources for `GuildConfig`, `GuildPlace`, and `GuildCastleClient`.
- In live `Gildia`, remove `GetTreasury`, `DepositToTreasury`, `SpendFromTreasury`, and `GuildTreasuryUpdated` if rolling back the treasury system entirely.
- In live `Cztery szczyty`, restore the previous `GuildService` source.
- Existing guild records with `treasury.resources`, `memberContributions`, `totalContribution`, and `treasuryHistory` can remain; older code will ignore or drop those fields on future saves if the compatibility changes are rolled back.

## 2026-06-07 - Gildia physical guild location placeholders

### Scope

- Added physical placeholder locations to the `Guild` place castle hub:
  - `Dojo`
  - `Treasury`
  - `HallOfFame`
  - `Farms`
  - `Mine`
  - `Fishing`
  - `BossRaid`
- Added `Workspace.GuildLocations` as the location container in live `Gildia`.
- Each location is a separate `Model` with placeholder parts, a visible `BillboardGui` name label, and one `GuildLocationPrompt` `ProximityPrompt`.
- Updated `GuildPlace` so the server idempotently creates/refreshes the placeholder models and validates guild membership before firing the location panel remote.
- Added `RemoteEvents.GuildLocationOpened` for server-to-client location panel payloads.
- Updated `GetGuildCastleState` to return the physical location list with id, name, description, status, and in-castle hint text.
- Updated `GuildCastleClient`:
  - location tiles now show the physical area hint instead of being UI-only tabs
  - prompt responses open a modal with location name, description, `Coming soon`, and close button
  - refreshed location tiles are cleared/rebuilt so respawn refreshes do not duplicate UI
- Added `Guild/Workspace/GuildLocations/MANIFEST.md` to document the important non-script Workspace structure.
- Kept the existing return-to-lobby flow intact.
- Did not touch `Level/`.

### Files updated

- `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- `Guild/StarterPlayer/StarterPlayerScripts/LocalScript/GuildCastleClient.lua`
- `Guild/Workspace/GuildLocations/MANIFEST.md`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Gildia`: `game.ServerScriptService.Script.GuildPlace`
- `Gildia`: `game.StarterPlayer.StarterPlayerScripts.GuildCastleClient`
- `Gildia`: `game.ReplicatedStorage.RemoteEvents.GuildLocationOpened`
- `Gildia`: `game.Workspace.GuildLocations`
- `Gildia`: `game.Workspace.GuildLocations.{Dojo,Treasury,HallOfFame,Farms,Mine,Fishing,BossRaid}`

### Verification

- Confirmed active Studio was `Gildia`.
- Verified edit-mode `Workspace.GuildLocations` has 7 child models.
- Verified every location model has exactly one `ProximityPrompt` and one `BillboardGui`.
- Verified live `GuildPlace` and `GuildCastleClient` sources compile with `loadstring`.
- Ran Play Solo in `Gildia` as the saved guild member/owner for `Pinecone`:
  - `GetGuildCastleState` returned success for `Pinecone`
  - `Locations` returned 7 entries
  - all 7 prompts fired `GuildLocationOpened` with the expected `Location.Id`
  - each prompt payload included the expected name, description, and `Status = "Coming soon"`
  - the location panel rendered the selected location title and status
  - respawn kept counts stable at one `GuildCastleGui`, one `ReturnToLobbyButton`, seven location buttons, one close button, and seven prompts
  - `RequestLobbyReturn` still fired the existing return flow and returned `Teleporting`, then the expected Studio `TeleportFailed`
- Checked Output after Play; only the existing StyleRule `CornerRadius` warnings appeared.
- Ran `git diff --check` on touched paths; only the existing LF/CRLF warning for `CHANGELOG_AI.md` appeared.

### Not tested

- A true no-guild second client was not available through the current MCP tool surface. The prompt handler was source-verified to call `getAuthorizedGuild(player)` before opening the panel, and the client has no `FireServer` path for `GuildLocationOpened`.
- A successful cross-place return teleport cannot complete in this Studio session; Studio returned the expected `TeleportFailed`.
- MCP could not synthesize a real mouse click on the close button because `VirtualInputManager.SendMouseButtonEvent` lacks capability in this context. The close button exists and the source binds its `Activated` handler.

### Risks

- The geometry is placeholder-only and is intentionally simple.
- Location systems are not implemented yet; no combat upgrades, treasury management, rankings, production, mining, fishing, farming, or raid gameplay was added.
- The placeholder layout is centered around the current simple Guild place baseplate/spawn setup and may need art/layout adjustment once a full castle model is authored.

### Rollback

- Revert the files listed above and this changelog entry.
- In live `Gildia`, restore the previous `GuildPlace` and `GuildCastleClient` sources.
- Remove `game.ReplicatedStorage.RemoteEvents.GuildLocationOpened`.
- Remove `game.Workspace.GuildLocations` if rolling back the physical placeholders entirely.

## 2026-06-02 - Cztery szczyty Guild privacy, requests, and invites

### Scope

- Added guild privacy control to the lobby guild system:
  - `privacy = "Public" | "Private"`
  - `joinRequests`
  - `invites`
- Public guilds still join immediately through `JoinGuild`.
- Private guilds create a join request through `RequestJoin` instead of direct membership.
- Added server-authoritative owner/officer actions:
  - `SetPrivacy`
  - `AcceptJoinRequest`
  - `RejectJoinRequest`
  - `SendInvite`
  - `CancelInvite`
  - `AcceptInvite`
  - `DeclineInvite`
- Kept existing owner-only role management, kick, description edit, disband, leave, donate, upgrade, and teleport flows intact.
- Extended `GuildUpdated` broadcast usage so privacy/request/invite/member changes refresh online guild members and the affected requester/invitee when present.
- Updated lobby `GuildClient`:
  - shows `Public` / `Private` status
  - shows `Join` for public guilds and `Request to Join` for private guilds
  - adds `Requests` and `Invites` tabs
  - shows privacy toggle to Owner/Officer only
  - lets Owner/Officer accept/reject requests and send/cancel invites
  - lets invited no-guild players accept/decline invites
- Updated `Guild` place castle panel so `GetGuildCastleState` returns and renders guild privacy.
- Did not touch `Level/`.

### Data fields added

- `guild.privacy`
- `guild.joinRequests[userId] = { userId, username, createdAt }`
- `guild.invites[userId] = { userId, username, invitedByUserId, createdAt }`

### Remotes updated

- Existing `RemoteFunctions.GuildAction` dispatch now handles:
  - `RequestJoin`
  - `SetPrivacy`
  - `AcceptJoinRequest`
  - `RejectJoinRequest`
  - `SendInvite`
  - `CancelInvite`
  - `AcceptInvite`
  - `DeclineInvite`
- Existing `RemoteEvents.GuildUpdated` is reused for live refresh.
- Existing `Guild` place `RemoteFunctions.GetGuildCastleState` now includes `Guild.Privacy`.
- No new lobby remote objects were added.

### Files updated

- `Four Peaks/ServerScriptService/ModuleScript/GuildService.lua`
- `Four Peaks/ServerScriptService/Script/GuildRemotes.server.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/GuildClient.lua`
- `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- `Guild/StarterPlayer/StarterPlayerScripts/LocalScript/GuildCastleClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Cztery szczyty`: `game.ServerScriptService.ModuleScript.GuildService`
- `Cztery szczyty`: `game.ServerScriptService.Script.GuildRemotes`
- `Cztery szczyty`: `game.StarterPlayer.StarterPlayerScripts.GuildClient`
- `Gildia`: `game.ServerScriptService.Script.GuildPlace`
- `Gildia`: `game.StarterPlayer.StarterPlayerScripts.GuildCastleClient`

### Verification

- Confirmed active Studio instances and synced `Cztery szczyty` and `Gildia` through Roblox MCP.
- Verified live `loadstring` compilation for:
  - `GuildService`
  - `GuildRemotes`
  - `GuildClient`
  - `GuildPlace`
  - `GuildCastleClient`
- Ran Play Solo in `Cztery szczyty` as the `Pinecone` guild owner:
  - `GetGuildState` returned `CanManageJoin = true`
  - initial privacy was `Public`
  - `SetPrivacy` changed the guild to `Private`
  - `SearchGuilds` returned `Privacy = Private`
  - `SetPrivacy` restored the guild to `Public`
  - sending an invite to the current guild member failed with `Player is already in this guild.`
  - lobby UI showed `Requests` and `Invites` tabs
  - lobby UI showed `Guild privacy: Public`
  - owner UI showed `Join controls` and `Make Private`
- Ran Play Solo in `Gildia`:
  - `GetGuildCastleState` returned `Privacy = Public`
  - castle UI rendered `Public`
  - `ReturnToLobbyButton` still existed exactly once
- Checked Output in both places after Play; only the existing StyleRule `CornerRadius` warnings appeared.
- Ran `git diff --check` on touched Lua files with no issues.

### Not tested

- A true 2-player Studio flow was not available through the current MCP controls, so these were not fully live-tested end-to-end:
  - player2 sends request from a separate client
  - owner sees that request without closing UI
  - owner accepts and player2 becomes a member in a live two-client session
  - player3 joins a public guild from a separate client
  - member-side hidden/denied controls in a real second client
  - officer request handling in a real second client
- Request/invite persistence after rejoin was verified by DataStore-backed implementation and compile/runtime smoke tests, but not by a multi-client rejoin flow in Studio.
- `Guild` place does not duplicate request/invite management; it renders privacy only. Privacy changes remain in the canonical lobby `GuildService`.

### Risks

- `AcceptJoinRequest` currently requires the requester to be online so the existing `PlayerData` membership can be updated through the established PlayerData path.
- Cross-server request/invite refresh still depends on same-server `GuildUpdated`; a future MessagingService fanout would be needed for multi-server live refresh.
- Invites can be sent by userId or username; username resolution uses Roblox player-name APIs and may fail if the platform lookup fails.

### Rollback

- Revert the files listed above and this changelog entry.
- In live `Cztery szczyty`, restore previous sources for `GuildService`, `GuildRemotes`, and `GuildClient`.
- In live `Gildia`, restore previous sources for `GuildPlace` and `GuildCastleClient`.
- Existing guild records with `privacy`, `joinRequests`, or `invites` will be ignored by older code if rolled back, but can remain in DataStore until a cleanup pass is explicitly requested.

## 2026-06-02 - Gildia basic castle UI data panel

### Scope

- Expanded the `Guild` place castle UI from an attribute-only placeholder into a server-backed guild panel.
- Added `ReplicatedStorage.RemoteFunctions.GetGuildCastleState` in the `Guild` place.
- Updated `GuildPlace` so `GetGuildCastleState` validates the player through the same server-side profile/guild-record membership path before returning guild data.
- The castle state now returns:
  - guild name, description, level, XP
  - treasury values for Silver, Souls, Tickets, and WeaponPoints
  - member count and same-server online member count
  - the current player's guild role and contribution
- Updated `GuildCastleClient` to render the server snapshot in `GuildCastleGui`.
- Kept `ReturnToLobbyButton` and the existing server-authoritative lobby return flow intact.
- Added a `Lokacje gildii` section with buttons for Dojo, Skarbiec, Sala chwały, Farmy, Kopalnia, Łowiska, and Boss Raid. These are MVP placeholders that select the tile and show `Coming soon`.
- Kept `GuildCastleGui.ResetOnSpawn = false` and refreshed the server snapshot on respawn without creating duplicate UI.
- Did not touch `Level/`.

### Files updated

- `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- `Guild/StarterPlayer/StarterPlayerScripts/LocalScript/GuildCastleClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Gildia`: `game.ServerScriptService.Script.GuildPlace`
- `Gildia`: `game.StarterPlayer.StarterPlayerScripts.GuildCastleClient`
- `Gildia`: `game.ReplicatedStorage.RemoteFunctions.GetGuildCastleState`

### Verification

- Confirmed active Studio was `Gildia`.
- Synced the updated Guild place sources into live Studio through Roblox MCP using temporary `GuildPlaceNext` / `GuildCastleClientNext` scripts, compiled them, then copied their sources onto the live scripts.
- Verified live `loadstring` compilation for `GuildPlace` and `GuildCastleClient`.
- Verified live remotes:
  - `RemoteEvents.RequestLobbyReturn`
  - `RemoteEvents.LobbyReturnStatus`
  - `RemoteFunctions.GetGuildCastleState`
- Ran Play in `Gildia` as the saved guild member/owner:
  - `GetGuildCastleState` returned `Pinecone`
  - description loaded as `jabadabaduuu jabadabaduuu jabadabaduuu jabadabaduuu`
  - level loaded as `3`
  - XP loaded as `1,245`
  - treasury loaded with `Silver = 9,028`, `Souls = 0`, `Tickets = 0`, `WeaponPoints = 0`
  - member count loaded as `2`
  - online member count loaded as `1`
  - player role loaded as `Owner`
  - `GuildCastleGui` existed with exactly one `ReturnToLobbyButton`
  - seven location buttons existed after render
- Re-tested the return flow:
  - `RequestLobbyReturn` still used server-side `LOBBY_PLACE_ID = 88516424167732`
  - Studio TeleportService returned `TeleportFailed`
  - the UI showed `Return to lobby failed. Try again.` and re-enabled the button
- Killed/respawned the player in Play and verified:
  - one `GuildCastleGui` before and after respawn
  - one `ReturnToLobbyButton` before and after respawn
  - seven location buttons before and after respawn
- Checked Studio Output after Play; only the existing StyleRule `CornerRadius` warnings appeared.
- Ran `git diff --check` on touched Guild Lua files with no issues.

### Not tested

- A two-player Studio test was not available through the current MCP controls, so online count was verified with one active Guild-place player against a guild record with two total members.
- MCP could not synthetically click a location `TextButton`; the live button instances and the client `Activated` handler for `Coming soon` were verified by source and runtime hierarchy.
- A no-guild runtime client was not available in this session. The existing join rejection plus `GetGuildCastleState` membership validation remain server-side and do not rely on client teleport data.

### Risks

- `OnlineMemberCount` currently counts players online in the same Guild-place server. A cross-server/cross-place online presence count would need a separate presence service.
- The location buttons are placeholder UI only; no location systems are implemented yet.

### Rollback

- Revert the files listed above and this changelog entry.
- In live `Gildia`, restore the previous `GuildPlace` and `GuildCastleClient` sources and remove `RemoteFunctions.GetGuildCastleState` if rolling back the castle data panel entirely.

## 2026-06-02 - Gildia return-to-lobby server-authoritative flow

### Scope

- Added a server-authoritative return path from the `Guild` place back to the `Four Peaks` lobby.
- Set the known live place ids from the connected Studio instances:
  - `GuildConfig.GUILD_PLACE_ID = 89635326813830`
  - `GuildConfig.LOBBY_PLACE_ID = 88516424167732`
- Added `ReplicatedStorage.RemoteEvents.RequestLobbyReturn` and `LobbyReturnStatus` in the `Guild` place.
- Updated `GuildPlace` so the client never sends a place id; the server reads `LOBBY_PLACE_ID`, verifies the player still has valid guild authorization, and teleports with `guildId` preserved in teleport data.
- Added a visible `ReturnToLobbyButton` to the castle UI with failure status handling and no polling.
- Added a Studio-only direct Play fallback that reads the saved server-side guild membership when teleport data is unavailable, so the Guild place can be tested locally without weakening live client authority.
- Mirrored the live lobby `GUILD_PLACE_ID` into the repo config to avoid future repo-to-Studio drift.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/GuildConfig.lua`
- `Guild/ReplicatedStorage/ModuleScripts/GuildConfig.lua`
- `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- `Guild/StarterPlayer/StarterPlayerScripts/LocalScript/GuildCastleClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Gildia`: `game.ReplicatedStorage.ModuleScripts.GuildConfig`
- `Gildia`: `game.ServerScriptService.Script.GuildPlace`
- `Gildia`: `game.StarterPlayer.StarterPlayerScripts.GuildCastleClient`
- `Gildia`: `game.ReplicatedStorage.RemoteEvents.RequestLobbyReturn`
- `Gildia`: `game.ReplicatedStorage.RemoteEvents.LobbyReturnStatus`
- `Cztery szczyty`: `game.ReplicatedStorage.ModuleScripts.GuildConfig`

### Verification

- Confirmed active Studio instances and place ids:
  - `Cztery szczyty` lobby: `88516424167732`
  - `Gildia` place: `89635326813830`
- Synced the Guild place scripts into live `Gildia` through Roblox MCP after HTTP sync was blocked by disabled Studio HTTP requests.
- Verified live `loadstring` compilation for `GuildConfig`, `GuildPlace`, and `GuildCastleClient`.
- Verified live `RequestLobbyReturn` and `LobbyReturnStatus` exist as `RemoteEvent` instances.
- Ran Play in `Cztery szczyty` and verified the existing guild state for `Pinecone` returns `GuildPlaceId = 89635326813830`.
- Invoked `TeleportToCastle` from the lobby through the existing server RemoteFunction; the server used the configured Guild place id, but Studio returned the expected `Teleport failed.` result for this cross-place test session.
- Ran Play in `Gildia`:
  - verified the player loaded into the saved guild `Pinecone`
  - verified `GuildCastleGui` exists
  - verified exactly one `ReturnToLobbyButton` exists
  - fired `RequestLobbyReturn` without passing a place id
  - captured `LobbyReturnStatus` payloads with `LobbyPlaceId = 88516424167732`
  - verified TeleportService failure returns `TeleportFailed`, shows `Return to lobby failed. Try again.`, and re-enables the button
  - killed/respawned the player and verified the button count stayed at `1`
- Checked Studio Output after Play; only the existing StyleRule `CornerRadius` warnings appeared.
- Ran `git diff --check` on the touched paths with no issues.

### Not tested

- A successful live cross-place teleport from `Gildia` back to `Cztery szczyty` could not complete in this Studio session because TeleportService returned failure in Studio.
- A true no-guild second-player abuse test was not available through the current MCP tool surface. The server-side handler was verified to require `GuildCastleReady`, saved profile membership, and guild-record membership before teleporting.

### Risks

- The return flow depends on both places remaining in the same published experience and `LOBBY_PLACE_ID` staying current.
- Studio direct Play fallback is guarded by `RunService:IsStudio()` and uses saved server-side membership; it should not affect live joins.

### Rollback

- Revert the files listed above and this changelog entry.
- In live `Gildia`, restore the previous `GuildConfig`, `GuildPlace`, and `GuildCastleClient` sources and remove `RequestLobbyReturn` / `LobbyReturnStatus` if rolling back the return flow entirely.
- In live `Cztery szczyty`, restore the previous `GuildConfig` source if the Guild place id should return to a placeholder.

## 2026-06-02 - Cztery szczyty Guild live refresh push

### Scope

- Added server-push refresh for the lobby Guild UI.
- Added `ReplicatedStorage.RemoteEvents.GuildUpdated` from `GuildRemotes`.
- Updated `GuildService` to broadcast `GuildUpdated` to online guild members after guild mutations:
  - create/join/leave
  - description edits
  - promote/demote/kick
  - disband
  - donate/treasury/XP updates
  - upgrades and guild task progress
- Updated `GuildClient` to listen for `GuildUpdated` and refresh the currently open panel through `GetGuildState` without closing it.
- Kept the selected tab state local to the client; pushed refresh re-renders the active tab instead of forcing the default tab.
- Did not add polling.

### Files updated

- `Four Peaks/ServerScriptService/ModuleScript/GuildService.lua`
- `Four Peaks/ServerScriptService/Script/GuildRemotes.server.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/GuildClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Cztery szczyty`: `game.ServerScriptService.ModuleScript.GuildService`
- `Cztery szczyty`: `game.ServerScriptService.Script.GuildRemotes`
- `Cztery szczyty`: `game.StarterPlayer.StarterPlayerScripts.GuildClient`
- `Cztery szczyty`: `game.ReplicatedStorage.RemoteEvents.GuildUpdated`

### Verification

- Confirmed active Studio was `Cztery szczyty`.
- Synced the updated guild sources into live Studio through Roblox MCP.
- Verified live `loadstring` compilation for `GuildService`, `GuildRemotes`, and `GuildClient`.
- Verified `ReplicatedStorage.RemoteEvents.GuildUpdated` exists in live Studio.
- Ran Play in Studio:
  - opened `GuildGui`
  - invoked a Silver donate directly through `GuildAction` rather than through `GuildClient.invokeAction`; the open UI refreshed through `GuildUpdated`, showing XP `1,244 -> 1,245` and contribution `10,000 -> 10,010` without closing the panel
  - demoted an existing non-owner member from `Officer` to `Member` through direct `GuildAction`; the open member list refreshed without closing the panel
  - promoted the same member back to `Officer`; the open member list refreshed again and final role was restored to `Officer`
- Checked Studio Output after the Play test; only existing StyleRule `CornerRadius` warnings appeared.
- Ran `git diff --check` on touched files with no issues.

### Not tested

- A true two-client Studio test was not available through the current Roblox MCP tool surface; `start_stop_play` launched one `LocalPlayer`, and MCP exposed no Start Server with 2 players control.
- The player2 join/leave/kick visual path was not fully live-tested with two visible clients, but the same server broadcast path was verified for donation and role changes while the panel stayed open.

### Risks

- Push refresh is in-server only. If future guild edits happen from another live server, cross-server MessagingService fanout would still be needed.
- Kicked/offline players still rely on the existing membership repair path on next guild state load; online kicked players receive an extra refresh event.

### Rollback

- Revert the files listed above and this changelog entry.
- In live `Cztery szczyty`, restore previous sources for `GuildService`, `GuildRemotes`, and `GuildClient`, and remove `ReplicatedStorage.RemoteEvents.GuildUpdated` if rolling back the push event entirely.

## 2026-06-01 - Cztery szczyty Guild MVP and Guild place scaffold

### Scope

- Added a server-authoritative Guild MVP for the `Four Peaks` lobby.
- Added `GuildConfig` with `GUILD_PLACE_ID = 0` placeholder and upgrade/task/donation config.
- Added `GuildService` for create/search/join/leave, owner description/role/kick/disband actions, donations, treasury, upgrades, member contribution ranking, guild task progress API, and guild-castle teleport data.
- Added `Guild` membership fields to the existing `PlayerData` profile schema.
- Added `GuildRemotes` with `GetGuildState`, `SearchGuilds`, and `GuildAction` RemoteFunctions.
- Added programmatic `GuildClient` UI opened by the existing live `ScreenGuiButtons.Frame.Guild` button.
- Mirrored the live `Guild` button into `ScreenGuiButtons/studio.snapshot.json`.
- Added a repo scaffold for a separate `Guild/` place with server membership validation and a basic castle panel.
- Kept `Level/`, blacksmith, missions, inventory, shop, party, and existing dungeon teleport scripts untouched.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/GuildConfig.lua`
- `Four Peaks/ServerScriptService/ModuleScript/GuildService.lua`
- `Four Peaks/ServerScriptService/ModuleScript/PlayerData.lua`
- `Four Peaks/ServerScriptService/Script/GuildRemotes.server.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/GuildClient.lua`
- `Four Peaks/StarterGui/ScreenGuiButtons/ScreenButtonsClient.lua`
- `Four Peaks/StarterGui/ScreenGuiButtons/studio.snapshot.json`
- `Guild/ReplicatedStorage/ModuleScripts/GuildConfig.lua`
- `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- `Guild/StarterPlayer/StarterPlayerScripts/LocalScript/GuildCastleClient.lua`

### Live Studio objects updated

- `Cztery szczyty`: `game.ReplicatedStorage.ModuleScripts.GuildConfig`
- `Cztery szczyty`: `game.ServerScriptService.ModuleScript.GuildService`
- `Cztery szczyty`: `game.ServerScriptService.ModuleScript.PlayerData`
- `Cztery szczyty`: `game.ServerScriptService.Script.GuildRemotes`
- `Cztery szczyty`: `game.StarterPlayer.StarterPlayerScripts.GuildClient`
- `Cztery szczyty`: `game.StarterGui.ScreenGuiButtons.ScreenButtonsClient`
- `Cztery szczyty`: `game.ReplicatedStorage.RemoteFunctions.{GetGuildState,SearchGuilds,GuildAction}`

### Verification

- Confirmed active Studio was `Cztery szczyty`.
- Confirmed the live `StarterGui.ScreenGuiButtons.Frame.Guild` `ImageButton` exists.
- Synced the updated lobby sources into live Studio through Roblox MCP.
- Verified live `loadstring` compilation for `GuildConfig`, `GuildService`, `GuildRemotes`, `GuildClient`, `PlayerData`, and `ScreenButtonsClient`.
- Ran Play Solo in the lobby:
  - verified `GuildGui` exists and opens through the same `ScreenButtonsAction`/`ScreenButtonsNonce` path used by `ScreenButtonsClient`
  - created a guild and verified name, description area, level, XP, owner role, and member list
  - verified the left tab labels render, including `Opis`, `Pod zadania 0/5`, `Donate`, `Dojo`, `Skarbiec`, `Farmy, kopalnia i łowiska`, and `Sala chwały`
  - verified search returns the created guild
  - verified an oversized Silver donation fails with `Not enough Silver`
  - verified a valid Silver donation subtracts player Silver and increases guild treasury/XP/task progress
  - verified Dojo upgrade fails without enough treasury Silver, then succeeds after enough donation
  - verified owner management UI text renders for the owner
  - verified `LeaveGuild` works and disbands when the owner is the last member
  - verified `DisbandGuild` works for the owner and is denied when the player has no owner membership
  - verified `TeleportToCastle` reads `GUILD_PLACE_ID`, passes the current `guildId` in state, and returns the expected placeholder failure while `GUILD_PLACE_ID = 0`
- Checked Studio Output after Play Solo; only pre-existing StyleRule `CornerRadius` warnings appeared.
- Checked `ScreenGuiButtons/studio.snapshot.json` parses as JSON.
- Ran `git diff --check` on touched files; only existing LF/CRLF conversion warnings were reported.

### Not tested

- A true physical/synthetic mouse click on the `Guild` button could not be fired through MCP because `VirtualInputManager:SendMouseButtonEvent` is blocked in the current command capability; the live button object and source hookup were verified, and the exact ScreenButtons attribute open path was tested.
- A two-player Studio server test was not available through the current MCP controls, so player2 join/promote/demote/kick and member-side owner-action denial were not live-tested.
- The separate `Guild` place was not synced into Studio because the only extra open Studio instance was another `Cztery szczyty`, not a Guild place.
- Real teleport cannot be completed until `GUILD_PLACE_ID` is set to the published Guild place id.

### Risks

- Guild membership is saved in the existing `PlayerData` profile; the shared guild record uses `GuildRecords_v1` plus a small `GuildDirectory_v1` DataStore because guilds are shared across players.
- If a member is kicked while offline, their profile membership is repaired the next time the guild state is loaded and the server sees they are no longer in the guild record.
- Current guild DataStore writes are MVP-grade and server-authoritative inside the active server; high-concurrency cross-server guild edits may need an UpdateAsync conflict strategy later.
- `GUILD_PLACE_ID` is intentionally `0`, so the lobby returns a clear not-configured response instead of attempting an invalid teleport.

### Rollback

- Revert the files listed above and this changelog entry.
- In live `Cztery szczyty`, remove `GuildConfig`, `GuildService`, `GuildRemotes`, `GuildClient`, and the three guild RemoteFunctions, then restore the previous `PlayerData` and `ScreenButtonsClient` sources.
- Remove the repo-only `Guild/` place scaffold if the separate place is postponed.

## 2026-06-01 - Poziom normal mob distance despawn and spawn emergence

### Scope

- Added automatic despawn for normal dungeon mobs when their nearest alive player is more than `100` studs away.
- Kept elites and bosses exempt from the distance despawn.
- Added a client-side spawn presentation where newly synced mobs start below ground, rise into place, and briefly show a dirt puff.
- Kept NPC remote names, attributes, folder paths, enemy templates, and wave spawn rules unchanged.

### Files updated

- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.ServerScriptService.ModuleScript.NpcService`
- `Poziom`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.NpcPresentation`

### Verification

- Confirmed active Studio was `Poziom`.
- Synced the updated `NpcService` and `NpcPresentation` sources into live Studio through Roblox MCP.
- Verified both live sources compile with `loadstring`.
- Verified the live sources contain the `NORMAL_DESPAWN_DISTANCE = 100` despawn path and the spawn-rise presentation helpers.
- Started a Play smoke test, but MCP Luau execution landed in the client context and could not access `ServerScriptService`, so a forced server-side despawn scenario was not completed.
- Checked the Studio console after the Play attempt; only existing StyleRule `CornerRadius` warnings were present.
- Ran `git diff --check` on the touched Lua files; it reported only existing LF/CRLF conversion warnings.

### Risks

- Distance despawn is based on flat X/Z distance to the nearest alive player, matching the existing NPC movement and spawn-ring distance style.
- Normal mobs that fall behind during rapid player movement will disappear instead of pathing back from off-screen.
- The emergence effect is client-side visual presentation only; server spawn position and combat timing remain unchanged.

### Rollback

- Revert `Level/ServerScriptService/ModuleScript/NpcService.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`, and this changelog entry.
- In live `Poziom`, restore the previous sources of `game.ServerScriptService.ModuleScript.NpcService` and `game.StarterPlayer.StarterPlayerScripts.LocalScript.NpcPresentation`.

## 2026-06-01 - Poziom Daily Missions board text binding fix

### Scope

- Fixed the dungeon `DailyMissionsClient` so authored mission card text fields can be `TextLabel`, `TextBox`, or `TextButton`.
- The live board now replaces the default placeholder text like `Kill 9 elite enemies` with the server-selected daily mission descriptions and progress.
- Kept the daily mission remotes, mission selection logic, and UI hierarchy unchanged.

### Files updated

- `Level/StarterGUI/DailyMissions.ScreenGui/DailyMissionsClient.LocalScript.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Poziom`: `game.StarterGui.DailyMissions.DailyMissionsClient`

### Verification

- Confirmed active Studio was `Poziom`.
- Verified live `DailyMissionsClient` compiles with `loadstring`.
- Ran a Play smoke test and inspected `PlayerGui.DailyMissions`; the six notes showed live mission text/progress such as rerolls, revenge elite, 15 elites, coins, spending, and boss phase instead of the default placeholder text.
- Checked the Studio console after the smoke test; only existing StyleRule `CornerRadius` warnings were present.
- Ran `git diff --check` on the touched client file; it reported only the existing LF/CRLF conversion warning.

### Risks

- This fixes the visible board text binding; it does not change which daily missions are selected or how their counters progress.
- Any already-running play session needs a fresh client copy of `DailyMissionsClient`.

### Rollback

- Revert `Level/StarterGUI/DailyMissions.ScreenGui/DailyMissionsClient.LocalScript.lua` and this changelog entry.
- In live `Poziom`, restore the previous source of `game.StarterGui.DailyMissions.DailyMissionsClient`.

## 2026-06-01 - Lobby/level profile cache and loadout sync fix

### Scope

- Fixed stale global `PlayerData` cache after leaving a place by adding `PlayerData.Release` plus `PlayerRemoving` cleanup in both `Four Peaks` and `Level`.
- Kept the existing save path, but now clears in-memory `GlobalPlayerProgress_v1` data so a returning player reloads the latest level-written profile instead of an old lobby copy.
- Updated lobby `PortalToDungeon` weapon resolution to fall back to `PlayerData.Loadout[1]` when `PlayerStateStore` has no equipped weapon instance, preserving older/saved loadouts for dungeon teleport.
- Kept remote names, attributes, folders, and broader inventory/mission systems unchanged.

### Files updated

- `Four Peaks/ServerScriptService/ModuleScript/PlayerData.lua`
- `Four Peaks/ServerScriptService/Script/PortalToDungeon.lua`
- `Level/ServerScriptService/ModuleScript/PlayerData.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Cztery szczyty`: `game.ServerScriptService.ModuleScript.PlayerData`
- `Cztery szczyty`: `game.ServerScriptService.Script.PortalToDungeon`
- `Poziom`: `game.ServerScriptService.ModuleScript.PlayerData`

### Verification

- Confirmed both Studio instances were available through Roblox MCP.
- Synced the repo changes into live `Cztery szczyty` and `Poziom`.
- Verified live Luau compilation with `loadstring` for the updated `PlayerData` modules and `PortalToDungeon`.
- Verified live markers for cache release, cache clearing, and profile loadout fallback.
- Ran short Play smoke tests in both places; console output showed only existing StyleRule `CornerRadius` warnings and no new sync/loadout/daily mission errors.
- Ran `git diff --check` on the touched files; it reported only existing LF/CRLF conversion warnings.

### Risks

- This fixes stale profile reads on future leave/return cycles; an already-running play session that loaded the old module may need a fresh Play/server session.
- If a DataStore write fails during `PlayerRemoving`, the in-memory cache is still cleared, so the next place relies on the latest persisted DataStore state rather than a retry from the old server cache.
- The weapon fallback only uses `PlayerData.Loadout` when no concrete equipped weapon instance is available from `PlayerStateStore`.

### Rollback

- Revert the three files listed above and this changelog entry.
- In live Studio, restore the previous sources of `PlayerData` in both places and `PortalToDungeon` in `Cztery szczyty`.

## 2026-05-31 - Cztery szczyty limited-time Events system

### Scope

- Added a server-authoritative limited-time Events system for the `Four Peaks` lobby with the first event `Blood Moon`.
- Added shared `EventsConfig` and `EventUtil` modules with exact `ComingSoon`, `Active`, and `Ended` statuses, UTC Unix windows, Studio-only zero-date fallback, event sorting, and timer formatting.
- Added `Events.Progress` profile data in Four Peaks `PlayerData`, sanitized on load with per-event stats and claimed reward maps.
- Added `EventService` and `EventRemotes` with `GetEventsState` and `ClaimEventReward`, server-side validation, per-player claim locking/rate limiting, and real reward grants for tickets, WP, souls, and materials.
- Added `EventsClient`, a programmatic dark fantasy `EventsGui` opened by the existing `ScreenGuiButtons/Events` button through `ScreenButtonsClient`.
- Added minimal `Level/` progress bridge modules and hooks so dungeon kills, elite kills, chest opens, and victorious run completions update active event progress in the shared profile.
- Left Daily Login Rewards, daily/weekly mission rewards, WP conversion, banner/gacha ticket balances, and unrelated backend dirty files untouched.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/EventsConfig.lua`
- `Four Peaks/ReplicatedStorage/ModuleScripts/EventUtil.lua`
- `Four Peaks/ReplicatedStorage/RemoteFunctions/GetEventsState`
- `Four Peaks/ReplicatedStorage/RemoteFunctions/ClaimEventReward`
- `Four Peaks/ServerScriptService/ModuleScript/PlayerData.lua`
- `Four Peaks/ServerScriptService/ModuleScript/EventService.lua`
- `Four Peaks/ServerScriptService/Script/EventRemotes.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/EventsClient.lua`
- `Four Peaks/StarterGui/ScreenGuiButtons/ScreenButtonsClient.lua`
- `Level/ReplicatedStorage/ModuleScripts/EventsConfig.lua`
- `Level/ReplicatedStorage/ModuleScripts/EventUtil.lua`
- `Level/ServerScriptService/ModuleScript/EventProgress.lua`
- `Level/ServerScriptService/ModuleScript/MissionProgress.lua`
- `Level/ServerScriptService/Script/ChestService.server.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Cztery szczyty`: `game.ReplicatedStorage.ModuleScripts.EventsConfig`
- `Cztery szczyty`: `game.ReplicatedStorage.ModuleScripts.EventUtil`
- `Cztery szczyty`: `game.ReplicatedStorage.RemoteFunctions.GetEventsState`
- `Cztery szczyty`: `game.ReplicatedStorage.RemoteFunctions.ClaimEventReward`
- `Cztery szczyty`: `game.ServerScriptService.ModuleScript.PlayerData`
- `Cztery szczyty`: `game.ServerScriptService.ModuleScript.EventService`
- `Cztery szczyty`: `game.ServerScriptService.Script.EventRemotes`
- `Cztery szczyty`: `game.StarterPlayer.StarterPlayerScripts.EventsClient`
- `Cztery szczyty`: `game.StarterGui.ScreenGuiButtons.ScreenButtonsClient`
- `Poziom`: `game.ReplicatedStorage.ModuleScripts.EventsConfig`
- `Poziom`: `game.ReplicatedStorage.ModuleScripts.EventUtil`
- `Poziom`: `game.ServerScriptService.ModuleScript.EventProgress`
- `Poziom`: `game.ServerScriptService.ModuleScript.MissionProgress`
- `Poziom`: `game.ServerScriptService.Script.ChestService`

### Verification

- Confirmed active Studio instances and updated `Cztery szczyty` first, then `Poziom`.
- Verified live `Poziom` compilation with `loadstring` for `EventsConfig`, `EventUtil`, `EventProgress`, `MissionProgress`, and `ChestService`.
- Verified live `Cztery szczyty` compilation with `loadstring` for `EventsConfig`, `EventUtil`, `EventService`, `EventRemotes`, `EventsClient`, `PlayerData`, and `ScreenButtonsClient`.
- Required live `EventService` successfully and confirmed `GetState`/`AddProgress` are available.
- Verified the live `Events` button exists and `ScreenButtonsClient` now calls `openExclusive("EventsGui")`.
- Verified `EventUtil` reports the zero-date `Blood Moon` config as `Active` in Studio/dev mode.

### Risks

- `Blood Moon` uses `StartUnix = 0` and `EndUnix = 0`, so it is active only in Studio/dev mode; live servers require real Unix dates in both Four Peaks and Level configs before progress/claims become active.
- Title, cosmetic, and booster rewards are placeholders that log TODO warnings and mark claims safely without granting backend power.
- The dungeon bridge writes progress through the shared profile and marks it dirty; high-frequency kill progress relies on the existing save cadence rather than forcing a DataStore save per kill.
- MCP verification covered source compile and wiring, but not a full manual click-through or end-to-end Play claim session.

### Rollback

- Revert the files listed above and this changelog entry.
- In live Studio, remove the new Event modules/scripts/remotes and restore the previous sources of `PlayerData`, `ScreenButtonsClient`, `MissionProgress`, and `ChestService`.

## 2026-05-31 - Cztery szczyty Daily Login auto-open

### Scope

- Updated `DailyLoginClient` so the Daily Login panel opens automatically on lobby client startup when the server reports `CanClaim = true`.
- Kept the client passive: it only invokes `GetDailyLoginState`; reward granting remains server-authoritative through `ClaimDailyLoginReward`.
- The auto-open check runs once after a short startup delay and does not reopen the panel again after the player closes it.

### Files updated

- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/DailyLoginClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.StarterPlayer.StarterPlayerScripts.DailyLoginClient`

### Verification

- Confirmed the active Studio instance was `Cztery szczyty`.
- Synced the updated `DailyLoginClient` source into live Studio through Roblox MCP.
- Verified the live `DailyLoginClient` source compiles with `loadstring`.
- Verified the live source contains the new `autoOpenIfClaimable` startup path.
- Started and stopped a short Play smoke test; the MCP console showed only existing Studio style warnings and no DailyLogin-specific errors.

### Risks

- This opens the Daily Login modal shortly after client startup when a reward is available, so it can appear before the player manually clicks any lobby button.

### Rollback

- Revert `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/DailyLoginClient.lua` and this changelog entry.
- In live Studio, restore the previous source of `game.StarterPlayer.StarterPlayerScripts.DailyLoginClient`.

## 2026-05-31 - Cztery szczyty Daily Login Rewards system

### Scope

- Added a server-authoritative 7-day Daily Login Rewards system for the `Four Peaks` lobby.
- Added `DailyLogin` profile data to `PlayerData` with `LastClaimDayUTC`, `CurrentDay`, and `TotalClaims`, sanitized on load.
- Added `DailyLoginRewardsConfig` under `ReplicatedStorage.ModuleScripts` with the planned ticket, souls, material bundle, booster placeholder, and day-7 ticket rewards.
- Added `DailyLoginService` with UTC calendar-day claim checks, current-cycle day status payloads, per-player claim locking/rate limiting, reward granting, and explicit Day 7 -> Day 1 wraparound.
- Added `DailyLoginRemotes` with `GetDailyLoginState` and `ClaimDailyLoginReward` RemoteFunctions under `ReplicatedStorage.RemoteFunctions`.
- Added a programmatic `DailyLoginClient` UI opened by the existing `ScreenGuiButtons/Login Rewards` button through the existing `ScreenButtonsAction`/`ScreenButtonsNonce` flow.
- Extended `CurrencyService` with `Souls` balances plus `GetSouls`/`AddSouls` and generic `Souls` add/remove support.
- Extended pickup toasts with `ticket` and `souls` variants.
- Kept WP missions, daily/weekly missions, banner roll cost behavior, and `Level/` untouched.

### Files updated

- `Four Peaks/ServerScriptService/ModuleScript/PlayerData.lua`
- `Four Peaks/ServerScriptService/ModuleScript/CurrencyService.lua`
- `Four Peaks/ServerScriptService/ModuleScript/DailyLoginService.lua`
- `Four Peaks/ServerScriptService/Script/DailyLoginRemotes.lua`
- `Four Peaks/ReplicatedStorage/ModuleScripts/DailyLoginRewardsConfig.lua`
- `Four Peaks/ReplicatedStorage/RemoteFunctions/GetDailyLoginState`
- `Four Peaks/ReplicatedStorage/RemoteFunctions/ClaimDailyLoginReward`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/DailyLoginClient.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/PickupToastClient.lua`
- `Four Peaks/StarterGui/ScreenGuiButtons/ScreenButtonsClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.ModuleScripts.DailyLoginRewardsConfig`
- `game.ReplicatedStorage.RemoteFunctions.GetDailyLoginState`
- `game.ReplicatedStorage.RemoteFunctions.ClaimDailyLoginReward`
- `game.ServerScriptService.ModuleScript.PlayerData`
- `game.ServerScriptService.ModuleScript.CurrencyService`
- `game.ServerScriptService.ModuleScript.DailyLoginService`
- `game.ServerScriptService.Script.DailyLoginRemotes`
- `game.StarterPlayer.StarterPlayerScripts.DailyLoginClient`
- `game.StarterPlayer.StarterPlayerScripts.PickupToastClient`
- `game.StarterGui.ScreenGuiButtons.ScreenButtonsClient`

### Verification

- Confirmed the active Studio instance was `Cztery szczyty` before work and synced the repo sources into the live place through Roblox MCP.
- Verified live Luau compilation with `loadstring` for `DailyLoginRewardsConfig`, `PlayerData`, `CurrencyService`, `DailyLoginService`, `DailyLoginRemotes`, `DailyLoginClient`, `PickupToastClient`, and `ScreenButtonsClient`.
- Ran an MCP service probe with injected test profile data and `PlayerData.Save` stubbed to avoid DataStore writes:
  - initial state was claimable on Day 1
  - Day 1 granted `1` ticket and advanced to Day 2
  - second same-day claim failed and did not add another ticket
  - simulated next day Day 2 granted `500` souls
  - simulated next day Day 3 granted another ticket
  - Day 4 stayed on Day 4 when the material backend could not load in the MCP client context
  - Day 6 booster placeholder advanced safely to Day 7
  - Day 7 granted `2` tickets and wrapped to Day 1
- Started and stopped a short Play session after Studio sync; MCP console output showed only existing Studio style warnings and no DailyLogin-specific errors.
- Ran `git diff --check -- 'Four Peaks'`; it reported only existing LF/CRLF conversion warnings on touched files.
- Checked new Daily Login Lua files for trailing whitespace with `rg`.

### Risks

- The MCP execute context is client-like, so it cannot directly require the existing server-only `PlayerStateStore`/`CraftingService` path; Day 4 material grant still needs a real server playtest claim to verify the material bundle is added through `CraftingService`.
- `EXP Booster` is intentionally a server-side placeholder with a warning until a real booster backend exists.
- The DailyLogin UI is built programmatically rather than authored as a StarterGui tree, matching several existing lobby UI scripts but still requiring a visual click-through in Studio for final polish.

### Rollback

- Revert the files listed above.
- In live Studio, remove `DailyLoginRewardsConfig`, `DailyLoginService`, `DailyLoginRemotes`, `DailyLoginClient`, `GetDailyLoginState`, and `ClaimDailyLoginReward`.
- Restore the previous live sources of `PlayerData`, `CurrencyService`, `PickupToastClient`, and `ScreenButtonsClient`.
- No `Level/` rollback is needed because this pass did not modify dungeon files.

## 2026-05-20 - GitHub bridge backend for Roblox ErrorReporter

### Scope

- Added a standalone Cloudflare Worker backend under `backend/roblox-error-bridge/` for `POST /roblox-error`.
- The bridge validates a shared secret from the `X-Roblox-Error-Secret` header before accepting any Roblox payload.
- The bridge normalizes and truncates incoming `message`, `stackTrace`, and context fields before sending data to GitHub.
- The bridge searches GitHub Issues by `errorCode` and:
  - creates a new issue when none exists
  - updates the issue body plus posts a comment when a matching issue already exists
- The bridge creates the expected labels when possible and skips label creation failures without crashing the request path.
- The bridge handles GitHub rate-limit responses with explicit `503` responses plus `Retry-After`.
- Extended the Roblox-side `ErrorReporter.lua` in both places to send the new shared secret header and to warn when `GITHUB_BRIDGE_SECRET` is still unset.
- Updated Roblox-facing documentation so the endpoint URL and shared secret wiring are explicit on both the backend and Roblox sides.

### Files updated

- `backend/roblox-error-bridge/src/index.mjs`
- `backend/roblox-error-bridge/wrangler.toml`
- `backend/roblox-error-bridge/.dev.vars.example`
- `backend/roblox-error-bridge/README.md`
- `Level/ServerScriptService/Services/ErrorReporter.lua`
- `Four Peaks/ServerScriptService/Services/ErrorReporter.lua`
- `ROBLOX_ERROR_REPORTING.md`
- `CHANGELOG_AI.md`

### Verification

- Confirmed there was no existing backend app structure in the repo before adding the standalone bridge target.
- Reviewed the new Worker code path to confirm:
  - only `POST /roblox-error` is accepted
  - secret validation happens before payload processing
  - GitHub rate-limit errors are surfaced as `503`
  - issue create/update paths both reuse the same normalized payload
  - repeated reports are tracked in hidden issue metadata keyed by job id
- Confirmed the Roblox-side reporter now has explicit placeholders for:
  - `GITHUB_BRIDGE_URL`
  - `GITHUB_BRIDGE_SECRET`
- Did not deploy the Worker or call real GitHub APIs in this pass, so end-to-end verification still requires a real secret, repository, and Cloudflare deploy.

### Risks

- The backend is currently shipped as a ready Cloudflare Worker target, not a fully duplicated second Vercel code target, so Vercel is documented as a compatible contract rather than a separately committed runtime adapter.
- Hidden issue metadata stores per-job occurrence maxima to avoid overcounting repeated reports from the same Roblox server session; if one issue spans a very large number of unique job ids over time, that hidden metadata block will grow.
- Real GitHub label policies or repo permissions can still block label creation, though the request path now logs and continues instead of crashing.

### Rollback

- Revert the new `backend/roblox-error-bridge/` folder.
- Revert `Level/ServerScriptService/Services/ErrorReporter.lua`, `Four Peaks/ServerScriptService/Services/ErrorReporter.lua`, `ROBLOX_ERROR_REPORTING.md`, and this changelog entry.
- If desired, remove `GITHUB_BRIDGE_SECRET` usage and go back to the previous bridge URL-only Roblox configuration.

## 2026-05-20 - Roblox dual-channel error reporting with GitHub bridge payloads

### Scope

- Replaced the old Discord-only server reporter flow in both main places with a shared `ErrorReporter` module while keeping the legacy `ErrorReportService` entrypoint as a compatibility wrapper.
- Added a second HTTP transport for GitHub issue reporting through an external bridge endpoint so Roblox never needs a GitHub token.
- Added stable `errorCode` generation using `placeId + scriptName + lineNumber + sanitized message`, with `TD2-ERR-XXXXXXXX` output.
- Added per-error-code server-side occurrence tracking and a `60s` cooldown so repeated errors update counts without spamming outbound HTTP calls.
- Extended server and client bootstrap payloads to include richer fields such as `scriptName`, `lineNumber`, `phase`, `sanitizedMessage`, and the GitHub bridge payload shape.
- Added guarded `xpcall`-based wrappers around critical lobby and combat callbacks in:
  - `WaveController`
  - `SpellService`
  - `WeaponCombat.server`
  - `ProgressService`
  - `BlacksmithService`
  - `MissionRemotes` with `MissionService` context
  - `PortalToDungeon`
- Added dedicated setup and testing documentation for Roblox error reporting, backend URL placement, HTTP enablement, synthetic tests, and GitHub verification.

### Files updated

- `Level/ServerScriptService/Services/ErrorReporter.lua`
- `Four Peaks/ServerScriptService/Services/ErrorReporter.lua`
- `Level/ServerScriptService/Services/ErrorReportService.lua`
- `Four Peaks/ServerScriptService/Services/ErrorReportService.lua`
- `Level/ServerScriptService/ErrorBootstrap.server.lua`
- `Four Peaks/ServerScriptService/ErrorBootstrap.server.lua`
- `Level/StarterPlayer/StarterPlayerScripts/ClientErrorReporter.client.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/ClientErrorReporter.client.lua`
- `Level/ServerScriptService/Script/SpellService.lua`
- `Level/ServerScriptService/Script/WeaponCombat.server.lua`
- `Level/ServerScriptService/Script/ProgressService.lua`
- `Level/ServerScriptService/Script/Model.model/WaveController.lua`
- `Four Peaks/ServerScriptService/Script/BlacksmithService.lua`
- `Four Peaks/ServerScriptService/Script/MissionRemotes.lua`
- `Four Peaks/ServerScriptService/Script/PortalToDungeon.lua`
- `ROBLOX_ERROR_REPORTING.md`
- `CHANGELOG_AI.md`

### Verification

- Confirmed both Roblox Studio places were available through MCP at task start and set `Cztery szczyty` active before repo work.
- Verified the repo already had existing `ErrorReportService` plus `ErrorBootstrap` / `ClientErrorReporter` hooks in both places, then extended that structure instead of replacing the bootstrap flow wholesale.
- Ran targeted repo searches to confirm the new reporting path covers the existing Discord transport, client relay, and the named critical services.
- Reviewed diffs for the touched files to confirm:
  - both places now expose a shared `ErrorReporter.lua`
  - legacy `ErrorReportService.lua` stays as a compatibility wrapper
  - client payloads now include `rawMessage`, `stackTrace`, `scriptName`, `lineNumber`, and `phase`
  - critical server callbacks now use protected wrappers with service-specific context
- Did not run a live Roblox playtest or outbound HTTP request in Studio in this pass, so runtime validation of real webhook / bridge delivery still needs manual testing after URLs are configured.

### Risks

- `Level/` and `Four Peaks/` keep separate copies of `ErrorReporter.lua`, so future config or logic changes must be mirrored in both files unless the project later consolidates the shared code path.
- Because this pass stayed repo-side and did not sync or hot-load the scripts into live Studio, a manual Studio test is still required before considering the feature production-ready.
- Protected wrappers prevent unhandled callback crashes from disappearing silently, but any callback that errors inside a long-running spawned loop will still stop that one loop instance after reporting, which matches Roblox task error behavior but is worth monitoring in playtests.

### Rollback

- Revert all files listed in this changelog entry.
- Remove `ROBLOX_ERROR_REPORTING.md` if you want to discard the new documentation.
- Restore the previous contents of `ErrorBootstrap.server.lua`, `ClientErrorReporter.client.lua`, and the touched gameplay services if you need to return to the Discord-only reporter.
- No GitHub token rollback is needed in Roblox because the Roblox-side code never stores one.

## 2026-05-20 - Poziom Slime procedural fallback after playtest

### Scope

- Re-ran a real `Play` verification pass after the first Slime/Golem animation-object patch.
- Confirmed the first Slime pass was incomplete: the client track for `rbxassetid://99390813148093` could start, but the current live `Slime` rig still showed no meaningful visible deformation.
- Inspected the imported Slime asset targets and the live Slime rig structure and found they do not line up cleanly: the asset references target names such as `Armature`, `slime 2`, and multiple `Cube.*` targets, while the current live Slime template exposes only one visible `Bone` plus `Motor6D` joints in a different structure.
- Switched the live `Slime` template and the existing live `Workspace.Slime` model to `NpcLightweight = true` so the already-shipped procedural client presentation path now drives visible Slime motion during gameplay.
- Left the previously added `Idle/Run/Attack` animation objects in place for recordkeeping, but the live fix for Slime is now the procedural path rather than the incompatible imported asset.

### Files updated

- `Level/ReplicatedStorage/Enemies/Normal/Slime/MANIFEST.md`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.Enemies.Normal.Slime.Attributes.NpcLightweight`
- `game.Workspace.Slime.Attributes.NpcLightweight`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Started a fresh `Play` session and inspected a live `Workspace.Enemies.Slime` instance on the client.
- Verified that after `NpcLightweight = true`, the live Slime clone carries the lightweight attribute and its client-side pivot/rotation changes over time instead of remaining visually static.
- Captured two client-side snapshots of the same live Slime roughly `0.8s` apart and confirmed both translation and rotation changed during runtime.
- Kept this pass scoped to Slime because the user specifically reported Slime still looked unanimated; Golem was not changed in this follow-up pass.

### Risks

- This makes Slime use the project's procedural NPC motion path instead of the provided imported animation asset.
- If you still want authored skeletal animation on Slime later, we will need either the correct asset for the current rig or a rig/template rebuild that matches the provided asset targets.

### Rollback

- In live Studio, clear `NpcLightweight` from `game.ReplicatedStorage.Enemies.Normal.Slime` and `game.Workspace.Slime`.
- Revert `Level/ReplicatedStorage/Enemies/Normal/Slime/MANIFEST.md` and this changelog entry in the repo.

## 2026-05-20 - Poziom Slime and Golem animation loop objects

### Scope

- Restored client-side animation inputs for the live `Poziom` `Slime` and `Golem` rigs without changing the global NPC presentation code path.
- Added `Idle [Animation]`, `Run [Animation]`, and `Attack [Animation]` directly to `game.ReplicatedStorage.Enemies.Normal.Slime` with `AnimationId = rbxassetid://99390813148093`.
- Added `Idle [Animation]`, `Run [Animation]`, and `Attack [Animation]` directly to `game.ReplicatedStorage.Enemies.Elite.Golem` with `AnimationId = rbxassetid://93249939332915`.
- Added the same `Idle/Run/Attack` animation objects directly to the existing live `game.Workspace.Slime` and `game.Workspace.Golem` models, which were still missing animation descendants even after the first template-only pass.
- Updated the local repo manifests so the non-script Studio change is recorded in the historical mirror.

### Files updated

- `Level/ReplicatedStorage/Enemies/Normal/Slime/MANIFEST.md`
- `Level/ReplicatedStorage/Enemies/Elite/Golem/MANIFEST.md`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.Enemies.Normal.Slime.{Idle,Run,Attack}`
- `game.ReplicatedStorage.Enemies.Elite.Golem.{Idle,Run,Attack}`
- `game.Workspace.Slime.{Idle,Run,Attack}`
- `game.Workspace.Golem.{Idle,Run,Attack}`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Verified both live enemy templates and both preplaced `Workspace` models already expose `AnimationController` plus `Animator`.
- Confirmed that before the final pass, `ReplicatedStorage` templates had only the first `Idle` addition while `Workspace.Slime` and `Workspace.Golem` still had `0` animation descendants.
- Created the missing `Idle/Run/Attack` descendants and verified the final live asset ids are:
  - `Slime` -> `rbxassetid://99390813148093`
  - `Golem` -> `rbxassetid://93249939332915`
- Started a fresh `Play` session and confirmed a live `Workspace.Enemies.Slime` instance now exposes all three animation descendants and is actively playing the assigned track on the client.
- Ran a direct in-Play preview for cloned `Slime` and `Golem` rigs in front of the player and confirmed both animators keep the assigned track playing with advancing `TimePosition`, which verified the clips are actually moving on the target rigs during runtime.

### Risks

- This pass reuses one provided clip across `Idle`, `Run`, and `Attack`, so the enemies are now animated consistently but still do not have distinct authored movement or attack clips.
- There is still no separate live `death` animation asset on these rigs.

### Rollback

- In live Studio, delete `Idle`, `Run`, and `Attack` from `game.ReplicatedStorage.Enemies.Normal.Slime`, `game.ReplicatedStorage.Enemies.Elite.Golem`, `game.Workspace.Slime`, and `game.Workspace.Golem`.
- Revert `Level/ReplicatedStorage/Enemies/Normal/Slime/MANIFEST.md`, `Level/ReplicatedStorage/Enemies/Elite/Golem/MANIFEST.md`, and this changelog entry in the repo.

## 2026-05-12 - Poziom WindBlade persistent audio emitter pool

### Scope

- Replaced the `WindBlade` cast audio playback path with a persistent client-side emitter pool after cloned-per-cast sounds still clipped intermittently.
- Created six reusable invisible spatial audio emitters per slash variant under `workspace.SpellVFX`; each cast moves an available emitter to the visual effect position and plays its already-created `Sound` from `TimePosition = 0`.
- Decoupled audio lifetime from the `WindBlade` visual clone, so `Debris:AddItem()` can clean up particles without cutting off the slash sound.
- Kept the embedded authored sounds in the cloned `WindBlade` visual stopped/reset so the cast still plays only the selected variant.
- Normalized playback rolloff on pooled sounds with a minimum `RollOffMaxDistance` because the live asset had `Wind Slash1` at `10000` and `Wind Slash2` at `20`, which could make the second alternating hit sound clipped or effectively silent with the combat camera.
- Kept the server-side per-caster `1 / 2 / 1 / 2` alternation and all `WindBlade` damage, cooldown, hitbox, scaling, targeting, and visual particle behavior unchanged.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom`.
- Verified the live `WindBlade` asset still contains `Wind Slash1` and `Wind Slash2`, and confirmed their authored `TimeLength` values are short (`~0.31s` and `~0.48s`), so the remaining clipping was not caused by a long sample exceeding the visual cleanup buffer.
- Confirmed the live asset has mismatched rolloff (`Wind Slash1` max distance `10000`, `Wind Slash2` max distance `20`), and the pooled playback now raises the minimum playback rolloff to keep both variants audible during normal combat camera distance.
- Synced the updated `SpellVFXClient` source into live Studio and ran `loadstring(script.Source)` successfully.
- Ran `git diff --check`; it reported only LF/CRLF normalization warnings and no patch-format errors.

### Risks

- This changes the client audio implementation from clone-local playback to persistent local spatial emitters positioned at the effect, which is intentionally different from the first approach because the previous clone-bound playback still clipped.
- Full repeated combat testing is still recommended to confirm the subjective timing/volume under real run load.

### Rollback

- Revert `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua` and this changelog entry in the repo.
- In live Studio, restore the previous source of `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`.

## 2026-05-12 - Poziom WindBlade audio preload retry for replicated sounds

### Scope

- Tightened the `Poziom` `WindBlade` client audio preload path again after the alternating slash sounds could still clip and leave the following cast silent.
- Fixed a preload race where the `WindBlade` template part could exist on the client before its child `Sound` instances were fully replicated, causing the client to mark preload as already attempted too early and never build the stronger cloned playback templates later.
- Changed `SpellVFXClient` so it now re-scans the `ReplicatedStorage.Assets.Animations.WindBlade` template for missing slash sounds on later casts until the playback templates are actually captured and preloaded.
- Kept the stronger cloned playback path, delayed retry, late-load retry, spatial playback location, and per-caster `1 / 2 / 1 / 2` alternation unchanged.
- Did not change damage, cooldown, hitboxes, scaling, targeting, or any server combat flow.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom` before the sync.
- Verified the local `SpellVFXClient` source now no longer uses a one-shot `windBladeAudioPreloadStarted` gate and instead keeps trying to capture and preload missing `WindBlade` sound templates until they exist on the client.
- Synced the updated source into live Studio and re-ran a compile check with `loadstring(script.Source)`.
- Re-checked the live source for the new retryable preload state:
  - `windBladeSoundPreloaded`
  - `windBladeAudioPreloadInFlight`
  - `queueWindBladeAudioPreload`
- Ran `git diff --check`; it reported only LF/CRLF normalization warnings and no patch-format errors.

### Risks

- This specifically addresses client replication timing around the `WindBlade` sound children and should remove the path where the stronger playback templates never become available, but it still does not replace a full repeated live combat run under real load.
- If any remaining clipping still survives after this pass, the next step should be lightweight runtime telemetry around which exact sound object path played on each cast so we can prove whether the miss is asset replication, playback state, or event delivery.

### Rollback

- Revert `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua` and this changelog entry in the repo.
- In live Studio, restore the previous source of `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`.

## 2026-05-12 - Poziom WindBlade cloned playback templates and retry

### Scope

- Strengthened the `Poziom` `WindBlade` client audio path again after the first preload/buffer fix still allowed occasional clipped casts followed by one silent cast.
- Switched `WindBlade` cast playback to use preloaded cloned sound templates as the playback source, instead of relying only on the sound instances embedded in each freshly cloned visual effect.
- Kept the sound spatial by parenting the selected playback sound clone onto the cast effect clone in `workspace`.
- Added a short retry path: if the selected cast sound is not actually `Playing` shortly after `Play()`, the client resets and starts it once more, and also retries once when `Loaded` fires late.
- Increased the cleanup margin again so delayed playback has more time before the effect clone is removed by `Debris`.
- Kept the existing per-caster `1 / 2 / 1 / 2` alternation, `Wind Slash 1/2` plus `Wind Slash1/2` name compatibility, and all spell combat behavior unchanged.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom` before patching.
- Synced the updated `SpellVFXClient` source to live Studio and verified the source now contains:
  - `windBladeSoundTemplates`
  - clone-side `WindBladePlaybackSound1/2`
  - delayed retry through `task.delay(...)`
  - late-load retry through `Sound.Loaded`
  - the larger cleanup buffer
- Ran `loadstring(script.Source)` on the live `SpellVFXClient`; it compiled successfully after sync.
- Ran `git diff --check`; it reported only LF/CRLF normalization warnings and no whitespace or patch-format errors.

### Risks

- This is a stronger mitigation aimed at Roblox audio start timing on cloned effects, but it still does not replace a full repeated live combat run with real `WindBlade` casts under load.
- The cast effect still contains the embedded authored sounds for compatibility, but the actual playback path now prefers the separately preloaded sound templates to avoid stale or delayed state on the fresh effect clone.

### Rollback

- Revert `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua` and this changelog entry in the repo.
- In live Studio, restore the previous source of `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`.

## 2026-05-12 - Poziom WindBlade audio preload and cleanup buffer

### Scope

- Tightened the `Poziom` `WindBlade` client audio path to reduce intermittent cast sound clipping and silent follow-up casts after a hitch.
- Added background preload for the authored `WindBlade` sound assets through `ContentProvider:PreloadAsync` as soon as `SpellVFXClient` starts and the template is available.
- Increased the `WindBlade` clone cleanup buffer so the cloned visual stays alive longer than the longer of its particle or sound lengths, giving delayed audio playback extra room before `Debris` cleanup.
- Kept the existing `1 / 2 / 1 / 2` per-caster server toggle, sound lookup names, spatial playback source, and all combat behavior unchanged.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom` before patching.
- Re-verified the live `WindBlade` template contains the existing `Wind Slash1` and `Wind Slash2` sound assets.
- Synced the updated `SpellVFXClient` source to live Studio and verified the source now contains:
  - `ContentProvider` preload usage
  - `ensureWindBladeAudioPreloaded(...)`
  - a larger `WIND_BLADE_AUDIO_CLEANUP_BUFFER`
- Ran `loadstring(script.Source)` on the live `SpellVFXClient`; it compiled successfully after sync.
- Ran `git diff --check`; it reported only LF/CRLF normalization warnings and no whitespace or patch-format errors.

### Risks

- This pass reduces the most likely timing issue by preloading and extending clone lifetime, but it does not add a full telemetry/debug layer for missed playback events.
- If the remaining hitch turns out to come from a deeper Roblox audio engine quirk rather than delayed asset readiness or early cleanup, the next pass would likely need targeted runtime instrumentation around `Sound.Playing` / `IsLoaded` during real repeated casts.

### Rollback

- Revert `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua` and this changelog entry in the repo.
- In live Studio, restore the previous source of `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`.

## 2026-05-12 - Poziom WindBlade alternating cast audio

### Scope

- Extended the existing `Poziom` `WindBlade` cast VFX follow-up so the cloned `ReplicatedStorage.Assets.Animations.WindBlade` effect now also plays one authored spatial slash sound per cast.
- Added a per-caster `1 / 2 / 1 / 2` sound toggle on the server and included the selected variant in the existing transient `SpellVFXEvent` nova payload for `WindBlade`.
- Updated the client `WindBlade` cast visual path to resolve both spaced and unspaced sound names (`Wind Slash 1` / `Wind Slash1`, `Wind Slash 2` / `Wind Slash2`), stop/reset both sounds on the clone, and play only the selected one.
- Extended the `WindBlade` clone lifetime helper so it keeps the effect alive long enough for either particle or sound playback before `Debris` cleanup.
- Kept `WindBlade` damage, cooldown, radius, targeting, hitboxes, and the rest of the spell logic unchanged.

### Files updated

- `Level/ServerScriptService/Script/SpellService.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ServerScriptService.Script.SpellService`
- `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom` before patching.
- Verified the live asset currently contains the unspaced sound names `Wind Slash1` and `Wind Slash2`, and kept code compatibility for both spaced and unspaced variants.
- Ran `loadstring(script.Source)` checks for the live `SpellService` and `SpellVFXClient`; both compiled successfully after sync.
- Verified the synced live sources now contain:
  - `windBladeSoundToggle`
  - `windBladeSoundVariant`
  - dual-name sound lookup for `Wind Slash 1/2` and `Wind Slash1/2`
  - clone-side `playWindBladeSound(...)`
- Started Play in `Poziom` and ran a runtime clone test that mirrored the new client helper behavior:
  - variant `1` played only `Wind Slash1`
  - variant `2` played only `Wind Slash2`
  - the non-selected sound stayed stopped in both cases
- Re-checked the Studio console after the new sync and test; no new `WindBlade` script errors were produced by this pass.
- Ran `git diff --check`; it reported only LF/CRLF normalization warnings and no whitespace or patch-format errors.

### Risks

- This pass validated the server toggle path by source inspection and compile success, and validated the client playback behavior with a runtime clone test; it did not complete a full organic combat run where `SpellService` auto-casts `WindBlade` repeatedly against live enemies.
- The live asset still uses `Wind Slash1` / `Wind Slash2` naming today, so keeping both name variants in code is intentional compatibility rather than dead code.

### Rollback

- Revert `Level/ServerScriptService/Script/SpellService.lua`, `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`, and this changelog entry in the repo.
- In live Studio, restore the previous source of `game.ServerScriptService.Script.SpellService` and `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`.

## 2026-05-12 - Poziom WindBlade visual hookup and GustBurst compatibility

### Scope

- Synced the historical `GustBurst` air nova spell in the `Level` repo mirror to the current live `WindBlade` name while preserving the same spell archetype, damage, cooldown, radius, scaling, targeting, and hit behavior.
- Added a narrow legacy alias layer in `SpellDefinitions` so old `GustBurst` spell ids and `GustBurst_{Standard,Amplified}` unlock product ids resolve to `WindBlade` without breaking current `WindBlade` lookups.
- Added unlock-input normalization in `ReceiveTeleportLoadout` and `ProgressService` so stale teleport payloads or cached `UnlockedSpellsCSV` entries using the old `GustBurst` naming still unlock and offer `WindBlade`.
- Extended `SpellService.runNova` to send forward-facing `dir` and `effectPos` metadata over the existing `SpellVFXEvent` payload without changing the nova damage application or cooldown flow.
- Hooked `StarterPlayerScripts/LocalScript/SpellVFXClient` so `WindBlade` casts now clone the authored `ReplicatedStorage.Assets.Animations.WindBlade` part, orient it in front of the player toward the current attack direction, emit its authored particle set, and clean it up through `Debris:AddItem()`.
- Kept the fallback behavior silent: if `ReplicatedStorage.Assets.Animations.WindBlade` is missing, the spell keeps functioning and the custom cast visual simply does not spawn.
- Did not touch lobby/Four Peaks, did not rebalance the spell, and did not rename remotes or reorganize combat systems.

### Files updated

- `Level/ReplicatedStorage/ModuleScripts/SpellDefinitions.lua`
- `Level/ServerScriptService/Script/ReceiveTeleportLoadout.lua`
- `Level/ServerScriptService/Script/ProgressService.lua`
- `Level/ServerScriptService/Script/SpellService.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.ModuleScripts.SpellDefinitions`
- `game.ServerScriptService.Script.ReceiveTeleportLoadout`
- `game.ServerScriptService.Script.ProgressService`
- `game.ServerScriptService.Script.SpellService`
- `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom` before inspection and sync.
- Verified live `ReplicatedStorage.ModuleScripts.SpellDefinitions` already used `WindBlade` and patched both live Studio and repo to add legacy `GustBurst` alias compatibility.
- Ran compile checks with `loadstring(script.Source)` on the live `SpellDefinitions`, `SpellService`, `ProgressService`, `ReceiveTeleportLoadout`, and `SpellVFXClient` sources; all compiled successfully after the patch.
- Required a fresh live clone of `SpellDefinitions` and confirmed:
  - `GetSpell("GustBurst")` resolves to `WindBlade`
  - `GetProduct("GustBurst_Standard")` resolves to `WindBlade_Standard`
  - `GetProduct("GustBurst_Amplified")` resolves to `WindBlade_Amplified`
- Verified the live asset `ReplicatedStorage.Assets.Animations.WindBlade` exists and is a `Part`.
- Verified the live `SpellService` source now includes directional `effectPos` / `dir` data for nova payloads, and the live `SpellVFXClient` source now routes `WindBlade` nova payloads into the template-clone visual path.
- Started Play in the live `Poziom` place, spawned a local preview loop from the same `ReplicatedStorage.Assets.Animations.WindBlade` template in front of the player, captured the result on screen, and confirmed the slash particles were visible in runtime and later cleaned up (`Workspace.WindBladePreview` count returned `0` after Debris expiry).
- Ran `git diff --check`; it reported only existing LF/CRLF conversion warnings and no whitespace or patch-format errors.

### Risks

- The runtime preview confirmed the authored `WindBlade` asset is visible, oriented, and cleaned up in Play, but this pass did not force a full end-to-end combat cast from the live auto-cast loop with an organically earned `WindBlade` upgrade during a run.
- A manual verification attempt through the MCP execute tool produced one plugin-side console message (`FireAllClients can only be called from the server`) while probing the runtime context; this came from the failed test command itself, not from the patched game scripts.
- The `WindBlade` particle burst counts are name-based heuristics because the template does not carry authored emit-count metadata; if the effect reads too faint or too dense in a real combat run, the next tweak is only in `SpellVFXClient` emit counts.

### Rollback

- Revert the five `Level/...` source files listed above and this changelog entry in the repo.
- In live Studio, restore the previous sources of `SpellDefinitions`, `ReceiveTeleportLoadout`, `ProgressService`, `SpellService`, and `SpellVFXClient`.
- If you want to remove legacy compatibility as part of a later cleanup, delete the `GustBurst` alias mapping only after confirming no teleport payloads, saved unlock csv strings, or external tools still reference the old ids.

## 2026-05-11 - Four Peaks blacksmith template list, tooltips, and local character hide

### Scope

- Reworked the Four Peaks blacksmith client list rendering so it now uses the first fully authored `WeaponBackground` as the only runtime template and rebuilds the left list entirely from exact clones of that template.
- Removed the old fallback behavior that patched partial `WeaponBackground` shells in code, so empty authored shells and spacer nodes are no longer used as live tiles.
- Kept the authored UI layout, frames, padding, fonts, and borders intact by cloning the authored template node instead of synthesizing runtime child labels and frames.
- Expanded `MaterialDefinitions` with stable material metadata fields: `description`, `source`, `iconName`, `filename`, live `assetRef` resolution, and legacy alias compatibility.
- Switched material icon lookup to the new live `ReplicatedStorage.MaterialIcons` contract and added one-time warnings for missing per-material icon mappings.
- Updated the blacksmith bottom material slots to show quantities only, hide empty/missing icon frames, and drive hover tooltips from the selected weapon materials.
- Added a compact dark-fantasy tooltip overlay for bottom material slots that shows `displayName`, `description`, and `Source: ...` without changing the authored screen layout.
- Added local-only character hiding while the blacksmith UI is open by setting `LocalTransparencyModifier = 1` on character `BasePart` descendants and disabling attached local visual effects until close.
- Synced the updated Four Peaks blacksmith client path into the live `Cztery szczyty` Studio place, created the missing live `MaterialDefinitions` and `BlacksmithTheme` modules, created the live `BackButtonClient`, and created the live `ReplicatedStorage.MaterialIcons` folder contract with named `StringValue` placeholders.
- Did not rename remotes, did not replace the authored GUI tree, and did not rewrite blacksmith server systems in this follow-up.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/MaterialDefinitions.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.ModuleScripts.MaterialDefinitions`
- `game.ReplicatedStorage.ModuleScripts.BlacksmithTheme`
- `game.ReplicatedStorage.MaterialIcons`
- `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`
- `game.StarterGui.BlacksmithGui.BlacksmithGui.BackButton.BackButton.BackButtonClient`

### Verification

- Confirmed the active Roblox Studio instance was `Cztery szczyty` before syncing the live changes.
- Verified the live place now contains `MaterialDefinitions`, `BlacksmithTheme`, `BackButtonClient`, and a `ReplicatedStorage.MaterialIcons` folder with `49` named children (`Material_01`..`Material_48` plus `materials_icon`).
- Verified the synced live `BlacksmithUI` source now contains the new template-driven list path, tooltip overlay, and local character hide helpers.
- Ran `loadstring` checks in live Studio for `BlacksmithUI`, `MaterialDefinitions`, `BlacksmithTheme`, and `BackButtonClient`; all four sources compiled successfully.
- Required the live `MaterialDefinitions` module and verified metadata resolution for `Iron Ore`, generic summary icon fallback, and legacy/file alias resolution (`Slime Gem` -> `Material_24`, `Material_14.jpg` -> `Material_14`).
- Reconfirmed the authored `StarterGui.BlacksmithGui.BlacksmithGui.List.List.ScrollingFrame` still has one full `WeaponBackground` template plus empty shells/spacers, which matches the new clone-only runtime assumption.

### Risks

- The live `MaterialIcons` folder was created with the requested naming contract, but the per-material `StringValue.Value` asset ids are still blank because the actual image ids are stored in Asset Manager rather than the data model; until those ids are filled, missing icons will warn once and the affected bottom icon frames will stay hidden.
- This pass verified source compilation and live object contracts, but not a full interactive playtest of opening the blacksmith, hovering icons, and closing with a spawned local player in runtime.
- The template-driven list assumes the first fully populated `WeaponBackground` remains the canonical authored tile; if the authored GUI later changes structure, the template finder will need another small refresh.

### Rollback

- Revert `Four Peaks/ReplicatedStorage/ModuleScripts/MaterialDefinitions.lua`, `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`, and this changelog entry in the repo.
- In live Studio, restore the previous sources of `MaterialDefinitions`, `BlacksmithTheme`, `BlacksmithUI`, and `BackButtonClient`.
- In live Studio, remove `ReplicatedStorage.MaterialIcons` if you want to fully return to the pre-contract state.

## 2026-05-08 - Four Peaks blacksmith full catalog crafting UI pass

### Scope

- Added shared blacksmith material and theme modules for stable `Material_01..Material_48` IDs, display names, fallback material icon ids, rarity colors, and element colors.
- Extended the Four Peaks crafting config with the requested bow, halberd, pistol/handcannon, scythe, staff/wand, and sword recipe catalog while preserving the existing recipes.
- Normalized crafting recipes to three-material requirements and added legacy material aliases so old IDs such as `Iron Ore`, `Coal Chunk`, `Slime Gem`, and `Void Crystal` can still count toward new `Material_XX` requirements.
- Updated blacksmith snapshots so the client receives the full recipe catalog, including locked entries that are not yet found/unlocked by the player.
- Kept server-side craft validation in `CraftingService.CraftRecipe` as the authority for recipe found/unlocked state, account level, required materials, silver, and unique/already-owned weapons.
- Added generated `WeaponConfigs` entries for the missing requested weapons with conservative category-based stats, rarity, element inference, descriptions, and passive text.
- Updated `WeaponCatalog` placeholder lookup so missing exact models fall back to a concrete existing weapon template in the same category, log a warning, and do not block crafting.
- Rewired `BlacksmithUI` to render the authored `WeaponBackground` tile children, category buttons, bottom material slots, right info panel, locked/forgable state, material progress, silver progress, rarity colors, and element colors.
- Added a small repo mirror `BackButtonClient` LocalScript that fires a local `BlacksmithCloseRequested` bindable event; the main blacksmith client handles camera/UI restore through the existing close flow.
- Did not rename remotes, did not create a new ScreenGui, and did not reorganize blacksmith systems.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/MaterialDefinitions.lua`
- `Four Peaks/ReplicatedStorage/ModuleScripts/BlacksmithTheme.lua`
- `Four Peaks/ReplicatedStorage/ModuleScripts/CraftingConfig.lua`
- `Four Peaks/ReplicatedStorage/ModuleScripts/WeaponConfigs.lua`
- `Four Peaks/ServerScriptService/ModuleScript/CraftingService.lua`
- `Four Peaks/ServerScriptService/ModuleScript/WeaponCatalog.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`
- `Four Peaks/StarterGui/BlacksmithGui/BlacksmithGui/BackButton/BackButton/BackButtonClient.lua`
- `CHANGELOG_AI.md`

### Verification

- Confirmed the active Roblox Studio instance was `Cztery szczyty` before working.
- Reused the previously inspected live `StarterGui.BlacksmithGui` hierarchy for the authored tile paths, material slot paths, category buttons, and BackButton path.
- Ran `git diff --check`; it reported only existing LF/CRLF conversion warnings and no whitespace errors.
- Checked for a local Luau parser (`luau`, `luau-analyze`, `selene`) and none were available in PATH.
- This pass was implemented in the repo mirror only; the updated sources were not pushed into live Studio during this turn.

### Risks

- The authored `StarterGui.BlacksmithGui` object tree must still match the inspected paths for `WeaponBackground`, `Forgable`, `Locked`, `MaterialAmount1..3`, `Material_Icon`, and `ImageButton1..6`.
- Material icons currently use the existing generic fallback icon because the named `Material_01.jpg..Material_48.jpg` assets are not present in the repo or live place.
- Generated weapon stats, rarity, recipe costs, and element inference are conservative placeholders and may need a later balance pass.
- Missing model fallback intentionally allows crafting to continue with placeholder templates, but a Studio playtest should verify equip visuals for newly added weapons.
- Since live Studio was not synced in this pass, in-game behavior will not change until these repo sources are copied into the live Four Peaks place.

### Rollback

- Revert the newly added `MaterialDefinitions.lua`, `BlacksmithTheme.lua`, and `BackButtonClient.lua` files.
- Revert `CraftingConfig.lua`, `WeaponConfigs.lua`, `CraftingService.lua`, `WeaponCatalog.lua`, `BlacksmithUI.lua`, and this changelog entry.
- No live Studio rollback is needed for this pass unless a later follow-up syncs these repo sources into Studio.

## 2026-05-06 - Cztery szczyty blacksmith crafting UI and camera refresh

### Scope

- Reworked the lobby blacksmith client to use the existing live `BlacksmithGui` layout instead of generating a separate overlay panel at runtime.
- Updated blacksmith silver display so `Silver.Frame.TextLabel` shows only the player's current silver amount.
- Updated the three blacksmith material slots so they display only recipe materials in `Name owned/required` format and never show silver as a material.
- Converted blacksmith recipe data to a 3-material recipe model with silver kept as a separate craft cost.
- Added client-side confirm / warning popups for forge confirm, missing silver, missing materials, and already-owned unique weapons.
- Added lobby camera handoff for blacksmith open/close using `BlacksmithCameraPoint` as the look target plus a configurable local script offset and FOV restore.
- Hid lobby `Settings` and `ScreenGuiButtons` while the blacksmith UI is open, then restored their prior enabled state on close.
- Strengthened server-side blacksmith validation for weapon existence, unique ownership, material requirements, silver requirements, and client refresh after blacksmith actions.
- Did not create a new ScreenGui, did not rebuild the authored `BlacksmithGui` layout tree, and did not change upgrade/sell server systems outside the blacksmith craft validation path.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/CraftingConfig.lua`
- `Four Peaks/ServerScriptService/ModuleScript/CraftingService.lua`
- `Four Peaks/ServerScriptService/Script/BlacksmithService.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`
- `CHANGELOG_AI.md`

### Verification

- Re-read the live `Cztery szczyty` `StarterGui.BlacksmithGui` tree through Roblox MCP before patching to confirm the current authored UI paths, material slot names, list buttons, and `BlacksmithCameraPoint`.
- Confirmed `BlacksmithCameraPoint.WorldPosition` is populated in the current live lobby UI hierarchy, so the new client camera target path matches the requested source object.
- Ran `git diff --check` on the touched files; it reported only LF-to-CRLF normalization warnings and no patch-format or trailing-whitespace errors.
- No local Luau parser or linter was available in this environment, so this step was verified by targeted code inspection plus the repo diff check only.
- This change is currently mirrored in the repo files; the live Studio scripts were not rewritten automatically in this pass.

### Risks

- The new blacksmith client assumes the current live `BlacksmithGui` keeps the verified child names such as `MaterialAmount1..3`, `Forge_button`, `CategoryList`, and `BlacksmithCameraPoint`; if the authored UI tree changes again, the script paths will need another targeted refresh.
- `CameraOffset = Vector3.new(0, 2.5, 8)` is intentionally easy to flip; if the camera lands on the wrong side of the blacksmith in playtest, the likely follow-up is switching the Z offset sign rather than changing the whole camera flow.
- Recipe requirements now use exactly three materials per weapon, which is the requested UI model but does rebalance the old blacksmith costs compared with the prior 4-5 material split.
- Because this pass did not push the edited script sources back into live Studio, an in-Studio sync and playtest are still needed before treating the lobby place as updated source of truth.

### Rollback

- Revert `Four Peaks/ReplicatedStorage/ModuleScripts/CraftingConfig.lua`, `Four Peaks/ServerScriptService/ModuleScript/CraftingService.lua`, `Four Peaks/ServerScriptService/Script/BlacksmithService.lua`, `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`, and this changelog entry.
- If a later follow-up syncs these sources into live Studio and needs to be undone, restore the previous live `BlacksmithUI`, `BlacksmithService`, `CraftingService`, and `CraftingConfig` script sources there as well.

## 2026-05-02 - Poziom Slime orientation correction

### Scope

- Rotated the live `Poziom` template `ReplicatedStorage.Enemies.Normal.Slime` by `+90 deg` around `Y` during the first pass, then followed up with a runtime-facing fix after confirming template rotation alone was not enough.
- Updated `NpcPresentation.client.lua` so enemy visuals can apply an optional per-model facing correction through attribute `NpcFacingYawDegrees`.
- Set `NpcFacingYawDegrees = 90` on the live `ReplicatedStorage.Enemies.Normal.Slime` template so the slime can face correctly relative to `RootPart` during runtime presentation.
- Rechecked `ReplicatedStorage.Enemies.Elite.Golem` with the same asset-side inspection and left it unchanged for now.
- Added a local manifest note under the historical `Level/` mirror so the repo records the live `Slime` template correction and the current parity caveat.
- Did not change `WaveController`, `NpcService`, remotes, tags, or enemy balance values.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`
- `Level/ReplicatedStorage/Enemies/Normal/Slime/MANIFEST.md`
- `CHANGELOG_AI.md`

### Verification

- Confirmed the active Roblox Studio instance was `Poziom` before making the live asset change.
- Rotated the live `ReplicatedStorage.Enemies.Normal.Slime` model in Studio and re-read the template descendants afterward to confirm the custom rig still keeps `PrimaryPart = RootPart`, `AnimationController`, `Animator`, `RootPart/Bone`, `InitialPoses`, and `AnimSaves`.
- Identified the real runtime cause in `NpcPresentation.client.lua`: the client preserves a cached `root -> pivot` offset, so rotating the whole template does not change the model facing relative to `RootPart`.
- Patched the local repo and the live `Poziom` `NpcPresentation` script to multiply the cached `root -> pivot` offset by optional `NpcFacingYawDegrees`.
- Set `NpcFacingYawDegrees = 90` on the live `Slime` template and confirmed the attribute is present.
- Ran a targeted clone plus `PivotTo(CFrame.lookAt(...))` spot-check for both `Slime` and `Golem`; both templates accepted the same runtime-style transform without errors, and `Golem` was left unchanged.
- Added a manifest entry in the local `Level/` mirror documenting the live correction and marking the older placeholder subtree as a stale historical snapshot.

### Risks

- The `Golem` check in this environment was structural and transform-based, not a full visual playtest inside a running client session, so a manual in-Studio look is still the best final confirmation.
- The chosen `NpcFacingYawDegrees = 90` value is based on the reported symptom and runtime presentation path; if the slime still faces the wrong side in a live playtest, the likely follow-up is flipping the sign to `-90` rather than changing the whole system again.
- The historical `Level/ReplicatedStorage/Enemies/Normal/Slime` snapshot still contains the older placeholder subtree; the new manifest documents that drift, but it does not yet replace the entire non-script mirror with an exact live export.

### Rollback

- In Roblox Studio, clear or reset `ReplicatedStorage.Enemies.Normal.Slime` attribute `NpcFacingYawDegrees`.
- Revert the live `NpcPresentation` script change so it no longer applies runtime facing yaw offsets.
- Optionally rotate `ReplicatedStorage.Enemies.Normal.Slime` by `-90 deg` around `Y` if you also want to undo the initial template rotation.
- Remove `Level/ReplicatedStorage/Enemies/Normal/Slime/MANIFEST.md`.
- Revert this changelog entry.

## 2026-05-02 - Poziom apostrophe-safe item icon lookup

### Scope

- Extended the `Poziom` client icon lookup so chest reward previews and run item tiles can resolve item icons when Studio asset names use typographic apostrophes instead of ASCII apostrophes.
- Kept the existing runtime `ReplicatedStorage.Assets.Items/<Rarity>/<ItemName>` approach and did not move icon ids into `ChestItemConfig`.
- Did not change chest reward server logic, inventory payloads, rarity logic, or Roblox Studio object names.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/RunStatsHud.client.lua`
- `CHANGELOG_AI.md`

### Verification

- Compared live `ReplicatedStorage.Assets.Items` against `ChestItemConfig.Items` and confirmed the remaining mismatches were apostrophe variants only.
- Re-read both local HUD scripts after patching to confirm icon lookup now tries the exact name plus straight and curly apostrophe fallbacks.
- Synced the updated HUD scripts to live `Poziom` and re-verified repo/live source parity after write.

### Risks

- This fix intentionally normalizes only apostrophe variants; if future icon names diverge in other punctuation or spacing, those items will still need either another fallback or a dedicated mapping.
- The historical local mirror under `Level/ReplicatedStorage/Assets/Items` may still lag behind the live Studio asset tree even though runtime lookup now resolves all current live icons.

### Rollback

- Restore the previous exact-name-only icon lookup in `ChestRewardClient.client.lua` and `RunStatsHud.client.lua`.
- Revert this changelog entry.

## 2026-05-02 - Poziom mixed-rarity chest roll preview

### Scope

- Updated the `Poziom` chest reward client so the rolling preview cycles through item candidates from multiple rarities instead of only the final reward rarity.
- Kept the actual final chest reward, chest token flow, Space skip / accept behavior, and fallback reward handling unchanged.
- Did not change server reward logic, payloads, item definitions, or any Roblox Studio object names.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `CHANGELOG_AI.md`

### Verification

- Re-read the local `ChestRewardClient` after patching to confirm the preview sequence now builds from multiple rarity buckets before revealing the final reward.
- Synced the same source to the live `Poziom` Studio `ChestRewardClient` script and re-verified repo/live source parity by length and rolling checksum.

### Risks

- The roll preview is now intentionally more visually varied, so it no longer hints at the final reward rarity during the animation.
- If a future balance pass expects rarity-specific tease behavior during the roll, this preview builder will need a dedicated weighting rule instead of the current mixed-bucket shuffle.

### Rollback

- Restore the previous same-rarity candidate logic in `ChestRewardClient.client.lua`.
- Revert this changelog entry.

## 2026-05-02 - Poziom chest Space accept and right-to-left run items

### Scope

- Fixed the `Poziom` chest reward client so `Space` still works for chest skip / accept while the reward GUI is open, even if Roblox marks that input as already processed.
- Repositioned the run items grid to fill from the top-right toward the left in 4 columns, while keeping the existing `AcquisitionIndex` ordering.
- Did not change server inventory ordering, remote payloads, or chest reward server flow.
- Did not rename any Roblox Studio objects, remotes, attributes, or tags.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/RunStatsHud.client.lua`
- `CHANGELOG_AI.md`

### Verification

- Re-read the local client HUD scripts after patching to confirm the `Space` handler no longer exits early on `gameProcessedEvent` when the chest reward GUI is open.
- Verified the run items grid now uses `Horizontal` fill, `TopRight` start corner, and right alignment while preserving `LayoutOrder`.
- Synced both updated scripts to the live `Poziom` Studio place and re-verified repo/live source parity by length and rolling checksum.

### Risks

- `Space` is now intentionally honored for the chest reward GUI regardless of `gameProcessedEvent`, so any future modal that reuses this exact pattern should be checked for unintended key overlap.
- The right-to-left item layout preserves current acquisition ordering, which means the oldest visible item stays furthest right; if the desired UX later changes to "newest on the far right," that will require a separate ordering change.

### Rollback

- Restore the previous `InputBegan` guard in `ChestRewardClient.client.lua`.
- Restore the previous grid alignment settings in `RunStatsHud.client.lua`.
- Revert this changelog entry.

## 2026-05-02 - Poziom chest reward overlay removal

### Scope

- Removed the full-screen darkening overlay behind the chest reward window in `Poziom`.
- Kept the chest roll animation, item icons, input flow, and modal logic unchanged.
- Did not rename any Roblox Studio objects, remotes, attributes, or tags.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `CHANGELOG_AI.md`

### Verification

- Verified the local chest reward client now sets the screen-dim frame transparency to `1`.
- Synced the same source change into the live `Poziom` Studio `ChestRewardClient` script and re-verified source parity after write.

### Risks

- The chest reward modal will no longer visually separate itself from the world with a darkened backdrop, so readability now depends only on the card styling.

### Rollback

- Restore `dim.BackgroundTransparency` in `ChestRewardClient.client.lua` to the previous value.
- Revert this changelog entry.

## 2026-05-02 - Poziom HUD icon sync and live Studio update

### Scope

- Synced the `Poziom` client HUD scripts into live Roblox Studio for the chest reward, run stats, run items, and chest modal cursor behavior.
- Extended the chest reward modal and run items HUD to use runtime icon lookup from `ReplicatedStorage.Assets.Items/<Rarity>/<ItemName>`.
- Kept the existing text fallback for missing rarity folders, missing item names, and fallback chest rewards.
- Added a historical repo mirror for the current `Level/ReplicatedStorage/Assets/Items` Studio structure using placeholder `.ImageLabel` files.
- Did not rename any Roblox Studio objects, remotes, attributes, tags, rarity folders, or item names.
- Did not change server reward logic, payload shapes, or `ChestItemConfig` APIs.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/RunStatsHud.client.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/CameraMouseLock.lua`
- `Level/ReplicatedStorage/Assets/Items/Common/Bent Dagger.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Cracked Heartstone.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Heavy Pebble.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Lucky Pebble.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Old Magnet.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Runner's Laces.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Rusty Buckler.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Sharp Splinter.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Silver Shaving.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Tin Coin.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Torn Page.ImageLabel`
- `Level/ReplicatedStorage/Assets/Items/Common/Training Gloves.ImageLabel`
- `CHANGELOG_AI.md`

### Verification

- Confirmed the active Studio instance was `Poziom` before making any live edits.
- Re-read the live `ChestRewardClient`, `RunStatsHud`, and `CameraMouseLock` scripts after sync and verified their byte lengths and rolling checksums match the final repo copies.
- Enumerated the live `ReplicatedStorage.Assets.Items` tree and mirrored the currently present `Common` icon names into the repo placeholder structure.
- Kept the runtime lookup path strict to `Rarity/Name`, so live Common icons now resolve without hardcoding asset ids into config modules.

### Risks

- Live `Assets.Items` currently exposes only the `Common` rarity folder, so higher-rarity items still rely on the text fallback until matching Studio icon folders are added.
- Icon lookup depends on exact `item.Name` matches with the `ImageLabel` names in `ReplicatedStorage.Assets.Items`; future naming drift will silently fall back to text.
- This step updates live Studio plus the historical `Level/` mirror, but it does not introduce a deeper `roblox/` manifest policy for icon assets.

### Rollback

- Revert the updated HUD scripts and remove the added `Level/ReplicatedStorage/Assets/Items` placeholder mirror files from the repo.
- In Roblox Studio, restore the previous source of `ChestRewardClient`, `RunStatsHud`, and `CameraMouseLock` if the live sync needs to be undone.
- No server-side rollback is needed because no server scripts or reward payloads changed.

## 2026-05-02 - Poziom chest / stats / run items UI polish

### Scope

- Updated the `Poziom` client HUD flow for chest rewards, run stats, and run items.
- Added a local chest draw animation with Space skip / accept behavior.
- Moved run stats to the left and limited their visibility to pause or chest reward flow.
- Repositioned and simplified the run items panel to a transparent middle-right inventory strip.
- Updated camera cursor-release handling so chest rewards behave like other blocking modal UI.
- Did not rename any Roblox Studio objects, remotes, attributes, or tags.
- Did not change server payloads or server reward logic.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/RunStatsHud.client.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/CameraMouseLock.lua`
- `CHANGELOG_AI.md`

### Verification

- Re-read the edited files after patching to confirm the intended client-side logic is present.
- Ran `git diff --check` for the touched files; it reported only LF-to-CRLF normalization warnings and no whitespace or patch-format errors.
- Checked the local toolchain for `luau`, `luau-analyze`, and `selene`; none were available in this environment, so no standalone Luau parser or linter run was possible.

### Risks

- This step updated the repo mirror only; live `Poziom` Studio scripts were not rewritten automatically as part of this change, so final runtime confirmation still needs an in-Studio playtest.
- The compact stats fit-to-height scaling depends on viewport size and should be sanity-checked on both taller and shorter client resolutions.
- The chest draw flow now relies on a client-side rolling state machine; if another system force-closes the reward unexpectedly, the in-Studio test should confirm the modal always returns input cleanly.

### Rollback

- Revert `ChestRewardClient.client.lua`, `RunStatsHud.client.lua`, `CameraMouseLock.lua`, and this changelog entry.
- No Roblox Studio rollback is needed because this step did not modify live Studio objects.

## 2026-05-01 - Documentation baseline for Studio/repo parity

### Scope

- Added project documentation for Roblox Studio parity planning.
- Updated root instructions for future AI work.
- Did not change Lua logic, Roblox Studio object names, remotes, attributes, tags, or gameplay behavior.

### Files added or updated

- `AGENTS.md`
- `PROJECT_MAP.md`
- `CHANGELOG_AI.md`
- `AI_WORKFLOW.md`
- `BUG_REPORT_TEMPLATE.md`
- `FEATURE_REQUEST_TEMPLATE.md`
- `REVIEW_CHECKLIST.md`
- `ROBLOX_REPO_SYNC.md`
- `STUDIO_REPO_PARITY_PLAN.md`

### Verification

- Verified the target files exist in the repo root after creation.
- Documentation content is based on MCP Studio inspection plus repo filesystem analysis.

### Risks

- The parity tables reflect the inspected Studio state on `2026-05-01`; if Studio changed after inspection, some entries may need refresh.
- Proposed canonical repo paths under `roblox/` are documentation only at this stage and are not yet implemented on disk.

### Rollback

- Restore the previous `AGENTS.md`.
- Remove the newly added documentation files if the user wants to restart the documentation baseline.
- No gameplay rollback is needed because no gameplay files were changed.

## 2026-05-01 - Studio-only parity batch 1

### Scope

- Added the first `roblox/` mirror files for selected Studio-only scripts.
- Limited this batch to `ReplicatedStorage`, `StarterPlayer/StarterCharacter`, `ServerScriptService`, and `Workspace` targets.
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.

### Files added

- `roblox/Poziom/ReplicatedStorage/ModuleScript/ClientLoadingOverlay.lua`
- `roblox/Poziom/ReplicatedStorage/ModuleScript/CraftingConfig.lua`
- `roblox/Poziom/ReplicatedStorage/ModuleScript/NpcShared.lua`
- `roblox/Poziom/ReplicatedStorage/ModuleScript/SpellDefinitions.lua`
- `roblox/Poziom/ReplicatedStorage/ModuleScript/WeaponConfigs.lua`
- `roblox/Poziom/ReplicatedStorage/ModuleScripts/EventDefinitions.lua`
- `roblox/Poziom/StarterPlayer/StarterCharacter/Animate.lua`
- `roblox/CzterySzczyty/ServerScriptService/Script/DayNightCycle.lua`
- `roblox/CzterySzczyty/ServerScriptService/ResetDefaultAnimations.lua`
- `roblox/CzterySzczyty/StarterPlayer/StarterCharacter/Animate.lua`
- `roblox/CzterySzczyty/Workspace/NPCs/Blacksmith/Animate.lua`
- `roblox/CzterySzczyty/Workspace/Rig/Animate.lua`

### Files updated

- `ROBLOX_REPO_SYNC.md`
- `STUDIO_REPO_PARITY_PLAN.md`
- `CHANGELOG_AI.md`

### Verification

- Verified the created `.lua` files against live Studio source using a byte-based rolling checksum.
- Confirmed exact matches for all created files in this batch.
- Confirmed `Cztery szczyty` still has duplicate live `Workspace.Rig.Animate` instances with identical source; the repo currently mirrors the source once and documents the collision.

### Risks

- The repo still does not encode duplicate sibling instance count for `Workspace.Rig` in `Cztery szczyty`.
- Large legacy `ServerStorage` trees remain deferred to a later parity batch.

### Rollback

- Remove the newly added files under `roblox/` for this batch.
- Revert the documentation updates in `ROBLOX_REPO_SYNC.md`, `STUDIO_REPO_PARITY_PLAN.md`, and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.

## 2026-05-01 - ServerStorage parity batch 2 (partial, Poziom only)

### Scope

- Added the next safe `roblox/` parity mirrors for `Poziom/ServerStorage`.
- Limited this partial batch to the exact Studio-only targets that were small enough to verify safely.
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.
- Stopped before `Cztery szczyty/ServerStorage` to keep the batch small and low risk.

### Files added

- `roblox/Poziom/ServerStorage/EnemyRigBackup/Elite/Ent/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Elite/Golem/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Elite/Knight/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/Demon/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/Goblin/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/Harp/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/LandShark/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/Skeleton/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/Slime/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/Warewolf/Animate.lua`
- `roblox/Poziom/ServerStorage/EnemyRigBackup/Normal/Zombie/Animate.lua`
- `roblox/Poziom/ServerStorage/IslandGeneratorFolder/TerrainMaterialModule.lua`
- `roblox/Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/qPerfectionWeld.lua`

### Mirror skipped and rolled back

- `roblox/Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script.lua`
  - exact-match extraction was attempted from live Studio
  - checksum verification failed during reconstruction
  - the temporary mirror file was removed so the repo would not keep a non-exact copy

### Files updated

- `STUDIO_REPO_PARITY_PLAN.md`
- `ROBLOX_REPO_SYNC.md`
- `CHANGELOG_AI.md`

### Verification

- Verified exact byte-based rolling checksums for all created files in this partial batch.
- Confirmed the shared `EnemyRigBackup` placeholder source matches live Studio across all created `Animate.lua` mirrors.
- Confirmed `TerrainMaterialModule.lua` and `qPerfectionWeld.lua` are exact matches to live Studio.
- Confirmed no invalid `Script.lua` mirror remains on disk for `Blackpowder Flintlock`.

### Risks

- `Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script` still needs a clean exact mirror extraction before the `Poziom` ServerStorage parity slice is fully complete.
- `Cztery szczyty/ServerStorage` remains entirely pending for the next batch.

### Rollback

- Remove the newly added `roblox/Poziom/ServerStorage/...` files from this partial batch.
- Revert the documentation updates in `STUDIO_REPO_PARITY_PLAN.md`, `ROBLOX_REPO_SYNC.md`, and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.

## 2026-05-02 - Poziom Blackpowder Flintlock Script micro-batch

### Scope

- Retried the exact parity mirror for one previously skipped Studio-only script:
  - `game.ServerStorage.WeaponTemplates.Pistol.Blackpowder Flintlock.Script`
- Limited this micro-batch to a single file under `Poziom/ServerStorage`.
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.

### Files added

- `roblox/Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script.lua`

### Files updated

- `STUDIO_REPO_PARITY_PLAN.md`
- `CHANGELOG_AI.md`

### Verification

- Extracted the live Studio source in 14 MCP chunks to avoid large-response drift.
- Verified every chunk locally with the same byte-based rolling checksum used in Studio.
- Reassembled the file only after all chunk checks passed.
- Verified the final mirrored file on disk against live Studio by exact byte-based rolling checksum and byte length.
- Final live/file verification values:
  - length: `41690`
  - checksum: `1162413910`

### Risks

- `Poziom/ServerStorage` is closer to parity, but `Cztery szczyty/ServerStorage` is still pending.
- The mirror process for very large legacy scripts remains sensitive to MCP output size, so future large-file parity work should continue using chunked extraction.

### Rollback

- Remove `roblox/Poziom/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script.lua`.
- Revert the documentation updates in `STUDIO_REPO_PARITY_PLAN.md` and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.

## 2026-05-02 - CzterySzczyty ServerStorage parity part 1

### Scope

- Added the next safe `roblox/` parity mirrors for the first `Cztery szczyty/ServerStorage` slice.
- Limited this batch to:
  - `game.ServerStorage.Modele.Rig.Animate`
  - `game.ServerStorage.WeaponTemplates.Bow.Stormwind Recurve.Projectile`
  - `game.ServerStorage.WeaponTemplates.Pistol.Blackpowder Flintlock.Script`
  - `game.ServerStorage.WeaponTemplates.Pistol.Blackpowder Flintlock.qPerfectionWeld`
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.

### Files added

- `roblox/CzterySzczyty/ServerStorage/Modele/Rig/Animate.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Bow/Stormwind Recurve/Projectile.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/qPerfectionWeld.lua`

### Files updated

- `STUDIO_REPO_PARITY_PLAN.md`
- `CHANGELOG_AI.md`

### Verification

- Verified `Projectile.lua` and `qPerfectionWeld.lua` by exact byte-based rolling checksum and byte length after write.
- Extracted `Modele/Rig/Animate` in 8 MCP chunks, verified every chunk locally, then verified the final mirrored file on disk.
- Extracted `Blackpowder Flintlock/Script` in 14 MCP chunks, verified every chunk locally, then verified the final mirrored file on disk.
- Final live/file verification values:
  - `roblox/CzterySzczyty/ServerStorage/Modele/Rig/Animate.lua`
    - length: `22891`
    - checksum: `401040173`
  - `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Bow/Stormwind Recurve/Projectile.lua`
    - length: `193`
    - checksum: `845681944`
  - `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/Script.lua`
    - length: `41690`
    - checksum: `1162413910`
  - `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Pistol/Blackpowder Flintlock/qPerfectionWeld.lua`
    - length: `7047`
    - checksum: `486137443`

### Risks

- `Cztery szczyty/ServerStorage` still has pending legacy `Scythe`, `Staff`, and `Sword` subtrees.
- Large-file parity work remains sensitive to MCP response size, so chunked extraction should remain the default for long legacy scripts.

### Rollback

- Remove the newly added `roblox/CzterySzczyty/ServerStorage/...` files from this batch.
- Revert the documentation updates in `STUDIO_REPO_PARITY_PLAN.md` and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.

## 2026-05-02 - CzterySzczyty ServerStorage Scythe parity batch

### Scope

- Added the next safe `roblox/` parity mirrors for the `Cztery szczyty/ServerStorage/WeaponTemplates/Scythe` slice.
- Limited this batch to:
  - `game.ServerStorage.WeaponTemplates.Scythe.Reaper’s Crescent.ScytheMain.BulletScript`
  - `game.ServerStorage.WeaponTemplates.Scythe.Reaper’s Crescent.ScytheMain.GravityShield`
  - `game.ServerStorage.WeaponTemplates.Scythe.Reaper’s Crescent.ScytheMain.GravityShieldLocal`
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.

### Files added

- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain/BulletScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain/GravityShield.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain/GravityShieldLocal.lua`

### Files updated

- `STUDIO_REPO_PARITY_PLAN.md`
- `CHANGELOG_AI.md`

### Verification

- Verified all three mirrored files by exact byte-based rolling checksum and byte length after write.
- Confirmed the live Studio Unicode folder name `Reaper’s Crescent` could be mirrored directly on disk without a fallback rename or manifest mapping.
- Final live/file verification values:
  - `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain/BulletScript.lua`
    - length: `6067`
    - checksum: `1238427791`
  - `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain/GravityShield.lua`
    - length: `1983`
    - checksum: `1772035597`
  - `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain/GravityShieldLocal.lua`
    - length: `2000`
    - checksum: `979950623`

### Risks

- `Cztery szczyty/ServerStorage` still has pending legacy `Staff` and `Sword` subtrees.
- This batch did not add manifest coverage for non-script tool internals; it only mirrored the requested scripts.

### Rollback

- Remove the newly added `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Scythe/Reaper’s Crescent/ScytheMain/...` files from this batch.
- Revert the documentation updates in `STUDIO_REPO_PARITY_PLAN.md` and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.

## 2026-05-02 - CzterySzczyty ServerStorage Staff parity batch

### Scope

- Added the next safe `roblox/` parity mirrors for the `Cztery szczyty/ServerStorage/WeaponTemplates/Staff` slice.
- Limited this batch to:
- `game.ServerStorage.WeaponTemplates.Staff.Apprentice Arcstaff.Burn.BurnScript`
- `game.ServerStorage.WeaponTemplates.Staff.Apprentice Arcstaff.EnergyNameScript`
- `game.ServerStorage.WeaponTemplates.Staff.Apprentice Arcstaff.StaffCore.Attachment.BillboardGui.SpinningScript`
- `game.ServerStorage.WeaponTemplates.Staff.Apprentice Arcstaff.StaffCore.IdleScript`
- `game.ServerStorage.WeaponTemplates.Staff.Apprentice Arcstaff.StaffCore.LightningScript`
- `game.ServerStorage.WeaponTemplates.Staff.Archmage’s Worldstaff.StaffMain.BigBulletScript`
- `game.ServerStorage.WeaponTemplates.Staff.Archmage’s Worldstaff.StaffMain.MeteorStormScript`
- `game.ServerStorage.WeaponTemplates.Staff.Archmage’s Worldstaff.StaffMain.MeteorStormScript.BulletScript`
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.

### Files added

- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/Burn/BurnScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/EnergyNameScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/StaffCore/Attachment/BillboardGui/SpinningScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/StaffCore/IdleScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/StaffCore/LightningScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain/BigBulletScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain/MeteorStormScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain/MeteorStormScript/BulletScript.lua`

### Files updated

- `STUDIO_REPO_PARITY_PLAN.md`
- `CHANGELOG_AI.md`

### Verification

- Verified all eight mirrored files by exact byte-based rolling checksum and byte length after write.
- Detected an initial end-of-file newline drift in seven files, then rewrote only those files without the extra newline and re-verified them.
- Confirmed the live Studio Unicode folder name `Archmage’s Worldstaff` could be mirrored directly on disk without a fallback rename or manifest mapping.
- Final live/file verification values:
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/Burn/BurnScript.lua`
  - length: `216`
  - checksum: `5290914`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/EnergyNameScript.lua`
  - length: `131`
  - checksum: `1932199593`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/StaffCore/Attachment/BillboardGui/SpinningScript.lua`
  - length: `88`
  - checksum: `1401154301`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/StaffCore/IdleScript.lua`
  - length: `713`
  - checksum: `1120465338`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Apprentice Arcstaff/StaffCore/LightningScript.lua`
  - length: `1701`
  - checksum: `100521509`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain/BigBulletScript.lua`
  - length: `4381`
  - checksum: `2124134173`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain/MeteorStormScript.lua`
  - length: `4251`
  - checksum: `600351395`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/Archmage’s Worldstaff/StaffMain/MeteorStormScript/BulletScript.lua`
  - length: `4381`
  - checksum: `164449258`

### Risks

- `Cztery szczyty/ServerStorage` still has the pending legacy `Sword` subtree.
- This batch did not add manifest coverage for non-script tool internals; it only mirrored the requested scripts.

### Rollback

- Remove the newly added `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Staff/...` files from this batch.
- Revert the documentation updates in `STUDIO_REPO_PARITY_PLAN.md` and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.

## 2026-05-02 - CzterySzczyty ServerStorage Sword parity batch

### Scope

- Added the next safe `roblox/` parity mirrors for the `Cztery szczyty/ServerStorage/WeaponTemplates/Sword` slice.
- Limited this batch to the requested `Excalion, Blade of Kings` subtree only.
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.

### Files added

- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/DeathSouls/SoulScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Fireball/Despawn.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Handle/Light/Fire_Effect.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/AfterImageScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/AfterImageScript/Decimate.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/AfterImageScript/SlowScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/Decimate.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulHunt.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulHunt/SoulHunt_Client.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulHunt/SoulHunt_Seeker.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulScript.lua`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulScript/Decimate.lua`

### Files updated

- `STUDIO_REPO_PARITY_PLAN.md`
- `CHANGELOG_AI.md`

### Verification

- Verified all twelve mirrored files by exact byte-based rolling checksum and byte length after write.
- Found one special-case parity issue: `Server/AfterImageScript/SlowScript` in Studio ends with a trailing newline, so the mirror had to preserve that final byte to pass exact verification.
- Final live/file verification values:
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/DeathSouls/SoulScript.lua`
  - length: `3050`
  - checksum: `1445004627`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Fireball/Despawn.lua`
  - length: `23`
  - checksum: `2037181266`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Handle/Light/Fire_Effect.lua`
  - length: `446`
  - checksum: `472581755`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/AfterImageScript.lua`
  - length: `3077`
  - checksum: `1558881576`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/AfterImageScript/Decimate.lua`
  - length: `3450`
  - checksum: `1111029196`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/AfterImageScript/SlowScript.lua`
  - length: `265`
  - checksum: `1050649217`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/Decimate.lua`
  - length: `3539`
  - checksum: `566904153`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulHunt.lua`
  - length: `3669`
  - checksum: `1262105262`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulHunt/SoulHunt_Client.lua`
  - length: `1672`
  - checksum: `1045727031`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulHunt/SoulHunt_Seeker.lua`
  - length: `3735`
  - checksum: `1984505583`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulScript.lua`
  - length: `3133`
  - checksum: `956554734`
- `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/Excalion, Blade of Kings/Server/SoulScript/Decimate.lua`
  - length: `3539`
  - checksum: `566904153`

### Risks

- This batch mirrored only requested scripts, not the full non-script `Tool` internals under `WeaponTemplates/Sword`.
- Full repo-vs-Studio parity still needs final documentation review for non-script manifests, duplicate instance caveats, and repo-only snapshots.

### Rollback

- Remove the newly added `roblox/CzterySzczyty/ServerStorage/WeaponTemplates/Sword/...` files from this batch.
- Revert the documentation updates in `STUDIO_REPO_PARITY_PLAN.md` and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.

## 2026-05-02 - Final parity report and parity-level documentation

### Scope

- Added the final Studio ↔ repo parity report.
- Clarified the difference between `script parity` and `full object parity`.
- Updated the parity plan to mark script coverage complete and list the remaining object-level work.
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.

### Files added

- `PARITY_FINAL_REPORT.md`

### Files updated

- `STUDIO_REPO_PARITY_PLAN.md`
- `ROBLOX_REPO_SYNC.md`
- `CHANGELOG_AI.md`

### Verification

- Confirmed that all `53` planned Studio-only parity mirror paths exist on disk under `roblox/`.
- Rechecked the current `Workspace.Rig.Animate` situation in the active `Cztery szczyty` Studio session and recorded the duplicate-history ambiguity for future manifest work.
- Verified that this step changed documentation only and did not touch Roblox Studio or gameplay code.

### Risks

- `Script parity` is complete at repo-coverage level, but `full object parity` is still incomplete until manifests and repo-only decisions are finished.
- The earlier `Workspace.Rig.Animate` duplicate finding and the later single-instance recheck should be treated as an unresolved object-parity edge case until manually verified.

### Rollback

- Remove `PARITY_FINAL_REPORT.md`.
- Revert the documentation updates in `STUDIO_REPO_PARITY_PLAN.md`, `ROBLOX_REPO_SYNC.md`, and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.

## 2026-05-02 - Full object parity manifest baseline

### Scope

- Added the first targeted `MANIFEST.md` layer for critical non-script Studio structures under `roblox/`.
- Limited this pass to structures most likely to block later safe reorganization:
  - remote folders
  - `StarterGui`
  - `Workspace.NPCs`
  - portal structure
  - `Workspace.Rig`
  - `ServerStorage.Modele.Rig`
  - `ServerStorage.WeaponTemplates`
- Updated parity documentation to distinguish current manifest coverage from the remaining deeper object-parity gaps.
- Did not move or rename any Roblox Studio objects.
- Did not change gameplay logic.

### Files added

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

### Files updated

- `ROBLOX_REPO_SYNC.md`
- `PARITY_FINAL_REPORT.md`
- `STUDIO_REPO_PARITY_PLAN.md`
- `CHANGELOG_AI.md`

### Verification

- Reused the active Studio parity context and ran targeted live inspections only for the structures needed by this manifest pass.
- Confirmed the current live `Cztery szczyty` lobby portal path is `Workspace.Budynki.Portal` with child `PortalTeleport`.
- Confirmed the current live `Poziom` targeted recheck did not expose `Workspace.NPCs` or portal-named descendants in the active session.
- Confirmed this step added documentation only and did not touch Roblox Studio or gameplay code.

### Risks

- `Full object parity` is still partial because most manifests stop at the critical structure boundary and do not yet enumerate every nested non-script descendant.
- `Poziom` workspace-side portal and NPC object coverage remains uncertain until a later targeted check finds a live structure worth mirroring under `roblox/Poziom/Workspace`.
- The historical duplicate ambiguity for `Cztery szczyty/Workspace.Rig.Animate` still needs a manual decision if instance-count parity becomes important.

### Rollback

- Remove the newly added `MANIFEST.md` files under `roblox/`.
- Revert the documentation updates in `ROBLOX_REPO_SYNC.md`, `PARITY_FINAL_REPORT.md`, `STUDIO_REPO_PARITY_PLAN.md`, and `CHANGELOG_AI.md`.
- No Roblox Studio rollback is needed because Studio was not modified.
## 2026-05-06 - Cztery szczyty blacksmith ScreenGui enabled open fix and live Studio sync

### Scope

- Fixed the blacksmith open flow so the authored `StarterGui.BlacksmithGui` is treated as the canonical open state through `ScreenGui.Enabled` instead of the older runtime-built `overlay/panel` path.
- Kept the existing authored `BlacksmithGui` layout and did not create a new UI tree.
- Updated the repo `BlacksmithService` to ensure the blacksmith `ProximityPrompt` idempotently and re-check when `Workspace.NPCs` / `Blacksmith` / prompt descendants appear later.
- Synced the repo `BlacksmithUI`, `BlacksmithService`, `CraftingService`, and `CraftingConfig` sources into the live `Cztery szczyty` Studio place through Roblox MCP.
- Set live `StarterGui.BlacksmithGui.Enabled = false` so the UI starts hidden and is opened by script on interaction.
- Added a direct live fallback `ProximityPrompt` on `Workspace.NPCs.Blacksmith.HumanoidRootPart` so the authored blacksmith model already exposes interaction while the server-side ensure logic also remains in place.
- Did not add new remotes, did not rename any blacksmith remotes, and did not rebuild the authored blacksmith layout.

### Files updated

- `Four Peaks/ServerScriptService/Script/BlacksmithService.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`
- `game.ServerScriptService.Script.BlacksmithService`
- `game.ServerScriptService.ModuleScript.CraftingService`
- `game.ReplicatedStorage.ModuleScripts.CraftingConfig`
- `game.StarterGui.BlacksmithGui.Enabled`
- `game.Workspace.NPCs.Blacksmith.HumanoidRootPart.BlacksmithPrompt`

### Verification

- Confirmed the active Studio instance was `Cztery szczyty` before patching and re-set it active for this pass.
- Re-read the live `StarterPlayer.StarterPlayerScripts.BlacksmithUI` after sync and confirmed it now uses the repo version with `CameraOffset`, `HiddenLobbyGuiNames`, `gui.Enabled = false`, and no `WaitForChild("overlay")` dependency.
- Re-read the live `ServerScriptService.Script.BlacksmithService` after sync and confirmed the new `bindBlacksmithPrompt`, `ensureBlacksmithPrompt`, and watcher-based re-check flow is present.
- Re-read the live `CraftingService` and `CraftingConfig` after sync and confirmed the current Studio sources now include `materials`, `unique`, `alreadyOwned`, and the new combined material progress flow expected by the blacksmith client.
- Verified through Luau execution that `StarterGui.BlacksmithGui.Enabled` is now `false`, the authored GUI has no `overlay` child, and `Workspace.NPCs` now contains `1` `ProximityPrompt`.
- Verified the live fallback prompt exists on `Workspace.NPCs.Blacksmith.HumanoidRootPart`.
- Re-checked the Studio console after sync: the earlier `WaitForChild("overlay")` infinite-yield entry remains in the historical log from before the patch, but no new blacksmith overlay error was produced during the post-sync source verification steps.

### Risks

- The current live editing session exposed `Players` but not the usual `PlayerGui` / `PlayerScripts` blacksmith clones during MCP verification, so this pass could not fully replay a real end-to-end prompt click inside a fresh runtime client from MCP alone.
- Because `StarterGui.BlacksmithGui.Enabled` is a live Studio object property rather than a Lua source file, that exact default state is not mirrored by a repo file beyond this changelog note and the client script behavior that also forces `gui.Enabled = false`.
- The direct authored fallback prompt on `Workspace.NPCs.Blacksmith` is intentionally compatible with the new server-side ensure logic, but if the NPC model’s preferred prompt part changes later, both the authored prompt location and the service helper may need a small targeted refresh.

### Rollback

- Revert `Four Peaks/ServerScriptService/Script/BlacksmithService.lua` and this changelog entry in the repo.
- In live Studio, restore the previous sources of `BlacksmithUI`, `BlacksmithService`, `CraftingService`, and `CraftingConfig`.
- In live Studio, set `StarterGui.BlacksmithGui.Enabled` back to its previous value if desired and remove `Workspace.NPCs.Blacksmith.HumanoidRootPart.BlacksmithPrompt` if you want to return to a script-only prompt setup.
## 2026-05-06 - Cztery szczyty blacksmith lore, element, camera, and left-list readability sync

### Scope

- Updated live `Cztery szczyty` `WeaponConfigs` so every current blacksmith weapon now defines a shared `description` lore field and a shared `element` field.
- Kept `WeaponConfigs.description` as shared source-of-truth text so the blacksmith details panel and inventory both use the same lore description instead of the old stat-summary sentence.
- Updated live `BlacksmithUI` so the right panel now renders:
  - `WeaponName` as the weapon name only
  - `Description` from `WeaponConfigs.description`
  - `ElementType` as `Element type: <element>`
  - `StatName1` as `ATK <value>`
  - `Passive` as `Passive: <passive or ability name>`
  - `PassiveDesc` from passive description with ability-description fallback
- Removed the old stat-summary sentence from the right-panel `Description` output and kept stats/passive information in their dedicated fields.
- Increased the left weapon-list runtime text sizing so weapon names are visibly larger and long names remain readable without showing full lore in the list.
- Simplified the left weapon-list meta line to compact states such as `Owned`, `Locked`, and `<silver> silver`.
- Re-aimed the local blacksmith camera to use `BlacksmithGui.BlacksmithCameraPoint` as the look target with `CameraOffset = Vector3.new(0, 2.5, -8)` so the camera faces the blacksmith/anvil more reliably.
- Did not create a new UI, did not rebuild the authored `BlacksmithGui` tree, and did not change remote contracts.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/WeaponConfigs.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.ModuleScripts.WeaponConfigs`
- `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`

### Verification

- Confirmed the active Studio instance was `Cztery szczyty` and applied the live changes there before mirroring the same changes into the repo files.
- Re-read the live `WeaponConfigs` source after sync and confirmed all 12 current blacksmith weapons now include both `description` and `element`.
- Re-read the live `BlacksmithUI` source after sync and confirmed:
  - `CameraOffset` is `Vector3.new(0, 2.5, -8)`
  - the right panel uses `weaponDef.description`
  - the right panel renders `Element type: <element>`
  - the passive label is prefixed with `Passive:`
  - the left-list runtime labels use larger title/meta sizing and compact meta text
- Compared the authored `BlacksmithCameraPoint` position against the live `Workspace.NPCs.Blacksmith` orientation and selected `Vector3.new(0, 2.5, -8)` because it best aligned the camera in front of the blacksmith among the tested fixed offsets.
- Verified the repo diff contains only the planned `WeaponConfigs` lore/element additions and the intended `BlacksmithUI` rendering/camera/list-readability updates for this pass.
- Ran `git diff --check` on the touched repo files; the only output was existing LF/CRLF conversion warnings and no patch-format or whitespace errors.

### Risks

- A live Luau `require(WeaponConfigs)` check inside the already-running Studio session still reflected an older cached module table even after the source sync, so the cleanest end-to-end confirmation for the new shared `description` / `element` fields is a fresh play session or server restart.
- The chosen fixed camera offset is based on the current authored `BlacksmithCameraPoint` and `Blacksmith` placement; if either object moves later, the offset may need a small follow-up tweak.
- The left list now prioritizes larger readable weapon names, so especially long names may wrap onto two lines depending on future button art or size changes.

### Rollback

- Revert `Four Peaks/ReplicatedStorage/ModuleScripts/WeaponConfigs.lua`, `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`, and this changelog entry in the repo.
- In live Studio, restore the previous source of `game.ReplicatedStorage.ModuleScripts.WeaponConfigs` and `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`.
- If needed, restore the previous blacksmith camera offset in the live local script to the earlier value.
## 2026-05-11 - Cztery szczyty blacksmith icon contracts, display names, prompt hiding, and close flow sync

### Scope

- Updated live `Cztery szczyty` and mirrored repo changes for the Four Peaks blacksmith pass that fixes weapon tile icon wiring, element icon wiring, simple blacksmith-facing names, prompt hiding, and close behavior.
- Extended `WeaponConfigs` with blacksmith presentation fields without changing `weaponId`, `recipeId`, inventory keys, or save keys:
  - `displayName`
  - `iconName`
  - `iconFallbackNames`
  - `elementIconName`
- Normalized blacksmith element presentation so `Electricity` is exposed to the UI as `Electric`.
- Updated `CraftingService` so blacksmith snapshot entries use `def.displayName` when present and sort ties by `weaponId` instead of display text.
- Replaced the old `WeaponIconReplicator` model-replication behavior with icon-contract setup for:
  - `ReplicatedStorage.WeaponIcons`
  - `ReplicatedStorage.ElementIcons`
  - `ReplicatedStorage.MaterialIcons`
- Populated the live icon folders with `StringValue` children keyed by asset names and defaulted missing values to `rbxgameasset://Images/<name>` so the UI can resolve imported Asset Manager images by name without guessing numeric ids.
- Updated `BlacksmithUI` so:
  - left weapon tiles resolve weapon icons from `ReplicatedStorage.WeaponIcons`
  - left weapon tiles resolve element icons from `ReplicatedStorage.ElementIcons`
  - right info panel stays text-only
  - selected weapon names use simplified `displayName`
  - bottom material slot frames stay visible even when an icon is missing
  - only `Material_Icon` hides when no material icon resolves
  - blacksmith prompts under the NPC are disabled locally while the UI is open and restored on close
  - `closeUI()` restores camera, tooltip state, local character visibility, prompt state, and selection state
  - `closeUI()` now logs `print("[BlacksmithUI] Closing blacksmith UI")`
- Updated `BackButtonClient` to log `print("[BlacksmithUI] BackButton clicked")` before firing the shared close bindable.
- Updated `BannerUI` to tolerate the new `ReplicatedStorage.WeaponIcons` `StringValue` contract so the banner system does not depend on replicated icon models anymore.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/WeaponConfigs.lua`
- `Four Peaks/ServerScriptService/ModuleScript/CraftingService.lua`
- `Four Peaks/ServerScriptService/Script/WeaponIconReplicator.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BannerUI.lua`
- `Four Peaks/StarterGui/BlacksmithGui/BlacksmithGui/BackButton/BackButton/BackButtonClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.ModuleScripts.WeaponConfigs`
- `game.ServerScriptService.ModuleScript.CraftingService`
- `game.ServerScriptService.Script.WeaponIconReplicator`
- `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`
- `game.StarterPlayer.StarterPlayerScripts.BannerUI`
- `game.StarterGui.BlacksmithGui.BlacksmithGui.BackButton.BackButton.BackButtonClient`
- `game.ReplicatedStorage.WeaponIcons`
- `game.ReplicatedStorage.ElementIcons`
- `game.ReplicatedStorage.MaterialIcons`

### Verification

- Confirmed the active Studio instance was `Cztery szczyty` and re-set it active before live edits.
- Synced the live `WeaponConfigs`, `CraftingService`, `WeaponIconReplicator`, `BlacksmithUI`, `BannerUI`, and `BackButtonClient` sources to the new behavior.
- Verified via Luau execution that:
  - `ReplicatedStorage.MaterialIcons` exists with `49` children
  - `ReplicatedStorage.ElementIcons` exists with `8` children
  - `ReplicatedStorage.WeaponIcons` exists with `59` children
  - all three icon folders contain only `StringValue` children
- Verified syntax compilation with `loadstring(script.Source)` for:
  - `ReplicatedStorage.ModuleScripts.WeaponConfigs`
  - `ServerScriptService.ModuleScript.CraftingService`
  - `StarterPlayer.StarterPlayerScripts.BlacksmithUI`
  - `StarterPlayer.StarterPlayerScripts.BannerUI`
  - `ServerScriptService.Script.WeaponIconReplicator`
  - `StarterGui.BlacksmithGui.BlacksmithGui.BackButton.BackButton.BackButtonClient`
- Verified sample blacksmith presentation data in live `WeaponConfigs`, including:
  - `Knight's Oath` -> `Physical Sword`
  - `Excalion, Blade of Kings` -> `Light Sword`
  - `Voidpiercer` -> `Void Sword`
  - `Apprentice Arcstaff` -> `Electric Staff`
  - `Kingslayer Handcannon` -> `Physical Pistol`
- Ran `git diff --check` in the repo; the only output was LF/CRLF conversion warnings on touched files and no patch-format or trailing-whitespace errors.

### Risks

- The live icon contract now uses `rbxgameasset://Images/<name>` values so Roblox can resolve Asset Manager images by imported name in the current experience; if the imported asset names differ from the expected keys, the folder values will need a small manual rename/value pass.
- MCP verification in this pass confirmed source sync, folder structure, and compile success, but did not run a full in-session click-through with visible hover/camera behavior from an active player runtime.
- `BannerUI` is now compatible with `StringValue` weapon icons, but if any other future UI still assumes `ReplicatedStorage.WeaponIcons` contains `Model` children, it will need the same compatibility treatment.

### Rollback

- Revert `Four Peaks/ReplicatedStorage/ModuleScripts/WeaponConfigs.lua`, `Four Peaks/ServerScriptService/ModuleScript/CraftingService.lua`, `Four Peaks/ServerScriptService/Script/WeaponIconReplicator.lua`, `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`, `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BannerUI.lua`, `Four Peaks/StarterGui/BlacksmithGui/BlacksmithGui/BackButton/BackButton/BackButtonClient.lua`, and this changelog entry in the repo.
- In live Studio, restore the previous sources of the updated scripts/modules and remove or reset `ReplicatedStorage.WeaponIcons`, `ReplicatedStorage.ElementIcons`, and `ReplicatedStorage.MaterialIcons` if you want to return to the old contract.

## 2026-05-11 - Cztery szczyty blacksmith original weapon names and direct BackButton close flow

### Scope

- Restored original weapon names as the primary blacksmith-facing name source so `WeaponName` on the left tiles and `Info.WeaponName` on the right panel show the authored weapon names again.
- Kept the simplified blacksmith label as a separate presentation field by adding:
  - `weaponName`
  - `weaponTypeLabel`
  - `category`
- Left `weaponId`, `recipeId`, save keys, and inventory keys unchanged.
- Updated `WeaponConfigs` so:
  - `displayName` falls back to the original weapon name for compatibility with existing readers
  - `weaponTypeLabel` stays the simplified `<Element> <Type>` text used only for the `WeaponType` field
  - `category` is preserved explicitly for filtering
- Updated `BlacksmithUI` so:
  - left tile `WeaponName` uses the original weapon name
  - left tile `WeaponType` uses `weaponTypeLabel`
  - right panel `Info.WeaponName` uses the original weapon name
  - forge confirmation popup uses the original weapon name
  - `closeUI()` clears the current blacksmith snapshot and rerenders an empty state before hiding the GUI so selection state and `Forge_button` reset cleanly
  - the existing `BackButton` `ImageButton` is bound directly in `BlacksmithUI` through `Activated`, with `Active` and `Visible` asserted on init
- Reduced `BackButtonClient` to a passive legacy stub so there is no second close path targeting the wrong ancestor `BlacksmithGui`.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/WeaponConfigs.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`
- `Four Peaks/StarterGui/BlacksmithGui/BlacksmithGui/BackButton/BackButton/BackButtonClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `game.ReplicatedStorage.ModuleScripts.WeaponConfigs`
- `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`
- `game.StarterGui.BlacksmithGui.BlacksmithGui.BackButton.BackButton.BackButtonClient`

### Verification

- Confirmed the active Studio instance was `Cztery szczyty` and re-set it active before the live sanity pass.
- Verified the live `BlacksmithUI` source contains:
  - `getWeaponDisplayName(...)`
  - tile and right-panel name assignment through `getWeaponDisplayName(...)`
  - tile `WeaponType` assignment through `getWeaponTypeLabel(...)`
  - direct `backButton.Activated:Connect(...)`
  - `snapshot = nil` inside `closeUI()`
- Verified the live `BackButtonClient` source is a passive legacy stub and no longer owns the click behavior.
- Required a fresh clone of the live `WeaponConfigs` module and confirmed:
  - `Reaper's Crescent` -> `weaponName = Reaper's Crescent`, `displayName = Reaper's Crescent`, `weaponTypeLabel = Void Scythe`
  - `Excalion, Blade of Kings` -> `weaponName = Excalion, Blade of Kings`, `displayName = Excalion, Blade of Kings`, `weaponTypeLabel = Light Sword`
  - `Knight's Oath` -> `weaponName = Knight's Oath`, `displayName = Knight's Oath`, `weaponTypeLabel = Physical Sword`
- Confirmed the live back button path `StarterGui.BlacksmithGui.BlacksmithGui.BackButton.BackButton` exists as an `ImageButton` and the client source asserts `Active = true` and `Visible = true`.

### Risks

- This pass verified source state and fresh module output, but it did not complete a full interactive click-through inside an active player session, so final visual confirmation of the button path and tile text still benefits from one live playtest.
- Because Studio may cache required modules by instance, a stale server/client session can still reflect pre-change data until the updated source is re-required in a fresh runtime context.

### Rollback

- Revert `Four Peaks/ReplicatedStorage/ModuleScripts/WeaponConfigs.lua`, `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua`, `Four Peaks/StarterGui/BlacksmithGui/BlacksmithGui/BackButton/BackButton/BackButtonClient.lua`, and this changelog entry in the repo.
- In live Studio, restore the previous source of `game.ReplicatedStorage.ModuleScripts.WeaponConfigs`, `game.StarterPlayer.StarterPlayerScripts.BlacksmithUI`, and `game.StarterGui.BlacksmithGui.BlacksmithGui.BackButton.BackButton.BackButtonClient`.
