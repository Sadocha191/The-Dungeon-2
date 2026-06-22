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
        - The client waits `0.5` seconds after showing the GUI, then plays the full animation and freezes it at the final frame.
  - `Camera` (`Camera`)
    - Assigned to `ViewportFrame.CurrentCamera` by the client.
  - `Frame` (`Frame`)
    - `Item` (`ImageLabel`)
      - Hidden while the chest animation plays.
      - Receives the rolled item icon after the animation finishes.
      - Gets a runtime transparent `TakeRewardButton` child so clicking/tapping the item claims the reward.

## Notes

- The imported GUI/model hierarchy is not fully mirrored on disk; this manifest documents the live object contract used by code.
- The client keeps the old generated `ChestRewardGui` as a fallback only when `ChestOpening` is missing.
