# MANIFEST

- Roblox path: `game.ReplicatedStorage.Remotes`
- Repo path: `roblox/Poziom/ReplicatedStorage/Remotes`
- Structure type: `Remote folder`
- Required by code: `Yes`
- Parity status: `COMPLETE`

## Key children

- `ChestItemEvent [RemoteEvent]`
- `ClientReady [RemoteEvent]`
- `ClientWorldLoaded [RemoteEvent]`
- `DailyMissionsUpdated [RemoteEvent]`
- `DamageIndicatorEvent [RemoteEvent]`
- `GetDailyMissions [RemoteFunction]`
- `MissionSummaryEvent [RemoteEvent]`
- `NpcBatchEvent [RemoteEvent]`
- `NpcSyncRequest [RemoteEvent]`
- `PartyLevelUp [RemoteEvent]`
- `PartyUpgradePicked [RemoteEvent]`
- `PartyXPUpdate [RemoteEvent]`
- `PauseMenuEvent [RemoteEvent]`
- `PickupIndicatorEvent [RemoteEvent]`
- `PickupToastEvent [RemoteEvent]`
- `PlayerProgressEvent [RemoteEvent]`
- `RemotesInit [Script]`
- `ReportClientError [RemoteEvent]`
- `SpellEvent [RemoteEvent]`
- `SpellVFXEvent [RemoteEvent]`
- `WaveStatusEvent [RemoteEvent]`
- `WeaponEvent [RemoteEvent]`
- `WeaponSwingVFX [RemoteEvent]`

## Scripts inside

- `RemotesInit [Script]`

## RemoteEvents / RemoteFunctions

- `RemoteEvents`: `ChestItemEvent`, `ClientReady`, `ClientWorldLoaded`, `DailyMissionsUpdated`, `DamageIndicatorEvent`, `MissionSummaryEvent`, `NpcBatchEvent`, `NpcSyncRequest`, `PartyLevelUp`, `PartyUpgradePicked`, `PartyXPUpdate`, `PauseMenuEvent`, `PickupIndicatorEvent`, `PickupToastEvent`, `PlayerProgressEvent`, `ReportClientError`, `SpellEvent`, `SpellVFXEvent`, `WaveStatusEvent`, `WeaponEvent`, `WeaponSwingVFX`
- `RemoteFunctions`: `GetDailyMissions`

## Attributes

- No attributes were observed on the folder root in the targeted Studio inspection.

## CollectionService tags

- No tags were observed on the folder root in the targeted Studio inspection.

## Migration risk

- `HIGH`: client and server code use hard-coded remote names and the `ReplicatedStorage.Remotes` path. Do not rename, merge, or move this folder before a full usage audit.

## Notes

- This structure is one of the main runtime contracts between server, client, and UI code in `Poziom`.
- The manifest covers the current known live folder contents from the targeted parity inspection. Child object properties beyond name and class were not exhaustively exported in this pass.
