# CHANGELOG_AI

This file tracks AI-made repo changes and the intended rollback path.

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
