local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local PlayerData = require(serverModules:WaitForChild("PlayerData"))
local MissionState = require(serverModules:WaitForChild("MissionState"))
local MissionConfigs = require(replicatedModules:WaitForChild("MissionConfigs"))

local DailyMissionService = {}

local DAILY_COUNT = 6
local DAILY_PICK_SEED = 1000003
local SYNC_THROTTLE = 0.35

local scheduledSyncs: {[number]: boolean} = {}

local function ensureRemotesFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	return folder
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end
	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remotesFolder = ensureRemotesFolder()
local getDailyMissionsRemote = ensureRemoteFunction(remotesFolder, "GetDailyMissions")
local dailyMissionsUpdatedRemote = ensureRemoteEvent(remotesFolder, "DailyMissionsUpdated")

local function shuffleWithSeed(list, seed: number)
	local random = Random.new(seed)
	local out = table.clone(list)
	for index = #out, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		out[index], out[swapIndex] = out[swapIndex], out[index]
	end
	return out
end

local function pickIds(defsList, count: number, seed: number)
	local picked = {}
	local shuffled = shuffleWithSeed(defsList, seed)
	for index = 1, math.min(count, #shuffled) do
		picked[index] = shuffled[index].Id
	end
	return picked
end

local function getExpectedDailyCount(): number
	return math.min(DAILY_COUNT, #MissionConfigs.GetPool("Daily"))
end

local function selectionInvalid(selected: {any}, expectedCount: number): boolean
	if typeof(selected) ~= "table" then
		return true
	end
	if #selected ~= expectedCount then
		return true
	end

	for _, missionId in ipairs(selected) do
		local def = MissionConfigs.Get(missionId)
		if not def or def.Type ~= "Daily" then
			return true
		end
	end

	return false
end

local function ensureDailySelection(plr: Player, state)
	local expectedCount = getExpectedDailyCount()
	if not selectionInvalid(state.SelectedDaily, expectedCount) then
		return
	end

	local seed = (plr.UserId % 1000000) + (tonumber(state.DailyKey) or MissionState.UtcDayKey()) * DAILY_PICK_SEED
	state.SelectedDaily = pickIds(MissionConfigs.GetPool("Daily"), expectedCount, seed)
	PlayerData.MarkDirty(plr)
end

local function getCounter(state, scope: string, key: string): number
	local counters = scope == "Weekly" and state.CountersWeekly or state.CountersDaily
	return tonumber(counters[key]) or 0
end

local function getProgressForMission(def, state)
	local goal = def.Goal
	if typeof(goal) ~= "table" then
		return 0, 0
	end

	local current = 0
	local target = math.max(0, math.floor(tonumber(goal.Target) or 0))
	local goalType = tostring(goal.Type or "")
	local key = tostring(goal.Key or "")

	if goalType == "Counter" or goalType == "MaxCounter" then
		current = math.max(0, math.floor(getCounter(state, def.Type, key)))
	end

	return current, target
end

local function buildMissionPayload(def, state)
	local current, target = getProgressForMission(def, state)
	return {
		Id = def.Id,
		Type = def.Type,
		Title = def.Title,
		Description = def.Description,
		Goal = def.Goal,
		Reward = def.Reward,
		Repeatable = def.Repeatable == true,
		Progress = {
			Current = current,
			Target = target,
		},
		Completed = target > 0 and current >= target,
	}
end

function DailyMissionService.GetPayload(plr: Player)
	if not plr or plr.Parent ~= Players then
		return { missions = {} }
	end

	local state = MissionState.Ensure(plr)
	ensureDailySelection(plr, state)

	local missions = {}
	for _, missionId in ipairs(state.SelectedDaily) do
		local def = MissionConfigs.Get(missionId)
		if def and def.Type == "Daily" then
			missions[#missions + 1] = buildMissionPayload(def, state)
		end
	end

	return {
		missions = missions,
	}
end

local function selectedDailyUsesKey(plr: Player, counterKey: string): boolean
	local state = MissionState.Ensure(plr)
	ensureDailySelection(plr, state)

	for _, missionId in ipairs(state.SelectedDaily) do
		local def = MissionConfigs.Get(missionId)
		local goal = def and def.Goal
		if typeof(goal) == "table" and tostring(goal.Key or "") == counterKey then
			return true
		end
	end

	return false
end

function DailyMissionService.QueueSync(plr: Player, counterKey: string?)
	if not plr or plr.Parent ~= Players then
		return
	end

	if typeof(counterKey) == "string" and counterKey ~= "" and not selectedDailyUsesKey(plr, counterKey) then
		return
	end

	local userId = plr.UserId
	if scheduledSyncs[userId] then
		return
	end

	scheduledSyncs[userId] = true
	task.delay(SYNC_THROTTLE, function()
		scheduledSyncs[userId] = nil
		if plr.Parent ~= Players then
			return
		end

		dailyMissionsUpdatedRemote:FireClient(plr, DailyMissionService.GetPayload(plr))
	end)
end

getDailyMissionsRemote.OnServerInvoke = function(plr: Player)
	return DailyMissionService.GetPayload(plr)
end

Players.PlayerRemoving:Connect(function(plr: Player)
	scheduledSyncs[plr.UserId] = nil
end)

return DailyMissionService