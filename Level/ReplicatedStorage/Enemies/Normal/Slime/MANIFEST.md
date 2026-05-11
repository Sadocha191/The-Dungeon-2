# MANIFEST

- Roblox path: `game.ReplicatedStorage.Enemies.Normal.Slime`
- Repo path: `Level/ReplicatedStorage/Enemies/Normal/Slime`
- Object parity status: `PARTIAL`

## Live template notes

- Live Studio is the source of truth for this asset.
- On `2026-05-02`, the live `Slime` template was rotated by `+90°` around the `Y` axis to fix the model facing sideways while chasing the player.
- On `2026-05-02`, the live `Slime` template also received attribute `NpcFacingYawDegrees = 90` so `NpcPresentation.client.lua` can apply the facing correction relative to `RootPart` at runtime.
- The live template currently uses:
  - `PrimaryPart = RootPart`
  - `AnimationController` with an `Animator`
  - mesh parts `Cube.003`, `Cube.004`, `Cube.009`, `Cube.010`, `Cube.011`, `Cube.012`
  - `RootPart` with child `Bone`
  - `InitialPoses` folder
  - `AnimSaves` object value
- The template remains unanchored in `ReplicatedStorage`; runtime anchoring still happens in `ServerScriptService.ModuleScript.NpcService.Register`.
- The visual-facing correction now depends on the runtime client reading `NpcFacingYawDegrees`; rotating the whole template alone is not sufficient when the render path preserves `root -> pivot` offset.

## Historical snapshot note

- The existing placeholder entries in this repo folder:
  - `Body.Part`
  - `Core.Part`
  - `Crest.Part`
  - `NubL.Part`
  - `NubR.Part`
  - `Puddle.Part`
  - `HumanoidRootPart.Part`
  - `Script`
- are older snapshot artifacts from the previous `Slime` rig and should be treated as `stale_snapshot` until a deeper non-script parity pass rewrites this folder to match the current live template structure exactly.
