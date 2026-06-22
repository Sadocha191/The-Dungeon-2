# GuildLocations Manifest

Roblox path: `game.Workspace.GuildLocations`

Repo path: `Guild/Workspace/GuildLocations`

Object-parity status: `PARTIAL`

## Purpose

`GuildLocations` contains physical location models for the Guild place castle hub. The live server script also idempotently creates and refreshes these models so prompts are not duplicated during runtime.

## Children

Each child is a `Model` with:

- `GuildLocationId` attribute matching the model name.
- `DisplayName` attribute for UI/signage.
- `Status = "Coming soon"` attribute.
- `Ground`, `Building`, `Entrance`, and `Sign` `Part` children.
- `Sign.LocationBillboard.NameLabel` for visible location signage.
- `Entrance.GuildLocationPrompt` `ProximityPrompt` with `GuildLocationId` attribute.

Expected models:

- `Dojo`
- `Treasury`
- `HallOfFame`
- `Farms`
- `Mine`
- `Fishing`
- `BossRaid`

`Treasury` is now an active location: its prompt opens the real guild treasury panel. The other listed locations remain placeholders.

## Security

Prompts are not trusted by the client. `GuildPlace.server.lua` handles `ProximityPrompt.Triggered`, validates the player through server-side guild membership, and only then fires `RemoteEvents.GuildLocationOpened`. For `Treasury`, all deposit/spend mutations go through server-owned RemoteFunctions and DataStore validation.

## Notes

Most geometry is still placeholder art. Treasury resource donation/spending is implemented, but no combat upgrades, rankings, production, fishing, mining, farming, or raid gameplay is implemented here yet.
