# Changelog AI — 2026-08

## 2026-08-01 — Authored lobby currency counters

### Changes

- Removed the legacy `Four Peaks/StarterPlayer/StarterPlayerScripts/PlayerHubLobby.lua` client that restyled and populated `PlayerHudGui_Lobby.coinsBox` at runtime.
- Added `Four Peaks/StarterGui/Currency/CurrencyClient.lua` for the authored `Currency` ScreenGui.
- Bound the counters to `Currency.Frame.Silver.Silver` and `Currency.Frame.Souls.Souls`, with a safe descendant fallback for the text labels.
- Silver and Souls now display complete integer values with spaces as thousands separators, for example `1 000 000`; compact `K`, `M`, and `B` formatting is not used.
- Preserved `PlayerProgressEvent` synchronization and added an explicit `requestSync` after the client connects.
- Preserved lobby Backpack hiding, Chat hiding while a modal is open, and currency-HUD hiding while modal UI is active.
- Disabled the legacy `PlayerHudGui_Lobby` if an old Studio copy is still present, preventing duplicate currency counters during migration.
- Replaced the previous per-frame modal visibility check with event-driven GUI property and hierarchy listeners.
- Updated the Four Peaks StarterGui manifest to use `Currency` instead of `PlayerHudGui_Lobby`.

### Runtime cost

- No `RenderStepped`, `Heartbeat`, polling loop, or per-object update loop was added.
- Currency text updates only when `PlayerProgressEvent` sends a progress payload.
- Modal visibility recalculates only when relevant ScreenGui state, modal attributes, hierarchy, or Party overlay visibility changes.

### Validation

- Reviewed the current `LobbyProgress.lua` contract and confirmed it sends `silver`, `coins`, and `souls` and accepts `requestSync`.
- Reviewed the replacement script for full-value formatting, legacy HUD suppression, modal visibility handling, and event cleanup paths.
- Roblox Studio runtime testing was not available through the GitHub connector.

### Studio validation required

1. Confirm the active lobby contains `StarterGui.Currency.Frame.Silver.Silver` and `StarterGui.Currency.Frame.Souls.Souls`.
2. Confirm the new `CurrencyClient` LocalScript is parented directly under `StarterGui.Currency`.
3. Remove the old `StarterGui.PlayerHudGui_Lobby` object after verifying the new counters, if it still exists in Studio.
4. Set Silver and Souls to values above one million and confirm the UI displays full values such as `1 000 000` without `K`, `M`, or `B` suffixes.
5. Open Inventory, Missions, Events, Guild, Party, Daily Login, Settings, and Profile UI and confirm the currency HUD hides and returns correctly.
6. Confirm Backpack remains hidden and Chat visibility restores after closing modal UI.

### Risks

- The replacement depends on the authored `Currency` hierarchy shown in Studio. A renamed `Frame`, `Silver`, or `Souls` object will stop initialization with a clear error.
- The repository still has partial full-object parity with Studio, so the authored visual object properties are not recreated by this code-only change.

### Rollback

- Restore `PlayerHubLobby.lua`, remove `CurrencyClient.lua`, restore `PlayerHudGui_Lobby` in the StarterGui manifest, and re-enable the old lobby HUD object in Studio.
