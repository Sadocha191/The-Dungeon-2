local ServerScriptService = game:GetService("ServerScriptService")

local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(serverModuleFolder, "[SpellTargeting] Server ModuleScript folder is required")
local npcServiceModule = serverModuleFolder:FindFirstChild("NpcService")
assert(npcServiceModule and npcServiceModule:IsA("ModuleScript"), "[SpellTargeting] NpcService ModuleScript is required")
local NpcService = require(npcServiceModule)

local SpellTargeting = {}

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
	return SpellTargeting.GetEnemiesInRadius(pos, range or 10)
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
