# MANIFEST

- Roblox path: `game.ReplicatedStorage.RemoteFunctions`
- Repo path: `roblox/CzterySzczyty/ReplicatedStorage/RemoteFunctions`
- Structure type: `Remote folder`
- Required by code: `Yes`
- Parity status: `COMPLETE`

## Key children

- `ConvertWeaponPoints [RemoteFunction]`
- `GetActiveBanners [RemoteFunction]`
- `GetGachaState [RemoteFunction]`
- `PartyQuery [RemoteFunction]`
- `RF_ClaimMission [RemoteFunction]`
- `RF_GetInventorySnapshot [RemoteFunction]`
- `RF_GetMissions [RemoteFunction]`
- `RF_GetTutorialState [RemoteFunction]`
- `RollBanner [RemoteFunction]`

## Scripts inside

- No scripts were observed inside this folder in the targeted Studio inspection.

## RemoteEvents / RemoteFunctions

- `RemoteEvents`: none in this folder
- `RemoteFunctions`: `ConvertWeaponPoints`, `GetActiveBanners`, `GetGachaState`, `PartyQuery`, `RF_ClaimMission`, `RF_GetInventorySnapshot`, `RF_GetMissions`, `RF_GetTutorialState`, `RollBanner`

## Attributes

- No attributes were observed on the folder root in the targeted Studio inspection.

## CollectionService tags

- No tags were observed on the folder root in the targeted Studio inspection.

## Migration risk

- `HIGH`: request/response flows for missions, inventory, banners, party state, and tutorial state depend on both the folder path and exact function names.

## Notes

- This folder is flatter than the weapon or UI structures, so a single manifest is enough to document the current live object set.
