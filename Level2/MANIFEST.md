# level2 Studio snapshot

- Studio place: `level2`
- Dungeon identity: `HollowMarsh`
- PlaceId: `86815986698401`
- Per-place config: `ServerStorage.DungeonLevel.LevelConfig`
- Shared runtime: five roots below `ServerScriptService.DungeonPackages`
- Early adapter: `ReplicatedFirst.LoadingBootstrap`

The filesystem intentionally mirrors script/package content and important nonscript contracts, not terrain serialization. Studio remains the source of truth for the map.
