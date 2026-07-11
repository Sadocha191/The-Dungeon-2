local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(serverModuleFolder, "[NpcTargeting] Server ModuleScript folder is required")
local npcMovementModule = serverModuleFolder:FindFirstChild("NpcMovement")
assert(npcMovementModule and npcMovementModule:IsA("ModuleScript"), "[NpcTargeting] NpcMovement ModuleScript is required")
local NpcMovement = require(npcMovementModule)
local NpcNavigationConfig = require(serverModuleFolder:WaitForChild("NpcNavigationConfig"))

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
	local playerInfo = {}
	for _, info in ipairs(alivePlayers) do
		playerInfo[info.player] = info
	end
	for _, npc in npcPairs() do
		if not npc.dead and npc.model.Parent then
			local bestInfo = playerInfo[npc.targetPlayer]

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
	local nearest = math.huge
	for _, info in ipairs(alivePlayers) do
		nearest = math.min(nearest, (info.hrp.Position - npc.position).Magnitude)
	end
	return nearest > maxDistance
end

local function targetScore(npc: any, info: any): number
	local delta = info.hrp.Position - npc.position
	local verticalPenalty = npc.movementMode == "Flying" and 0.1 or 1.35
	return delta.Magnitude + math.abs(delta.Y) * verticalPenalty
end

function NpcTargeting.RefreshTargets(npcPairs: () -> (), alivePlayers: {any}, now: number)
	local aliveByPlayer = {}
	for _, info in ipairs(alivePlayers) do
		aliveByPlayer[info.player] = info
	end

	for _, npc in npcPairs() do
		if not npc.dead and npc.model.Parent then
			local current = aliveByPlayer[npc.targetPlayer]
			local unreachableExpired = npc.unreachableSince ~= nil
				and now - npc.unreachableSince >= NpcNavigationConfig.Scheduler.UnreachableRetargetSeconds
			if unreachableExpired then
				npc.retargetBlockedPlayer = npc.targetPlayer
				npc.retargetBlockedUntil = now + NpcNavigationConfig.Scheduler.UnreachableRetargetSeconds
				npc.unreachableSince = nil
				current = nil
			end

			local bestInfo = current
			local bestScore = current and targetScore(npc, current) * 0.9 or math.huge
			for _, info in ipairs(alivePlayers) do
				if not (info.player == npc.retargetBlockedPlayer and now < (npc.retargetBlockedUntil or 0)) then
					local score = targetScore(npc, info)
					if score < bestScore then
						bestScore = score
						bestInfo = info
					end
				end
			end
			npc.targetPlayer = bestInfo and bestInfo.player or nil
			if now >= (npc.retargetBlockedUntil or 0) then
				npc.retargetBlockedPlayer = nil
				npc.retargetBlockedUntil = nil
			end
			if bestInfo and bestInfo.player ~= (current and current.player) then
				npc.unreachableSince = nil
			end
		end
	end
end

function NpcTargeting.FindNearestTarget(npc: any, alivePlayers: {any}, _now: number): any?
	if not npc.targetPlayer then
		return nil
	end
	for _, info in ipairs(alivePlayers) do
		if info.player == npc.targetPlayer then
			return info
		end
	end
	return nil
end

function NpcTargeting.ComputeFormationWeight(dist: number, stopDistance: number): number
	local collapseDistance = stopDistance + NPC_FORMATION_COLLAPSE_BUFFER
	if dist <= collapseDistance then
		return 0
	end
	return math.clamp((dist - collapseDistance) / NPC_FORMATION_BLEND_DISTANCE, 0, 1)
end

return NpcTargeting
