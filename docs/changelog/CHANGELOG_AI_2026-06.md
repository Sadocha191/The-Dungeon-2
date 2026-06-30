# CHANGELOG_AI — 2026-06

Pełne wpisy zmian AI z miesiąca 2026-06. Kolejność zachowuje oryginalny plik.

## 2026-06-30 - Poziom NpcService DamageService contact damage migration

### Scope

- Migrated `NpcService` melee/contact player damage from the temporary `_G.ApplyDamageToPlayer` shim to direct `DamageService.Apply`.
- Removed the local `Humanoid:TakeDamage` fallback from the NPC contact-damage path so NPC melee damage cannot bypass the central player damage pipeline.
- Preserved melee range validation, vertical validation, attack cooldowns, damage values, NPC records, death callbacks, and the public `NpcService` API.
- Passed the attacking NPC model as both `source` and `attacker` with `sourceType = "npc"` and `damageType = "contact"` so existing thorns handling receives the real attacker model.
- Did not modify `DamageService`, `RunStatsService`, `WaveController`, `ShrineService`, `DebugStressTools`, remotes, NPC configuration, or balance.

### Files updated

- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `CHANGELOG_AI.md`
- `docs/changelog/CHANGELOG_AI_2026-06.md`

### Live Studio objects updated

- `Level`: `game.ServerScriptService.ModuleScript.NpcService`

### Verification

- Confirmed connected Studio instances and active Studio `Level`.
- Synced `game.ServerScriptService.ModuleScript.NpcService` from the repo change.
- Confirmed `NpcService.lua` no longer contains `_G.ApplyDamageToPlayer` or a local player-damage `Humanoid:TakeDamage` fallback.
- Confirmed Studio grep finds `_G.ApplyDamageToPlayer` and fallback `hum:TakeDamage` in `WaveController`, not in `NpcService`; `WaveController` remained unchanged and still uses the compatibility shim.
- Checked the require graph: `NpcService -> DamageService`, `RunStatsService -> NpcService`, `RunStatsService -> DamageService`, and `DamageService -> StatsConfig/RunDefenseState`; no `DamageService -> NpcService/RunStatsService` cycle was introduced.
- Ran a Play server probe using clones of the real `ReplicatedStorage.Enemies.Normal.Slime` template through `NpcService.Register`, allowing the existing `NpcService` Heartbeat melee path to call `DamageService.Apply`.
- Verified real Slime contact damage, armor reduction, shrine difficulty applied exactly once, shrine shield/temporary shield/persistent shield/overheal consumption, thorns damage to the attacking Slime model, invalid vertical contact rejection, and evasion.
- Checked Studio Output after Play. No `NpcService` startup or damage migration errors appeared; expected `DamageService` evasion logs appeared during the evasion case, with existing unrelated Hybrid Terrain and error-reporter configuration messages still present.
- Ran `git diff --check`; it reported no whitespace errors, only LF/CRLF conversion warnings on touched text files.
- Confirmed no new runtime loops, `_G` writers, callbacks, or schedulers were added.

### Risks

- A missing `DamageService` module now fails `NpcService` startup explicitly instead of falling back to direct Humanoid damage.
- `WaveController` still uses the temporary compatibility shim until its separate migration.

### Rollback

- Restore the previous `NpcService.lua` source in repo and Studio, then revert this changelog entry.

## 2026-06-30 - Poziom DamageService player damage pipeline

### Scope

- Added `Level` `DamageService` as the single server-side owner of incoming player damage application.
- Added `DamageService.server` as the only writer of `_G.ApplyDamageToPlayer`, keeping `NpcService` and `WaveController` on the temporary compatibility shim.
- Moved the incoming damage pipeline out of `RunStatsService.ApplyDamageToPlayer` while keeping that public function available as a numeric-return delegator.
- Removed competing `_G.ApplyDamageToPlayer` writers from `RunStatsService`, `ShrineService`, and `DebugStressTools`.
- Kept `RunDefenseState` as the owner of defensive state from stage 1A; did not duplicate shield, overheal, or lethal-prevention state.
- Kept `ShrineService` responsible for shrines, shrine attributes, shield regen, and HP regen.
- Kept `DebugStressTools` Studio-only and moved god-mode damage blocking to `DamageService` reading `ReplicatedStorage.DebugSettings.GodModeEnabled`.
- Did not modify `NpcService`, `WaveController`, `ChestItemService`, remotes, persistent data, attribute names, or source damage balance.

### Files updated

- `Level/ServerScriptService/ModuleScript/DamageService.lua`
- `Level/ServerScriptService/Script/DamageService.server.lua`
- `Level/ServerScriptService/ModuleScript/Stats/RunStatsService.lua`
- `Level/ServerScriptService/Script/ShrineService.server.lua`
- `Level/ServerScriptService/Script/DebugStressTools.lua`
- `CHANGELOG_AI.md`
- `docs/changelog/CHANGELOG_AI_2026-06.md`

### Live Studio objects updated

- `Level`: `game.ServerScriptService.ModuleScript.DamageService`
- `Level`: `game.ServerScriptService.Script.DamageService`
- `Level`: `game.ServerScriptService.ModuleScript.Stats.RunStatsService`
- `Level`: `game.ServerScriptService.Script.ShrineService`
- `Level`: `game.ServerScriptService.Script.DebugStressTools`

### Verification

- Confirmed connected Studio instances and set active Studio to `Level`.
- Verified Studio `loadstring` compilation for `DamageService`, `DamageService.server`, `RunStatsService`, `ShrineService`, and `DebugStressTools`.
- Verified repo and Studio source checksum parity for all five changed live sources.
- Verified `rg "_G\\.ApplyDamageToPlayer\\s*="` and Studio `script_grep` both report only `DamageService.server`.
- Verified `DamageService.lua` requires only `StatsConfig` and `RunDefenseState`.
- Ran a Play startup-order probe from a normal server `Script`: `_G.ApplyDamageToPlayer` became `function` while `RunStarted=false` and active NPC model count was `0`; at `RunStarted=true`, the shim was still `function` and active NPC model count was still `0`.
- Ran a Play server pipeline probe covering `_G` shim calls, `RunStatsService.ApplyDamageToPlayer`, `DamageService.CanDamage`, Studio god mode, armor, evasion, shrine difficulty exactly once, shrine shield before run shields, temporary shield before persistent shield, persistent shield before overheal, Angel's Debt lethal prevention, and thorns damage to an `NpcService`-registered attacker.
- Checked Studio Output after Play. No damage-shim or fallback-related errors appeared; existing unrelated `Hybrid Terrain Hex Generator` and error-reporter configuration messages remained.
- Confirmed no new runtime loop was added. Existing loops in `RunStatsService`, `ShrineService`, and `DebugStressTools` remain.
- Ran `git diff --check`; it reported only LF/CRLF conversion warnings on touched text files.

### Risks

- `NpcService` and `WaveController` still depend on the temporary `_G.ApplyDamageToPlayer` shim until a later migration to `require(DamageService)`.
- Thorns and Angel's Debt use temporary callbacks registered by `RunStatsService` to avoid a `DamageService -> RunStatsService/NpcService` require cycle.
- The fallback branches in `NpcService` and `WaveController` do not log when used, so fallback non-use was verified by shim readiness before run start plus unchanged caller branches rather than by dedicated fallback counters.

### Rollback

- Delete `DamageService.lua` and `DamageService.server.lua`.
- Restore the previous `RunStatsService.lua`, `ShrineService.server.lua`, and `DebugStressTools.lua` sources.
- Revert this changelog entry.
- In live `Level`, remove `game.ServerScriptService.ModuleScript.DamageService` and `game.ServerScriptService.Script.DamageService`, then restore the previous sources of the three changed existing scripts.

## 2026-06-29 - Poziom RunDefenseState defensive state extraction

### Scope

- Added `Level` `RunDefenseState` as a neutral defensive-state module for persistent shield, temporary shield, overheal, block shield gain, and Angel's Debt lethal-prevention records.
- Updated `RunStatsService` to keep the existing public API and incoming damage pipeline while delegating shield, overheal, block shield, and Angel's Debt state operations to `RunDefenseState`.
- Kept `_G.ApplyDamageToPlayer`, `ShrineService`, `DebugStressTools`, `NpcService`, `WaveController`, RemoteEvents, attribute names, damage order, shield/overheal/Angel's Debt math, and runtime loops unchanged.

### Files updated

- `Level/ServerScriptService/ModuleScript/Stats/RunDefenseState.lua`
- `Level/ServerScriptService/ModuleScript/Stats/RunStatsService.lua`
- `CHANGELOG_AI.md`
- `docs/changelog/CHANGELOG_AI_2026-06.md`

### Live Studio objects updated

- `Level`: `game.ServerScriptService.ModuleScript.Stats.RunDefenseState`
- `Level`: `game.ServerScriptService.ModuleScript.Stats.RunStatsService`

### Verification

- Confirmed connected Studio instances and set active Studio to `Level`.
- Audited all `RunStatsService` reads and writes of `persistentShield`, `temporaryShield`, `currentOverheal`, `specialFlags.BlockShieldGain`, `specialEffects.AngelDebt`, and dynamic shield/overheal attributes before editing.
- Confirmed `RunDefenseState` has no `require()` dependencies and does not require `RunStatsService`, `DamageService`, `NpcService`, or `ShrineService`.
- Verified Studio `loadstring` compilation for `RunDefenseState` and `RunStatsService`.
- Verified repo and Studio source checksum parity for both changed scripts.
- Ran a short `Level` Play server test through public `RunStatsService` API covering temporary shield gain/absorption, persistent shield stat rebuild/clamp, overheal gain/absorption, Blood Moon shield blocking/unregister, and Angel's Debt lethal prevention.
- Checked that no new `_G` writer and no new runtime loop were added; the existing `RunStatsService` `Heartbeat` remained unchanged.
- Ran `git diff --check`; it reported only LF/CRLF conversion warnings on touched text files.

### Risks

- Angel's Debt still consumes the first entry returned by `pairs`, matching the previous unordered-table behavior.
- Already-running Studio play sessions need a fresh server/module require to pick up the extracted state module.

### Rollback

- Revert `RunStatsService.lua`, delete `RunDefenseState.lua`, and revert this changelog entry.
- In live `Level`, restore the previous source of `game.ServerScriptService.ModuleScript.Stats.RunStatsService` and remove `game.ServerScriptService.ModuleScript.Stats.RunDefenseState`.

## 2026-06-29 - Poziom DebugStressTools Studio-only guard

### Scope

- Added an early `RunService:IsStudio()` return to `Level` `DebugStressTools` before it can create or modify `DebugSettings`, enable god mode, change spawn stress values, wrap `_G.ApplyDamageToPlayer`, connect player/character hooks, or attach its `Heartbeat`.
- Kept the existing Studio stress-tool defaults and behavior unchanged.
- Did not change wave balance, damage systems, spawn configuration, remotes, persistent data, or other gameplay systems.

### Files updated

- `Level/ServerScriptService/Script/DebugStressTools.lua`
- `CHANGELOG_AI.md`
- `docs/changelog/CHANGELOG_AI_2026-06.md`

### Live Studio objects updated

- `Level`: `game.ServerScriptService.Script.DebugStressTools`

### Verification

- Confirmed connected Studio instances and set active Studio to `Level`.
- Confirmed the active Studio script path is `game.ServerScriptService.Script.DebugStressTools`.
- Searched the repo for `DebugStressTools.lua`; only `Level/ServerScriptService/Script/DebugStressTools.lua` was found.
- Synced the updated source into live Studio and read it back; the `RunService:IsStudio()` guard is before `Players`, `ReplicatedStorage`, `DebugSettings`, `_G.ApplyDamageToPlayer`, player hooks, and `Heartbeat`.
- Verified the live Studio source compiles with `loadstring` in Edit mode.
- Ran a short `Level` Play smoke test. The persistent Studio script object is currently `Enabled=false`, so ordinary Play did not execute it; the test did not change that persistent property.
- Temporarily enabled the runtime server copy during Play and verified `ReplicatedStorage.DebugSettings` is created with the existing defaults for `GodModeEnabled`, `AutoMobSpawnsEnabled`, `SpawnStressMode`, `SpawnBurstSize`, `SpawnIntervalScale`, `MaxAliveScale`, and `PerfHudEnabled`.
- In the short smoke test, `_G.ApplyDamageToPlayer` was `nil`, so the damage-wrapper branch was not exercised.
- Local `luau` was not available in PATH; Studio `loadstring` was used for the syntax check instead.

### Risks

- Production servers will skip this debug script entirely, so any accidental reliance on `DebugSettings` in live production would remain absent instead of being created by debug tooling.
- Already-running Studio sessions need the synced source or a fresh server execution to pick up the guard.

### Rollback

- Revert `Level/ServerScriptService/Script/DebugStressTools.lua` and this changelog entry.
- In live `Level`, restore the previous source of `game.ServerScriptService.Script.DebugStressTools`.

## 2026-06-28 - Studio-to-repo chest, upgrade, inventory, and Slime sync

### Scope

- Mirrored the current live `Level` Studio `ChestRewardClient` source into the existing repo mirror `ChestRewardClient.client.lua`, including full chest animation completion handling, rolling item previews, reveal/pop reward state, `TAKE REWARD`, Space claim, and take-response timeout handling.
- Mirrored the current live `Level` Studio `UpgradesClient` source with the shorter spell-card lore, `LV.` level labels, `STATS` heading, stat delta display, combo/synergy lines, and no separate `Amplified` variant cards.
- Mirrored the current live `Four Peaks` Studio inventory remake and `InventorySnapshot` sources into the repo.
- Removed the repo-only legacy `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/InventoryController.lua` copy because the matching live Studio object is absent and no repo references to that path were found.
- Documented the current live `Level` Slime template shadow state: `ReplicatedStorage.Enemies.Normal.Slime` has `CastShadow = false` on all current BasePart descendants.
- Did not modify `SpellDefinitions`, `WeaponConfigs`, `CraftingConfig`, `MaterialDefinitions`, `CodexDefinitions`, or `InventoryService` in this sync pass.

### Files updated

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardClient.client.lua`
- `Level/StarterGUI/UpgradesGUI/UpgradesClient.lua`
- `Level/ReplicatedStorage/Enemies/Normal/Slime/MANIFEST.md`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/InventoryController.lua` (deleted)
- `Four Peaks/ServerScriptService/Script/InventorySnapshot.lua`
- `CHANGELOG_AI.md`

### Live Studio objects mirrored

- `Level`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.ChestRewardClient`
- `Level`: `game.StarterGui.UpgradesGUI.UpgradesClient`
- `Level`: `game.ReplicatedStorage.Enemies.Normal.Slime`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.InventoryController`
- `Four Peaks`: `game.ServerScriptService.Script.InventorySnapshot`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.InventoryController` was checked and is absent in the current live Studio place.

### Verification

- Confirmed connected Studio instances and switched active Studio between `Level` and `Four Peaks` for targeted sync checks.
- Dumped the four live Studio script sources through Roblox MCP plus a local receiver, then verified local repo files byte-match the dumped Studio sources.
- Studio checksum metrics matched the dump for `ChestRewardClient`, `UpgradesClient`, `InventoryController`, and `InventorySnapshot`.
- Ran Studio `loadstring(...)` compile checks for all four mirrored live script sources; all returned `ok`.
- Verified source markers for the requested behavior, including chest constants `CHEST_ROLL_START_DELAY = 1`, `CHEST_REVEAL_FAILSAFE_TIMEOUT = 12`, `CHEST_TAKE_RESPONSE_TIMEOUT = 5`, `AnimationTrack.Ended`, `AnimationTrack.Stopped`, `TAKE REWARD`, upgrade `SHORT_LORE_BY_SPELL`, `LV.` labels, `STATS`, inventory `BindActionAtPriority`, and `[InventoryController] Remake ready`.
- Searched repo references for the removed legacy inventory path and old `overlay.panel` wait pattern; none were found.
- In a short `Four Peaks` Play session, `[InventoryController] Remake ready` appeared, no `Out of local registers` error appeared, no `overlay.panel` infinite yield appeared, `InventoryGui` opened and closed through the existing `ScreenButtonsAction` / `ScreenButtonsNonce` path, one `ViewportFrame` existed, and Weapons / Spell Loadout / Materials / Codex tab text was present.
- In the same lobby Play check, `WeaponIcons`, `MaterialIcons`, and `ElementIcons` existed in `ReplicatedStorage`; `SpellIcons` was not present in the current Studio session, so spell icon display may still fall back until that asset folder exists.
- In a short `Level` Play session, client logs had no errors from the synced chest or upgrade clients, `ChestRewardGui`, `ChestOpening`, and `UpgradesGUI` existed in `PlayerGui`, and the live `ReplicatedStorage.Enemies.Normal.Slime` template had `CastShadow = false` on `Cube.003`, `Cube.004`, `Cube.009`, `Cube.010`, `Cube.011`, `Cube.012`, and `RootPart`.
- `git diff --check` was run on the touched paths; it reported one Studio-origin blank line at EOF in `Four Peaks/ServerScriptService/Script/InventorySnapshot.lua`, which was preserved to keep exact Studio source parity.

### Risks

- Full manual gameplay validation is still needed for real chest reward claiming, two consecutive chest openings, keyboard `I` inventory toggling, search-box typing behavior, weapon equip/favorite/sell, spell loadout ordering, material/Codex data browsing, and actual upgrade-card selection flows.
- The current lobby Studio session does not expose `ReplicatedStorage.SpellIcons`, even though the new inventory controller can use it when present.
- The older `Level` `ServerStorage.EnemyRigBackup.Normal.Slime` backup model still has shadowed humanoid-rig parts; this pass only mirrored the current gameplay template under `ReplicatedStorage.Enemies.Normal.Slime`.
- A pre-existing `Level` Play server log error remains: `ServerScriptService.Hybrid Terrain Hex Generator:16: attempt to index nil with 'CreateToolbar'`. It was not introduced by this sync and was not changed here.

### Rollback

- Restore the previous versions of the four mirrored script files from git.
- Restore `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/InventoryController.lua` from git if the legacy duplicate must be reintroduced.
- Revert the Slime manifest note and this changelog entry.
- No Studio rollback is needed for this pass because Studio was treated as the source of truth and was not modified.
## 2026-06-27 - Spell presentation and gameplay VFX pass

### Scope

- Added a shared presentation schema to spell definitions: icon glyph, art motif, lore copy, gameplay copy, visual direction, frame style, Witch spellbook accent, Codex category, fusion info, and VFX profile.
- Authored unique presentation profiles for all 40 base spells and 7 combination spells in `Four Peaks`.
- Extended Witch spellbook payloads, Inventory spell details, and Codex entries to consume presentation data from existing `SpellDefinitions` instead of duplicating copy in UI code.
- Extended Level runtime spell stats and `SpellVFXEvent` payloads with compact `visualProfile` data used only for local VFX rendering.
- Added client-side cast sigils and spell-profile accent geometry for projectiles, orbits, novas, zones, beams, and impacts without adding new remotes or per-spell loops.
- Kept existing unlock, loadout, upgrade, combination, Codex, RemoteEvent, and persistent data names unchanged.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/SpellDefinitions.lua`
- `Four Peaks/ReplicatedStorage/ModuleScripts/CodexDefinitions.lua`
- `Four Peaks/ServerScriptService/Script/SpellService.lua`
- `Four Peaks/ServerScriptService/Script/InventorySnapshot.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/WitchShopClient.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/WitchShopClient.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/InventoryController.lua`
- `Level/ReplicatedStorage/ModuleScripts/SpellDefinitions.lua`
- `Level/ReplicatedStorage/ModuleScript/SpellDefinitions.lua`
- `Level/ServerScriptService/Script/SpellService.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Four Peaks`: `game.ReplicatedStorage.ModuleScripts.SpellDefinitions`
- `Four Peaks`: `game.ReplicatedStorage.ModuleScripts.CodexDefinitions`
- `Four Peaks`: `game.ServerScriptService.Script.SpellService`
- `Four Peaks`: `game.ServerScriptService.Script.InventorySnapshot`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.WitchShopClient`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.InventoryController`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.WitchShopClient`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.InventoryController`
- `Level`: `game.ReplicatedStorage.ModuleScripts.SpellDefinitions`
- `Level`: `game.ReplicatedStorage.ModuleScript.SpellDefinitions`
- `Level`: `game.ServerScriptService.Script.SpellService`
- `Level`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.SpellVFXClient`

### Verification

- Ran Studio `loadstring(...)` compile checks for all changed Four Peaks and Level Lua sources; all compiled successfully.
- Fresh-required temporary Four Peaks `SpellDefinitions`: 47 spells, 80 shop products, all spells had presentation fields, and icon glyphs had no duplicates.
- Verified `FireBolt_Standard` shop product carries icon/lore presentation data.
- Fresh-required temporary Four Peaks `CodexDefinitions`: spell and combination entries build from presentation data, including `SolarFlare` fusion art motif.
- Synced changed Four Peaks and Level live Studio objects through Roblox MCP.
- Fresh-required temporary Level `SpellDefinitions`: 47 spells and runtime `visualProfile` was present for `FireBolt`.
- Full manual Play verification of moment-to-moment VFX density, Witch panel readability at every viewport size, and multiplayer Codex browsing is still recommended.

### Risks

- UI art is procedural Roblox UI/parts, not final uploaded illustration assets.
- Level uses the same presentation schema and generated runtime visual profiles, while the richer authored copy currently lives in the Four Peaks definition used by lobby UI/Codex.
- Added VFX accent parts are short-lived and shared by existing events, but very dense combat should still be profiled in a full run.

### Rollback

- Revert the files listed above and resync the same live Studio objects.
- If only gameplay VFX needs rollback, revert `Level/ServerScriptService/Script/SpellService.lua`, both Level `SpellDefinitions.lua` copies, and `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`.
## 2026-06-27 - Spellbook, spell loadout, combinations, and codex

### Scope

- Extended shared spell definitions with configurable spell loadout slot limit, combination metadata, stat-line helpers, upgrade-level summaries, loadout validation, and element damage summaries.
- Added lobby Codex definitions built from existing spell, combination, weapon, enemy, boss, elite, and material config IDs.
- Added persistent `PlayerData.spellLoadout`, `spellLoadoutConfigured`, and `Codex` fields in the existing `GlobalPlayerProgress_v1` profile, with old-profile migration and no new DataStore.
- Extended the existing Witch shop UI into a searchable, filtered, paged spellbook that shows base stats, all upgrade levels, and possible combinations.
- Added Spell Loadout and Codex tabs to the existing lobby Inventory UI, using the existing `RF_GetInventorySnapshot` and `InventoryAction` remotes.
- Added server-side spell loadout validation for equip, unequip, reorder, and set actions.
- Passed per-player unlocked spells and selected spell loadout through existing TeleportData from Four Peaks to Level.
- Updated Level to apply `SpellLoadoutCSV`, offer only selected loadout spells, and offer combination spells only after all required base spells reach max level.
- Added Codex discovery writes for spell unlocks, combination picks, defeated enemies, elites, bosses, and dropped materials.
- Kept existing RemoteEvent/RemoteFunction names and persistent profile store names unchanged.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/SpellDefinitions.lua`
- `Four Peaks/ReplicatedStorage/ModuleScripts/CodexDefinitions.lua`
- `Four Peaks/ServerScriptService/ModuleScript/PlayerData.lua`
- `Four Peaks/ServerScriptService/ModuleScript/PlayerStateStore.lua`
- `Four Peaks/ServerScriptService/Script/SpellService.lua`
- `Four Peaks/ServerScriptService/Script/InventorySnapshot.lua`
- `Four Peaks/ServerScriptService/Script/InventoryService.lua`
- `Four Peaks/ServerScriptService/Script/PortalToDungeon.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/WitchShopClient.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/WitchShopClient.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/InventoryController.lua`
- `Level/ReplicatedStorage/ModuleScripts/SpellDefinitions.lua`
- `Level/ReplicatedStorage/ModuleScript/SpellDefinitions.lua`
- `Level/ServerScriptService/ModuleScript/PlayerData.lua`
- `Level/ServerScriptService/Script/ReceiveTeleportLoadout.lua`
- `Level/ServerScriptService/Script/ProgressService.lua`
- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `Level/StarterGUI/UpgradesGUI/UpgradesClient.lua`
- `Level/StarterGUI/UpgradesGUI.ScreenGui/UpgradesClient.localscript.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Four Peaks`: `game.ReplicatedStorage.ModuleScripts.SpellDefinitions`
- `Four Peaks`: `game.ReplicatedStorage.ModuleScripts.CodexDefinitions`
- `Four Peaks`: `game.ServerScriptService.ModuleScript.PlayerData`
- `Four Peaks`: `game.ServerScriptService.ModuleScript.PlayerStateStore`
- `Four Peaks`: `game.ServerScriptService.Script.SpellService`
- `Four Peaks`: `game.ServerScriptService.Script.InventorySnapshot`
- `Four Peaks`: `game.ServerScriptService.Script.InventoryService`
- `Four Peaks`: `game.ServerScriptService.Script.PortalToDungeon`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.WitchShopClient`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.InventoryController`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.WitchShopClient`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.LocalScript.InventoryController`
- `Level`: `game.ReplicatedStorage.ModuleScripts.SpellDefinitions`
- `Level`: `game.ReplicatedStorage.ModuleScript.SpellDefinitions`
- `Level`: `game.ServerScriptService.ModuleScript.PlayerData`
- `Level`: `game.ServerScriptService.Script.ReceiveTeleportLoadout`
- `Level`: `game.ServerScriptService.Script.ProgressService`
- `Level`: `game.ServerScriptService.Script.Model.WaveController`
- `Level`: `game.StarterGui.UpgradesGUI.UpgradesClient`

### Verification

- Confirmed connected Studio instances and switched active Studio between `Four Peaks` and `Level` for targeted sync and checks.
- Synced the files listed above into live Studio through local read-only HTTP and Roblox MCP.
- Ran Studio `loadstring(...)` compile checks while syncing each changed live source; all Four Peaks sources compiled successfully.
- Ran Studio `loadstring(...)` compile checks while syncing Level server/module sources and `StarterGui.UpgradesGUI.UpgradesClient`; all compiled successfully.
- Verified Four Peaks `SpellDefinitions` in Studio: `GetLoadoutLimit()` returned `6`, locked `SolarBeam_Standard` was rejected from loadout validation, duplicate family variants were deduped, `WaterShard` normalized to `WaterShard_Standard`, `FireTornado` was not combination-ready at `Tornado` level 5, and became ready when both `FireBolt` and `Tornado` were level 6.
- Verified Four Peaks `CodexDefinitions` built `159` entries and loadout element damage summary returned three buckets for a three-element loadout.
- Verified Level `SpellDefinitions` with the same loadout and combination checks; results matched Four Peaks.
- Ran `git diff --check -- "Four Peaks" "Level" CHANGELOG_AI.md`; no whitespace errors were reported, only existing LF/CRLF conversion warnings.
- Checked Level Studio Output after sync; no new relevant errors were present.
- Checked Four Peaks Studio Output after sync; no new relevant errors from the changed scripts were present. Existing bridge configuration messages and a DataStore queue warning were present.
- Full interactive UI, multi-client party teleport, actual level-up combination offer selection, and live Codex discovery persistence still need a manual Play/multiplayer pass.

### Risks

- The Codex enemy, elite, and boss entries currently use stable mob type IDs from existing material definitions; new encounter families need matching definitions to display friendly Codex text.
- Combination offers depend on spell attribute levels reaching each spell definition's `maxLevel`; any external script that bypasses those attributes can also bypass eligibility visibility.
- Multi-client party teleport and UI refresh should still get a manual multiplayer Studio pass after this filesystem implementation.

### Rollback

- Revert the files listed above.
- Remove `CodexDefinitions` from `ReplicatedStorage.ModuleScripts`.
- Restore previous `SpellDefinitions`, `PlayerData`, Inventory, Witch shop, teleport, and Level progress scripts from git.
- Existing profiles with new `spellLoadout`, `spellLoadoutConfigured`, or `Codex` fields can be left in DataStore; older code ignores those extra fields.
## 2026-06-27 - Four Peaks lobby NPC outlines and player nameplates

### Scope

- Added a local Four Peaks NPC outline system using `Highlight` objects.
- Highlight candidates are limited to top-level models under `Workspace.NPCs` that are known interactive lobby NPCs, have `TutorialNpcId`, or contain a `ProximityPrompt`.
- The NPC outline is white, keeps fill invisible, fades in/out smoothly, supports multiple nearby NPCs, and uses one client render loop rather than one loop per NPC.
- Added lobby player nameplates using `BillboardGui` above each character head, with display name above `Lv. <level>`.
- Exposed the existing persistent `PlayerData.level` as the replicated `AccountLevel` player attribute through the existing `LobbyProgress` flow.
- Added one lobby presentation config module for the NPC outline range and nameplate max distance.
- Did not change `Level/`, persistent data structure, DataStores, RemoteEvents, RemoteFunctions, or existing remote names.

### Files updated

- `Four Peaks/ReplicatedStorage/ModuleScripts/LobbyPresentationConfig.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LobbyNpcHighlights.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/LobbyPlayerNameplates.lua`
- `Four Peaks/ServerScriptService/Script/LobbyProgress.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- `Four Peaks`: `game.ReplicatedStorage.ModuleScripts.LobbyPresentationConfig`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.LobbyNpcHighlights`
- `Four Peaks`: `game.StarterPlayer.StarterPlayerScripts.LobbyPlayerNameplates`
- `Four Peaks`: `game.ServerScriptService.Script.LobbyProgress`

### Verification

- Confirmed and re-set active Studio to `Four Peaks` before inspection and live sync.
- Synced the four source files above into active Studio through Roblox MCP.
- Ran Studio `loadstring(...)` compile checks for `LobbyPresentationConfig`, `LobbyNpcHighlights`, `LobbyPlayerNameplates`, and `LobbyProgress`; all returned `ok`.
- In Play mode, verified existing interactive models `Blacksmith`, `Witch`, `Knight`, `CharacterCreatorNPC`, and `WeaponBannerNPC` received local `LobbyNpcHighlight`; active Studio did not currently include live `Workspace.NPCs.MissionNPC`.
- Verified non-interactive `Workspace.NPCs.Rig` duplicates and `Workspace.NPCs.grzyb` did not receive highlights.
- In Play mode, added two temporary prompt-based NPC models under `Workspace.NPCs`; both were highlighted at close range, with white outline and `FillTransparency = 1`.
- Moved both temporary NPCs far outside range; both faded/disabled, with far outline transparency reaching `1`.
- Verified one `LobbyPlayerNameplate` on the local player's head, name above level, `MaxDistance = 85`, and level text `Lv. 72` sourced from `AccountLevel`.
- Verified a local `AccountLevel` attribute change from `72` to `79` updated the level label to `Lv. 79`, then restored to `Lv. 72`.
- Triggered `LoadCharacter()` in Play mode; the respawned character had exactly one `LobbyPlayerNameplate`, with no duplicate BillboardGui.
- Verified server-side `AccountLevel` returned to persistent `PlayerData.level = 72` through `LobbyProgress`.
- Checked client and server logs for relevant warnings/errors from the new lobby scripts; none were present.
- Ran `git diff --check` on `Four Peaks` and `CHANGELOG_AI.md`; only an existing LF/CRLF warning for `LobbyProgress.lua` was reported.
- A true second-player join could not be spawned from the current single-client MCP Play session; the new client code does bind `Players.PlayerAdded` and was verified for existing-player setup in Play mode.

### Risks

- New prompt-based NPCs are detected automatically, but new interactive NPCs without a prompt, `TutorialNpcId`, or allowlisted name need one of those markers to receive the outline.
- Multi-client join visibility should still get one manual multiplayer Studio pass when a multi-client test session is available.

### Rollback

- Remove `LobbyPresentationConfig`, `LobbyNpcHighlights`, and `LobbyPlayerNameplates` from live Studio and the repo.
- Restore the previous `LobbyProgress` source without the `AccountLevel` attribute update.
- Revert the files listed above and this changelog entry.
## 2026-06-22 - Poziom signed enemy root ground offset

### Scope

- Fixed enemy grounding for templates whose root part sits below the visible model bottom, including floating Slime cases observed in live Play mode.
- Changed the shared `WaveController` spawn grounding offset and `NpcService` runtime ground-follow offset from nonnegative clamped values to signed root-to-bottom offsets.
- This allows the NPC root to sit slightly below terrain when the imported model geometry requires it, so the visible bottom rests on the surface.
- Kept the underground emerge spawn behavior, spawn pools, map bounds, remotes, folders, and enemy stats unchanged.

### Files updated

- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `CHANGELOG_AI.md`

### Live Studio objects updated

- Pending final live Studio sync in this pass.

### Verification

- In live Play mode before the fix, real `WaveController` Slime spawns included a client-visible floating case with `bottomGap = 4.25` studs while terrain under the same X/Z was `Workspace.Terrain`.
- Pending final live compile and spawn probes after sync.

### Risks

- Enemy templates with intentionally unusual root placement now follow their visible bottom rather than forcing the root above terrain; this is desired for ground enemies but flying enemies should keep using `CanFly` or `IgnoreGroundSnap`.

### Rollback

- Restore the previous nonnegative clamped root-ground offset logic in `WaveController` and `NpcService`, then revert this changelog entry.
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
