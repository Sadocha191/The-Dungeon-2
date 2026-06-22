# skrzynia

Roblox path: `game.Workspace.skrzynia`
Repo path: `Level/Workspace/skrzynia`
Object parity status: `PARTIAL`

## Purpose

Live world chest model template used by `ServerScriptService.Script.ChestService`.

## Expected Structure

- `skrzynia` (`Model`)
  - `PrimaryPart`: `RootPart`
  - `RootPart` (`Part`)
  - `Cylinder.001` (`MeshPart`)
  - `Cube.002` (`MeshPart`)
  - `AnimationController` (`AnimationController`)
    - `Animator` (`Animator`)

## Runtime Use

- `ChestService` clones this model for spawned world chests.
- Spawned clones are anchored by the service and receive a runtime `OpenPrompt` (`ProximityPrompt`).
- The source `Workspace.skrzynia` model is ignored by chest placement raycasts so it can remain in the place as the live template.

## Notes

- The imported MeshPart/Bone hierarchy is not fully mirrored on disk; this manifest documents the live object contract used by code.
- If `Workspace.skrzynia` is missing, `ChestService` falls back to its older generated-Part chest model.
