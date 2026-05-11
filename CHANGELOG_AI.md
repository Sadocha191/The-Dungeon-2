# CHANGELOG_AI

This file tracks AI-made repo changes and the intended rollback path.

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
