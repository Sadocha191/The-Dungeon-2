# MANIFEST

- Roblox path: `game.ReplicatedStorage.Enemies.Normal.Grzyb`
- Repo path: `Level/ReplicatedStorage/Enemies/Normal/Grzyb`
- Object parity status: `PARTIAL`

## Live template notes

- Live Studio is the source of truth for this asset.
- On `2026-06-21`, the live enemy template was added from a clone of `game.Workspace.Grzyb`.
- The source model did not have a dedicated root part, so the live enemy template received a transparent `RootPart` and now uses `PrimaryPart = RootPart`.
- The live template has an `AnimationController` with an `Animator`.
- The live template has `NpcFacingYawDegrees = -90` so runtime presentation rotates it 90 degrees clockwise around the vertical axis.
- No explicit `Idle`, `Run`, or `Attack` animation asset was assigned during this pass.

## Repo mirror note

- This repo folder is manifest-only for now and does not fully mirror the imported MeshPart hierarchy.
