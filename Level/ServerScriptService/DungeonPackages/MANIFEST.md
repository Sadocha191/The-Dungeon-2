# Dungeon package roots — Poziom

Studio source of truth: `Poziom` (`PlaceId 113361902471683`). All roots below are Models under `ServerScriptService.DungeonPackages` and have `DungeonPackageSchemaVersion = 1`, `DungeonPackageReady = true`, ownership/dependency attributes, a `Templates` hierarchy, and a child `PackageLink` in Studio.

| Root | Package asset | Dependencies |
| --- | --- | --- |
| `DungeonShared` | `rbxassetid://89030882431384` | none |
| `DungeonMovement` | `rbxassetid://126430943030265` | `DungeonShared` |
| `DungeonNPC` | `rbxassetid://125092214609252` | `DungeonShared` |
| `DungeonCombat` | `rbxassetid://89104851528052` | `DungeonShared`, `DungeonNPC` |
| `DungeonRun` | `rbxassetid://129190342132983` | `DungeonShared`, `DungeonNPC`, `DungeonCombat` |

`DungeonShared.DungeonPackageBootstrap` installs template roots once, then enables scripts in deterministic order; `RunReadyGate` starts last. Non-script values such as `PauseState` and `RunStarted`, service-container class metadata, package attributes, and `PackageLink` properties are represented here rather than as standalone filesystem files.

`ReplicatedFirst.LoadingBootstrap` intentionally remains outside the package as a thin per-place adapter because it must run before server-side package installation.
