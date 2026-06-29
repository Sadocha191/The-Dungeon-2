# MANIFEST

- Roblox path: `game.ReplicatedStorage.Enemies.Normal.Slime`
- Repo path: `Level/ReplicatedStorage/Enemies/Normal/Slime`
- Object parity status: `PARTIAL`

## Live template notes

- Live Studio is the source of truth for this asset.
- On `2026-05-02`, the live `Slime` template was rotated by `+90 degrees` around the `Y` axis to fix the model facing sideways while chasing the player.
- On `2026-05-02`, the live `Slime` template also received a facing-yaw correction so `NpcPresentation.client.lua` can apply the rotation relative to `RootPart` at runtime.
- On `2026-05-20`, a targeted recheck confirmed the current live `NpcFacingYawDegrees` value is `-90`.
- On `2026-05-20`, the live `Slime` template received `Idle [Animation]`, `Run [Animation]`, and `Attack [Animation]` with `AnimationId = rbxassetid://99390813148093` so the current client-side NPC presentation path can always find a loop for the existing state probes.
- On `2026-05-20`, a real `Play` recheck showed that asset `rbxassetid://99390813148093` does start a track but does not visibly deform the current live `Slime` rig because the asset targets do not match the current model structure.
- On `2026-05-20`, the live `Slime` template was switched to `NpcLightweight = true` so `NpcPresentation.client.lua` now uses the existing procedural motion path for this rig instead of relying on the incompatible imported animation asset.
- On `2026-06-28`, a targeted Studio sync confirmed the current live `ReplicatedStorage.Enemies.Normal.Slime` template has `CastShadow = false` on `Cube.003`, `Cube.004`, `Cube.009`, `Cube.010`, `Cube.011`, `Cube.012`, and transparent `RootPart`; no transparency, outline, mesh, or rig structure changes were made in this repo mirror.
- The live template currently uses:
  - `PrimaryPart = RootPart`
  - `AnimationController` with an `Animator`
  - `NpcLightweight = true`
  - `CastShadow = false` on all current BasePart descendants
  - `Idle [Animation]`
  - `Run [Animation]`
  - `Attack [Animation]`
  - mesh parts `Cube.003`, `Cube.004`, `Cube.009`, `Cube.010`, `Cube.011`, `Cube.012`
  - `RootPart` with child `Bone`
  - `InitialPoses` folder
  - `AnimSaves` object value
- The template remains unanchored in `ReplicatedStorage`; runtime anchoring still happens in `ServerScriptService.ModuleScript.NpcService.Register`.
- The visual-facing correction now depends on the runtime client reading `NpcFacingYawDegrees`; rotating the whole template alone is not sufficient when the render path preserves `root -> pivot` offset.
- The imported `Slime` animation asset currently appears to target a different rig naming scheme (`Armature`, `slime 2`, and multiple `Cube.*` targets that do not exist as live `Bone` objects on the current template), which is why the procedural fallback is now the live fix.

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
