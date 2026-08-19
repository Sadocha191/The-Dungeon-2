-- Package ownership metadata. This module is documentation and tooling input; runtime is installed by DungeonPackageBootstrap.
return {
	Name = "DungeonRun",
	SchemaVersion = 1,
	CanonicalRoot = "ServerScriptService.DungeonPackages.DungeonRun",
	Dependencies = {"DungeonShared","DungeonNPC","DungeonCombat"},
	Responsibilities = {"run readiness and lifecycle","encounter scheduling and wave execution","progress, drops and persistent run finalization","chests, shrines, statues and monuments","boss portal and ReturnToLobby","shared run UI and client presentation"},
	Exceptions = {},
}
