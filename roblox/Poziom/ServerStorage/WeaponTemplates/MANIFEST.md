# MANIFEST

- Roblox path: `game.ServerStorage.WeaponTemplates`
- Repo path: `roblox/Poziom/ServerStorage/WeaponTemplates`
- Structure type: `Tool folder`
- Required by code: `Yes`
- Parity status: `PARTIAL`

## Key children

- `Bow [Folder]`
- `Halberd [Folder]`
- `Pistol [Folder]`
- `Scythe [Folder]`
- `Staff [Folder]`
- `Sword [Folder]`

## Scripts inside

- `Bow/Hunter’s Longbow`: `BowClient [LocalScript]`, `BowServer [Script]`
- `Bow/Stormwind Recurve`: `Client [LocalScript]`, `Projectile [Script]`, `Server [Script]`
- `Halberd/Dragonspear Halberd`: `LocalScript [LocalScript]`, `Properties [Script]`, `qPerfectionWeld [Script]`
- `Halberd/Warden’s Halberd`: `Local Gui [LocalScript]`, `qPerfectionWeld [Script]`, `SwordScript [Script]`
- `Pistol/Blackpowder Flintlock`: `LocalScript [LocalScript]`, `Script [Script]`, `qPerfectionWeld [Script]`
- `Scythe/Reaper’s Crescent`: `ScytheClient [LocalScript]`, `ScytheMain [Script]`
- `Staff/Apprentice Arcstaff`: `ActivateScript [LocalScript]`, `MagicScript [Script]`
- `Staff/Archmage’s Worldstaff`: `StaffClient [LocalScript]`, `StaffMain [Script]`
- `Sword/Excalion, Blade of Kings`: `Client [LocalScript]`, `CresHorror [Script]`, `DeathSouls [Script]`, `MouseIcon [LocalScript]`, `Server [Script]`, `SoulMonitor [Script]`
- `Sword/Knight’s Oath`: `MouseIcon [LocalScript]`, `SwordScript [Script]`

## RemoteEvents / RemoteFunctions

- Embedded remotes were observed inside tool subtrees:
- `Bow`: `BowRE [RemoteEvent]`, `Remote [RemoteEvent]`
- `Pistol`: `gunremote [RemoteEvent]`
- `Scythe`: `MouseInput [RemoteFunction]`
- `Staff/Apprentice Arcstaff`: `EnergyWave [RemoteEvent]`, `FireZap [RemoteEvent]`, `SeverTranstition [RemoteEvent]`, `StoneWall [RemoteEvent]`, `StoneZap [RemoteEvent]`
- `Staff/Archmage’s Worldstaff`: `Remote [RemoteEvent]`, `MouseInput [RemoteFunction]`

## Attributes

- No attributes were observed on the `WeaponTemplates` folder root in the targeted Studio inspection.
- Descendant attributes on individual tools were not exhaustively audited in this pass.

## CollectionService tags

- No tags were observed on the `WeaponTemplates` folder root in the targeted Studio inspection.

## Migration risk

- `HIGH`: weapon scripts rely on exact `Tool` structure, embedded remotes, descendants such as `Handle`, `Light`, `Attachment`, and script-relative paths like `script.Parent`.

## Notes

- This manifest documents the live category layout and representative script-bearing tool structure.
- Full object parity is still incomplete here because the repo does not yet describe every non-script descendant of each tool, such as parts, attachments, particle emitters, sounds, and prompts.
