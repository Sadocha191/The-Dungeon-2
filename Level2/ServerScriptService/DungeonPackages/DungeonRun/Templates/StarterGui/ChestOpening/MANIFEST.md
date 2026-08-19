# ChestOpening

Roblox path: `game.StarterGui.ChestOpening`
Repo path: `Level/StarterGUI/ChestOpening`
Object parity status: `PARTIAL`

## Purpose

Authored chest-opening animation UI used by the Level reward flow. The imported viewport hierarchy remains Studio-owned, while runtime scripts add the reward controls and readable item details.

## Expected Structure

- `ChestOpening` (`ScreenGui`)
  - Starts disabled in Studio and is enabled when `ChestItemEvent` sends `type = "openReward"`.
  - `ViewportFrame` (`ViewportFrame`)
    - `WorldModel` (`WorldModel`)
      - `skrzynia` (`Model`)
        - Has `AnimationController.Animator`.
        - Has `OpenAnimation` (`Animation`) with `AnimationId = rbxassetid://128606196135074`.
        - Has the animated armature root `Bone`; authored root motion is transferred to the model pivot by `ChestOpeningRootMotion.client.lua`.
  - `Camera` (`Camera`)
    - Assigned to `ViewportFrame.CurrentCamera` by `ChestRewardClient.client.lua`.
  - `Frame` (`Frame`)
    - `Item` (`ImageLabel`)
      - Hidden while the chest animation starts.
      - Cycles preview icons during the roll and lands on the server-selected reward.
      - Gets a transparent runtime claim button so clicking or tapping the item accepts it.

## Runtime Presentation

`ChestRewardClient.client.lua` remains the owner of animation playback, reward reveal timing, claiming and fallback UI.

`ChestRewardPresentation.client.lua` adds a presentation layer to the authored `ChestOpening` GUI:

- dark responsive backdrop,
- opening status while the animation is playing,
- rarity-colored reward card after the final reveal,
- item name and description,
- exact stat changes from the server payload,
- stack limit or immediate-reward label,
- responsive placement for desktop and narrower screens,
- restyling and positioning of the existing `ChestRewardActions` claim controls.

The presentation controller does not roll rewards, grant items, change pause state or send additional remote requests.

## Runtime Scripts

- `ChestRewardClient.client.lua` controls the reward flow and authored animation.
- `ChestRewardPresentation.client.lua` renders the final reward information.
- `ChestOpeningRootMotion.client.lua` transfers animated root motion to the `skrzynia` model pivot and prevents doubled movement.

## Notes

- The imported GUI/model hierarchy is not fully mirrored on disk; this manifest documents the live object contract used by code.
- The generated `ChestRewardGui` remains a fallback only when the authored `ChestOpening` GUI is missing.
- The old pause/chest `Run Stats` panel is intentionally removed. `RunStatsHud.client.lua` now only renders the compact collected-item icons during an active run.
