# MANIFEST

- Roblox path: `game.Workspace.Budynki.Portal`
- Repo path: `roblox/CzterySzczyty/Workspace/Budynki/Portal`
- Structure type: `Portal model`
- Required by code: `Yes`
- Parity status: `PARTIAL`

## Key children

- `Cylinder.006 [MeshPart]`
- `Cylinder.007 [MeshPart]`
- `Cylinder.008 [MeshPart]`
- `PortalTeleport [Part]`
- `stone_archway_02 [MeshPart]`

## Scripts inside

- No scripts were observed inside this model in the targeted Studio inspection.

## RemoteEvents / RemoteFunctions

- None were observed directly under this model in the targeted Studio inspection.
- Portal flow is expected to coordinate with external remotes such as `OpenLevelSelect`, `RequestLevelTeleport`, and `TeleportStatus`.

## Attributes

- No attributes were observed on the model root in the targeted Studio inspection.

## CollectionService tags

- No tags were observed on the model root in the targeted Studio inspection.

## Migration risk

- `HIGH`: portal scripts and UI can depend on both the live model path and the `PortalTeleport` child name. Do not rename or move this structure without checking all portal, teleport, and level-select usages.

## Notes

- The current live lobby portal was observed at `Workspace.Budynki.Portal`, not at `Workspace.Portal`, `Workspace.PortalModel`, or a root-level `Workspace.PortalTeleport`.
- Generic portal names still matter as documentation targets because code or earlier plans may refer to them conceptually, but the current live path should be treated as the Studio source of truth.
