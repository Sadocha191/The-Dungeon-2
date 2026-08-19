# Dungeon package roots — level2

Studio source of truth: `level2` (`PlaceId 86815986698401`). All roots below are Models under `ServerScriptService.DungeonPackages` and have `DungeonPackageSchemaVersion = 1`, `DungeonPackageReady = true`, ownership/dependency attributes, and the same `Templates` hierarchy as `Poziom`.

| Root | Package asset | Dependencies |
| --- | --- | --- |
| `DungeonShared` | `rbxassetid://89030882431384` | none |
| `DungeonMovement` | `rbxassetid://126430943030265` | `DungeonShared` |
| `DungeonNPC` | `rbxassetid://125092214609252` | `DungeonShared` |
| `DungeonCombat` | `rbxassetid://89104851528052` | `DungeonShared`, `DungeonNPC` |
| `DungeonRun` | `rbxassetid://129190342132983` | `DungeonShared`, `DungeonNPC`, `DungeonCombat` |

`DungeonShared.DungeonPackageBootstrap` installs template roots once, then enables scripts in deterministic order; `RunReadyGate` starts last. Non-script values such as `PauseState` and `RunStarted`, service-container class metadata, package attributes, and `PackageLink` properties are represented here rather than as standalone filesystem files. Studio `level2` contains true linked instances for all five published assets listed above, using the same package IDs as `Poziom`.

`ReplicatedFirst.LoadingBootstrap` intentionally remains outside the package as a thin per-place adapter because it must run before server-side package installation.
