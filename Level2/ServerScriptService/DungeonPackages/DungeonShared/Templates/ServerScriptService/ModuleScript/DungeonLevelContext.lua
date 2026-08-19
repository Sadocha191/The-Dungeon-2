-- Server-wide owner of dungeon level identity and per-place configuration.
local ServerStorage = game:GetService("ServerStorage")

local PLACE_ID_TO_LEVEL_KEY = {
	[113361902471683] = "AshenWastes",
	[86815986698401] = "HollowMarsh",
}

local configRoot = ServerStorage:WaitForChild("DungeonLevel")
local configModule = configRoot:WaitForChild("LevelConfig")
assert(configModule:IsA("ModuleScript"), "[DungeonLevelContext] ServerStorage.DungeonLevel.LevelConfig must be a ModuleScript")

local config = require(configModule)
assert(typeof(config) == "table", "[DungeonLevelContext] LevelConfig must return a table")
assert(typeof(config.LevelKey) == "string" and config.LevelKey ~= "", "[DungeonLevelContext] LevelConfig.LevelKey is required")
assert(typeof(config.PlaceId) == "number" and config.PlaceId > 0, "[DungeonLevelContext] LevelConfig.PlaceId must be a positive number")
assert(typeof(config.Enemies) == "table" and typeof(config.Enemies.Pools) == "table" and #config.Enemies.Pools > 0,
	"[DungeonLevelContext] LevelConfig.Enemies.Pools must contain at least one band")
assert(typeof(config.Run) == "table", "[DungeonLevelContext] LevelConfig.Run is required")
assert(typeof(config.WorldPopulation) == "table", "[DungeonLevelContext] LevelConfig.WorldPopulation is required")

for index, band in ipairs(config.Enemies.Pools) do
	assert(typeof(band) == "table" and typeof(band.entries) == "table" and #band.entries > 0,
		("[DungeonLevelContext] enemy pool band %d must contain entries"):format(index))
	for entryIndex, entry in ipairs(band.entries) do
		assert(typeof(entry) == "table" and typeof(entry[1]) == "string" and entry[1] ~= ""
			and typeof(entry[2]) == "number" and entry[2] > 0,
			("[DungeonLevelContext] invalid enemy pool entry %d in band %d"):format(entryIndex, index))
	end
end

local mappedLevelKey = PLACE_ID_TO_LEVEL_KEY[game.PlaceId]
if mappedLevelKey and mappedLevelKey ~= config.LevelKey then
	error(("[DungeonLevelContext] place %d maps to %s but LevelConfig declares %s")
		:format(game.PlaceId, mappedLevelKey, config.LevelKey))
end
if game.PlaceId ~= 0 and game.PlaceId ~= config.PlaceId then
	error(("[DungeonLevelContext] active PlaceId %d does not match LevelConfig.PlaceId %d")
		:format(game.PlaceId, config.PlaceId))
end

local DungeonLevelContext = {}

function DungeonLevelContext.GetLevelKey(): string
	return config.LevelKey
end

function DungeonLevelContext.GetPlaceId(): number
	return config.PlaceId
end

function DungeonLevelContext.GetConfig()
	return config
end

function DungeonLevelContext.GetLevelKeyForPlaceId(placeId: number): string?
	return PLACE_ID_TO_LEVEL_KEY[placeId]
end

function DungeonLevelContext.ResolveTeleportLevelKey(rawLevelKey: any, player: Player?): string
	if typeof(rawLevelKey) == "string" and rawLevelKey ~= "" and rawLevelKey ~= config.LevelKey then
		warn(("[DungeonLevelContext] TeleportData LevelKey mismatch for %s: payload=%s, place=%s; using place config")
			:format(player and player.Name or "unknown player", rawLevelKey, config.LevelKey))
	end
	return config.LevelKey
end

return DungeonLevelContext
