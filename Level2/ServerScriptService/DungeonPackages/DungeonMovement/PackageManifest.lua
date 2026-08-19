-- Package ownership metadata. This module is documentation and tooling input; runtime is installed by DungeonPackageBootstrap.
return {
	Name = "DungeonMovement",
	SchemaVersion = 1,
	CanonicalRoot = "ServerScriptService.DungeonPackages.DungeonMovement",
	Dependencies = {"DungeonShared"},
	Responsibilities = {"MovementConfig","movement, sprint, momentum and air control","slide and slope slide","multijump, glide and dash","locomotion and slide presentation"},
	Exceptions = {},
}
