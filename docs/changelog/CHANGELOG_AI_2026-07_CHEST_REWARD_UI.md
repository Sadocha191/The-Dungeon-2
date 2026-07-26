# Chest reward reveal UI and run HUD cleanup

## Scope

- Added a responsive presentation layer to the authored Level chest-opening animation.
- The final reward now shows rarity, source, item name, description, exact stat changes and stack limit.
- Reused the existing server-selected payload and existing claim controls; reward rolling, granting, pause state and remotes are unchanged.
- Removed the large `Run Stats` panel that appeared during pause and chest opening.
- Preserved the compact collected-item icon grid on the right side during active runs.

## Files

- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/ChestRewardPresentation.client.lua`
- `Level/StarterPlayer/StarterPlayerScripts/LocalScript/RunStatsHud.client.lua`
- `Level/StarterGUI/ChestOpening/MANIFEST.md`

## Validation

- Reviewed the complete chest payload contract from `ChestItemService`: item and fallback rewards include display names, descriptions and formatted modifier lines.
- Verified the new presentation controller does not send reward requests or mutate reward data.
- Verified the rewritten run HUD only listens for inventory snapshots and `RunStarted` visibility.
- Compared the branch against `main`; only the Level client presentation and its manifest are changed.

## Not verified

- Roblox Studio Play and device-emulator validation were not available in this session.
- The authored `ChestOpening` hierarchy is only partially mirrored in the repository, so final pixel placement must be confirmed against the live Studio GUI before publishing.

## Rollback

Revert the PR. No DataStore, remote, teleport, server gameplay or migration rollback is required.
