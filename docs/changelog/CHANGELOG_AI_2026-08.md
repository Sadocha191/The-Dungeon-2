# Changelog AI — 2026-08

## 2026-08-01 — Integration of open PRs #149–#154

### Summary

- Finalized all six open pull requests for the game and prepared the combined result on `main`.
- Kept the controlled PR #149 integration already present on remote `main` and the local PR #150 integration that contains the finalized runtime delta without the temporary patch/workflow artifacts from the stacked branches.
- Merged the exact heads of PR #151, PR #152, PR #153, and the newly opened draft PR #154 into local `main`.
- Finished PR #154 for multiplayer safety by extending the existing `WeaponSwingVFX` payload with server-authored `attackerUserId` and `element`; local weapon motion now accepts only the exact attacking user while impact VFX remains visible to all clients.
- Synchronized the affected runtime sources and object removals to the active `Level` and `Four Peaks` Studio places before publishing Git.

### Repository files

- Updated `Level/ReplicatedStorage/ModuleScripts/NpcShared.lua`.
- Updated `Level/ServerScriptService/ModuleScript/{MobConfig,NpcService}.lua`.
- Updated `Level/ServerScriptService/Script/ChestService.server.lua` and `Level/ServerScriptService/Script/Model/WaveController.lua`.
- Updated `Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua`.
- Updated `Four Peaks/ServerScriptService/ResetDefaultAnimations.lua`.
- Added `Four Peaks/StarterGui/ScreenGuiButtons/ScreenButtonsHoverClient.lua`.
- Added `Four Peaks/StarterGui/Currency/CurrencyClient.lua` and removed `Four Peaks/StarterPlayer/StarterPlayerScripts/PlayerHubLobby.lua`.
- Updated `Level/ServerScriptService/Script/WeaponCombat.server.lua` and both `Level/StarterPlayer/StarterPlayerScripts/LocalScript/{WeaponClient,WeaponVFX.client}.lua` presentation clients.
- Removed the now-unused `Level/ServerScriptService/Script/WeaponVFXTemplates.server.lua` bootstrap after repo and live Studio searches confirmed that the new code-generated impact VFX has no template-folder consumer.
- Updated `roblox/CzterySzczyty/StarterGui/MANIFEST.md`, `CHANGELOG_AI.md`, and the July/August monthly changelogs.
- Updated the `WeaponSwingVFX` contract and removed the obsolete VFX-template entry in `docs/PROJECT_CODE_GUIDE.md`.

### Studio synchronization

- `Level`: all 21 runtime sources touched by PR #149/#150 matched the repository by normalized length and rolling checksum; `ChestAssetTemplateBootstrap` remained absent.
- `Four Peaks`: synchronized `game.ServerScriptService.ResetDefaultAnimations`, added `game.StarterGui.ScreenGuiButtons.ScreenButtonsHoverClient`, and added `game.StarterGui.Currency.CurrencyClient` with exact repository source parity.
- Removed the obsolete `game.StarterPlayer.StarterPlayerScripts.PlayerHubLobby` LocalScript.
- After a successful migration playtest, removed the obsolete `game.StarterGui.PlayerHudGui_Lobby` and its two descendants; the authored `game.StarterGui.Currency` hierarchy remains the sole lobby currency HUD.
- `Level`: synchronized `game.ServerScriptService.Script.WeaponCombat`, `game.StarterPlayer.StarterPlayerScripts.LocalScript.WeaponClient`, and `game.StarterPlayer.StarterPlayerScripts.LocalScript.WeaponVFX` with exact repository source parity.
- Enabled the previously disabled live `WeaponClient`, removed `game.ServerScriptService.Script.WeaponVFXTemplates`, and confirmed no generated `game.ReplicatedStorage.WeaponVFXTemplates` folder remains.

### Validation

- `Level` startup smoke completed with `SpellService`, `ChestService`, `HordeController`, and `RunReadyGate` ready; the authored enemy rank folders and both new rank/reward modules were present.
- `Four Peaks` completed two startup smokes, including a second run after legacy HUD removal.
- Lobby character `WalkAnim` and `RunAnim` both resolved to `rbxassetid://89814244152772`.
- The authored currency labels rendered live values as `111 040` and `9 440`; a controlled modal probe hid/restored both Currency and Chat, while Backpack remains controlled by the replacement client.
- The Events button reached scale `1.2` and raised `ZIndex` during hover, then returned to scale `1.0` and its original `ZIndex`. Rapid transitions across Events, Inventory, Guild, Party, and Profile left every tested scale and `ZIndex` restored.
- PR #154 automatically created the floating Scythe model and Trail after the late Backpack/loadout attributes arrived; the real Tool stayed out of the character model.
- A wrong `attackerUserId` was rejected by the local weapon handler, while the exact local `UserId` was accepted and enabled the Trail during the curved slash.
- A paused accepted attack remained frozen with Trail disabled, then resumed and enabled Trail after unpause; the previous pause state was restored.
- Fire, Water, and Light impact probes each created exactly three code-generated parts in the expected element color, and cleanup left zero impact parts after `0.3s`.
- A controlled character respawn rebuilt the floating weapon model and Trail without placing the Tool in the character's hand.
- All temporary client probes and attributes were removed.
- `git diff --check origin/main...HEAD` passed.
- No PR-specific error appeared. Existing unrelated output remained from `Hybrid Terrain Hex Generator:16` in Level and the `BlacksmithUI` wait for `PassiveDesc` in Four Peaks.

### Runtime loops, cost, and cleanup

- PR #149 continues to use the existing central `WaveController` Heartbeat; Elite scheduling starts at two minutes and repeats every 90 seconds, and shared chest work is O(players) with one bounded expiry task per chest.
- PR #150 adds no runtime loop; configured animation tracks are created once through the existing presentation setup.
- PR #151 adds one finite `task.spawn` only for a character that already exists when the server script starts; ongoing work is owned by the player's `CharacterAdded` signal.
- PR #152 is mouse/property/event-driven and adds no polling or frame loop. Active tweens and completion connections are cancelled before replacement and on button destruction.
- PR #153 removes the legacy `RenderStepped` modal scan. Currency rendering and modal visibility now update only on remote, GUI property, attribute, and hierarchy events, with ancestry cleanup for observed ScreenGuis.
- PR #154 replaces the existing local floating-weapon `RenderStepped` connection rather than adding another loop. There is exactly one connection for the local visual model, disconnected by `cleanupVisual`; character, Backpack, Tool attribute, and Tool destruction work is event-driven and deduplicated with weak-key tables.
- Each confirmed weapon attack creates three client-only neon parts, three short tweens, and three bounded `Debris` cleanup records lasting at most `0.22s`; the obsolete replicated weapon-template catalog and per-hit Tool cloning were removed.
- No new `_G` dependency, persistent-data field, DataStore contract, teleport payload, or remote name was added.

### Not verified and risks

- The natural two-minute Elite-to-death-to-shared-chest path, true two-player claiming, and reward persistence were not repeated in this final pass; their component contracts and prior controlled Studio tests remain documented in the July PR #149 entry.
- Animation asset ownership metadata and frame-by-frame rig deformation were not re-audited; active tracks and startup remained error-free.
- The modal test used the live Daily Login modal plus a controlled generic modal. Every listed lobby modal was not manually opened through its user-facing button.
- The connected test profile did not have a currency value above one million, so live event rendering above that threshold was not exercised without mutating persistent player data; the formatter path and authored labels retain the documented `1 000 000` representation.
- PR #154 ownership filtering was tested with wrong and correct user IDs in one client session, but a real two-client simultaneous attack session was not available.
- No target-scale MicroProfiler run was performed.

### Rollback

- Revert the integration commits in reverse order: PR #154, PR #153, PR #152, PR #151, then the PR #150 integration commit if Level animation/identity cleanup must also be removed. PR #149 can be rolled back separately from its controlled integration commit.
- In `Four Peaks` Studio, restore `PlayerHubLobby` and `PlayerHudGui_Lobby`, remove `CurrencyClient` and `ScreenButtonsHoverClient`, and restore the previous `ResetDefaultAnimations` source.
- In `Level` Studio, restore the 21 affected sources from the chosen pre-integration commit and recreate `ChestAssetTemplateBootstrap` only when rolling back PR #149 itself.
- For a PR #154-only Studio rollback, restore the previous `WeaponCombat`, `WeaponClient`, and `WeaponVFX` sources, disable `WeaponClient` to its prior property state, restore `WeaponVFXTemplates`, and allow it to recreate `ReplicatedStorage.WeaponVFXTemplates` during Play.

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
- Confirmed the authored Currency hierarchy and exact replacement source in the active `Four Peaks` Studio place.
- Completed client playtests for live counter rendering, modal hide/restore behavior, Chat restoration, and startup after legacy HUD removal.

### Studio validation completed

- Confirmed `StarterGui.Currency.Frame.Silver.Silver`, `StarterGui.Currency.Frame.Souls.Souls`, and `StarterGui.Currency.CurrencyClient`.
- Removed the obsolete `StarterPlayerScripts.PlayerHubLobby` and `StarterGui.PlayerHudGui_Lobby` after the first successful playtest.
- Confirmed live values use spaces as thousands separators and that Currency and Chat restore after a modal closes.
- Values above one million were not injected into persistent player data during the playtest; that threshold remains covered by the formatter implementation and authored `1 000 000` labels.

### Risks

- The replacement depends on the authored `Currency` hierarchy shown in Studio. A renamed `Frame`, `Silver`, or `Souls` object will stop initialization with a clear error.
- The repository still has partial full-object parity with Studio, so the authored visual object properties are not recreated by this code-only change.

### Rollback

- Restore `PlayerHubLobby.lua`, remove `CurrencyClient.lua`, restore `PlayerHudGui_Lobby` in the StarterGui manifest, and re-enable the old lobby HUD object in Studio.
