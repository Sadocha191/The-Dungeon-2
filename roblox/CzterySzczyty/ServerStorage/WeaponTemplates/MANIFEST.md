# MANIFEST

- Roblox path: `game.ServerStorage.WeaponTemplates`
- Repo path: `roblox/CzterySzczyty/ServerStorage/WeaponTemplates`
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
- `Scythe/Reaper’s Crescent`: `ScytheClient [LocalScript]`, `ScytheMain [Script]`, `ScytheMain/BulletScript [Script]`, `ScytheMain/GravityShield [Script]`, `ScytheMain/GravityShieldLocal [LocalScript]`
- `Staff/Apprentice Arcstaff`: `ActivateScript [LocalScript]`, `MagicScript [Script]`, `Burn/BurnScript [Script]`, `EnergyNameScript [Script]`, `StaffCore/Attachment/BillboardGui/SpinningScript [Script]`, `StaffCore/IdleScript [Script]`, `StaffCore/LightningScript [Script]`
- `Staff/Archmage’s Worldstaff`: `StaffClient [LocalScript]`, `StaffMain [Script]`, `StaffMain/BigBulletScript [Script]`, `StaffMain/MeteorStormScript [Script]`, `StaffMain/MeteorStormScript/BulletScript [Script]`
- `Sword/Excalion, Blade of Kings`: `Client [LocalScript]`, `CresHorror [Script]`, `DeathSouls [Script]`, `DeathSouls/SoulScript [Script]`, `Fireball/Despawn [Script]`, `Handle/Light/Fire_Effect [Script]`, `MouseIcon [LocalScript]`, `Server [Script]`, `Server/AfterImageScript [Script]`, `Server/AfterImageScript/Decimate [Script]`, `Server/AfterImageScript/SlowScript [Script]`, `Server/Decimate [Script]`, `Server/SoulHunt [Script]`, `Server/SoulHunt/SoulHunt_Client [LocalScript]`, `Server/SoulHunt/SoulHunt_Seeker [LocalScript]`, `Server/SoulScript [Script]`, `Server/SoulScript/Decimate [Script]`, `SoulMonitor [Script]`
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

- `HIGH`: tool descendants are path-sensitive, and many scripts use `script.Parent`, `FindFirstChild`, embedded remotes, and named descendants such as `Handle`, `Light`, `Burn`, `ScytheMain`, or `StaffMain`.

## Notes

- This manifest documents the live folder layout and the tool families most likely to break during later reorganization.
- Script parity for the known Studio-only subtree is complete, but full object parity here still needs deeper manifesting of non-script descendants when a later migration plan requires it.
