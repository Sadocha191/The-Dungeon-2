local RunSpawnConfig = {}

RunSpawnConfig.MAX_LIVING_ENEMIES = 100

RunSpawnConfig.NORMAL_SOUL_DROP = {
	chance = 0.10,
	minAmount = 1,
	maxAmount = 1,
}

RunSpawnConfig.LEVEL_SPAWN_BANDS = {
	{
		minLevel = 1,
		maxLevel = 5,
		baseMaxAlive = 24,
		alivePerMinute = 4,
		spawnBurst = 1,
		intervalMultiplier = 1.0,
	},
	{
		minLevel = 6,
		maxLevel = 10,
		baseMaxAlive = 34,
		alivePerMinute = 5,
		spawnBurst = 2,
		intervalMultiplier = 0.88,
	},
	{
		minLevel = 11,
		maxLevel = math.huge,
		baseMaxAlive = 46,
		alivePerMinute = 6,
		spawnBurst = 3,
		intervalMultiplier = 0.78,
	},
}

RunSpawnConfig.OVERTIME = {
	extraMaxAlive = 8,
	maxAliveStepSeconds = 12,
	maxAliveStepAmount = 2,
	extraBurst = 1,
	intervalMultiplier = 0.42,
}

RunSpawnConfig.SWARM = {
	extraBurst = 1,
	intervalMultiplier = 0.33,
}

RunSpawnConfig.IMPORTANT_ENCOUNTER = {
	elite = {
		maxAliveMultiplier = 0.58,
		intervalMultiplier = 1.35,
		burstMultiplier = 0.70,
		minNormalAlive = 8,
		trimInterval = 0.45,
		trimDistance = 82,
	},
	boss = {
		maxAliveMultiplier = 0.32,
		intervalMultiplier = 1.85,
		burstMultiplier = 0.45,
		minNormalAlive = 4,
		trimInterval = 0.22,
		trimDistance = 64,
	},
}

return RunSpawnConfig