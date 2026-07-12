local Players = game:GetService("Players")

local MobConfig = require(script.Parent:WaitForChild("MobConfig"))

local NpcReplication = {}

local DEFAULT_LOOK = Vector3.new(0, 0, -1)
local MOB_CONFIGS = MobConfig.Mobs or {}

local function unitDirection(value: any, fallback: Vector3?): Vector3
	if typeof(value) == "Vector3" and value.Magnitude > 1e-4 then
		return value.Unit
	end
	return fallback or DEFAULT_LOOK
end

local function findNearestAlivePlayerLook(origin: Vector3): Vector3?
	local bestDirection = nil
	local bestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 and player:GetAttribute("RunEnded") ~= true then
			local delta = Vector3.new(root.Position.X - origin.X, 0, root.Position.Z - origin.Z)
			local distance = delta.Magnitude
			if distance > 1e-4 and distance < bestDistance then
				bestDistance = distance
				bestDirection = delta.Unit
			end
		end
	end

	return bestDirection
end

local function getConfiguredFacingYaw(npc: any): number?
	local model = npc.model
	local modelYaw = model and model:GetAttribute("NpcFacingYawDegrees")
	if typeof(modelYaw) == "number" and math.abs(modelYaw) > 1e-4 then
		return nil
	end

	local config = MOB_CONFIGS[tostring(npc.mobType or "")]
	local yawDegrees = config and tonumber(config.facingYawDegrees)
	if yawDegrees and math.abs(yawDegrees) > 1e-4 then
		return yawDegrees
	end

	return nil
end

local function resolveSnapshotDirection(npc: any): Vector3
	local direction = unitDirection(npc.look)
	if typeof(npc.spawnSurfacePosition) == "Vector3" then
		direction = findNearestAlivePlayerLook(npc.spawnSurfacePosition) or direction
	end

	local fallbackYaw = getConfiguredFacingYaw(npc)
	if fallbackYaw then
		direction = CFrame.Angles(0, math.rad(fallbackYaw), 0):VectorToWorldSpace(direction)
	end

	return unitDirection(direction)
end

local function buildSnapshot(npc: any)
	local snapshot = {
		id = npc.id,
		model = npc.model,
		type = npc.mobType,
		pos = npc.position,
		dir = resolveSnapshotDirection(npc),
		vel = npc.velocity,
		speed = npc.baseSpeed,
		state = npc.state,
		hp = npc.health,
		maxHp = npc.maxHealth,
		dead = npc.dead,
		despawned = false,
		movementMode = npc.movementMode,
		movementProfile = npc.movementProfile,
	}
	if typeof(npc.spawnSurfacePosition) == "Vector3" then
		snapshot.spawnSurfacePos = npc.spawnSurfacePosition
		snapshot.spawnEmergeDepth = npc.spawnEmergeDepth
	end
	return snapshot
end

function NpcReplication.CollectBatchItems(
	npcPairs: () -> (),
	tombstones: (() -> ())?,
	includeTombstones: boolean?
)
	local items = {}
	for _, npc in npcPairs() do
		table.insert(items, buildSnapshot(npc))
	end
	if includeTombstones == true and tombstones then
		for _, tombstone in tombstones() do
			table.insert(items, tombstone)
		end
	end
	return items
end

function NpcReplication.SendBatchToPlayer(batchEvent: RemoteEvent, player: Player, fullSnapshot: boolean?, requestId: number?, npcPairs: () -> ())
	if not player or player.Parent ~= Players then
		return
	end

	local items = NpcReplication.CollectBatchItems(npcPairs, nil, false)
	batchEvent:FireClient(player, {
		serverTime = workspace:GetServerTimeNow(),
		full = fullSnapshot == true,
		requestId = requestId,
		items = items,
	})
end

function NpcReplication.BroadcastBatch(
	batchEvent: RemoteEvent,
	npcPairs: () -> (),
	tombstones: () -> (),
	clearTombstones: () -> ()
)
	local items = NpcReplication.CollectBatchItems(npcPairs, tombstones, true)
	clearTombstones()

	if #items == 0 then
		return
	end

	batchEvent:FireAllClients({
		serverTime = workspace:GetServerTimeNow(),
		items = items,
	})
end

return NpcReplication
