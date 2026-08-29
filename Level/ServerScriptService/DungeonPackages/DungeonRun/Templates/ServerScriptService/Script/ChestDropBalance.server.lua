-- ChestDropBalance.server.lua
-- Owns chest rarity weights and tiered bad-luck protection.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedModules = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local ChestItemConfig = require(sharedModules:WaitForChild("Items"):WaitForChild("ChestItemConfig"))
local ChestItemService = require(
	ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("Items"):WaitForChild("ChestItemService")
)
local RunStarted = ReplicatedStorage:WaitForChild("RunStarted")

local BALANCED_WEIGHTS = {
	Common = 50,
	Uncommon = 28,
	Rare = 14,
	Epic = 6,
	Legendary = 2,
}
local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
}
local PITY_THRESHOLDS = {
	Rare = 3,
	Epic = 7,
	Legendary = 14,
}

local pityByPlayer = {}
local originalRollReward = ChestItemService.RollReward

for rarity, weight in pairs(BALANCED_WEIGHTS) do
	ChestItemConfig.RarityWeights[rarity] = weight
end

local function requiredPityRank(counters): number
	if counters.legendary >= PITY_THRESHOLDS.Legendary then
		return RARITY_RANK.Legendary
	end
	if counters.epic >= PITY_THRESHOLDS.Epic then
		return RARITY_RANK.Epic
	end
	if counters.rare >= PITY_THRESHOLDS.Rare then
		return RARITY_RANK.Rare
	end
	return 0
end

local function rollWithPity(player, requiredRank)
	if requiredRank <= 0 then
		return originalRollReward(player)
	end

	local weights = ChestItemConfig.RarityWeights
	local previousWeights = {}
	for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
		previousWeights[rarity] = weights[rarity]
		if (RARITY_RANK[rarity] or 1) < requiredRank then
			weights[rarity] = 0
		end
	end

	local result = table.pack(pcall(originalRollReward, player))
	for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
		weights[rarity] = previousWeights[rarity]
	end

	if not result[1] then
		error(result[2], 0)
	end
	return result[2], result[3]
end

function ChestItemService.RollReward(player)
	local counters = pityByPlayer[player] or {
		rare = 0,
		epic = 0,
		legendary = 0,
	}
	pityByPlayer[player] = counters

	local requiredRank = requiredPityRank(counters)
	local definition, detail = rollWithPity(player, requiredRank)
	local rank = detail and (RARITY_RANK[detail.Rarity] or 1) or 1

	counters.rare = rank >= RARITY_RANK.Rare and 0 or (counters.rare + 1)
	counters.epic = rank >= RARITY_RANK.Epic and 0 or (counters.epic + 1)
	counters.legendary = rank >= RARITY_RANK.Legendary and 0 or (counters.legendary + 1)

	if detail then
		detail.PityTriggered = requiredRank > 0 and rank >= requiredRank
		if detail.PityTriggered then
			print(string.format(
				"[ChestDropBalance] %s pity triggered for %s",
				tostring(detail.Rarity),
				player.Name
			))
		end
	end

	return definition, detail
end

Players.PlayerRemoving:Connect(function(player)
	pityByPlayer[player] = nil
end)

RunStarted.Changed:Connect(function()
	table.clear(pityByPlayer)
end)

print("[ChestDropBalance] Enabled PR #161 rarity weights and tiered pity")
