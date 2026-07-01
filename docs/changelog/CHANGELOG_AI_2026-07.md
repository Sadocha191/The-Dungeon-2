# CHANGELOG_AI 2026-07

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
