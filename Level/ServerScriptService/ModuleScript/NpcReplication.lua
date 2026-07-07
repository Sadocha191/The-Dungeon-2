local Players = game:GetService("Players")

local NpcReplication = {}

local function buildSnapshot(npc: any)
	local snapshot = {
		id = npc.id,
		model = npc.model,
		type = npc.mobType,
		pos = npc.position,
		dir = npc.look,
		vel = npc.velocity,
		speed = npc.baseSpeed,
		state = npc.state,
		hp = npc.health,
		maxHp = npc.maxHealth,
		dead = npc.dead,
		despawned = false,
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
