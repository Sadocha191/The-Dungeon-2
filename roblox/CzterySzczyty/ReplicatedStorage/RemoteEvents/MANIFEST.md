# MANIFEST

- Roblox path: `game.ReplicatedStorage.RemoteEvents`
- Repo path: `roblox/CzterySzczyty/ReplicatedStorage/RemoteEvents`
- Structure type: `Remote folder`
- Required by code: `Yes`
- Parity status: `COMPLETE`

## Key children

- `AttackRequest [RemoteEvent]`
- `BlacksmithAction [RemoteEvent]`
- `BlacksmithSync [RemoteEvent]`
- `ChangeRace [RemoteEvent]`
- `CreateProfile [RemoteEvent]`
- `CreateProfileRequest [RemoteEvent]`
- `CreateProfileResponse [RemoteEvent]`
- `DialogueFinishedEvent [RemoteEvent]`
- `EquipItem [RemoteEvent]`
- `InventoryAction [RemoteEvent]`
- `InventorySync [RemoteEvent]`
- `OpenBlacksmithUI [RemoteEvent]`
- `OpenCharacterCreation [RemoteEvent]`
- `OpenDialogueEvent [RemoteEvent]`
- `OpenLevelSelect [RemoteEvent]`
- `OpenWeaponBannerUI [RemoteEvent]`
- `PartyAction [RemoteEvent]`
- `PlayerProgressEvent [RemoteEvent]`
- `RequestLevelTeleport [RemoteEvent]`
- `RerollRaceRequest [RemoteEvent]`
- `RerollRaceResponse [RemoteEvent]`
- `SpellEvent [RemoteEvent]`
- `TeleportStatus [RemoteEvent]`
- `TutorialTargetEvent [RemoteEvent]`
- `WitchShopEvent [RemoteEvent]`

## Scripts inside

- No scripts were observed inside this folder in the targeted Studio inspection.

## RemoteEvents / RemoteFunctions

- `RemoteEvents`: `AttackRequest`, `BlacksmithAction`, `BlacksmithSync`, `ChangeRace`, `CreateProfile`, `CreateProfileRequest`, `CreateProfileResponse`, `DialogueFinishedEvent`, `EquipItem`, `InventoryAction`, `InventorySync`, `OpenBlacksmithUI`, `OpenCharacterCreation`, `OpenDialogueEvent`, `OpenLevelSelect`, `OpenWeaponBannerUI`, `PartyAction`, `PlayerProgressEvent`, `RequestLevelTeleport`, `RerollRaceRequest`, `RerollRaceResponse`, `SpellEvent`, `TeleportStatus`, `TutorialTargetEvent`, `WitchShopEvent`
- `RemoteFunctions`: none in this folder

## Attributes

- No attributes were observed on the folder root in the targeted Studio inspection.

## CollectionService tags

- No tags were observed on the folder root in the targeted Studio inspection.

## Migration risk

- `HIGH`: lobby systems, character creation, inventory, party flow, teleport flow, and NPC services depend on these exact names and on the `ReplicatedStorage.RemoteEvents` path.

## Notes

- This folder is the main event contract for `Cztery szczyty`.
- The manifest is enough to document the current live remote set, but it does not replace usage auditing before any rename or move.
