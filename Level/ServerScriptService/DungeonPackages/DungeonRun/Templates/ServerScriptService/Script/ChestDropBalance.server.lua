-- ChestDropBalance.server.lua
-- Rebalances the active chest item service and guarantees a Legendary reward
-- after four consecutive non-Legendary chest item rolls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedModules = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local ChestItemConfig = require(sharedModules:WaitForChild("Items"):WaitForChild("ChestItemConfig"))
local ChestItemService = require(
	ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("Items"):WaitForChild("ChestItemService")
)
local RunStarted = ReplicatedStorage:WaitForChild("RunStarted")

local PITY_MISSES = 4
local BALANCED_WEIGHTS = {
	Common = 48,
	Uncommon = 28,
	Rare = 15,
	Epic = 8,
	Legendary = 1,
}

local legendaryMissesByPlayer = {}
local originalRollReward = ChestItemService.RollReward

for rarity, weight in pairs(BALANCED_WEIGHTS) do
	ChestItemConfig.RarityWeights[rarity] = weight
end

local function forceLegendaryRoll(player)
	local weights = ChestItemConfig.RarityWeights
	local previousWeights = {}

	for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
		previousWeights[rarity] = weights[rarity]
		weights[rarity] = rarity == "Legendary" and 1 or 0
	end

	local ok, rewardDefinition, rewardDetail = pcall(originalRollReward, player)

	for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
		weights[rarity] = previousWeights[rarity]
	end

	if not ok then
		error(rewardDefinition, 0)
	end

	return rewardDefinition, rewardDetail
end

function ChestItemService.RollReward(player)
	local misses = legendaryMissesByPlayer[player] or 0
	local shouldForceLegendary = misses >= PITY_MISSES

	local rewardDefinition, rewardDetail
	if shouldForceLegendary then
		rewardDefinition, rewardDetail = forceLegendaryRoll(player)
	else
		rewardDefinition, rewardDetail = originalRollReward(player)
	end

	if not rewardDetail then
		return rewardDefinition, rewardDetail
	end

	local resolvedRarity = tostring(rewardDetail.Rarity or "")
	if resolvedRarity == "Legendary" then
		legendaryMissesByPlayer[player] = 0
		if shouldForceLegendary then
			print(string.format("[ChestDropBalance] Legendary pity triggered for %s", player.Name))
		end
	elseif shouldForceLegendary then
		-- The player has exhausted all available Legendary stacks. Reset the pity
		-- instead of forcing the highest remaining rarity on every later chest.
		legendaryMissesByPlayer[player] = 0
	else
		legendaryMissesByPlayer[player] = misses + 1
	end

	rewardDetail.PityTriggered = shouldForceLegendary and resolvedRarity == "Legendary"
	return rewardDefinition, rewardDetail
end

Players.PlayerRemoving:Connect(function(player)
	legendaryMissesByPlayer[player] = nil
end)

RunStarted.Changed:Connect(function()
	table.clear(legendaryMissesByPlayer)
end)

print("[ChestDropBalance] Enabled improved rarity weights and 5-chest Legendary pity")
