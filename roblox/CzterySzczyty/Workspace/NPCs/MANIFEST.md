# MANIFEST

- Roblox path: `game.Workspace.NPCs`
- Repo path: `roblox/CzterySzczyty/Workspace/NPCs`
- Structure type: `NPC folder`
- Required by code: `Yes`
- Parity status: `PARTIAL`

## Key children

- `Blacksmith [Model]`
- `CharacterCreatorNPC [Model]`
- `Knight [Model]`
- `WeaponBannerNPC [Model]`
- `Witch [Model]`

## Scripts inside

- `Workspace.NPCs.Blacksmith.Animate [LocalScript]`
- `Workspace.NPCs.CharacterCreatorNPC.CharacterCreatorNPC [Script]`
- `Workspace.NPCs.WeaponBannerNPC.WeaponBannerNPC [Script]`

## RemoteEvents / RemoteFunctions

- No remotes were observed directly under the `NPCs` folder.
- NPC services and prompts are expected to communicate through `ReplicatedStorage.RemoteEvents` and `ReplicatedStorage.RemoteFunctions`.

## Attributes

- No attributes were observed on the folder root in the targeted Studio inspection.
- Model-level attributes and prompt configuration were not exhaustively audited in this pass.

## CollectionService tags

- No tags were observed on the folder root in the targeted Studio inspection.

## Migration risk

- `HIGH`: NPC model names and exact hierarchy are sensitive because services, prompts, and tutorial or shop flows can reference them by path or by contained prompt layout.

## Notes

- The live `Workspace.NPCs` folder does not currently show `MissionNPC` in this targeted Studio inspection.
- Historical repo snapshots under `Four Peaks/Workspace/NPCs` therefore remain a manual-decision area and should not be treated as live parity evidence.
