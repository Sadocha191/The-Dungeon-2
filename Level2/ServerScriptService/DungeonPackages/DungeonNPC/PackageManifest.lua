-- Package ownership metadata. This module is documentation and tooling input; runtime is installed by DungeonPackageBootstrap.
return {
	Name = "DungeonNPC",
	SchemaVersion = 1,
	CanonicalRoot = "ServerScriptService.DungeonPackages.DungeonNPC",
	Dependencies = {"DungeonShared"},
	Responsibilities = {"NPC registry and lifecycle","central movement scheduler and navigation","targeting, melee and combat behaviors","NPC replication and client presentation","shared enemy templates"},
	Exceptions = {},
}
