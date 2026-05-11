# MANIFEST

- Roblox path: `game.StarterGui`
- Repo path: `roblox/Poziom/StarterGui`
- Structure type: `UI`
- Required by code: `Yes`
- Parity status: `PARTIAL`

## Key children

- `BossBar [ScreenGui]`
- `DailyMissions [ScreenGui]`
- `FPSCounter [ScreenGui]`
- `HP [ScreenGui]`
- `HUD [ScreenGui]`
- `InfoUI [ScreenGui]`
- `Pause [ScreenGui]`
- `PickupToastGui [ScreenGui]`
- `SpellUI [ScreenGui]`
- `UpgradesGUI [ScreenGui]`

## Scripts inside

- `StarterGui.BossBar.BossBar [LocalScript]`
- `StarterGui.DailyMissions.DailyMissionsClient [LocalScript]`
- `StarterGui.FPSCounter.FPSCounterClient [LocalScript]`
- `StarterGui.FPSCounter.PerfHudClient [LocalScript]`
- `StarterGui.HP.HealthBarClient [LocalScript]`
- `StarterGui.HUD.HUDClient [LocalScript]`
- `StarterGui.InfoUI.InfoUIClient [LocalScript]`
- `StarterGui.Pause.PauseClient [LocalScript]`
- `StarterGui.SpellUI.SpellUIClient [LocalScript]`
- `StarterGui.UpgradesGUI.UpgradesClient [LocalScript]`

## RemoteEvents / RemoteFunctions

- None live directly under `StarterGui`.
- UI scripts inside this container depend on `ReplicatedStorage.Remotes` and on named GUI descendants.

## Attributes

- No attributes were observed on the `StarterGui` root in the targeted Studio inspection.
- Child GUI attributes were not exhaustively audited in this pass.

## CollectionService tags

- No tags were observed on the `StarterGui` root in the targeted Studio inspection.

## Migration risk

- `HIGH`: UI scripts often use `WaitForChild`, named ScreenGui paths, and fixed child names. Reordering or renaming GUI containers can break runtime lookup even when script files stay unchanged.

## Notes

- This manifest covers the key top-level GUI structure needed for later reorganization planning.
- Full object parity for UI is still incomplete because nested frames, buttons, prompts, and value objects are not fully described yet.
