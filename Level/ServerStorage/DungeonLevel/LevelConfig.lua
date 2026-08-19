-- Per-place dungeon content and population tuning. Shared runtime must read this through DungeonLevelContext.
return {
	SchemaVersion = 1,
	LevelKey = "AshenWastes",
	PlaceId = 113361902471683,

	Enemies = {
		Pools = {
			{ maxElapsedSeconds = 90, entries = { { "Slime", 100 } } },
			{ maxElapsedSeconds = 210, entries = { { "Slime", 55 }, { "Bat", 25 }, { "Goblin", 20 } } },
			{ maxElapsedSeconds = 360, entries = { { "Slime", 25 }, { "Bat", 20 }, { "Goblin", 30 }, { "Grzyb", 25 } } },
			{ maxElapsedSeconds = 540, entries = { { "Bat", 18 }, { "Goblin", 25 }, { "Grzyb", 22 }, { "Stump", 20 }, { "Cauldron", 15 } } },
			{ maxElapsedSeconds = 720, entries = { { "Goblin", 20 }, { "Grzyb", 15 }, { "Stump", 25 }, { "Cauldron", 20 }, { "Ent_Fat", 20 } } },
			{ entries = { { "Slime", 8 }, { "Bat", 12 }, { "Goblin", 18 }, { "Grzyb", 10 }, { "Stump", 20 }, { "Cauldron", 15 }, { "Ent_Fat", 17 } } },
		},
		MinibossOrder = { "Ent", "Golem" },
		Boss = {
			Name = "Golem",
		},
	},

	Run = {
		TimeLimitSeconds = 15 * 60,
		MinibossIntervalSeconds = 5 * 60,
		EliteFirstSpawnSeconds = 2 * 60,
		EliteIntervalSeconds = 90,
		BossReinforcementIntervalSeconds = 10,
		SwarmEventTimes = { 4 * 60, 12 * 60 },
		SwarmDurationSeconds = 60,
	},

	WorldPopulation = {
		Chests = {
			Min = 300,
			Max = 500,
		},
		Shrines = {
			Min = 10,
			Max = 20,
		},
		Structures = {
			StatueSpawnOrder = { "battle", "magnet", "battle", "magnet", "battle", "magnet" },
			MonumentCount = 3,
		},
	},

	WorldContract = {
		GroundSurfaceTags = { "Terrain", "NpcWalkable" },
		OptionalNavigationTags = { "NpcCrawlable", "NpcNoFlyZone", "NpcAirNode" },
		RuntimeFolders = { "Enemies", "Drops", "Chests", "Shrines", "Statues" },
	},
}
