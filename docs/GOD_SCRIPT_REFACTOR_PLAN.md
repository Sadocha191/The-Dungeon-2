# God Script Refactor Plan

Data startu: 2026-07-01  
Zakres: etapowy refaktor największych God Scriptów i gameplayowych zależności przez `_G`.

## Status etapów

| Etap | Status | Zakres | Warunek przejścia |
|---|---|---|---|
| 0. Audyt i mapa zależności | Ukończony dla repo i aktywnych place `Level`/`Four Peaks`; `Guild` Studio nie było otwarte | Metryki plików, `_G`, `require`, pętle runtime, aktywne ścieżki Studio, plan migracji | Diff dokumentacji i changelog przechodzą walidację |
| 1. `ProgressService` i gameplayowe `_G` | Ukończony w zatwierdzonym zakresie Stage 1; etap 2 nie rozpoczęty | `RunProgressApi` zastąpił `_G` dla XP/coins/souls/kills/run time/average level/boss/end run; party XP declaration-order bug naprawiony; martwy `SetGlobalRunPause` fallback usunięty z chest itemów | Przed etapem 2 pozostaje tylko osobna akceptacja dalszego zakresu i pełniejszy runtime test, jeżeli dostępny będzie multiplayer |
| 2. `WaveController` | 2A-2E ukończone | `AbilityGeometry` wydziela czystą geometrię ability; `AbilityHazards` wydziela hazard zones/ticki/cleanup; `AbilityExecutor` wydziela wykonanie ability elit i bossów; `EncounterScheduler` wydziela planowanie spawn/encounter; `RunPortalController` wydziela portal/prompt state; `WaveDebugApi` wydziela Studio-only debug hook registration | Brak zmian damage/tick/cooldown/spawn rate; po każdym podetapie Play test |
| 3. `NpcService` | 3A-3F ukończone | Registry, movement/steering/ground, targeting/melee, lifecycle/status/death/despawn oraz batch replication wydzielone | Jeden centralny update, brak per-NPC Heartbeat |
| 4. `SpellService` i projectiles | 4A-4F ukończone | `SpellProjectiles` wydziela projectile simulation i hit detection; `SpellTargeting` wydziela enemy query/target picking/beam segment distance; `SpellEffects` wydziela status/effect application; `SpellVisuals` wydziela server VFX dispatch/payload/orbit sync; `SpellSustained` wydziela zone/beam tick loopi; martwe server-side konstruktory VFX usunięte | Pociski mają jeden leniwy scheduler; targeting/effects/VFX dispatch oraz zone/beam tick loopi delegowane bez zmian balansu |
| 5. `RunStatsService` i `ShrineService` | 5A ukończone | Usunięto nieużywane globalne shimy `RunStatsService`; `ShrineService` `_G.PrepareRunShrines` pozostaje aktywnym kontraktem `RunReadyGate` | DamageService i RunDefenseState bez zmiany ownership |
| 6. Guild | 6A-6D ukończone | `GuildPlaceRemotes` wydziela remote factory aktywnego `Gildia`; `GuildPlaceLocations` wydziela config/status lokalizacji oraz budowę modeli/promptów; `GuildRecordState` wydziela sanitizację/state rekordów gildii w `Four Peaks`; persistence, membership, treasury, upgrades i teleport bez zmian | Potwierdzony aktywny place `Gildia`/`Four Peaks`; po każdym kolejnym podetapie Play smoke |
| 7. Duże kontrolery UI | Zaplanowany | Inventory/blacksmith/crafting UI po stabilizacji serwera | Brak zmian wyglądu/remotes/bindów |

## Aktywne ścieżki Studio

Potwierdzone przez MCP 2026-07-01:

| Place | Studio | Aktywne ścieżki |
|---|---|---|
| Level | `Level` | `ServerScriptService.Script.ProgressService`, `ServerScriptService.Script.Model.WaveController`, `ServerScriptService.ModuleScript.NpcService`, `ServerScriptService.ModuleScript.Stats.RunStatsService`, `ServerScriptService.Script.SpellService`, `ServerScriptService.Script.ShrineService`, `ServerScriptService.Script.DropService`, `ServerScriptService.ModuleScript.DamageService` |
| Four Peaks | `Four Peaks` | `ServerScriptService.ModuleScript.GuildService`, `ServerScriptService.ModuleScript.GuildRecordState`, `ServerScriptService.ModuleScript.CraftingService`, `ServerScriptService.Script.BlacksmithService`, `StarterPlayer.StarterPlayerScripts.InventoryController`, `StarterPlayer.StarterPlayerScripts.BlacksmithUI`, `StarterPlayer.StarterPlayerScripts.GuildClient` |
| Guild | `Guild` | `ServerScriptService.Script.GuildPlace`, `ServerScriptService.ModuleScript.GuildPlaceRemotes`, `ServerScriptService.ModuleScript.GuildPlaceLocations`, `StarterPlayer.StarterPlayerScripts.GuildCastleClient` |

Uwagi o parity:

- `Level/ServerScriptService/Script/Model/WaveController.lua` jest aktywnym mirrorem. Stale `Model.model/WaveController.lua` został usunięty w poprzednim etapie damage.
- `Four Peaks/StarterPlayer/StarterPlayerScripts/BlacksmithUI.lua` jest aktywną ścieżką Studio. `Four Peaks/StarterPlayer/StarterPlayerScripts/LocalScript/BlacksmithUI.lua` istnieje w repo jako rozjechana kopia i nie wolno jej aktualizować w ciemno.
- `script_grep` w Studio potwierdził aktywne `_G` w `Level` i `Four Peaks`; przed każdą migracją trzeba ponownie sprawdzić konkretną dotykaną ścieżkę.
- 2026-07-02: Stage 1 party XP fix verified `ProgressService` repo/Studio parity. MCP Play validated the Multi party award branch through `RunProgressApi.AwardPlayer`, no double award, Solo follow-up, and spell offer/pick flow. Full two-client multiplayer and natural normal/elite/boss kill runtime remain unverified because current MCP Play controls do not expose a true multi-client session.
- 2026-07-02: Stage 2A verified `WaveController` repo/Studio parity after extracting `AbilityGeometry`. Stale `Model.model/WaveController.lua` remains absent.
- 2026-07-02: Stage 2B verified `WaveController`, `AbilityGeometry`, and `AbilityHazards` repo/Studio parity after extracting hazard zone lifecycle. Temporary Play probes were removed from Studio.
- 2026-07-02: Stage 2C verified `WaveController`, `AbilityExecutor`, `AbilityGeometry`, and `AbilityHazards` repo/Studio parity after extracting ability execution. Temporary Play probes were removed from Studio.
- 2026-07-07: Stage 2D verified `WaveController` and `EncounterScheduler` after extracting encounter scheduling. Temporary Play probes were removed from Studio.
- 2026-07-07: Stage 2E verified `WaveController`, `RunPortalController`, and `WaveDebugApi` after extracting portal/prompt state and Studio-only debug hook registration. Temporary Play probes were removed from Studio.
- 2026-07-07: Stage 3A verified active `NpcService`, captured baseline metrics, and mirrored live Studio ground/visual repair behavior into the repo before any Stage 3 split. Temporary Play probes were removed from Studio.
- 2026-07-07: Stage 3B added `NpcRegistry` and moved NPC id/model maps plus tombstones behind a neutral registry module. `NpcService` remains the public facade and single central scheduler owner.
- 2026-07-07: Stage 3C added `NpcMovement` and moved NPC movement math, ground sampling, spawn emerge, visual repair, model translation, and obstacle steering out of `NpcService`. `NpcService` still owns the single central scheduler.
- 2026-07-07: Stage 3D added `NpcTargeting` and `NpcMelee` for player targeting, target priority metrics, engagement slots, melee height/range validation, and contact damage dispatch. `NpcService` still owns the public API and single central scheduler.
- 2026-07-07: Stage 3E added `NpcLifecycle` for runtime attributes, state/health writers, tombstones, kill/despawn, death callbacks, status/control effects, damage modifiers, impulse, and ability lock. `NpcService` still owns remotes, MissionProgress, damage indicator dispatch, public API, and the single central scheduler.
- 2026-07-07: Stage 3F added `NpcReplication` for NPC snapshot, full sync, broadcast batch payloads, and tombstone inclusion. `NpcService` still owns remote creation and the single central scheduler; `NpcShared.BatchRate` was not changed.
- 2026-07-07: Stage 4A added `SpellProjectiles` for active projectile state, movement, pierce tracking, and hit detection. `SpellService` still owns spell cooldowns, target selection, VFX payload shape, effects, damage formulas, and the global spell scheduler.
- 2026-07-07: Stage 4B added `SpellTargeting` for enemy root/position/alive queries, nearest/radius/all enemy queries, priority target picking/listing, and beam segment distance math. `SpellService` still owns damage/effects/VFX dispatch and spell archetype flow.
- 2026-07-07: Stage 4C added `SpellEffects` for target damage multipliers, vulnerability multiplier, DOT, slow, stun, vulnerability, knockback, pull, and pullStrength application. `SpellService` still owns spell archetype flow, VFX dispatch, and the main damage call.
- 2026-07-07: Stage 4D added `SpellVisuals` for transient spell VFX payload extraction/broadcast and orbit VFX `FireClient` state sync. `SpellService` still owns spell archetype flow, cooldowns, and main damage call.
- 2026-07-07: Stage 4E removed unused server-side spell visual constructors from `SpellService` after audit confirmed the active call sites live in `SpellVFXClient` and server dispatch runs through `SpellVisuals`.
- 2026-07-07: Stage 4F added `SpellSustained` for existing zone and beam sustained tick loops. `SpellService` still owns cooldowns, spell archetype selection, player state, and the single global spell `Heartbeat`.

## Metryki największych plików

Liczby są statycznym skanem repo. `Remote names` to unikalne publiczne remotes jawnie używane przez plik, bez nazw klas i payloadów.

| Plik | Linie | Local/public functions | `require` | Remote names | Runtime loops i connections | `_G` reads/writes |
|---|---:|---:|---:|---|---|---:|
| `Level/ServerScriptService/Script/Model/WaveController.lua` | 2576 | 101 / 11 | 10 | `WaveStatusEvent` | 1 `Heartbeat`; liczne `task.delay`; hazard tick taski; 10 `:Connect` | 20 / 11 |
| `Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController.lua` | 2565 | 74 / 4 | 0 | `InventoryAction`, `InventorySync`, `RF_GetInventorySnapshot`, `PlayerProgressEvent` | event-driven UI, 28 connections, krótkie `task.delay` refresh | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/NpcService.lua` | 869 | 13 / 20 | 8 | `NpcBatchEvent`, `NpcSyncRequest`, `DamageIndicatorEvent` | 1 `Heartbeat`, 1 remote connection | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/NpcReplication.lua` | 77 | 1 / 3 | 0 | none | no runtime loop or connection | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/NpcLifecycle.lua` | 222 | 1 / 16 | 3 | none | no runtime loop or connection | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/NpcMovement.lua` | 401 | 11 / 15 | 1 | none | no runtime loop or connection | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/NpcTargeting.lua` | 191 | 0 / 9 | 1 | none | no runtime loop or connection | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/NpcMelee.lua` | 105 | 3 / 2 | 1 | none | no runtime loop or connection | 0 / 0 |
| `Level/ServerScriptService/Script/ProgressService.lua` | 1645 | 56 / 7 | 0 | `PlayerProgressEvent`, `MissionSummaryEvent`, `SpellEvent`, `PauseMenuEvent` | character health watch task co 0.25 s; remote/player connections | 4 / 8 |
| `Four Peaks/StarterPlayer/StarterPlayerScripts/BlacksmithUI.lua` | 1631 | 68 / 0 | 3 | `OpenBlacksmithUI`, `BlacksmithSync`, `BlacksmithAction` | event-driven UI, 18 connections | 0 / 0 |
| `Four Peaks/ServerScriptService/ModuleScript/GuildService.lua` | 1225 | 32 / 23 | 4 | `GuildUpdated`, `TeleportStatus` | no frame loop; 1 player removing connection | 0 / 0 |
| `Four Peaks/ServerScriptService/ModuleScript/GuildRecordState.lua` | 314 | 0 / 20 | 1 | none | no runtime loop or connection | 0 / 0 |
| `Guild/ServerScriptService/Script/GuildPlace.server.lua` | 1063 | 54 / 4 | 3 | `GetGuildCastleState`, `GetTreasury`, `DepositToTreasury`, `SpendFromTreasury`, `GuildLocationOpened`, `GuildTreasuryUpdated`, `LobbyReturnStatus`, `RequestLobbyReturn` | no frame loop; player/remote connections; prompt binding delegated to `GuildPlaceLocations` | 0 / 0 |
| `Guild/ServerScriptService/ModuleScript/GuildPlaceRemotes.lua` | 79 | 3 / 1 | 0 | creates same guild RemoteEvents/RemoteFunctions | no runtime loop or connection | 0 / 0 |
| `Guild/ServerScriptService/ModuleScript/GuildPlaceLocations.lua` | 348 | 4 / 6 | 0 | guild location definitions/status/state and physical model/prompt builder | no frame loop; existing prompt `Triggered` binding moved here | 0 / 0 |
| `Four Peaks/ServerScriptService/ModuleScript/CraftingService.lua` | 1287 | 41 / 16 | 6 | none | no runtime loop | 0 / 0 |
| `Level/ServerScriptService/Script/SpellService.lua` | 594 | 44 / 0 | 9 | `SpellVFXEvent` | 1 global spell `Heartbeat`; projectile simulation delegated to `SpellProjectiles`; targeting delegated to `SpellTargeting`; effects delegated to `SpellEffects`; VFX dispatch delegated to `SpellVisuals`; zone/beam sustained loops delegated to `SpellSustained` | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/SpellSustained.lua` | 138 | 2 / 3 | 0 | none | existing zone and beam `task.spawn` tick loops moved from `SpellService`; no connection | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/SpellVisuals.lua` | 94 | 1 / 5 | 0 | none | no runtime loop or connection | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/SpellEffects.lua` | 137 | 4 / 5 | 0 | none | existing DOT `task.spawn` loop moved from `SpellService`; no connection | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/SpellProjectiles.lua` | 125 | 6 / 3 | 0 | none | 1 lazy `Heartbeat` only while active projectiles exist | 0 / 0 |
| `Level/ServerScriptService/ModuleScript/SpellTargeting.lua` | 80 | 0 / 10 | 1 | none | no runtime loop or connection | 0 / 0 |
| `Level/ServerScriptService/Script/ShrineService.server.lua` | 651 | 19 / 1 | 1 | `WaveStatusEvent` | 1 `Heartbeat`, player/run connections | 0 / 1 |
| `Level/ServerScriptService/ModuleScript/Stats/RunStatsService.lua` | 454 | 14 / 14 | 4 | none | 1 `Heartbeat`, player/run connections | 0 / 0 |
| `Four Peaks/ServerScriptService/Script/BlacksmithService.lua` | 312 | 12 / 0 | 3 | `OpenBlacksmithUI`, `BlacksmithSync`, `BlacksmithAction` | prompt/workspace/player/remote connections | 0 / 0 |

Repo-wide scan:

- `_G.` occurrences: present in Level gameplay, Four Peaks spellbook hooks, and error reporter debug hooks.
- `_G[...]`: only dynamic reads in `RunReadyGate.server.lua` and `StatueService.server.lua`.
- `rawget(_G`, `rawset(_G`, `shared.`, `getfenv`, `setfenv`: no current source matches.

## Gameplayowe `_G`

| Global | Writer | Aktywni callerzy | Kontrakt obecny | Docelowe API |
|---|---|---|---|---|
| `_G.AwardPlayer` | `ProgressService`, wrapped by `WaveController` InfoUI counter | `DropService`, `ChestItemService`, `DebugCommandService`, `WaveController` wrapper | Award XP and run coins; supports party XP; syncs HUD/missions | `RunRewardService.AwardPlayer(player, xp, coins)` plus explicit InfoUI counter callback/event |
| `_G.AwardSouls` | `ProgressService` | `DropService`, `ChestItemService` | Add persistent souls, mark dirty, sync HUD | `RunRewardService.AwardSouls(player, souls)` |
| `_G.TrySpendRunCoins` | `ProgressService` | `ChestService` | Spend run-only coins and sync HUD | `RunWalletService.TrySpendRunCoins(player, coins)` |
| `_G.GetRunCoins` | `ProgressService` | no repo caller | Read run-only coins | Keep only if a real caller appears; otherwise remove after Studio grep |
| `_G.RegisterEnemyKill` | `ProgressService`, wrapped by `WaveController` InfoUI counter | `WaveController` death path | Increment kill counters, mission progress, HUD | `RunKillService.RegisterEnemyKill(pos, killer)`; InfoUI should subscribe/call explicit counter |
| `_G.NotifyBossSpawn` | `ProgressService` | `WaveController` boss path | Start boss no-hit timing for all active players | `RunBossTracker.NotifyBossSpawn(runSeconds?)` |
| `_G.GetAverageRunLevel` | `ProgressService` | `WaveController` scaling | Average active run level | `RunProgressQuery.GetAverageRunLevel()` |
| `_G.GetRunSeconds` | `WaveController` | `WaveController`, `ProgressService`, `StatueService` | Global elapsed seconds from WaveController clock | `RunClockService.GetRunSeconds()` owned by run clock/start gate |
| `_G.EndRunForPlayer` | `ProgressService` | `WaveController`, `RunDeathHandler`, `ReturnToLobby` | Finalize run, save, summary, mission completion | `RunEndService.EndRunForPlayer(player, reason)` |
| `_G.EndRun` | no writer in repo/live grep | fallback reads in `WaveController`, `RunDeathHandler` | Legacy fallback | Remove fallback after direct `EndRunForPlayer` migration |
| `_G.SetGlobalRunPause` | no writer in repo/live grep | `ChestItemService` optional fallback | Intended global pause source toggle; currently falls back to `PauseState.Value` | `RunPauseService.SetSource(source, active)` or module API used by Progress/Chest |
| `_G.SpawnDropsAt` | `DropService` | `WaveController` | Spawn XP/coin/soul drops at position | `DropService.SpawnDropsAt(pos, xp, coins, souls)` after converting `DropService` to ModuleScript or adding domain module |
| `_G.ActivateGlobalMagnet` | `DropService` | no repo caller | Timed global magnet for a player | Remove if no active Studio caller; otherwise `DropMagnetService.Activate(player, duration)` |
| `_G.SpawnEnemyBurst` | `WaveController` | `StatueService` | Spawn enemies near anchor for statue events/debug-like burst | `EncounterSpawnService.SpawnEnemyBurst(...)` |
| `_G.SpawnRewardChestForPlayer` | `ChestService` | `StatueService` | Spawn reward chest for player at position | `ChestSpawnService.SpawnRewardChestForPlayer(...)` |
| `_G.PrepareRunChests` | `ChestService` | `RunReadyGate` dynamic `_G[name]` | Prepare chest objects before run | `RunWorldPreparation.PrepareChests()` |
| `_G.PrepareRunShrines` | `ShrineService` | `RunReadyGate` dynamic `_G[name]` | Prepare shrine objects before run | `RunWorldPreparation.PrepareShrines()` |
| `_G.PrepareRunStructures` | `StatueService` | `RunReadyGate` dynamic `_G[name]` | Prepare statue/structure objects before run | `RunWorldPreparation.PrepareStructures()` |
| `_G.GetRunStat`, `_G.HealRunPlayer` | removed in 5A | no active caller found before removal | Legacy stat query and heal helper | Public `RunStatsService.GetStat` and `RunStatsService.HealPlayer` remain |
| `_G.Debug*` WaveController hooks | `WaveController` | `DebugCommandService` | Studio/debug spawn toggles | Keep as Studio/debug-only until a debug command module owns them |
| `_G.Spells_*` | Four Peaks `SpellService` | `WitchNPC` and no-call helpers | Spellbook unlock/reset/open choice hooks | Later lobby spell API module; not part of Level etap 1 |
| `_G.ErrorReporterTest`, `_G.ErrorWebhookTest` | ErrorBootstrap | debug commands | Error reporter diagnostics | Out of scope for gameplay refactor |
| `_G.OnUpgradeChosen` | `MultiLevelUpClient` | no repo caller | Client-side hook | Treat separately with UI cleanup |

## Obecny graf `require()`

Level:

```mermaid
flowchart TD
  WaveController --> AbilityExecutor
  WaveController --> EncounterScheduler
  WaveController --> RunPortalController
  WaveController --> WaveDebugApi
  WaveController --> NpcService
  WaveController --> PlayerData
  WaveController --> PickupToastService
  WaveController --> RunSpawnConfig
  WaveController --> WorldBounds
  WaveController --> AbilityHazards
  WaveController --> CraftingConfig
  WaveController --> MissionProgress
  WaveController --> MobConfig
  WaveController --> RunProgressApi
  AbilityExecutor --> AbilityGeometry
  AbilityExecutor --> AbilityHazards
  AbilityExecutor --> DamageService
  AbilityExecutor --> NpcService
  EncounterScheduler
  NpcService --> WorldBounds
  NpcService --> NpcShared
  NpcService --> DamageService
  NpcService --> MissionProgress
  DamageService --> RunDefenseState
  AbilityHazards --> AbilityGeometry
  AbilityHazards --> DamageService
  AbilityGeometry
  RunPortalController
  WaveDebugApi
  SpellService --> SpellDefinitions
  SpellService --> NpcService
  SpellService --> PlayerData
  SpellService --> WeaponConfigs
  RunStatsService --> StatsConfig
  RunStatsService --> DamageService
  RunStatsService --> NpcService
  RunStatsService --> RunDefenseState
  ChestService --> ChestItemService
  ChestItemService --> RunStatsService
  ChestItemService --> PlayerData
  StatueService --> NpcService
  ShrineService --> WorldBounds
```

Four Peaks / Guild:

```mermaid
flowchart TD
  GuildService --> PlayerData
  GuildService --> CurrencyService
  GuildService --> GuildConfig
  CraftingService --> PlayerData
  CraftingService --> PlayerStateStore
  CraftingService --> CurrencyService
  CraftingService --> PickupToastService
  CraftingService --> CraftingConfig
  CraftingService --> WeaponConfigs
  BlacksmithService --> PlayerStateStore
  BlacksmithService --> CraftingService
  BlacksmithService --> WeaponCatalog
  BlacksmithUI --> WeaponConfigs
  BlacksmithUI --> MaterialDefinitions
  BlacksmithUI --> BlacksmithTheme
  GuildPlace --> GuildConfig
```

Potencjalne cykle do uniknięcia:

- Nie wolno migrować callerów przez `require(ProgressService)`, bo `ProgressService` jest `Script`, tworzy remotes i ma startup side effects.
- Nowe API progresu powinno siedzieć w modułach domenowych pod `ServerScriptService.ModuleScript`, a `ProgressService` powinien je bootstrapować albo używać jako koordynator.
- `ChestItemService -> RunStatsService -> NpcService -> DamageService -> RunDefenseState` już jest łańcuchem zależności; nie dodawać powrotnej zależności z `NpcService`/`DamageService` do rewardów/progresu.
- `WaveController -> NpcService` i `SpellService -> NpcService` oznacza, że moduły ability/projectile mogą zależeć od `NpcService`, ale `NpcService` nie może zależeć od ability/spell/wave.
- `DropService` i `ChestService` są `Script` bootstrapami; przed zastąpieniem `_G` trzeba wydzielić mały moduł API albo przenieść stan do domenowego ModuleScriptu bez zmiany nazw remotes.

## Docelowe granice odpowiedzialności

Etap 1, Progress:

- `RunClockService`: start/pause elapsed time, `GetRunSeconds`.
- `RunWalletService`: run coins, spend, earned counters.
- `RunRewardService`: XP/coins/souls award, party XP handoff.
- `RunKillService`: kill counters, multikill mission progress.
- `RunBossTracker`: boss spawn/no-hit timing.
- `RunEndService`: finalization, mission summary, save/teleport-adjacent handoff.
- `RunPauseService`: named pause sources for chest/upgrades/pause menu.

Nazwy są robocze; przed implementacją etapu 1 trzeba wybrać najmniejszy moduł, który usuwa realny `_G` bez tworzenia nowego God Service.

Etap 2, Wave:

- Najpierw czyste helpery geometrii ability: radius, line, cone, ground query.
- Potem hazard zones z zachowaniem tick rate/damage/duration.
- Dopiero później boss/elite ability execution, spawn/scheduling, portal/end encounter.

Status 2026-07-02:

- 2A ukończony.
- Dodano `Level/ServerScriptService/ModuleScript/AbilityGeometry.lua`.
- `AbilityGeometry` nie wymaga `WaveController`, `DamageService`, hazardów, executorów ani konfiguracji fal.
- Aktualny graf 2A: `WaveController -> AbilityGeometry`; brak zależności zwrotnej i brak cyklu.
- Przeniesione funkcje/operacje: `FlatVector`, `HorizontalDistance`, `VerticalDelta`, `Groundify`, `DistancePointToSegment`, `IsPointInRadius`, `IsPointAlongLine`, `IsPointInCone`.
- 2B ukończony.
- Dodano `Level/ServerScriptService/ModuleScript/AbilityHazards.lua`.
- `AbilityHazards` odpowiada za hazard zone part, tick loop, hazard radius damage przez `DamageService.Apply`, active-zone cleanup i `CancelAll`.
- Aktualny graf 2B: `WaveController -> AbilityHazards`, `AbilityHazards -> AbilityGeometry`, `AbilityHazards -> DamageService`; brak zależności zwrotnej do `WaveController`.
- `WaveController` nadal iteruje graczy dla jednorazowych ability, wywołuje `DamageService.Apply` dla non-hazard ability, tworzy non-hazard VFX, wybiera boss/elite ability i zarządza encounter state.
- Rozmiar po 2B: `WaveController` 2572 linie, `AbilityGeometry` 63 linie, `AbilityHazards` 171 linii.
- Pętle runtime po 2B: bez nowego `Heartbeat`; istniejący per-hazard `task.spawn` tick loop został przeniesiony z `WaveController` do `AbilityHazards` bez zmiany tick rate/duration.
- 2C ukończony.
- Dodano `Level/ServerScriptService/ModuleScript/AbilityExecutor.lua`.
- `AbilityExecutor` odpowiada za wykonanie archetypów ability elit i bossów, telegraph/burst VFX, opóźnione windupy, cooldown writes, wywołania damage ability i przekazanie hazardów do `AbilityHazards`.
- Aktualny graf 2C: `WaveController -> AbilityExecutor`; `AbilityExecutor -> AbilityGeometry`, `AbilityHazards`, `DamageService`, `NpcService`; `AbilityHazards -> AbilityGeometry`, `DamageService`; brak zależności zwrotnej do `WaveController`.
- `WaveController` nadal posiada konfiguracje ability, wybór ability/phase, spawn scheduling, portal/end state, rewardy i debug hooks.
- Rozmiar po 2C: `WaveController` 2087 linii, `AbilityExecutor` 573 linie, `AbilityGeometry` 63 linie, `AbilityHazards` 171 linii.
- Pętle runtime po 2C: bez nowego `Heartbeat`; istniejące `task.delay`/`task.spawn` windupów ability zostały przeniesione z `WaveController` do `AbilityExecutor` bez zmiany opóźnień, a per-hazard tick loop pozostał w `AbilityHazards`.
- Testy 2A: baseline przed/po dla radius/line/cone/groundify identyczny; Play test realnych ability potwierdził `GroundSlam`, `DashThrust` i `ShieldCone` hit/miss przez `WaveController -> AbilityGeometry`.
- Testy 2B: Play test realnych hazardów potwierdził `RootCage` ticki `3` z odstępami `0.8/0.8`, exit/enter, zatrzymanie po śmierci gracza, cleanup przy `RunStarted=false`, brak thorns bez `source`/`attacker`, oraz `ArenaPressure` ticki `3` z odstępami `0.8/0.8`.
- Testy 2C: Play test realnych call site'ów potwierdził `RockToss`, `DashThrust`, `ShieldCone`, `TripleCombo` z 3 trafieniami i odstępami około `0.26/0.28`, `RootCage` ticki `3` z odstępami `0.8/0.8`, `BoulderRain`, `Shockwave` przez `DamagePlayersInRadius`, oraz brak trafień po cleanupie castera przed opóźnionym `RockToss`.
- 2D ukończony.
- Dodano `Level/ServerScriptService/ModuleScript/EncounterScheduler.lua`.
- `EncounterScheduler` odpowiada za stan i obliczenia planowania encounterów: pool spawnu, scaling czasu, max alive, interval/burst, elite cadence, swarm windows, catch-up debt i trim normalnych mobów podczas important encounter.
- Aktualny graf 2D: `WaveController -> EncounterScheduler`; `EncounterScheduler` nie wymaga żadnych modułów i nie zależy zwrotnie od `WaveController`.
- `WaveController` nadal wykonuje faktyczne klonowanie mobów, pozycje spawnu, `NpcService.Register`, death/reward flow, portal/boss execution, ability stepping, debug hooks i pojedynczy `Heartbeat`.
- Rozmiar po 2D: `WaveController` 1888 linii, `EncounterScheduler` 407 linii, `AbilityExecutor` 573 linie, `AbilityGeometry` 63 linie, `AbilityHazards` 171 linii.
- Pętle runtime po 2D: bez nowego `Heartbeat` i bez nowej pętli schedulerowej; istniejący pojedynczy `RunService.Heartbeat` pozostał w `WaveController`, a scheduler tylko zwraca plany/liczby.
- Testy 2D: Play startup bez probe'a osiągnął `[HordeController] Ready`; tymczasowy probe potwierdził normal spawn `24/24` przy cap `100`, elite scheduler `1` spawn bez double, boss spawn, swarm `120/120` przy cap `120`, oraz cleanup `afterClearActive=0`.
- Zachowane wartości 2D: `ELITE_INTERVAL_SECONDS=300`, `SWARM_EVENT_TIMES={240,720}`, `SWARM_DURATION=60`, initial `maxAlive=24`, active cap `100`, swarm cap `120`; formuły interval/burst/overtime/catch-up/trim przeniesiono bez zmian balansu.
- 2E ukończony.
- Dodano `Level/ServerScriptService/ModuleScript/RunPortalController.lua`.
- Dodano `Level/ServerScriptService/ModuleScript/WaveDebugApi.lua`.
- `RunPortalController` odpowiada za model portalu, `ProximityPrompt`, stan aktywacji portalu i stan boss defeated; faktyczny boss spawn, rewardy i end-run nadal pozostają w `WaveController`.
- `WaveDebugApi` odpowiada za rejestrację debugowych `_G.Debug*` hooków wyłącznie w Studio; `WaveController` wymaga go tylko pod `RunService:IsStudio()`.
- Aktualny graf 2E: `WaveController -> RunPortalController`; `WaveController -> WaveDebugApi` tylko w Studio; nowe moduły nie wymagają `WaveController` i nie tworzą cyklu.
- Rozmiar po 2E: `WaveController` 1868 linii, `RunPortalController` 127 linii, `WaveDebugApi` 32 linie, `EncounterScheduler` 407 linii, `AbilityExecutor` 573 linie, `AbilityGeometry` 63 linie, `AbilityHazards` 171 linii.
- Pętle runtime po 2E: bez nowego `Heartbeat`, bez nowego schedulera i bez nowych pętli runtime; zachowany pojedynczy `RunService.Heartbeat` w `WaveController`.
- Testy 2E: Play startup bez probe'a osiągnął `[HordeController] Ready`; tymczasowy probe potwierdził portal `Awaken Boss`, debug hook registration w Studio, debug boss spawn `Boss_Golem`, prompt `Boss Active`, stan `Enter Portal` po boss defeated oraz cleanup bossa do `activeBossCount=0`.
- Nieweryfikowane w 2B: `FlamePool`, bo aktywne Studio nie wystawia `Demon` elite przez istniejący debug spawn; pełny naturalny run do losowych elit/bossów zostaje do późniejszego runtime passu.
- Nieweryfikowane w 2C: `FlamePool` i `TeleportStep`, bo aktywne Studio nie wystawia `Demon` elite przez istniejący debug spawn; pełna naturalna randomizacja runu i kompletna macierz cooldownów pozostają do późniejszego runtime passu.
- Nieweryfikowane w 2D: naturalny wall-clock do 4:00/5:00/12:00 nie był odczekany; probe przyspieszał scheduler przez testowy stan i istniejące `DebugSettings`.
- Nieweryfikowane w 2E: pełny manualny klik ProximityPrompt i pełny victory end-run po realnym killu bossa nie zostały wykonane; brak debug hooków na opublikowanym serwerze potwierdzono statycznie przez `RunService:IsStudio()` i assert w `WaveDebugApi.Register`.
- Rollback 2A: przywrócić poprzedni `WaveController.lua`, usunąć `AbilityGeometry.lua` z repo i live Studio oraz cofnąć wpisy changeloga/planu.
- Rollback 2B: przywrócić poprzedni `createHazardZone` w `WaveController.lua`, usunąć `AbilityHazards.lua` z repo i live Studio oraz cofnąć wpisy changeloga/planu.
- Rollback 2C: przywrócić poprzednie helpery wykonania ability w `WaveController.lua`, usunąć `AbilityExecutor.lua` z repo i live Studio oraz cofnąć wpisy changeloga/planu.
- Rollback 2D: przywrócić poprzednie helpery scheduling/spawn state w `WaveController.lua`, usunąć `EncounterScheduler.lua` z repo i live Studio oraz cofnąć wpisy changeloga/planu.
- Rollback 2E: przywrócić poprzedni portal/debug block w `WaveController.lua`, usunąć `RunPortalController.lua` i `WaveDebugApi.lua` z repo i live Studio oraz cofnąć wpisy changeloga/planu.

Etap 3, NPC:

- 3A ukończony.
- 3B ukończony.
- 3C ukończony.
- 3D ukończony.
- 3E ukończony.
- 3F ukończony.
- Aktywna ścieżka Studio: `game.ServerScriptService.ModuleScript.NpcService`.
- Plik repo: `Level/ServerScriptService/ModuleScript/NpcService.lua`.
- Checkpoint przed etapem 3: `3780841 Refactor dungeon NPC and reward systems`; worktree był czysty przed 3A.
- Wykryto drift Studio/repo: aktywne Studio miało nowszy ground/visual repair (`DETACHED_VISUAL_REPAIR_MIN_FLAT_DISTANCE`, `repairDetachedVisualParts`, `modelYExtents`, `moveNpcModelToRoot`) niż repo. Repo zostało zsynchronizowane do aktywnej wersji bez zmiany zachowania Studio.
- Publiczne API do zachowania: `GetRoot`, `GetPosition`, `IsAlive`, `GetHealth`, `GetLivingModels`, `GetActiveCount`, `DespawnOldestFarNormal`, `GetNearestEnemy`, `GetEnemiesInRadius`, `GetTargetingMetrics`, `ApplySlow`, `ApplyFreeze`, `AddImpulse`, `BindDeath`, `ApplyDamage`, `Register`, `SetIncomingDamageModifier`, `LockForAbility`, `SetPosition`, `Despawn`.
- Aktywni callerzy: `WaveController`, `WeaponCombat`, `SpellService`, `StatueService`, `RunStatsService`, `AbilityExecutor`.
- Obecny graf po 3F: `NpcService -> NpcRegistry`, `NpcService -> NpcLifecycle`, `NpcService -> NpcReplication`, `NpcService -> NpcMovement`, `NpcService -> NpcTargeting`, `NpcService -> NpcMelee`, `NpcService -> NpcShared`, opcjonalnie `NpcService -> MissionProgress`; `NpcLifecycle -> NpcRegistry`, `NpcLifecycle -> NpcMovement`, `NpcLifecycle -> NpcShared`; `NpcTargeting -> NpcMovement`; `NpcMelee -> DamageService`; `NpcMovement -> WorldBounds`; `NpcReplication` nie wymaga modułów; `NpcRegistry` nie wymaga żadnego modułu i nie tworzy cyklu.
- Stan runtime po 3B: `NpcRegistry` przechowuje `nextNpcId`, `npcById`, `npcByModel` i `tombstones`; per-entry `deathCallbacks` pozostają w rekordzie NPC tworzonym przez `NpcService`.
- Połączenia runtime: `NpcSyncRequest.OnServerEvent` i jeden centralny `RunService.Heartbeat`.
- Pętla runtime: jeden `Heartbeat` wykonuje `getAlivePlayers`, `buildEngagementSlots`, `updateNpc` dla każdego wpisu i batch replication co `NpcShared.BatchRate = 0.1`.
- Koszt hot loopu:
  - `getAlivePlayers` skanuje `Players:GetPlayers()` co frame.
  - `buildEngagementSlots` skanuje aktywne NPC co frame, dla każdego porównuje graczy i sortuje grupy.
  - `updateNpc` robi target cache/full scan co `0.35s`, movement, obstacle steering, ground correction, melee gating i batch state.
  - ground raycast odpala po `0.12s` albo przesunięciu XZ `>=4`.
  - obstacle steering buduje ignore list i tworzy `RaycastParams` przy próbie omijania przeszkód.
- Damage gracza pozostaje przez `DamageService.Apply(player, amount, { source = npcModel, sourceType = "npc", damageType = "contact", attacker = npcModel })`.
- Baseline Studio Play, kontrolowane Slime NPC, auto mob spawn wyłączony na czas probe'a:

| NPCs | Avg update ms | Max update ms | Ground raycasts/s | Obstacle raycasts/s | Target scans/s | Formation scans/s | Formation comparisons/s |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 | 0.081 | 0.686 | 80.0 | 95.0 | 0.0 | 1625.0 | 1625.0 |
| 25 | 0.135 | 0.444 | 212.5 | 25.0 | 0.0 | 6000.0 | 6000.0 |
| 50 | 0.260 | 1.459 | 425.0 | 100.0 | 0.0 | 12025.0 | 12025.0 |

- Uwagi 3A: target scans były bliskie `0` w oknach pomiaru, bo target został zcache'owany w warmupie; formation scans są wykonywane co frame. Po cleanupie probe'ów w Play pojawiał się 1 nie-probe aktywny wpis/extra enemy-folder children mimo wyłączonego auto spawnu, więc traktować to jako szum środowiska do późniejszego sprawdzenia, nie dowód wycieku `NpcService`.
- Nieweryfikowane w 3A: prawdziwy multiplayer target switching, naturalny long-run 100+ NPC, pełna macierz status/death/drop/thorns.
- 3B dodał `Level/ServerScriptService/ModuleScript/NpcRegistry.lua`.
- `NpcRegistry` odpowiada tylko za `NextId`, `GetByModel`, `Resolve`, `Contains`, `Add`, `Remove`, `Pairs`, `QueueTombstone`, `Tombstones`, `ClearTombstones`, `Reset` i `Count`.
- `NpcRegistry` nie ma `require()`, `_G`, remotes, `Heartbeat`, event connections ani zależności do `DamageService`, `WaveController`, `NpcService`, `RunStatsService` lub `ShrineService`.
- `NpcService` po 3B nadal zachowuje publiczne API: `GetRoot`, `GetPosition`, `IsAlive`, `GetHealth`, `GetLivingModels`, `GetActiveCount`, `DespawnOldestFarNormal`, `GetNearestEnemy`, `GetEnemiesInRadius`, `GetTargetingMetrics`, `ApplySlow`, `ApplyFreeze`, `AddImpulse`, `BindDeath`, `ApplyDamage`, `Register`, `SetIncomingDamageModifier`, `LockForAbility`, `SetPosition`, `Despawn`.
- `NpcService` po 3B ma nadal jeden `NpcSyncRequest.OnServerEvent` i jeden centralny `RunService.Heartbeat`; nie dodano per-NPC connection ani nowej pętli.
- Walidacja 3B: live Studio `NpcRegistry` utworzony, live `NpcService` zsynchronizowany; Play startup doszedł do normalnych logów ready bez błędów `NpcService`/`NpcRegistry`; naturalny run spawnował realne `Slime` z `NpcId`; character navigation do realnego Slime nie dodał błędów Output.
- Kontrolowany Studio-only harness 3B potwierdził: zwykłą rejestrację, duplicate register zwracający ten sam id bez wzrostu registry, rejestrację elity i bossa, manual `Destroy` cleanup, death callback dokładnie raz, despawn bez death callbacku, reset registry oraz 20 cykli register/remove bez narastania callbacków.
- Zachowanie `nextNpcId` po 3B pozostaje monotoniczne: `NpcRegistry.Reset()` czyści mapy/tombstones, ale nie resetuje licznika id, zgodnie z brakiem resetu `nextNpcId` w poprzednim inline stanie.
- Ograniczenia testu 3B: dokładna liczba natywnych `RBXScriptConnection` nie była mierzona; potwierdzono brak dodatkowych wywołań callbacków, brak nowych pętli oraz statycznie jeden `RunService.Heartbeat` i jedno `NpcSyncRequest.OnServerEvent`. Tombstone po manualnym `Destroy` mógł zostać skonsumowany przez batch broadcast w tej samej klatce, więc obserwacja tombstone dla tej ścieżki pozostaje pośrednia.
- 3C dodał `Level/ServerScriptService/ModuleScript/NpcMovement.lua`.
- `NpcMovement` odpowiada za `Flat`, `FlatMagnitude`, `SafeUnit`, `ClampMagnitude`, `NearestAlivePlayerFlatDistance`, visual repair, ground offset/height, spawn emerge, model translation, ground-adjusted position, orbit target math i obstacle steering.
- `NpcMovement` wymaga tylko `WorldBounds` i Roblox services potrzebnych do ruchu/raycast ignore; nie wymaga `NpcService`, `NpcRegistry`, `DamageService`, `WaveController`, `RunStatsService` ani `ShrineService`.
- `NpcService` po 3C nadal zachowuje publiczne API i jest właścicielem jednego `NpcSyncRequest.OnServerEvent` oraz jednego centralnego `RunService.Heartbeat`; nie dodano per-NPC connection, nowej pętli, remotes ani gameplay `_G`.
- Walidacja 3C: live Studio `NpcMovement` utworzony, live `NpcService` zsynchronizowany; repo/Studio parity dla `NpcService`, `NpcRegistry` i `NpcMovement` potwierdzona przez length/checksum/line count.
- Play test 3C przez tymczasowy Studio-only harness na realnym template `Slime` i publicznym `NpcService.Register`: spawn emerge przesunął pozycję z `Y=6.25` do `Y=12`, open chase przesunął NPC o `8.678` studs, obstacle steering przesunął NPC o `11.525` studs z bocznym zejściem `1.322` studs, a cleanup przez `NpcService.Despawn` zostawił `GetActiveCount() = 0`.
- Ograniczenia testu 3C: naturalny długi run, multiplayer target switching i pełna macierz melee/death/drop/thorns pozostają dla 3D/3E; tymczasowy harness miał testowo podniesione HP NPC, aby automatyczne ataki gracza nie kończyły walidacji ruchu przed pomiarem.
- 3D dodał `Level/ServerScriptService/ModuleScript/NpcTargeting.lua`.
- `NpcTargeting` odpowiada za alive-player snapshot, engagement slots, targetability, target priority/distance bonus, public targeting metrics, normal distance despawn check i target cache scan cadence.
- 3D dodał `Level/ServerScriptService/ModuleScript/NpcMelee.lua`.
- `NpcMelee` odpowiada za contact damage dispatch przez `DamageService.Apply` oraz dotychczasowe melee vertical/3D distance validation. Context damage nadal przekazuje `source`, `sourceType = "npc"`, `damageType = "contact"` i `attacker` jako rzeczywisty model NPC.
- `NpcService` po 3D nadal zachowuje publiczne API i jest właścicielem jednego `NpcSyncRequest.OnServerEvent` oraz jednego centralnego `RunService.Heartbeat`; nie dodano per-NPC connection, nowej pętli, remotes ani gameplay `_G`.
- Walidacja 3D: live Studio `NpcTargeting` i `NpcMelee` utworzone, live `NpcService` zsynchronizowany; repo/Studio parity dla `NpcService`, `NpcRegistry`, `NpcMovement`, `NpcTargeting` i `NpcMelee` potwierdzona przez length/checksum/line count.
- Play test 3D przez tymczasowe Server harnessy bez trwałych obiektów: publiczne `GetNearestEnemy`, `GetEnemiesInRadius` i `GetTargetingMetrics` na kontrolowanym normal/elite/boss `Slime` zachowały priorytet boss > elite > normal (`bossEffective=6`, `bossActual=30`, `bossPriority=3`); prawdziwy contact melee przez centralny `Heartbeat` zadał graczowi `36` HP; invalid height contact zadał `0` HP; cleanup zostawił `GetActiveCount() = 0`.
- Walidacja thorns 3D: diagnostyka pokazała, że bez załadowanego `RunStatsService` istniejący `DamageService` nie ma aktywnego thorns callbacku; po wymaganiu istniejącego `RunStatsService` ten sam pipeline odbił thorns, a prawdziwy contact melee zadał graczowi `45` HP i odbił `20` HP w NPC przy `RunStat_Thorns=4`. To nie zostało naprawione w 3D, bo etap nie zmienia bootstrapu stats systemu.
- Ograniczenia testu 3D: pełny naturalny long-run, prawdziwy multiplayer target switching, drop/reward/death callback matrix i status-effect matrix pozostają dla 3E/3F; thorns callback load-order pozostaje ryzykiem do osobnego audytu, jeśli ma działać przed pierwszym załadowaniem `RunStatsService`.
- 3E dodał `Level/ServerScriptService/ModuleScript/NpcLifecycle.lua`.
- `NpcLifecycle` odpowiada za runtime attribute cleanup, state/health writers, registry unregister/tombstones, model destroy, kill/despawn, death callback context, current speed under freeze/slow, control resistance, slow/freeze/impulse, incoming damage modifier i ability lock.
- `NpcService` po 3E nadal zachowuje publiczne API i jest właścicielem damage indicator remote, MissionProgress damage notification, model registration setup, public facade, jednego `NpcSyncRequest.OnServerEvent` oraz jednego centralnego `RunService.Heartbeat`; nie dodano per-NPC connection, nowej pętli, remotes ani gameplay `_G`.
- Walidacja 3E: live Studio `NpcLifecycle` utworzony, live `NpcService` zsynchronizowany; repo/Studio parity dla `NpcService`, `NpcRegistry`, `NpcMovement`, `NpcTargeting`, `NpcMelee` i `NpcLifecycle` potwierdzona przez length/checksum/line count.
- Play test 3E przez tymczasowy Server harness na publicznym `NpcService` API: `SetIncomingDamageModifier` zmienił damage `10 -> 20` i zostawił HP `80`; config `onDeath` i `BindDeath` odpaliły dokładnie raz z zachowanym contextem; `Despawn` nie odpalił death callbacków; manual `Model:Destroy()` wyrejestrował NPC; `ApplyFreeze` i `LockForAbility` zatrzymały ruch (`0` studs), `AddImpulse` przesunął NPC o `3.586` studs; cleanup zostawił `GetActiveCount() = 0`.
- Ograniczenia testu 3E: pełny naturalny long-run, prawdziwy multiplayer target switching, drop/reward integration z realnym `WaveController` killem oraz dłuższy status stacking matrix pozostają dla 3F/final audit.
- 3F dodał `Level/ServerScriptService/ModuleScript/NpcReplication.lua`.
- `NpcReplication` odpowiada za snapshot payload, full sync payload, broadcast batch payload i tombstone inclusion/clear order. Nie tworzy remotes i nie ma pętli runtime.
- `NpcService` po 3F nadal zachowuje publiczne API i jest właścicielem remote creation, `NpcSyncRequest.OnServerEvent`, jednego centralnego `RunService.Heartbeat`, `NpcShared.BatchRate`, damage indicator i MissionProgress damage notification.
- Walidacja 3F: live Studio `NpcReplication` utworzony, live `NpcService` zsynchronizowany; repo/Studio parity dla `NpcService`, `NpcRegistry`, `NpcMovement`, `NpcTargeting`, `NpcMelee`, `NpcLifecycle` i `NpcReplication` potwierdzona przez length/checksum/line count.
- Play test 3F: kontrolowany elite `Slime` zarejestrowany przez publiczne `NpcService.Register`; klient otrzymał `NpcBatchEvent` broadcasty (`broadcastCount=10`) i full sync odpowiedzi (`fullCount=2`) po `NpcSyncRequest`; payload zawierał testowy `NpcId=2` w broadcast i full snapshot, a `requestId=7321` został zachowany. Cleanup usunął testowego NPC i zostawił `GetActiveCount() = 0`.
- 3F nie zmienił `NpcShared.BatchRate`, targetingu, formation cadence ani movement ticku; realne throttling/partitioning pozostaje decyzją przyszłego performance passu, nie tego checkpointu.
- `NpcService` zostaje właścicielem publicznego API i centralnego schedulera.
- Etap 3 zakończony; kolejny etap główny: 4 `SpellService` i projectiles.
- Główny `Heartbeat` pozostaje centralny; żadnych per-NPC połączeń.
- Rollback 3A: cofnąć parity sync `NpcService.lua` tylko jeśli świadomie wracamy do stale repo copy, oraz cofnąć wpisy planu/changeloga.
- Rollback 3B: przywrócić inline `nextNpcId`, `npcById`, `npcByModel` i `tombstones` w `NpcService.lua`, usunąć `NpcRegistry.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 3C: przywrócić przeniesione helpery movement/grounding/steering inline w `NpcService.lua`, usunąć `NpcMovement.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 3D: przywrócić alive-player snapshot, engagement slots, target metrics, target scan cache, melee validation i contact damage dispatch inline w `NpcService.lua`, usunąć `NpcTargeting.lua` i `NpcMelee.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 3E: przywrócić runtime attribute cleanup, state/health writers, tombstone/kill/despawn/death callback/status/control helpery inline w `NpcService.lua`, usunąć `NpcLifecycle.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 3F: przywrócić snapshot/full sync/broadcast/tombstone batch helpery inline w `NpcService.lua`, usunąć `NpcReplication.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.

Etap 4, Spell/projectiles:

- 4A ukończony.
- 4B ukończony.
- 4C ukończony.
- 4D ukończony.
- 4E ukończony.
- 4F ukończony.
- 4A dodał `Level/ServerScriptService/ModuleScript/SpellProjectiles.lua`.
- `SpellProjectiles` odpowiada za aktywną listę pocisków, ruch po `dt`, dystans/range, pierce/hit-once tracking i hit detection przez callbacki z `SpellService`.
- 4B dodał `Level/ServerScriptService/ModuleScript/SpellTargeting.lua`.
- `SpellTargeting` odpowiada za enemy root/position/alive queries, nearest/radius/all enemy queries, priority target picking/listing i `DistancePointToSegment` używane przez beam/line spells.
- 4C dodał `Level/ServerScriptService/ModuleScript/SpellEffects.lua`.
- `SpellEffects` odpowiada za target damage multipliers, vulnerability multiplier, DOT, slow, stun/freeze, vulnerability attributes, knockback, pull i pullStrength application.
- 4D dodał `Level/ServerScriptService/ModuleScript/SpellVisuals.lua`.
- `SpellVisuals` odpowiada za `SpellVFXEvent` transient payload broadcast, visual stats extraction, `serverTime`, orbit VFX enable/disable sync i deduplikację orbit params.
- 4E usunął nieużywane server-side konstruktory VFX z `SpellService` (`spawn*Visual`, `createProjectileVisual`, `destroyProjectileVisual` oraz ich prywatne helpery). Aktywne konstruktory pozostają w `Level/StarterPlayer/StarterPlayerScripts/LocalScript/SpellVFXClient.lua`.
- 4F dodał `Level/ServerScriptService/ModuleScript/SpellSustained.lua`.
- `SpellSustained` odpowiada za istniejące zone i beam sustained tick loopi, ich broadcast ring/beam payloadów przez callbacki oraz wywołania `hitEnemy` dla ticków.
- `SpellService` po 4A nadal odpowiada za cooldowny, wybór targetu, `SpellVFXEvent`, VFX payload shape, damage/effect formulas, orbit/nova/zone/beam flow, `PlayerData`/weapon multipliers i jeden globalny spell `Heartbeat`.
- `SpellService` po 4B nadal odpowiada za cooldowny, `SpellVFXEvent`, VFX payload shape, damage/effect formulas, status/effect application, orbit/nova/zone/beam archetype flow, `PlayerData`/weapon multipliers i jeden globalny spell `Heartbeat`.
- `SpellService` po 4C nadal odpowiada za cooldowny, `SpellVFXEvent`, VFX payload shape, impact/ring/beam/projectile visual construction, main damage call, orbit/nova/zone/beam archetype flow, `PlayerData`/weapon multipliers i jeden globalny spell `Heartbeat`.
- `SpellService` po 4E nadal odpowiada za cooldowny, main damage call, orbit/nova/zone/beam archetype flow, `PlayerData`/weapon multipliers i jeden globalny spell `Heartbeat`.
- `SpellService` po 4F nadal odpowiada za cooldowny, main damage call, orbit/nova archetype flow, `PlayerData`/weapon multipliers i jeden globalny spell `Heartbeat`; zone/beam sustained loopi są delegowane do `SpellSustained`.
- Graf po 4F: `SpellService -> SpellEffects`, `SpellService -> SpellProjectiles`, `SpellService -> SpellTargeting`, `SpellService -> SpellVisuals`, `SpellService -> SpellSustained`, `SpellService -> NpcService`, `SpellService -> PlayerData`, `SpellService -> SpellDefinitions`, `SpellService -> WeaponConfigs`; `SpellTargeting -> NpcService`; `SpellEffects`, `SpellProjectiles`, `SpellVisuals` i `SpellSustained` nie wymagają modułów. Nie powstał cykl require.
- Runtime po 4A: per-projectile `Heartbeat` został usunięty z `SpellService`; `SpellProjectiles` tworzy co najwyżej jedno leniwe połączenie `RunService.Heartbeat`, tylko gdy istnieje aktywny pocisk, i rozłącza je po opróżnieniu listy.
- Runtime po 4C: istniejący DOT `task.spawn` co `0.5s` został przeniesiony do `SpellEffects` bez zmiany częstotliwości; `SpellService` zachowuje dotychczasowe beam/zone task loopi.
- Runtime po 4D: `SpellVisuals` nie dodaje żadnej pętli ani connection; przejął tylko istniejące `FireAllClients`/`FireClient` dispatch.
- Runtime po 4E: nie dodano pętli ani connection; usunięty kod nie miał call site’ów w aktywnym server flow.
- Runtime po 4F: istniejące zone i beam `task.spawn` tick loopi przeniesiono z `SpellService` do `SpellSustained` bez zmiany `tickRate`, `duration`, damage math ani warunku `isPlayerRunActive`; `SpellService` nie zawiera już `task.spawn`.
- Nie zmieniono prędkości, range, damage, cooldown, pierce, target selection, VFX payload shape, nazw remotes, persistent data ani atrybutów.
- Walidacja 4A: live Studio `SpellProjectiles` utworzony, live `SpellService` zsynchronizowany; repo/Studio parity potwierdzona przez znormalizowane length/hash: `SpellService` `46747/771417623`, `SpellProjectiles` `3187/229091311`.
- Play test 4A: tymczasowy Studio-only `Stage4ASpellProjectileHarness` uruchomiony jako zwykły server `Script` w tym samym VM co `SpellService`; realny `VoltNeedle` przeszedł przez `SpellService -> fireProjectile -> SpellProjectiles.Fire -> NpcService.ApplyDamage`, utworzył `1` pocisk (`before=0`, `after=1`), trafił target `Stage4A_VoltNeedle_Target`, zadał `18` damage i zmienił HP `200 -> 182`; po trafieniu aktywne pociski wróciły do `0`.
- Walidacja 4B: live Studio `SpellTargeting` utworzony, live `SpellService` zsynchronizowany; repo/Studio parity potwierdzona przez znormalizowane length/hash: `SpellService` `46264/18656830`, `SpellProjectiles` `3187/229091311`, `SpellTargeting` `2333/375152092`.
- Play test 4B: tymczasowy Studio-only `Stage4BSpellTargetingHarness` uruchomiony jako zwykły server `Script` w tym samym VM co `SpellService`; realny `VoltNeedle` przeszedł przez `PickPriorityEnemyList`, `GetNearestEnemy`, `GetEnemiesInRadius` i `GetEnemyPosition`, zadał `18` damage i zmienił HP `500 -> 482`; realny `ThunderRay` przeszedł przez `PickPriorityEnemy`, `GetAllEnemies`, `GetEnemyPosition` i `DistancePointToSegment`, zadał `2` ticki po `7` damage i zmienił HP `344 -> 330`.
- Walidacja 4C: live Studio `SpellEffects` utworzony, live `SpellService` zsynchronizowany; repo/Studio parity potwierdzona przez znormalizowane length/hash: `SpellService` `43799/913598721`, `SpellEffects` `4120/920148350`, `SpellProjectiles` `3187/229091311`, `SpellTargeting` `2333/375152092`.
- Play test 4C: tymczasowy Studio-only `Stage4CSpellEffectsHarness` uruchomiony jako zwykły server `Script` w tym samym VM co `SpellService`; realny `VoltNeedle` wywołał `SpellEffects.Apply`, `NpcService.ApplyFreeze` raz z duration `0.22` i zadał `18` damage; realny `FireBolt` wywołał `SpellEffects.Apply`, zadał direct damage `19` oraz DOT ticki `showFloating=false`; realny `WaterShard` wywołał `SpellEffects.Apply`, `NpcService.ApplySlow` raz z `slowPct=0.3`, `duration=1.3` i zadał `17` damage.
- Walidacja 4D: live Studio `SpellVisuals` utworzony, live `SpellService` zsynchronizowany; repo/Studio parity potwierdzona przez znormalizowane length/hash: `SpellService` `42309/706239663`, `SpellVisuals` `2543/314798517`, `SpellEffects` `4120/920148350`, `SpellProjectiles` `3187/229091311`, `SpellTargeting` `2333/375152092`.
- Play test 4D: tymczasowy Studio-only `Stage4DSpellVisualsHarness` uruchomiony jako zwykły server `Script` w tym samym VM co `SpellService`; realny `VoltNeedle` wysłał `projectile` i `impact` payload przez `SpellVisuals.Broadcast`, `FlameBurst` wysłał `nova`, `ScorchField` wysłał `ring`, `ThunderRay` wysłał `beam`, a `EmberOrbit` przeszedł przez `SpellVisuals.SyncOrbit` enable/disable. Payloady miały `serverTime`; wynik harnessu `ok=true`, `damageCount=58`, `damageDealt=716`.
- Walidacja 4E: repo/Studio parity potwierdzona dla aktywnego `SpellService` po usunięciu martwych server-side visual constructors: `SpellService` `19498/431803948`; pozostałe spell moduły bez zmian względem 4D.
- Play test 4E: tymczasowy Studio-only `Stage4ESpellSmokeHarness` uruchomiony jako zwykły server `Script` w tym samym VM co `SpellService`; realny `VoltNeedle` nadal wysłał `projectile` i `impact`, `ScorchField` wysłał `ring`, a `ThunderRay` wysłał `beam`; wynik `ok=true`, `damageCount=25`, `damageDealt=86`.
- Walidacja 4F: live Studio `SpellSustained` utworzony, live `SpellService` zsynchronizowany; repo/Studio parity potwierdzona przez length/hash: `SpellService` `17984/776218815`, `SpellSustained` `4093/41753248`, `SpellVisuals` `2543/314798517`, `SpellEffects` `4120/920148350`, `SpellProjectiles` `3187/229091311`, `SpellTargeting` `2333/375152092`.
- Play test 4F: tymczasowy Studio-only `Stage4FSpellSustainedHarness` uruchomiony jako zwykły server `Script` w tym samym VM co `SpellService`; po odblokowaniu i późniejszym przywróceniu `PauseState` realny `ScorchField` przeszedł przez `SpellService -> SpellSustained.RunZone -> NpcService.ApplyDamage` (`zoneInvoked=1`, `zoneDirectHits=8`, `tickRate=0.45`, `duration=3.672`), a realny `ThunderRay` przeszedł przez `SpellService -> SpellSustained.RunBeam -> NpcService.ApplyDamage` (`beamInvoked=1`, `beamDirectHits=13`, `tickRate=0.16`, `duration=1.537`, `range=54`, `width=4.32`); ring i beam payloady przeszły przez `SpellVisuals.Broadcast`.
- Cleanup 4A: tymczasowy harness usunięty ze Studio; `script_grep` i repo grep nie znajdują markerów `Stage4A`.
- Cleanup 4B: tymczasowy harness usunięty ze Studio; `script_grep` i repo grep nie znajdują markerów `Stage4B`.
- Cleanup 4C: tymczasowy harness usunięty ze Studio; `script_grep` i repo grep nie znajdują markerów `Stage4C`.
- Cleanup 4D: tymczasowy harness i `ServerStorage.Stage4DResult` usunięte ze Studio; `script_grep` i repo grep nie znajdują markerów `Stage4D`.
- Cleanup 4E: tymczasowy harness i `ServerStorage.Stage4EResult` usunięte ze Studio; `script_grep` i repo grep nie znajdują markerów `Stage4E`.
- Cleanup 4F: tymczasowy harness, heartbeat probe, `ServerStorage.Stage4FResult` i target folder usunięte ze Studio; `script_grep` i repo grep nie znajdują markerów `Stage4F`.
- Nieweryfikowane w 4F: pełny naturalny run z losowymi spellami, multiplayer, oraz klientowa wizualna inspekcja renderowanych VFX. Server flow dla zone/beam ticków został sprawdzony realnym `SpellService` flow.
- Pozostałe prace etapu 4: brak w zatwierdzonym zakresie.
- Rollback 4A: przywrócić poprzedni inline `fireProjectile` z per-projectile `RunService.Heartbeat` w `SpellService.lua`, usunąć `SpellProjectiles.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 4B: przywrócić enemy query/target picking/distance segment helpery inline w `SpellService.lua`, usunąć `SpellTargeting.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 4C: przywrócić target damage multiplier, vulnerability multiplier, DOT/effects helpery inline w `SpellService.lua`, usunąć `SpellEffects.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 4D: przywrócić `extractVisualStats`, `broadcastSpellVisual`, `syncOrbitVFX` i orbit stop helpery inline w `SpellService.lua`, usunąć `SpellVisuals.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 4E: przywrócić usunięte server-side visual constructors i helpery z commita poprzedzającego 4E oraz cofnąć wpisy planu/changeloga.
- Rollback 4F: przywrócić inline `runZone` i `runBeam` task loopi w `SpellService.lua`, usunąć `SpellSustained.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.

Etapy 5-7:

- Refaktor tylko jeśli po etapach 1-4 nadal pozostają mieszane odpowiedzialności.
- Guild dopiero po otwarciu Studio `Gildia`.
- UI na końcu, bez zmian wyglądu ani nazw obiektów.

Etap 5, RunStatsService/ShrineService:

- 5A ukończony.
- 5A usunął nieużywane globalne writer-y `_G.GetRunStat` i `_G.HealRunPlayer` z aktywnego `RunStatsService`; publiczne `RunStatsService.GetStat` i `RunStatsService.HealPlayer` pozostały bez zmian.
- Audyt 5A: repo grep i Studio grep przed zmianą nie znalazły aktywnych callerów `_G.GetRunStat` ani `_G.HealRunPlayer`; Studio grep po zmianie nie znajduje tych globali.
- Audyt 5A: `_G.PrepareRunShrines` w `ShrineService` pozostaje aktywnym kontraktem `RunReadyGate`, więc nie był usuwany ani modernizowany w tym checkpointcie.
- Graf 5A bez zmian ownership: `RunStatsService -> DamageService`, `RunStatsService -> NpcService`, `RunStatsService -> RunDefenseState`, `RunStatsService -> StatsConfig`; `ShrineService -> WorldBounds`. Nie dodano cyklu require.
- Runtime 5A: nie dodano pętli, connection, schedulerów, remotes, `_G` ani fallbacków; `RunStatsService` zachowuje istniejący jeden `Heartbeat`.
- Walidacja 5A: repo/Studio parity aktywnego `RunStatsService` potwierdzona przez length/hash `14191/403943297`.
- Play test 5A: bez używania globali wymagano `RunStatsService`, `DamageService` i `NpcService`; `_G.GetRunStat=false`, `_G.HealRunPlayer=false`, publiczne `GetStat`/`HealPlayer` dostępne; `HealPlayer` przywrócił `5` HP (`57 -> 62`), `DamageService.Apply` z registered attacker zadał `6` HP graczowi (`62 -> 56`) i thorns callback odbił `4` HP w NPC (`1000 -> 996`).
- Cleanup 5A: tymczasowy target folder usunięty; repo grep i Studio grep nie znajdują markerów `Stage5A`.
- Nieweryfikowane w 5A: pełny naturalny long-run z chest item modifiers i shrine completion nie był powtarzany; test dotyczył usunięcia nieużywanych globali oraz publicznego direct API.
- Rollback 5A: przywrócić dwa końcowe przypisania `_G.GetRunStat` i `_G.HealRunPlayer` w `RunStatsService.lua` oraz cofnąć wpisy planu/changeloga.

Etap 6, Guild:

- 6A ukończony.
- 6B ukończony.
- 6C ukończony.
- 6D ukończony.
- 6A potwierdził aktywne Studio `Guild` i ścieżkę `game.ServerScriptService.Script.GuildPlace`.
- 6A dodał `Guild/ServerScriptService/ModuleScript/GuildPlaceRemotes.lua`.
- `GuildPlaceRemotes` odpowiada wyłącznie za utworzenie/odzyskanie istniejących `RemoteEvents` i `RemoteFunctions` Gildii: `RequestLobbyReturn`, `LobbyReturnStatus`, `GuildLocationOpened`, `GuildTreasuryUpdated`, `GetGuildCastleState`, `GetTreasury`, `DepositToTreasury`, `SpendFromTreasury`.
- 6B dodał `Guild/ServerScriptService/ModuleScript/GuildPlaceLocations.lua`.
- `GuildPlaceLocations` odpowiada za definicje lokalizacji Gildii, lookup po id, status `Treasury/Open` vs `Coming soon` i budowę listy lokalizacji dla castle state.
- 6C rozszerzył `GuildPlaceLocations` o budowę fizycznych modeli lokacji, billboardów i istniejących promptów lokalizacji.
- `GuildPlace` po 6C nadal odpowiada za auth guild place, DataStore profile/guild loads, treasury deposit/spend, callback otwarcia lokacji, return teleport i remote callback handlers.
- 6D dodał `Four Peaks/ServerScriptService/ModuleScript/GuildRecordState.lua`.
- `GuildRecordState` odpowiada za dotychczasową sanitizację/normalizację rekordów gildii, treasury state, task/upgrades defaults, role rebuild i proste operacje na historii treasury.
- `GuildService` po 6D nadal odpowiada za DataStore load/save, directory, membership, join/invite flow, treasury donate/spend, upgrades, task progress, teleport i publiczne API.
- Graf 6D: `GuildService -> GuildRecordState`, `GuildService -> GuildConfig`, `GuildService -> PlayerData`, `GuildService -> CurrencyService`; `GuildRecordState -> GuildConfig`. Nie powstał cykl require.
- Runtime 6A: nie dodano pętli, connection, schedulerów, remotes o nowych nazwach, `_G` ani fallbacków; przeniesiono tylko istniejące remote factory helpery.
- Runtime 6B: nie dodano pętli, connection, schedulerów, remotes, `_G` ani fallbacków; przeniesiono tylko statyczny config/status lokalizacji.
- Runtime 6C: nie dodano pętli, schedulerów, remotes, `_G` ani fallbacków; istniejące `ProximityPrompt.Triggered` bindingi przeniesiono z `GuildPlace` do `GuildPlaceLocations` bez zmiany liczby promptów ani callbacku biznesowego.
- Runtime 6D: nie dodano pętli, schedulerów, remotes, `_G`, connection ani fallbacków; przeniesiono wyłącznie helpery record/state z `GuildService` do modułu bez zmiany publicznego API.
- Walidacja 6A: repo/Studio parity aktywnego `GuildPlace` i nowego modułu potwierdzona bajtowym length/hash: `GuildPlace` `43272/661975836`, `GuildPlaceRemotes` `1923/248263159`.
- Walidacja 6B: repo/Studio parity aktywnego `GuildPlace` i modułów potwierdzona bajtowym length/hash: `GuildPlace` `38838/189744719`, `GuildPlaceRemotes` `1923/248263159`, `GuildPlaceLocations` `5273/950361888`.
- Walidacja 6C: repo/Studio parity aktywnego `GuildPlace` i modułów potwierdzona bajtowym length/hash: `GuildPlace` `32813/312367508`, `GuildPlaceRemotes` `1923/248263159`, `GuildPlaceLocations` `11559/420695235`.
- Walidacja 6D: repo/Studio parity aktywnego `Four Peaks` potwierdzona bajtowym length/hash: `GuildService` `37970/716157583`, `GuildRecordState` `9763/53470018`.
- Play test 6A w aktywnym `Gildia`: startup zakończył się logiem `[GuildPlace] Ready`; runtime inspection potwierdził te same cztery `RemoteEvent` i cztery `RemoteFunction` klasy pod `ReplicatedStorage.RemoteEvents`/`RemoteFunctions`.
- Play test 6B w aktywnym `Gildia`: startup zakończył się logiem `[GuildPlace] Ready`; runtime inspection potwierdził `7` modeli pod `Workspace.GuildLocations`, każdy z `GuildLocationPrompt`, zachowane `GuildLocationId`, status `Treasury=Open`, pozostałe `Coming soon`, oraz billboard labels m.in. `Skarbiec`, `Łowiska`, `Sala chwały`.
- Play test 6C w aktywnym `Gildia`: startup zakończył się logiem `[GuildPlace] Ready`; runtime inspection potwierdził `7` modeli pod `Workspace.GuildLocations`, `7` promptów, status `Treasury=Open`, pozostałe `Coming soon`, i zachowane billboard labels `Skarbiec`, `Łowiska`, `Sala chwały`.
- Play test 6D w aktywnym `Four Peaks`: `GuildService.GetState` zwrócił read-only state z `Success=true`, `Config` i `PlayerResources`; publiczne `CreateGuild`, `Donate`, `TeleportToCastle` pozostały funkcjami; syntetyczny `GuildRecordState.SanitizeGuildRecord` zachował normalizację `Test Guild`, `Private`, 1 member, `Owner`, level `1` i treasury Silver `5`.
- Nieweryfikowane w 6D: create/join guild, treasury deposit/spend, upgrade, task progress i teleport do/z lobby nie były wykonywane, ponieważ checkpoint nie zmieniał DataStore write flow, treasury math ani teleport handlerów.
- Rollback 6A: przywrócić inline `getRemoteEventsFolder`, `ensureRemoteEvent`, `getRemoteFunctionsFolder`, `ensureRemoteFunction` w `GuildPlace.server.lua`, usunąć `GuildPlaceRemotes.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 6B: przywrócić inline `LOCATION_STATUS`, `GUILD_LOCATION_DEFINITIONS`, `GUILD_LOCATION_BY_ID`, `getLocationStatus` i `buildGuildLocationState` w `GuildPlace.server.lua`, usunąć `GuildPlaceLocations.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.
- Rollback 6C: przywrócić inline `getFlatDirectionToCenter`, `ensurePart`, `ensureLocationBillboard`, `ensureLocationPrompt`, `ensureGuildLocations` i dotychczasowy prompt binding w `GuildPlace.server.lua`, zostawić w `GuildPlaceLocations` tylko config/status/state z 6B albo cofnąć cały moduł do wersji 6B oraz cofnąć wpisy planu/changeloga.
- Rollback 6D: przywrócić inline helpery record/state (`clampInt`, `copyMap`, sanitize/ensure/rebuild helpers) w `GuildService.lua`, usunąć `GuildRecordState.lua` z repo i live Studio oraz cofnąć wpisy planu/changeloga.

## Plan migracji `_G`

### Aktualizacja 2026-07-01 po etapie 1

Zmigrowane z aktywnego `Level` do jawnego `RunProgressApi`:

- `AwardPlayer`,
- `AwardSouls`,
- `TrySpendRunCoins`,
- `GetRunCoins`,
- `RegisterEnemyKill`,
- `NotifyBossSpawn`,
- `GetAverageRunLevel`,
- `GetRunSeconds`,
- `EndRunForPlayer`.

Usunięto też repo/live callerów legacy fallbacków:

- `_G.EndRun`,
- `_G.SetGlobalRunPause`.

Pozostałe gameplayowe `_G` w `Level` po tym kroku:

- `DropService`: `_G.SpawnDropsAt`, `_G.ActivateGlobalMagnet`,
- `ChestService`: `_G.PrepareRunChests`, `_G.SpawnRewardChestForPlayer`,
- `ShrineService`: `_G.PrepareRunShrines`,
- `StatueService`: `_G.PrepareRunStructures`, dynamiczne `_G[name]` call site’y i odczyty spawn/chest hooków,
- `WaveController`: `_G.SpawnEnemyBurst`, debug-only `_G.Debug*`,
- `RunStatsService`: `_G.GetRunStat`, `_G.HealRunPlayer` usunięte w 5A po potwierdzeniu braku repo/live callerów.

Walidacja etapu 1:

- Repo grep i Studio grep nie znajdują już `_G.AwardPlayer`, `_G.AwardSouls`, `_G.TrySpendRunCoins`, `_G.GetRunCoins`, `_G.RegisterEnemyKill`, `_G.NotifyBossSpawn`, `_G.GetAverageRunLevel`, `_G.GetRunSeconds`, `_G.EndRunForPlayer`, `_G.EndRun`, `_G.SetGlobalRunPause`.
- Play startup smoke w `Level` przeszedł po poprawce limitu lokalnych rejestrów `WaveController`.
- Nie wykonano pełnych testów kill/XP/drop/chest/end-run, więc etap 2 nie powinien startować przed ich wykonaniem.

1. Read-only fallbacki bez aktywnych callerów zostały usunięte dla `GetRunStat`/`HealRunPlayer` w 5A po Studio grep i Play test.
2. Wydzielić najmniejszy moduł dla run rewards/wallet/kill query, który nie wymaga zależności zwrotnej do `WaveController`, `NpcService`, `DamageService` ani `ChestItemService`.
3. Zmigrować callerów w kolejności najmniejszego ryzyka:
   - `ChestService` spend coins,
   - `ChestItemService` reward fallback/pause,
   - `DropService` award calls,
   - `WaveController` kill/reward/end-run calls,
   - `RunDeathHandler` i `ReturnToLobby` end-run calls.
4. Po każdym call site: repo grep, Studio grep, compile/play smoke.
5. Usunąć shimy w tym samym całym zadaniu, gdy aktywni callerzy znikną.

## Testy regresji

Level smoke:

- start runu i `RunStarted`,
- run timer,
- zwykły kill, elite kill, boss kill,
- XP, party XP i level-up offer,
- wybór/skip/reroll/banish spella,
- coins/souls/drop pickup,
- chest reward i spend run coins,
- shrine/statue preparation przez `RunReadyGate`,
- end run victory/defeat/manual return,
- save/summary/teleport status,
- reconnect/PlayerAdded path jeśli możliwe.

Wave/NPC/Spell:

- normal wave, elite, boss,
- radius/line/cone/multi-hit/hazard/arena pressure,
- spawn cap i difficulty scaling bez zmiany częstotliwości,
- NPC targeting, movement, obstacle avoidance, melee cooldown, DamageService, armor/shield/evasion/thorns/status effects/drop,
- projectile archetypes i brak rosnącej liczby `Heartbeat`.

Four Peaks/Guild/UI:

- inventory open/close/sync/sort/filter/select/equip/favorite/sell,
- blacksmith open/close/craft/upgrade/equip/sell/material tooltip,
- guild create/join/invite/leave/kick/roles/treasury/upgrades/tasks/teleport/reload, dopiero po Studio `Gildia`.

## Ryzyka i rollback

- Największe ryzyko etapu 1 to kolejność startu: obecne `_G` działa dzięki późnemu wiązaniu. Nowe moduły muszą mieć jawny bootstrap bez cyklu.
- `WaveController` zawija `_G.RegisterEnemyKill` i `_G.AwardPlayer` dla liczników InfoUI. Migracja musi zachować te liczniki albo przenieść je do jawnego callbacku.
- `ChestItemService` ma fallback do bezpośredniego `PauseState.Value`, bo `_G.SetGlobalRunPause` nie ma writera. Zmiana pause wymaga testu chest reward flow.
- `DropService` jest `Script` ze stanem aktywnych dropów. Proste `require(DropService)` nie jest opcją; trzeba wydzielić stateful module albo API pod kontrolą bootstrapu.
- Rollback każdego etapu: przywrócić zmienione pliki z poprzedniego commita, przywrócić live Studio source przez MCP `multi_edit`, cofnąć wpis changeloga i uruchomić smoke test tego etapu.

## Walidacja etapu 0

- Zmieniane pliki etapu 0: tylko ten dokument oraz changelog/index.
- Brak zmian runtime, brak nowych pętli, brak nowych `_G`, brak zmian remotes/persistent/teleport.
- Testy wymagane dla etapu 0: `git diff --check`, przegląd diffu, `git status --short`.
- Elementy nieweryfikowane: Play test, compile skryptów runtime, `Guild` Studio.
