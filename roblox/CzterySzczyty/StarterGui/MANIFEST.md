# MANIFEST

- Roblox path: `game.StarterGui`
- Repo path: `roblox/CzterySzczyty/StarterGui`
- Structure type: `UI`
- Required by code: `Yes`
- Parity status: `PARTIAL`

## Key children

- `BannerUI [ScreenGui]`
- `BlacksmithGui [ScreenGui]`
- `BountyBoardGui [ScreenGui]`
- `CharacterCreationUI [ScreenGui]`
- `DialogueUI [ScreenGui]`
- `FPSCounter [ScreenGui]`
- `InventoryGui [ScreenGui]`
- `MineGui [ScreenGui]`
- `MissionsGui [ScreenGui]`
- `PartyGui [ScreenGui]`
- `PickupToastGui [ScreenGui]`
- `PlayerHudGui_Lobby [ScreenGui]`
- `PortalUI [ScreenGui]`
- `ProfileStats [ScreenGui]`
- `ScreenGuiButtons [ScreenGui]`
- `Settings [ScreenGui]`
- `SpellMenu [ScreenGui]`
- `TeleportOverlayGui [ScreenGui]`
- `TutorialHUD [ScreenGui]`
- `WitchShopGui [ScreenGui]`

## Scripts inside

- `StarterGui.FPSCounter.FPSCounterClient [LocalScript]`
- `StarterGui.PortalUI.PortalUIClient [LocalScript]`
- `StarterGui.ProfileStats.ProfileStatsClient [LocalScript]`
- `StarterGui.ScreenGuiButtons.ScreenButtonsClient [LocalScript]`
- `StarterGui.ScreenGuiButtons.ScreenButtonsHoverClient [LocalScript]`
- `StarterGui.Settings.SettingsClient [LocalScript]`

## RemoteEvents / RemoteFunctions

- None live directly under `StarterGui`.
- Child UI scripts consume `ReplicatedStorage.RemoteEvents` and `ReplicatedStorage.RemoteFunctions`.

## Attributes

- No attributes were observed on the `StarterGui` root in the targeted Studio inspection.
- Known code-relevant UI attributes in this project include `Modal`, `ScreenButtonsNonce`, and `ScreenButtonsAction`, but this pass did not re-audit every descendant for placement.

## CollectionService tags

- No tags were observed on the `StarterGui` root in the targeted Studio inspection.

## Migration risk

- `HIGH`: GUI names, modal layering, and child lookup paths are sensitive. Moving or renaming containers can break character creation, portal UI, inventory, and tutorial flows even when scripts remain unchanged.

## Notes

- This manifest documents the top-level lobby UI hierarchy only.
- Full object parity for UI is still incomplete because nested descendants such as frames, buttons, prompts, and other code-relevant widgets are not exhaustively described yet.
