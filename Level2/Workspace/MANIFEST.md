# Hollow Marsh world contract

The current Studio Workspace contains Terrain plus the map-owned `Animacje` and `GilgameshLightVFX` branches. They are not shared package content and are intentionally not copied from Ashen Wastes.

The map must provide a raycastable ground surface using Terrain or the `NpcWalkable` tag. Optional navigation tags are `NpcCrawlable`, `NpcNoFlyZone`, and `NpcAirNode`. Runtime creates and owns `Enemies`, `Drops`, `Chests`, `Shrines`, and `Statues`; a designer must not replace those with persistent authored folders of the same names.
