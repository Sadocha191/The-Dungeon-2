# ChestOpening

Roblox path: `game.StarterGui.ChestOpening`
Repo path: `Level/StarterGUI/ChestOpening`
Object parity status: `PARTIAL`

## Purpose

Authored chest-opening reward UI used by `StarterPlayer.StarterPlayerScripts.LocalScript.ChestRewardClient`.

## Expected Structure

- `ChestOpening` (`ScreenGui`)
  - Starts disabled in Studio and is enabled by `ChestRewardClient` when `ChestItemEvent` sends `type = "openReward"`.
  - `ViewportFrame` (`ViewportFrame`)
    - `WorldModel` (`WorldModel`)
      - `skrzynia` (`Model`)
        - Has `AnimationController.Animator`.
        - Has `OpenAnimation` (`Animation`) with `AnimationId = rbxassetid://128606196135074`.
        - Has the animated armature root `Bone`; its authored root motion is transferred to the model pivot by `ChestOpeningRootMotion.client.lua`.
        - The client plays the full animation and freezes it at the final frame.
  - `Camera` (`Camera`)
    - Assigned to `ViewportFrame.CurrentCamera` by the client.
  - `Frame` (`Frame`)
    - `Item` (`ImageLabel`)
      - Hidden while the chest animation plays.
      - Receives the rolled item icon after the animation finishes.
      - Gets a runtime transparent `TakeRewardButton` child so clicking/tapping the item claims the reward.

## Runtime Scripts

- `ChestRewardClient.client.lua` starts the authored animation and controls the reward reveal.
- `ChestOpeningRootMotion.client.lua` reads the animated root `Bone.Transform` after animation evaluation, applies the same transform to the `skrzynia` model pivot, and clears the bone transform to prevent doubled movement. It does not create a replacement tween or procedural jump.

## Notes

- The imported GUI/model hierarchy is not fully mirrored on disk; this manifest documents the live object contract used by code.
- The client keeps the old generated `ChestRewardGui` as a fallback only when `ChestOpening` is missing.
