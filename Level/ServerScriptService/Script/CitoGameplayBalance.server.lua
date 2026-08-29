-- Central tuning pass for the CITO gameplay fixes.
-- Keeps run-balance overrides in one small place instead of duplicating magic values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local ChestItemConfig = require(shared:WaitForChild("Items"):WaitForChild("ChestItemConfig"))
local NpcNavigationConfig = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("NpcNavigationConfig"))

-- Better item rarity distribution. This materially shortens bad-luck streaks even before hard pity.
ChestItemConfig.RarityWeights.Common = 50
ChestItemConfig.RarityWeights.Uncommon = 28
ChestItemConfig.RarityWeights.Rare = 14
ChestItemConfig.RarityWeights.Epic = 6
ChestItemConfig.RarityWeights.Legendary = 2

-- The item config applies rarity scaling during module construction, so clamp the final
-- gameplay values here. PickupRange uses the legacy /8 bridge in ChestItemService.
for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
	for _, item in ipairs(ChestItemConfig.GetItemsForRarity(rarity)) do
		if item.Modifiers then
			local lifesteal = tonumber(item.Modifiers.Lifesteal)
			if lifesteal and lifesteal > 0 then
				item.Modifiers.Lifesteal = math.min(lifesteal, 0.08)
			end
			local pickup = tonumber(item.Modifiers.PickupRange)
			if pickup and pickup > 0 then
				item.Modifiers.PickupRange = math.min(pickup, 8)
			end
	end
end

-- Normal ground mobs should behave like a swarm: direct pursuit first, without
-- expensive queued PathfindingService jobs. Existing local ground/surface probes still
-- keep feet on the nearest continuous layer, so bridges/overhangs do not become roofs.
NpcNavigationConfig.Scheduler.MaxConcurrentPaths = 0
NpcNavigationConfig.Scheduler.MaxPathStartsPerSecond = 0
NpcNavigationConfig.Scheduler.MaxPendingPaths = 0
for _, profileName in ipairs({ "GroundSmall", "GroundLarge" }) do
	local profile = NpcNavigationConfig.Profiles[profileName]
	profile.DirectFailureThreshold = math.huge
	profile.StepFailureThreshold = math.huge
	profile.PathRefreshSeconds = math.huge
	profile.RepathCooldown = math.huge
end

local function updateEarlyChestDiscount(player: Player)
	local opened = math.max(0, math.floor(tonumber(player:GetAttribute("ChestOpenedCount")) or 0))
	local targetMultiplier
	if opened <= 0 then
		targetMultiplier = 0.64 -- 55 -> 35
	elseif opened == 1 then
		targetMultiplier = 0.75 -- 80 -> 60
	elseif opened == 2 then
		targetMultiplier = 0.90 -- 105 -> 95
	else
		targetMultiplier = 1
	end
	player:SetAttribute("ChestCostMult", targetMultiplier)
end

local function syncUnlockedSpellPool(player: Player)
	local unlocked = player:GetAttribute("UnlockedSpellsCSV")
	if typeof(unlocked) == "string" then
		-- ProgressService historically prioritizes SpellLoadoutCSV. Mirroring the complete
		-- unlocked set removes the functional loadout restriction while remaining compatible
		-- with mixed/older teleport payloads.
		player:SetAttribute("SpellLoadoutCSV", unlocked)
	end
end

local function clampLifesteal(player: Player)
	local value = player:GetAttribute("ShrineLifestealPct")
	if typeof(value) == "number" and value > 0.35 then
		player:SetAttribute("ShrineLifestealPct", 0.35)
	end
end

local function applyCharacterJump(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = math.min(humanoid.JumpPower, 46)
	end
end

local function setupPlayer(player: Player)
	updateEarlyChestDiscount(player)
	syncUnlockedSpellPool(player)
	clampLifesteal(player)

	player:GetAttributeChangedSignal("ChestOpenedCount"):Connect(function()
		updateEarlyChestDiscount(player)
	end)
	player:GetAttributeChangedSignal("UnlockedSpellsCSV"):Connect(function()
		syncUnlockedSpellPool(player)
	end)
	player:GetAttributeChangedSignal("ShrineLifestealPct"):Connect(function()
		clampLifesteal(player)
	end)
	player.CharacterAdded:Connect(function(character)
		task.defer(applyCharacterJump, character)
	end)
	if player.Character then
		task.defer(applyCharacterJump, player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
