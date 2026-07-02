# CHANGELOG_AI 2026-07

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
