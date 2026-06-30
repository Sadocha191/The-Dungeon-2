local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedModules = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local StatsConfig = require(sharedModules:WaitForChild("Stats"):WaitForChild("StatsConfig"))
local RunDefenseState = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("Stats"):WaitForChild("RunDefenseState"))

local DamageService = {}

local DEFAULTS = StatsConfig.CloneDefaults()
local lethalPreventionCallback = nil
local thornsCallback = nil

local function getStatAttributeName(statName)
	return "RunStat_" .. tostring(statName)
end

local function getNumberAttr(player, name, fallback)
	local value = player and player:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback or 0
end

local function getStat(player, statName)
	local attrValue = player and player:GetAttribute(getStatAttributeName(statName))
	local value = typeof(attrValue) == "number" and attrValue or DEFAULTS[statName]
	return StatsConfig.Clamp(statName, value)
end

local function getHumanoid(player)
	local character = player and player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getSourceModel(context)
	if typeof(context) ~= "table" then
		return typeof(context) == "Instance" and context or nil
	end
	local sourceModel = context.sourceModel or context.SourceModel or context.Model or context.model
	if typeof(sourceModel) == "Instance" then
		return sourceModel
	end
	local source = context.source or context.Source
	if typeof(source) == "Instance" then
		return source
	end
	if typeof(source) == "table" then
		local nestedModel = source.Model or source.model or source.SourceModel or source.sourceModel
		if typeof(nestedModel) == "Instance" then
			return nestedModel
		end
	end
	return nil
end

local function isStudioGodModeEnabled()
	if not RunService:IsStudio() then
		return false
	end

	local debugFolder = ReplicatedStorage:FindFirstChild("DebugSettings")
	local godModeEnabled = debugFolder and debugFolder:FindFirstChild("GodModeEnabled")
	return godModeEnabled and godModeEnabled:IsA("BoolValue") and godModeEnabled.Value == true
end

local function syncDynamicAttributes(player)
	local legacyShield = RunDefenseState.IsBlockShieldGain(player) == true and 0 or math.max(0, getNumberAttr(player, "ShrineShieldCurrent", 0))
	RunDefenseState.SyncAttributes(player, legacyShield)
end

local function resolveDamageTarget(player)
	if not player or player.Parent ~= Players then
		return nil
	end

	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	if isStudioGodModeEnabled() then
		return nil
	end

	return humanoid
end

function DamageService.CanDamage(player, context)
	return resolveDamageTarget(player, context) ~= nil
end

function DamageService.Apply(player, amount, context)
	local humanoid = resolveDamageTarget(player, context)
	if not humanoid then
		return 0
	end

	local incoming = math.max(0, tonumber(amount) or 0)
	if incoming <= 0 then
		return 0
	end

	local evasionChance = math.max(0, getStat(player, "Evasion"))
	if evasionChance > 0 and math.random() < evasionChance then
		print(string.format("[DamageService] %s evaded incoming damage", player.Name))
		return 0
	end

	incoming *= (1 + getNumberAttr(player, "ShrineDifficultyPct", 0))

	local armor = math.clamp(getStat(player, "Armor"), 0, 0.80)
	incoming *= (1 - armor)

	local legacyShield = RunDefenseState.IsBlockShieldGain(player) == true and 0 or math.max(0, getNumberAttr(player, "ShrineShieldCurrent", 0))
	if legacyShield > 0 and incoming > 0 then
		local absorbed = math.min(legacyShield, incoming)
		legacyShield -= absorbed
		incoming -= absorbed
		player:SetAttribute("ShrineShieldCurrent", legacyShield)
	end

	incoming = RunDefenseState.AbsorbRunDefense(player, incoming)

	if incoming > 0 then
		local lethal = incoming >= humanoid.Health
		if lethal then
			local sourceId, effectData = RunDefenseState.ConsumeLethalPrevention(player)
			if sourceId and effectData and lethalPreventionCallback and lethalPreventionCallback(player, sourceId, effectData, context) == true then
				syncDynamicAttributes(player)
				return amount
			end
		end
		humanoid:TakeDamage(incoming)
	end

	local thorns = math.max(0, getStat(player, "Thorns"))
	if thorns > 0 and thornsCallback then
		thornsCallback(player, thorns, getSourceModel(context), context)
	end

	syncDynamicAttributes(player)
	return incoming
end

function DamageService.SetLethalPreventionCallback(callback)
	lethalPreventionCallback = callback
end

function DamageService.SetThornsCallback(callback)
	thornsCallback = callback
end

return DamageService
