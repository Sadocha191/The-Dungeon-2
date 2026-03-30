-- RunReadyGate.server.lua (Level1)
-- Keeps players on one loading screen until base assets are preloaded, the run world
-- is generated, and the client confirms streamed textures/lighting are ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function ensureRemoteEvent(name: string): RemoteEvent
	local ev = remotes:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then
		return ev
	end
	if ev then
		ev:Destroy()
	end

	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remotes
	return ev
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
setLoadingState("waiting", {
	chests = 0,
	shrines = 0,
	statues = 0,
	monuments = 0,
})

local function freeze(plr: Player, state: boolean)
	local char = plr.Character
	if not char then
		return
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if state then
		local snapshot = frozenState[plr]
		if not snapshot then
			snapshot = {
				walkSpeed = hum and hum.WalkSpeed or 16,
				jumpPower = hum and hum.JumpPower or 50,
				anchored = hrp and hrp.Anchored or false,
			}
			frozenState[plr] = snapshot
		end

		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
		if hrp then
			hrp.Anchored = true
		end
		return
	end

	local snapshot = frozenState[plr]
	if hum then
		hum.WalkSpeed = snapshot and snapshot.walkSpeed or 16
		hum.JumpPower = snapshot and snapshot.jumpPower or 50
	end
	if hrp then
		hrp.Anchored = snapshot and snapshot.anchored or false
	end
	frozenState[plr] = nil
end

local function allPlayersReady(stateTable: {[Player]: boolean}): boolean
	for _, plr in ipairs(Players:GetPlayers()) do
		if stateTable[plr] ~= true then
			return false
		end
	end
	return true
end

local function waitForGlobalFunction(name: string, timeoutSec: number)
	local deadline = os.clock() + math.max(0.1, timeoutSec)
	while os.clock() <= deadline do
		local fn = _G[name]
		if type(fn) == "function" then
			return fn
		end
		task.wait(0.1)
	end
	return nil
end

local function prepareRunWorld()
	local counts = {
		chests = 0,
		shrines = 0,
		statues = 0,
		monuments = 0,
	}

	local prepareChests = waitForGlobalFunction("PrepareRunChests", 8)
	if prepareChests then
		counts.chests = math.max(0, math.floor(tonumber(prepareChests()) or 0))
	else
		warn("[RunReadyGate] PrepareRunChests unavailable during bootstrap")
	end

	local prepareShrines = waitForGlobalFunction("PrepareRunShrines", 8)
	if prepareShrines then
		counts.shrines = math.max(0, math.floor(tonumber(prepareShrines()) or 0))
	else
		warn("[RunReadyGate] PrepareRunShrines unavailable during bootstrap")
	end

	local prepareStructures = waitForGlobalFunction("PrepareRunStructures", 8)
	if prepareStructures then
		local structureCounts = prepareStructures()
		if typeof(structureCounts) == "table" then
			counts.statues = math.max(0, math.floor(tonumber(structureCounts.statues) or 0))
			counts.monuments = math.max(0, math.floor(tonumber(structureCounts.monuments) or 0))
		end
	else
		warn("[RunReadyGate] PrepareRunStructures unavailable during bootstrap")
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
	for _, plr in ipairs(Players:GetPlayers()) do
		freeze(plr, false)
	end
end

local function tryPrepareWorld()
	if RunStarted.Value or worldPrepared or bootstrapInProgress then
		return
	end
	if #Players:GetPlayers() == 0 then
		return
	end
	if not allPlayersReady(initialReady) then
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

	local counts = prepareRunWorld()
	worldPrepared = true
	bootstrapInProgress = false
	setLoadingState("prepared", counts)
	tryStart()
end

Players.PlayerAdded:Connect(function(plr)
	initialReady[plr] = RunStarted.Value
	worldReady[plr] = RunStarted.Value

	plr.CharacterAdded:Connect(function()
		if not RunStarted.Value then
			freeze(plr, true)
		end
	end)

	if plr.Character and not RunStarted.Value then
		task.defer(freeze, plr, true)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	initialReady[plr] = nil
	worldReady[plr] = nil
	frozenState[plr] = nil
	task.defer(function()
		tryPrepareWorld()
		tryStart()
	end)
end)

ClientReady.OnServerEvent:Connect(function(plr)
	initialReady[plr] = true
	tryPrepareWorld()
end)

ClientWorldLoaded.OnServerEvent:Connect(function(plr, generation: number?)
	if not worldPrepared then
		return
	end
	if tonumber(generation) ~= bootstrapGeneration then
		return
	end

	worldReady[plr] = true
	tryStart()
end)

for _, plr in ipairs(Players:GetPlayers()) do
	initialReady[plr] = RunStarted.Value
	worldReady[plr] = RunStarted.Value
	if plr.Character and not RunStarted.Value then
		task.defer(freeze, plr, true)
	end
end
