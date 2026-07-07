local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(serverModuleFolder, "[NpcTargeting] Server ModuleScript folder is required")
local npcMovementModule = serverModuleFolder:FindFirstChild("NpcMovement")
assert(npcMovementModule and npcMovementModule:IsA("ModuleScript"), "[NpcTargeting] NpcMovement ModuleScript is required")
local NpcMovement = require(npcMovementModule)

local NpcTargeting = {}

local NPC_FORMATION_LANE_ORDER = { 0, -1, 1, -2, 2, -3, 3 }
local NPC_FORMATION_LANE_COUNT = #NPC_FORMATION_LANE_ORDER
local NPC_FORMATION_LANE_SPACING = 1.85
local NPC_FORMATION_RING_SPACING = 0.95
local NPC_FORMATION_JITTER_SCALE = 0.22
local NPC_FORMATION_COLLAPSE_BUFFER = 2.75
local NPC_FORMATION_BLEND_DISTANCE = 7.5
local TARGET_PRIORITY_ELITE_DISTANCE_BONUS = 12
local TARGET_PRIORITY_BOSS_DISTANCE_BONUS = 24

NpcTargeting.FormationMovementConfig = {
	laneSpacing = NPC_FORMATION_LANE_SPACING,
	ringSpacing = NPC_FORMATION_RING_SPACING,
	jitterScale = NPC_FORMATION_JITTER_SCALE,
}

function NpcTargeting.GetAlivePlayers(): {any}
	local result = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("RunEnded") ~= true then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hrp:IsA("BasePart") and hum.Health > 0 then
				table.insert(result, {
					player = plr,
					hrp = hrp,
					humanoid = hum,
				})
			end
		end
	end
	return result
end

function NpcTargeting.BuildEngagementSlots(alivePlayers: {any}, npcPairs: () -> ()): {[string]: any}
	local slots = {}
	if #alivePlayers == 0 then
		return slots
	end

	local groups = {}
	for _, npc in npcPairs() do
		if not npc.dead and npc.model.Parent then
			local bestInfo = nil
			local bestDist = math.huge
			for _, info in ipairs(alivePlayers) do
				local dist = NpcMovement.FlatMagnitude(info.hrp.Position, npc.position)
				if dist < bestDist then
					bestDist = dist
					bestInfo = info
				end
			end

			if bestInfo then
				local key = tostring(bestInfo.player.UserId)
				local bucket = groups[key]
				if not bucket then
					bucket = {
						npcs = {},
						playerPos = bestInfo.hrp.Position,
					}
					groups[key] = bucket
				else
					bucket.playerPos = bestInfo.hrp.Position
				end
				bucket.npcs[#bucket.npcs + 1] = npc
			end
		end
	end

	for _, group in pairs(groups) do
		local playerPos = group.playerPos
		local centroid = Vector3.zero
		for _, npc in ipairs(group.npcs) do
			centroid += npc.position
		end
		if #group.npcs > 0 then
			centroid /= #group.npcs
		else
			centroid = playerPos
		end
		local approachDir = NpcMovement.SafeUnit(NpcMovement.Flat(centroid - playerPos), Vector3.new(0, 0, -1))
		table.sort(group.npcs, function(a, b)
			local distA = NpcMovement.FlatMagnitude(playerPos, a.position)
			local distB = NpcMovement.FlatMagnitude(playerPos, b.position)
			if math.abs(distA - distB) > 0.1 then
				return distA < distB
			end
			return a.spawnTime < b.spawnTime
		end)

		for index, npc in ipairs(group.npcs) do
			local slotIndex = index - 1
			slots[npc.id] = {
				lane = NPC_FORMATION_LANE_ORDER[(slotIndex % NPC_FORMATION_LANE_COUNT) + 1] or 0,
				depth = math.floor(slotIndex / NPC_FORMATION_LANE_COUNT),
				approachDir = approachDir,
			}
		end
	end

	return slots
end

function NpcTargeting.IsTargetable(npc: any): boolean
	return not npc.dead and npc.model.Parent ~= nil and typeof(npc.spawnSurfacePosition) ~= "Vector3"
end

function NpcTargeting.GetTargetPriority(npc: any): number
	if npc.isBoss then
		return 3
	end
	if npc.isElite then
		return 2
	end
	return 1
end

function NpcTargeting.GetTargetPriorityDistanceBonus(npc: any): number
	if npc.isBoss then
		return TARGET_PRIORITY_BOSS_DISTANCE_BONUS
	end
	if npc.isElite then
		return TARGET_PRIORITY_ELITE_DISTANCE_BONUS
	end
	return 0
end

function NpcTargeting.ComputeTargetingMetrics(npc: any, fromPos: Vector3): (number, number, number)
	local actualDistance = (npc.position - fromPos).Magnitude
	local effectiveDistance = math.max(0, actualDistance - NpcTargeting.GetTargetPriorityDistanceBonus(npc))
	return effectiveDistance, actualDistance, NpcTargeting.GetTargetPriority(npc)
end

function NpcTargeting.ShouldDistanceDespawn(npc: any, alivePlayers: {any}, maxDistance: number): boolean
	if npc.isElite or npc.isBoss or #alivePlayers == 0 then
		return false
	end
	return NpcMovement.NearestAlivePlayerFlatDistance(npc.position, alivePlayers) > maxDistance
end

function NpcTargeting.FindNearestTarget(npc: any, alivePlayers: {any}, now: number): any?
	local targetPlayer = npc.targetPlayer
	if targetPlayer then
		for _, info in ipairs(alivePlayers) do
			if info.player == targetPlayer then
				return info
			end
		end
	end

	if now < npc.nextTargetScanAt then
		return nil
	end
	npc.nextTargetScanAt = now + 0.35

	local bestInfo = nil
	local bestDist = math.huge
	for _, info in ipairs(alivePlayers) do
		local dist = NpcMovement.FlatMagnitude(info.hrp.Position, npc.position)
		if dist < bestDist then
			bestDist = dist
			bestInfo = info
		end
	end

	npc.targetPlayer = bestInfo and bestInfo.player or nil
	return bestInfo
end

function NpcTargeting.ComputeFormationWeight(dist: number, stopDistance: number): number
	local collapseDistance = stopDistance + NPC_FORMATION_COLLAPSE_BUFFER
	if dist <= collapseDistance then
		return 0
	end
	return math.clamp((dist - collapseDistance) / NPC_FORMATION_BLEND_DISTANCE, 0, 1)
end

return NpcTargeting
