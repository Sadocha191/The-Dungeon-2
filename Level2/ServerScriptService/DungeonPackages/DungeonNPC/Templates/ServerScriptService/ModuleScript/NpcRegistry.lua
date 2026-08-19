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
end

function NpcRegistry.Remove(npc: NpcRecord): boolean
	if not NpcRegistry.Contains(npc) then
		return false
	end

	npcById[npc.id] = nil
	npcByModel[npc.model] = nil
	return true
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
end

function NpcRegistry.Count(): number
	local count = 0
	for _ in pairs(npcById) do
		count += 1
	end
	return count
end

return NpcRegistry
