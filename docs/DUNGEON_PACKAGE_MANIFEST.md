# Dungeon Packages — asset and version manifest

Snapshot date: 2026-08-19. Owner: Pinecone Industries. Runtime schema: `1`.

| Package | Asset URI | Canonical Studio root | Dependencies |
| --- | --- | --- | --- |
| DungeonShared | `rbxassetid://89030882431384` | `ServerScriptService.DungeonPackages.DungeonShared` | none |
| DungeonMovement | `rbxassetid://126430943030265` | `ServerScriptService.DungeonPackages.DungeonMovement` | DungeonShared |
| DungeonNPC | `rbxassetid://125092214609252` | `ServerScriptService.DungeonPackages.DungeonNPC` | DungeonShared |
| DungeonCombat | `rbxassetid://89104851528052` | `ServerScriptService.DungeonPackages.DungeonCombat` | DungeonShared, DungeonNPC |
| DungeonRun | `rbxassetid://129190342132983` | `ServerScriptService.DungeonPackages.DungeonRun` | DungeonShared, DungeonNPC, DungeonCombat |

Required root attributes are `DungeonPackageSchemaVersion = 1`, `DungeonPackageReady = true`, `DungeonPackageCanonicalRoot`, ownership, dependencies and responsibilities. Each root contains a `PackageManifest` ModuleScript and `Templates` containers carrying destination service/class metadata. `DungeonShared` additionally owns the active `DungeonPackageBootstrap` Script.

## Installed Places

| Place | LevelKey | Package state |
| --- | --- | --- |
| Poziom (`113361902471683`) | AshenWastes | five published linked roots |
| level2 (`86815986698401`) | HollowMarsh | five published linked roots using the same asset IDs as Poziom |

All five Pinecone Industries package assets grant the `The Dungeon 2` universe (`9965460435`) experience access. The Level2 links were inserted through Studio package-aware copy/paste after access propagation; `DungeonCombat` used `Paste into at Original Location` to preserve the canonical root path without detaching or dirtying the link.

Do not publish level-specific config, map geometry, Terrain, Lighting or decorations as a shared package version. Do not move/delete a `PackageLink` child; that detaches the instance from package update workflows.

## Publish/update checklist

1. Confirm the edited root and dependency impact.
2. Compile and playtest the source Place.
3. `Publish to Package` from the root context menu.
4. Update linked copies in all dungeon Places in dependency order.
5. Verify the five package asset IDs and schema attributes.
6. Smoke test direct play, teleport loadout, run start and return.
7. Save/publish Places, then mirror Studio into repo.

The migration update probe published byte-equivalent package versions from Level2 and Poziom exposed `Get Latest Package` on the matching linked roots. No gameplay-only probe attribute remains in either Place.

Rollback is either `Package Details → Version History` followed by restoring a known version, or reverting the package-owning checkpoint commit and republishing. Restore all affected Places to the same compatible package set before reopening production servers.
