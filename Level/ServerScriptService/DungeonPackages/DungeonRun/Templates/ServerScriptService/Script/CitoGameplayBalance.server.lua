-- Central tuning pass for the CITO gameplay fixes.
-- Keeps run-balance overrides in one place instead of duplicating magic values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local ChestItemConfig = require(shared:WaitForChild("Items"):WaitForChild("ChestItemConfig"))
local moduleRoot = ServerScriptService:WaitForChild("ModuleScript")
local NpcNavigationConfig = require(moduleRoot:WaitForChild("NpcNavigationConfig"))
local NpcService = require(moduleRoot:WaitForChild("NpcService"))
local RunProgressApi = require(moduleRoot:WaitForChild("RunProgressApi"))
local ChestItemService = require(moduleRoot:WaitForChild("Items"):WaitForChild("ChestItemService"))
local PauseState = ReplicatedStorage:WaitForChild("PauseState")

-- ChestItemConfig applies rarity scaling while constructing the item table. Clamp the
-- final modifiers consumed by RunStatsService. PickupRange uses the existing /8 bridge.
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
end

-- Megabonk-like swarm movement: ground mobs stay on direct pursuit/local surface
-- handling and do not queue PathfindingService work. Flying profiles stay untouched.
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

-- Early XP is intentionally accelerated, then converges back to the authored curve.
-- Using awarded base XP makes this work for both solo and party progression without
-- reaching into ProgressService's private run tables.
local rawXpThisRun = {}
RunProgressApi.Wrap("AwardPlayer", function(original)
	return function(player: Player, xp: number, coins: number)
		local rawXp = math.max(0, tonumber(xp) or 0)
		local totalBefore = rawXpThisRun[player] or 0
		local multiplier = 1
		if totalBefore < 180 then
			multiplier = 1.50
		elseif totalBefore < 400 then
			multiplier = 1.30
		elseif totalBefore < 650 then
			multiplier = 1.15
		end
		rawXpThisRun[player] = totalBefore + rawXp
		return original(player, math.floor(rawXp * multiplier + 0.5), coins)
	end
end)

-- WeaponCombat currently asks NpcService for hard-coded type ranges. Increase only calls
-- originating from WeaponCombat so NPC targeting/spells do not inherit the range buff.
local originalGetNearestEnemy = NpcService.GetNearestEnemy
NpcService.GetNearestEnemy = function(fromPosition: Vector3, maxRange: number, ...)
	local source = debug.info(2, "s")
	if type(source) == "string" and string.find(source, "WeaponCombat", 1, true) then
		maxRange = (tonumber(maxRange) or 0) * 1.18
	end
	return originalGetNearestEnemy(fromPosition, maxRange, ...)
end

local function updateEarlyChestDiscount(player: Player)
	local opened = math.max(0, math.floor(tonumber(player:GetAttribute("ChestOpenedCount")) or 0))
	local targetMultiplier
	if opened <= 0 then
		targetMultiplier = 0.64 -- 55 -> 35
	elseif opened == 1 then
		targetMultiplier = 0.75 -- 80 -> 60
	elseif opened == 2 then
		targetMultiplier = 0.90 -- 105 -> about 95
	else
		targetMultiplier = 1
	end
	player:SetAttribute("ChestCostMult", targetMultiplier)
end

local function syncUnlockedSpellPool(player: Player)
	local unlocked = player:GetAttribute("UnlockedSpellsCSV")
	if typeof(unlocked) == "string" then
		-- ProgressService prioritizes SpellLoadoutCSV. Mirroring the complete unlocked set
		-- removes the functional loadout restriction and remains compatible with old payloads.
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

-- Protect chest reward ownership from another modal clearing the shared BoolValue.
-- This fixes chest -> level-up -> choose spell: choosing the spell can no longer resume
-- mobs while the chest reward is still unresolved.
local chestPending = {}
local originalOpenReward = ChestItemService.OpenReward
local originalClaimReward = ChestItemService.ClaimReward
local originalResetPlayer = ChestItemService.ResetPlayer

local function anyChestPending(): boolean
	for player in pairs(chestPending) do
		if player.Parent == Players then
			return true
		end
	end
	return false
end

ChestItemService.OpenReward = function(player: Player, context)
	local definition, detail = originalOpenReward(player, context)
	if definition and detail then
		chestPending[player] = true
		player:SetAttribute("ChestRewardPending", true)
		PauseState.Value = true
	end
	return definition, detail
end

ChestItemService.ClaimReward = function(player: Player, token)
	local ok = originalClaimReward(player, token)
	if ok then
		chestPending[player] = nil
		player:SetAttribute("ChestRewardPending", false)
	end
	return ok
end

ChestItemService.ResetPlayer = function(player: Player, ...)
	chestPending[player] = nil
	player:SetAttribute("ChestRewardPending", false)
	return originalResetPlayer(player, ...)
end

PauseState.Changed:Connect(function(isPaused)
	if not isPaused and anyChestPending() then
		-- Defer prevents re-entrant Value writes from fighting the source that just released.
		task.defer(function()
			if anyChestPending() and not PauseState.Value then
				PauseState.Value = true
			end
		end)
	end
end)

local function setupPlayer(player: Player)
	updateEarlyChestDiscount(player)
	syncUnlockedSpellPool(player)
	clampLifesteal(player)
	player:SetAttribute("ChestRewardPending", false)

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
Players.PlayerRemoving:Connect(function(player)
	rawXpThisRun[player] = nil
	chestPending[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
