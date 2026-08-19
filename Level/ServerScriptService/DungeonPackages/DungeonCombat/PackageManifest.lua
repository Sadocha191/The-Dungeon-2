-- Package ownership metadata. This module is documentation and tooling input; runtime is installed by DungeonPackageBootstrap.
return {
	Name = "DungeonCombat",
	SchemaVersion = 1,
	CanonicalRoot = "ServerScriptService.DungeonPackages.DungeonCombat",
	Dependencies = {"DungeonShared","DungeonNPC"},
	Responsibilities = {"weapon runtime and authored weapon templates","spell runtime, targeting and effects","central projectile simulation","run combat stats and combat presentation"},
	Exceptions = {},
}
