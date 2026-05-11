# MANIFEST

- Roblox path: `game.Workspace.Rig`
- Repo path: `roblox/CzterySzczyty/Workspace/Rig`
- Structure type: `Model`
- Required by code: `Yes`
- Parity status: `PARTIAL`

## Key children

- `Animate [LocalScript]`
- humanoid body-part descendants such as `Humanoid`, `HumanoidRootPart`, `Head`, `UpperTorso`, `LowerTorso`, limbs, and mesh parts were observed in live Studio

## Scripts inside

- `Workspace.Rig.Animate [LocalScript]`

## RemoteEvents / RemoteFunctions

- None were observed directly under this model in the targeted Studio inspection.

## Attributes

- No attributes were observed on the model root in the targeted Studio inspection.

## CollectionService tags

- No tags were observed on the model root in the targeted Studio inspection.

## Migration risk

- `HIGH`: animation controllers and any code that clones or references this rig can depend on exact descendant names and on the presence of the `Animate` script in place.

## Notes

- The repo keeps one canonical source mirror at `roblox/CzterySzczyty/Workspace/Rig/Animate.lua`.
- Earlier parity analysis found two identical live `Workspace.Rig.Animate` instances with the same path text. A later recheck saw one visible descendant.
- The filesystem cannot encode duplicate sibling instance count at the same path. Treat this as unresolved object-parity ambiguity until a manual Studio decision confirms whether the duplicate still exists.
