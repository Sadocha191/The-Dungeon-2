# MANIFEST

- Roblox path: `game.ReplicatedStorage.Enemies.Elite.Golem`
- Repo path: `Level/ReplicatedStorage/Enemies/Elite/Golem`
- Object parity status: `PARTIAL`

## Live template notes

- Live Studio is the source of truth for this asset.
- On `2026-05-20`, the live `Golem` template received `Idle [Animation]`, `Run [Animation]`, and `Attack [Animation]` with `AnimationId = rbxassetid://93249939332915` so the current client-side NPC presentation path can always find a loop for the existing state probes.
- The live template currently uses:
  - `AnimationController` with an `Animator`
  - `Idle [Animation]`
  - `Run [Animation]`
  - `Attack [Animation]`
  - mesh parts `Cube.003`, `Cube.004`, `Cube.007`
  - `RootPart`
  - `RootPart1`
  - `InitialPoses` folder
  - `AnimSaves` object value
- The template remains unanchored in `ReplicatedStorage`; runtime anchoring still happens in `ServerScriptService.ModuleScript.NpcService.Register`.

## Historical snapshot note

- The existing placeholder entries in this repo folder:
  - `Body.Part`
  - `Core.Part`
  - `Guard.Part`
  - `Head.Part`
  - `ShoulderL.Part`
  - `ShoulderR.Part`
  - `HumanoidRootPart.Part`
  - `Script`
- are older snapshot artifacts from the previous `Golem` rig and should be treated as `stale_snapshot` until a deeper non-script parity pass rewrites this folder to match the current live template structure exactly.
