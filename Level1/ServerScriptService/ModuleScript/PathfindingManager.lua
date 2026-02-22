local PathfindingService = game:GetService("PathfindingService")

local PathfindingManager = {}

local PROCESS_INTERVAL = 0.1
local MAX_PATHS_PER_TICK = 3
local QUEUE_WARN_THRESHOLD = 50

local queue = {}
local queuedByNpc = {}
local requestStateByNpc = {}

local computeCountThisSecond = 0
local computeWindowStartedAt = os.clock()

local function getNpcState(npcModel: Model)
	local state = requestStateByNpc[npcModel]
	if not state then
		state = {
			token = 0,
		}
		requestStateByNpc[npcModel] = state
	end
	return state
end

local function removeQueuedItem(item)
	if not item then
		return
	end

	if queuedByNpc[item.npcModel] == item then
		queuedByNpc[item.npcModel] = nil
	end
	item.cancelled = true
end

local function scoreRequest(item)
	return item.priority
end

local function dequeueNextItem()
	local bestIndex = nil
	local bestScore = -math.huge
	for i, item in ipairs(queue) do
		if not item.cancelled then
			local score = scoreRequest(item)
			if score > bestScore then
				bestScore = score
				bestIndex = i
			end
		end
	end

	if not bestIndex then
		return nil
	end

	local item = table.remove(queue, bestIndex)
	if queuedByNpc[item.npcModel] == item then
		queuedByNpc[item.npcModel] = nil
	end
	return item
end

local function reportMetrics()
	local now = os.clock()
	if (now - computeWindowStartedAt) >= 1 then
		print(string.format("[PathfindingManager] ComputeAsync/s=%d queue=%d", computeCountThisSecond, #queue))
		computeCountThisSecond = 0
		computeWindowStartedAt = now
	end

	if #queue > QUEUE_WARN_THRESHOLD then
		warn(string.format("[PathfindingManager] Path queue is high: %d", #queue))
	end
end

local function processQueueTick()
	for _ = 1, MAX_PATHS_PER_TICK do
		local item = dequeueNextItem()
		if not item then
			break
		end

		if item.cancelled then
			continue
		end

		if not item.npcModel.Parent then
			continue
		end

		local state = requestStateByNpc[item.npcModel]
		if not state or state.token ~= item.token then
			continue
		end

		local path = PathfindingService:CreatePath(item.agentParams)
		path:ComputeAsync(item.startPos, item.goalPos)
		computeCountThisSecond += 1

		if requestStateByNpc[item.npcModel] ~= state or state.token ~= item.token then
			continue
		end

		if item.callback then
			item.callback({
				token = item.token,
				status = path.Status,
				path = path,
				waypoints = path.Status == Enum.PathStatus.Success and path:GetWaypoints() or nil,
			})
		end
	end

	reportMetrics()
end

function PathfindingManager.RequestPath(
	npcModel: Model,
	startPos: Vector3,
	goalPos: Vector3,
	agentParams,
	priority: number,
	callback
)
	if not npcModel or not npcModel.Parent then
		return nil
	end

	local state = getNpcState(npcModel)
	state.token += 1

	local existing = queuedByNpc[npcModel]
	if existing then
		removeQueuedItem(existing)
	end

	local item = {
		npcModel = npcModel,
		startPos = startPos,
		goalPos = goalPos,
		agentParams = agentParams,
		priority = priority or 0,
		callback = callback,
		token = state.token,
		requestedAt = os.clock(),
	}

	queuedByNpc[npcModel] = item
	table.insert(queue, item)

	return state.token
end

function PathfindingManager.CancelForNpc(npcModel: Model)
	local item = queuedByNpc[npcModel]
	if item then
		removeQueuedItem(item)
	end

	local state = requestStateByNpc[npcModel]
	if state then
		state.token += 1
	end
end

task.spawn(function()
	while true do
		task.wait(PROCESS_INTERVAL)
		processQueueTick()
	end
end)

return PathfindingManager
