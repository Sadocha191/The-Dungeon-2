# MANIFEST

- Roblox path: `game.ReplicatedStorage.Enemies.Elite.Ent`
- Repo path: `Level/ReplicatedStorage/Enemies/Elite/Ent`
- Object parity status: `PARTIAL`

## Live template notes

- Live Studio is the source of truth for this asset.
- On `2026-06-21`, the live enemy template was replaced with a clone of `game.Workspace.Ent`.
- The live template currently uses `PrimaryPart = RootPart`.
- The live template has an `AnimationController` with an `Animator`.
- The live template has `NpcFacingYawDegrees = -90` so runtime presentation rotates it 90 degrees clockwise around the vertical axis.
- `WaveController` gives `Ent` a per-mob `visualScale = 3.3`, slightly larger than the default elite scale of `3`.
- No explicit `Idle`, `Run`, or `Attack` animation asset was assigned during this pass.

## Historical snapshot note

- The older placeholder entries in this repo folder are stale object snapshots and do not fully mirror the current imported live model.
