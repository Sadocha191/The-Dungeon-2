local NpcRegistry = {}

type NpcRecord = {
	id: string,
	model: Model,
}

type Tombstone = {[string]: any}

local nextNpcId = 0
local npcById: {[string]: NpcRecord} = {}
local npcByModel: {[Model]: NpcRecord} = {}
local tombstones: {Tombstone} = {}
local SPATIAL_CELL_SIZE = 12
local MAX_QUERY_CELL_SPAN = 64
local spatialGrid = {}
local spatialCellById = {}
local spatialCellCount = 0
local spatialQueries = 0
local spatialCandidates = 0
local lifecycleMetrics = {
	totalSpawns = 0,
	totalUnregisters = 0,
	duplicateUnregisterAttempts = 0,
}

local function cellCoordinates(position: Vector3): (number, number)
	return math.floor(position.X / SPATIAL_CELL_SIZE), math.floor(position.Z / SPATIAL_CELL_SIZE)
end

local function removeFromSpatialGrid(npc: NpcRecord)
	local cell = spatialCellById[npc.id]
	if not cell then
		return
	end
	local column = spatialGrid[cell.x]
	local bucket = column and column[cell.z]
	if bucket then
		bucket[npc.id] = nil
		if next(bucket) == nil then
			column[cell.z] = nil
			spatialCellCount = math.max(0, spatialCellCount - 1)
			if next(column) == nil then
				spatialGrid[cell.x] = nil
			end
		end
	end
	spatialCellById[npc.id] = nil
end

function NpcRegistry.NextId(): string
	nextNpcId += 1
	return tostring(nextNpcId)
end

function NpcRegistry.GetByModel(model: Model): NpcRecord?
	return npcByModel[model]
end

function NpcRegistry.Resolve(target: any): NpcRecord?
	if typeof(target) ~= "Instance" then
		return nil
	end

	if target:IsA("Model") then
		return npcByModel[target]
	end

	local model = target:FindFirstAncestorOfClass("Model")
	if model then
		return npcByModel[model]
	end

	return nil
end

function NpcRegistry.Contains(npc: NpcRecord?): boolean
	return npc ~= nil and npcById[npc.id] == npc
end

function NpcRegistry.Add(npc: NpcRecord)
	assert(type(npc) == "table", "[NpcRegistry] npc record is required")
	assert(type(npc.id) == "string" and npc.id ~= "", "[NpcRegistry] npc id is required")
	assert(typeof(npc.model) == "Instance" and npc.model:IsA("Model"), "[NpcRegistry] npc model is required")

	npcById[npc.id] = npc
	npcByModel[npc.model] = npc
	local mutableNpc = npc :: any
	mutableNpc.lifecycleState = "Alive"
	mutableNpc.unregisterCount = 0
	lifecycleMetrics.totalSpawns += 1
	NpcRegistry.UpdateSpatial(npc)
end

function NpcRegistry.Remove(npc: NpcRecord): boolean
	if not NpcRegistry.Contains(npc) then
		lifecycleMetrics.duplicateUnregisterAttempts += 1
		return false
	end

	removeFromSpatialGrid(npc)
	npcById[npc.id] = nil
	npcByModel[npc.model] = nil
	local mutableNpc = npc :: any
	mutableNpc.unregisterCount = (mutableNpc.unregisterCount or 0) + 1
	mutableNpc.lifecycleState = "Unregistered"
	lifecycleMetrics.totalUnregisters += 1
	return true
end

function NpcRegistry.UpdateSpatial(npc: NpcRecord)
	if not NpcRegistry.Contains(npc) or typeof((npc :: any).position) ~= "Vector3" then
		return
	end
	local x, z = cellCoordinates((npc :: any).position)
	local previous = spatialCellById[npc.id]
	if previous and previous.x == x and previous.z == z then
		return
	end
	removeFromSpatialGrid(npc)
	local column = spatialGrid[x]
	if not column then
		column = {}
		spatialGrid[x] = column
	end
	local bucket = column[z]
	if not bucket then
		bucket = {}
		column[z] = bucket
		spatialCellCount += 1
	end
	bucket[npc.id] = npc
	spatialCellById[npc.id] = { x = x, z = z }
end

function NpcRegistry.QueryRadius(position: Vector3, radius: number, output: {NpcRecord}?): {NpcRecord}
	local queryRadius = math.max(0, tonumber(radius) or 0)
	local result = output or {}
	table.clear(result)
	local minX, minZ = cellCoordinates(position - Vector3.new(queryRadius, 0, queryRadius))
	local maxX, maxZ = cellCoordinates(position + Vector3.new(queryRadius, 0, queryRadius))
	spatialQueries += 1

	if (maxX - minX + 1) * (maxZ - minZ + 1) > MAX_QUERY_CELL_SPAN then
		for _, npc in pairs(npcById) do
			table.insert(result, npc)
		end
		spatialCandidates += #result
		return result
	end

	for x = minX, maxX do
		local column = spatialGrid[x]
		if column then
			for z = minZ, maxZ do
				local bucket = column[z]
				if bucket then
					for _, npc in pairs(bucket) do
						table.insert(result, npc)
					end
				end
			end
		end
	end
	spatialCandidates += #result
	return result
end

function NpcRegistry.GetSpatialMetrics()
	return {
		cellSize = SPATIAL_CELL_SIZE,
		cells = spatialCellCount,
		queries = spatialQueries,
		candidates = spatialCandidates,
		averageCandidates = spatialQueries > 0 and spatialCandidates / spatialQueries or 0,
	}
end

function NpcRegistry.ValidateRemoved(npc: NpcRecord): (boolean, {string})
	local failures = {}
	if npcById[npc.id] ~= nil then
		table.insert(failures, "npcById")
	end
	if npcByModel[npc.model] ~= nil then
		table.insert(failures, "npcByModel")
	end
	if spatialCellById[npc.id] ~= nil then
		table.insert(failures, "spatialCellById")
	end
	local mutableNpc = npc :: any
	if (mutableNpc.unregisterCount or 0) ~= 1 then
		table.insert(failures, "unregisterCount=" .. tostring(mutableNpc.unregisterCount or 0))
	end
	return #failures == 0, failures
end

function NpcRegistry.GetLifecycleMetrics()
	local byModelCount = 0
	for _ in pairs(npcByModel) do
		byModelCount += 1
	end
	local spatialRecordCount = 0
	for _ in pairs(spatialCellById) do
		spatialRecordCount += 1
	end
	local result = table.clone(lifecycleMetrics)
	result.registryRecords = NpcRegistry.Count()
	result.modelRecords = byModelCount
	result.spatialRecords = spatialRecordCount
	result.pendingTombstones = #tombstones
	return result
end

function NpcRegistry.Pairs()
	return pairs(npcById)
end

function NpcRegistry.QueueTombstone(tombstone: Tombstone)
	table.insert(tombstones, tombstone)
end

function NpcRegistry.Tombstones()
	return ipairs(tombstones)
end

function NpcRegistry.ClearTombstones()
	table.clear(tombstones)
end

function NpcRegistry.Reset()
	for id, npc in pairs(npcById) do
		npcById[id] = nil
		if npc.model then
			npcByModel[npc.model] = nil
		end
	end
	table.clear(tombstones)
	table.clear(spatialGrid)
	table.clear(spatialCellById)
	spatialCellCount = 0
end

function NpcRegistry.Count(): number
	local count = 0
	for _ in pairs(npcById) do
		count += 1
	end
	return count
end

return NpcRegistry
