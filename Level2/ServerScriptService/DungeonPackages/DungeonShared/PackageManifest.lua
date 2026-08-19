-- Package ownership metadata. This module is documentation and tooling input; runtime is installed by DungeonPackageBootstrap.
return {
	Name = "DungeonShared",
	SchemaVersion = 1,
	CanonicalRoot = "ServerScriptService.DungeonPackages.DungeonShared",
	Dependencies = {},
	Responsibilities = {"DungeonLevelContext and place validation","persistent profile runtime shared by dungeon systems","shared damage, world bounds, mission bridge and remote definitions","shared replicated definitions and error reporting"},
	Exceptions = {"ReplicatedFirst.LoadingBootstrap remains a thin per-place early-loading adapter."},
}
