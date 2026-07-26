local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function findServerModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end

	local folder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end

	return nil
end

local NpcService = require(findServerModule("NpcService") or error("[DamageIndicatorService] Missing NpcService"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local damageIndicatorEvent = remotes:FindFirstChild("DamageIndicatorEvent")
if damageIndicatorEvent and not damageIndicatorEvent:IsA("RemoteEvent") then
	damageIndicatorEvent:Destroy()
	damageIndicatorEvent = nil
end
if not damageIndicatorEvent then
	damageIndicatorEvent = Instance.new("RemoteEvent")
	damageIndicatorEvent.Name = "DamageIndicatorEvent"
	damageIndicatorEvent.Parent = remotes
end

local ELEMENT_ALIASES = {
	Electric = "Electricity",
	Lightning = "Electricity",
	Wind = "Air",
	Nature = "Earth",
	Holy = "Light",
	Dark = "Void",
	Shadow = "Void",
}

local VALID_ELEMENTS = {
	Physical = true,
	Fire = true,
	Electricity = true,
	Air = true,
	Water = true,
	Earth = true,
	Void = true,
	Light = true,
}

local DamageIndicatorService = {}

local function normalizeElement(value: any): string
	local element = tostring(value or "")
	element = ELEMENT_ALIASES[element] or element
	if VALID_ELEMENTS[element] then
		return element
	end
	return "Physical"
end

local function cloneMeta(meta: {[string]: any}?): {[string]: any}
	local result = {}
	for key, value in pairs(meta or {}) do
		result[key] = value
	end
	return result
end

local function resolveTargetId(target: any): string?
	if typeof(target) == "Instance" then
		local attribute = target:GetAttribute("NpcId")
		if typeof(attribute) == "string" and attribute ~= "" then
			return attribute
		end
		return nil
	end
	if typeof(target) == "string" and target ~= "" then
		return target
	end
	return nil
end

function DamageIndicatorService.ApplyDamage(target: any, amount: number, meta: {[string]: any}?): number
	local sourcePlayer = meta and meta.player
	local showFloating = not (meta and meta.showFloating == false)
	local position = showFloating and NpcService.GetPosition(target) or nil
	local targetId = showFloating and resolveTargetId(target) or nil

	local damageMeta = cloneMeta(meta)
	if showFloating then
		damageMeta.showFloating = false
	end

	local applied = NpcService.ApplyDamage(target, amount, damageMeta)
	if applied <= 0 or not showFloating then
		return applied
	end
	if not sourcePlayer or sourcePlayer.Parent ~= Players or typeof(position) ~= "Vector3" then
		return applied
	end

	local element = normalizeElement(meta and meta.element)
	local secondaryElement = nil
	if meta and meta.secondaryElement ~= nil then
		local normalizedSecondary = normalizeElement(meta.secondaryElement)
		if normalizedSecondary ~= element then
			secondaryElement = normalizedSecondary
		end
	end

	local payload = {
		pos = position + Vector3.new(0, 2, 0),
		amount = math.max(1, math.floor(applied + 0.5)),
		crit = meta and meta.crit == true or false,
		element = element,
		secondaryElement = secondaryElement,
		targetId = targetId,
	}

	if meta and typeof(meta.kind) == "string" and meta.kind ~= "" then
		payload.kind = meta.kind
	end
	if meta and typeof(meta.sourceId) == "string" and meta.sourceId ~= "" then
		payload.sourceId = meta.sourceId
	end

	damageIndicatorEvent:FireClient(sourcePlayer, payload)
	return applied
end

return DamageIndicatorService
