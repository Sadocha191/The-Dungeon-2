-- ChestItemPowerBalance.server.lua
-- Applies one centralized high-impact tuning pass to active chest item definitions.
-- ChestItemService keeps ownership of rolling and granting rewards; this script only
-- adjusts the shared configuration before players can open world chests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedModules = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local ChestItemConfig = require(sharedModules:WaitForChild("Items"):WaitForChild("ChestItemConfig"))

local BONUS_SCALE_BY_RARITY = {
	Common = 2.00,
	Uncommon = 2.25,
	Rare = 2.50,
	Epic = 2.75,
	Legendary = 3.00,
}

local MAX_STACKS_BY_RARITY = {
	Common = 4,
	Uncommon = 3,
	Rare = 2,
	Epic = 1,
	Legendary = 1,
}

local INTEGER_STATS = {
	MaxHP = true,
	Shield = true,
	Thorns = true,
	PickupRange = true,
}

local UNSCALED_STATS = {
	-- Difficulty is a drawback, not item power. Keep the authored risk unchanged.
	Difficulty = true,
}

local function roundScaledValue(statName, value, scale)
	local scaled = value * scale
	if INTEGER_STATS[statName] then
		return math.floor(scaled + 0.5)
	end
	return math.floor((scaled * 1000) + 0.5) / 1000
end

if ChestItemConfig.RuntimePowerScaleApplied ~= true then
	for _, itemDefinition in ipairs(ChestItemConfig.Items or {}) do
		local rarity = tostring(itemDefinition.Rarity or "Common")
		local scale = BONUS_SCALE_BY_RARITY[rarity] or 1
		local stackCap = MAX_STACKS_BY_RARITY[rarity]

		if stackCap then
			itemDefinition.MaxStacks = math.min(itemDefinition.MaxStacks or stackCap, stackCap)
		end

		for statName, value in pairs(itemDefinition.Modifiers or {}) do
			local numericValue = tonumber(value)
			if numericValue and numericValue > 0 and UNSCALED_STATS[statName] ~= true then
				itemDefinition.Modifiers[statName] = roundScaledValue(statName, numericValue, scale)
			end
		end
	end

	ChestItemConfig.RuntimePowerScaleApplied = true
end

print("[ChestItemPowerBalance] Enabled high-impact chest item scaling")
