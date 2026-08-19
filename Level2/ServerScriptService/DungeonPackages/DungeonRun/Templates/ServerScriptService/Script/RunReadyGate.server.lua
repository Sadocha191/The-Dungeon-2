-- RunReadyGate.server.lua (Level1)
-- Keeps players on one loading screen until the run world is generated and
-- every connected client confirms its spawn area is ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function ensureRemoteEvent(name: string): RemoteEvent
	local event = remotes:FindFirstChild(name)

	if event and event:IsA("RemoteEvent") then
		return event
	end

	if event then
		event:Destroy()
	end

	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes

	return event
end

local ClientReady = ensureRemoteEvent("ClientReady")
local ClientWorldLoaded = ensureRemoteEvent("ClientWorldLoaded")

local RunStarted = ReplicatedStorage:FindFirstChild("RunStarted")

if not RunStarted then
	RunStarted = Instance.new("BoolValue")
	RunStarted.Name = "RunStarted"
	RunStarted.Value = false
	RunStarted.Parent = ReplicatedStorage
end

local RunLoadingState = ReplicatedStorage:FindFirstChild("RunLoadingState")

if not RunLoadingState then
	RunLoadingState = Instance.new("Folder")
	RunLoadingState.Name = "RunLoadingState"
	RunLoadingState.Parent = ReplicatedStorage
end

local initialReady: {[Player]: boolean} = {}
local worldReady: {[Player]: boolean} = {}
local frozenState: {[Player]: {[string]: any}} = {}

local bootstrapGeneration = 0
local bootstrapInProgress = false
local worldPrepared = false

local function setLoadingState(phase: string, counts: {[string]: number}?)
	RunLoadingState:SetAttribute("Phase", phase)

	if counts then
		RunLoadingState:SetAttribute("ChestsCount", math.max(0, math.floor(tonumber(counts.chests) or 0)))
		RunLoadingState:SetAttribute("ShrinesCount", math.max(0, math.floor(tonumber(counts.shrines) or 0)))
		RunLoadingState:SetAttribute("StatuesCount", math.max(0, math.floor(tonumber(counts.statues) or 0)))
		RunLoadingState:SetAttribute("MonumentsCount", math.max(0, math.floor(tonumber(counts.monuments) or 0)))
	end
end

RunLoadingState:SetAttribute("Generation", bootstrapGeneration)
RunLoadingState:SetAttribute("PrepareDurationMs", 0)
setLoadingState("waiting", {
	chests = 0,
	shrines = 0,
	statues = 0,
	monuments = 0,
})

local function freeze(player: Player, state: boolean)
	local character = player.Character

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if state then
		local snapshot = frozenState[player]

		if not snapshot then
			snapshot = {
				walkSpeed = humanoid and humanoid.WalkSpeed or 16,
				jumpPower = humanoid and humanoid.JumpPower or 50,
				anchored = root and root.Anchored or false,
			}
			frozenState[player] = snapshot
		end

		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end

		if root then
			root.Anchored = true
		end

		return
	end

	local snapshot = frozenState[player]

	if humanoid then
		humanoid.WalkSpeed = snapshot and snapshot.walkSpeed or 16
		humanoid.JumpPower = snapshot and snapshot.jumpPower or 50
	end

	if root then
		root.Anchored = snapshot and snapshot.anchored or false
	end

	frozenState[player] = nil
end

local function allPlayersReady(stateTable: {[Player]: boolean}): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if stateTable[player] ~= true then
			return false
		end
	end

	return true
end

local function anyPlayerReady(stateTable: {[Player]: boolean}): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if stateTable[player] == true then
			return true
		end
	end

	return false
end

local function waitForGlobalFunctions(names: {string}, timeoutSec: number): {[string]: any}
	local functions = {}
	local deadline = os.clock() + math.max(0.1, timeoutSec)

	while os.clock() <= deadline do
		local missing = false

		for _, name in ipairs(names) do
			if functions[name] == nil then
				local candidate = _G[name]

				if type(candidate) == "function" then
					functions[name] = candidate
				else
					missing = true
				end
			end
		end

		if not missing then
			break
		end

		task.wait(0.1)
	end

	return functions
end

local function callPrepareFunction(name: string, callback)
	if type(callback) ~= "function" then
		warn(string.format("[RunReadyGate] %s unavailable during bootstrap", name))
		return nil
	end

	local ok, result = pcall(callback)

	if not ok then
		warn(string.format("[RunReadyGate] %s failed during bootstrap: %s", name, tostring(result)))
		return nil
	end

	return result
end

local function prepareRunWorld()
	local counts = {
		chests = 0,
		shrines = 0,
		statues = 0,
		monuments = 0,
	}

	-- Resolve all bootstrap callbacks against one shared timeout. The previous
	-- sequential waits could consume up to 24 seconds when callbacks were late.
	local prepareFunctions = waitForGlobalFunctions({
		"PrepareRunChests",
		"PrepareRunShrines",
		"PrepareRunStructures",
	}, 8)

	local chestCount = callPrepareFunction("PrepareRunChests", prepareFunctions.PrepareRunChests)
	counts.chests = math.max(0, math.floor(tonumber(chestCount) or 0))

	local shrineCount = callPrepareFunction("PrepareRunShrines", prepareFunctions.PrepareRunShrines)
	counts.shrines = math.max(0, math.floor(tonumber(shrineCount) or 0))

	local structureCounts = callPrepareFunction("PrepareRunStructures", prepareFunctions.PrepareRunStructures)

	if typeof(structureCounts) == "table" then
		counts.statues = math.max(0, math.floor(tonumber(structureCounts.statues) or 0))
		counts.monuments = math.max(0, math.floor(tonumber(structureCounts.monuments) or 0))
	end

	return counts
end

local function tryStart()
	if RunStarted.Value or not worldPrepared then
		return
	end

	if #Players:GetPlayers() == 0 then
		return
	end

	if not allPlayersReady(worldReady) then
		return
	end

	setLoadingState("running")
	RunStarted.Value = true

	for _, player in ipairs(Players:GetPlayers()) do
		freeze(player, false)
	end
end

local function tryPrepareWorld()
	if RunStarted.Value or worldPrepared or bootstrapInProgress then
		return
	end

	if #Players:GetPlayers() == 0 then
		return
	end

	-- World preparation is server-global. Start after the first client is ready
	-- instead of waiting for the slowest client before doing any server work.
	if not anyPlayerReady(initialReady) then
		return
	end

	bootstrapInProgress = true
	bootstrapGeneration += 1
	RunLoadingState:SetAttribute("Generation", bootstrapGeneration)
	setLoadingState("preparing", {
		chests = 0,
		shrines = 0,
		statues = 0,
		monuments = 0,
	})

	-- Keep the remote handler responsive while the world generation work runs.
	task.spawn(function()
		local startedAt = os.clock()
		local counts = prepareRunWorld()
		local durationMs = math.floor(((os.clock() - startedAt) * 1000) + 0.5)

		RunLoadingState:SetAttribute("PrepareDurationMs", durationMs)
		worldPrepared = true
		bootstrapInProgress = false
		setLoadingState("prepared", counts)

		print(string.format(
			"[RunReadyGate] Prepared world in %.2fs (chests=%d shrines=%d statues=%d monuments=%d)",
			durationMs / 1000,
			counts.chests,
			counts.shrines,
			counts.statues,
			counts.monuments
		))

		tryStart()
	end)
end

Players.PlayerAdded:Connect(function(player)
	initialReady[player] = RunStarted.Value
	worldReady[player] = RunStarted.Value

	player.CharacterAdded:Connect(function()
		if not RunStarted.Value then
			freeze(player, true)
		end
	end)

	if player.Character and not RunStarted.Value then
		task.defer(freeze, player, true)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	initialReady[player] = nil
	worldReady[player] = nil
	frozenState[player] = nil

	task.defer(function()
		tryPrepareWorld()
		tryStart()
	end)
end)

ClientReady.OnServerEvent:Connect(function(player)
	initialReady[player] = true
	tryPrepareWorld()
end)

ClientWorldLoaded.OnServerEvent:Connect(function(player, generation: number?)
	if not worldPrepared then
		return
	end

	if tonumber(generation) ~= bootstrapGeneration then
		return
	end

	worldReady[player] = true
	tryStart()
end)

for _, player in ipairs(Players:GetPlayers()) do
	initialReady[player] = RunStarted.Value
	worldReady[player] = RunStarted.Value

	if player.Character and not RunStarted.Value then
		task.defer(freeze, player, true)
	end
end
