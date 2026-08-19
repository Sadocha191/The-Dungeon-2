local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(serverModuleFolder, "[SpellTargeting] Server ModuleScript folder is required")
local npcServiceModule = serverModuleFolder:FindFirstChild("NpcService")
assert(npcServiceModule and npcServiceModule:IsA("ModuleScript"), "[SpellTargeting] NpcService ModuleScript is required")
local NpcService = require(npcServiceModule)

local SpellTargeting = {}

local WORLD_HIT_PADDING = 0.1

local function addIgnoreInstance(ignore, instance)
	if instance then
		table.insert(ignore, instance)
	end
end

local function createWorldRaycastParams()
	local ignore = {}
	for _, player in ipairs(Players:GetPlayers()) do
		addIgnoreInstance(ignore, player.Character)
	end

	addIgnoreInstance(ignore, Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("Mobs"))
	addIgnoreInstance(ignore, Workspace:FindFirstChild("Drops"))
	addIgnoreInstance(ignore, Workspace:FindFirstChild("SpellVFX"))

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	return params
end

local function raycastWorld(origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude <= 1e-4 then
		return nil
	end
	return Workspace:Raycast(origin, direction, createWorldRaycastParams())
end

function SpellTargeting.GetEnemyRoot(model)
	return NpcService.GetRoot(model)
end

function SpellTargeting.IsEnemyAlive(model)
	return NpcService.IsAlive(model)
end

function SpellTargeting.GetEnemyPosition(model)
	local pos = NpcService.GetPosition(model)
	if pos then
		return pos
	end
	local root = SpellTargeting.GetEnemyRoot(model)
	return root and root.Position or nil
end

function SpellTargeting.HasLineOfSight(pos, model)
	local targetPos = SpellTargeting.GetEnemyPosition(model)
	if typeof(pos) ~= "Vector3" or not targetPos then
		return false
	end

	local hit = raycastWorld(pos, targetPos - pos)
	return hit == nil or (model and hit.Instance:IsDescendantOf(model))
end

function SpellTargeting.GetUnobstructedDistance(origin, direction, maxDistance)
	local distance = math.max(0, tonumber(maxDistance) or 0)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude <= 1e-4 or distance <= 0 then
		return 0
	end

	local hit = raycastWorld(origin, direction.Unit * distance)
	if not hit then
		return distance
	end
	return math.max(0, hit.Distance - WORLD_HIT_PADDING)
end

function SpellTargeting.GetNearestEnemy(pos, range)
	return NpcService.GetNearestEnemy(pos, range or 9999)
end

function SpellTargeting.GetEnemiesInRadius(pos, radius)
	return NpcService.GetEnemiesInRadius(pos, radius or 10)
end

function SpellTargeting.GetAllEnemies()
	return NpcService.GetLivingModels()
end

function SpellTargeting.GetPrioritizedEnemiesInRange(pos, range)
	local candidates = SpellTargeting.GetEnemiesInRadius(pos, range or 10)
	local visible = {}
	for _, candidate in ipairs(candidates) do
		if SpellTargeting.HasLineOfSight(pos, candidate) then
			table.insert(visible, candidate)
		end
	end
	return visible
end

function SpellTargeting.PickPriorityEnemy(pos, range)
	local candidates = SpellTargeting.GetPrioritizedEnemiesInRange(pos, range)
	return candidates[1]
end

function SpellTargeting.PickPriorityEnemyList(pos, range, count)
	local desiredCount = math.max(1, math.floor(tonumber(count) or 1))
	local candidates = SpellTargeting.GetPrioritizedEnemiesInRange(pos, range)
	if #candidates <= 0 then
		return {}
	end

	local out = {}
	local candidateCount = #candidates
	local index = 1
	while #out < desiredCount do
		table.insert(out, candidates[index])
		index += 1
		if index > candidateCount then
			index = 1
		end
	end
	return out
end

function SpellTargeting.DistancePointToSegment(point, a, b)
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom <= 1e-4 then
		return (point - a).Magnitude
	end
	local t = math.clamp(((point - a):Dot(ab)) / denom, 0, 1)
	local projection = a + (ab * t)
	return (point - projection).Magnitude
end

return SpellTargeting
