local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerData = require(serverModules:WaitForChild("PlayerData"))
local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local EventUtil = require(replicatedModules:WaitForChild("EventUtil"))

local EventProgress = {}

local MISSION_KEY_MAP = {
	KILLS = "EnemiesDefeated",
	ELITE_KILLS = "ElitesDefeated",
	BOSSES = "DungeonRunsCompleted",
}

local function clampInt(value)
	value = math.floor(tonumber(value) or 0)
	if value < 0 then
		return 0
	end
	return value
end

local function sanitizeBoolMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" and value == true then
			out[key] = true
		end
	end
	return out
end

local function sanitizeStats(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = clampInt(value)
			if amount > 0 then
				out[key] = amount
			end
		end
	end
	return out
end

local function sanitizeEventEntry(raw)
	if typeof(raw) ~= "table" then
		raw = {}
	end
	return {
		Stats = sanitizeStats(raw.Stats),
		ClaimedTasks = sanitizeBoolMap(raw.ClaimedTasks),
		ClaimedMilestones = sanitizeBoolMap(raw.ClaimedMilestones),
		ClaimedFinalRewards = raw.ClaimedFinalRewards == true,
	}
end

local function ensureEventsData(player)
	local data = PlayerData.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end
	if typeof(data.Events) ~= "table" then
		data.Events = { Progress = {} }
	end
	if typeof(data.Events.Progress) ~= "table" then
		data.Events.Progress = {}
	end
	for eventId, eventEntry in pairs(data.Events.Progress) do
		if typeof(eventId) ~= "string" or eventId == "" then
			data.Events.Progress[eventId] = nil
		else
			data.Events.Progress[eventId] = sanitizeEventEntry(eventEntry)
		end
	end
	return data.Events
end

local function getEventProgress(player, eventId)
	local eventsData = ensureEventsData(player)
	if not eventsData then
		return nil
	end
	local eventProgress = eventsData.Progress[eventId]
	if typeof(eventProgress) ~= "table" then
		eventProgress = sanitizeEventEntry(nil)
		eventsData.Progress[eventId] = eventProgress
	end
	return eventProgress
end

local function requiredForProgressKey(eventConfig, progressKey)
	local maxRequired = 0
	for _, taskDef in ipairs(eventConfig.Tasks or {}) do
		if taskDef.ProgressKey == progressKey then
			maxRequired = math.max(maxRequired, math.max(1, clampInt(taskDef.RequiredAmount)))
		end
	end
	return maxRequired
end

function EventProgress.Add(player, progressKey, amount, source)
	if not player or not player.Parent then
		return { Success = false, Applied = 0, Message = "InvalidPlayer" }
	end
	progressKey = tostring(progressKey or "")
	amount = math.max(0, clampInt(amount))
	if progressKey == "" or amount <= 0 then
		return { Success = false, Applied = 0, Message = "InvalidProgress" }
	end

	local eventsData = ensureEventsData(player)
	if not eventsData then
		return { Success = false, Applied = 0, Message = "PlayerDataUnavailable" }
	end

	local nowUnix = EventUtil.GetUTCNow()
	local changed = false
	local applied = 0

	for _, eventConfig in ipairs(EventUtil.GetEnabledEvents()) do
		if EventUtil.IsEventActive(eventConfig, nowUnix) then
			local required = requiredForProgressKey(eventConfig, progressKey)
			if required > 0 then
				local eventProgress = getEventProgress(player, tostring(eventConfig.Id or ""))
				local current = clampInt(eventProgress.Stats[progressKey])
				local nextValue = math.min(required, current + amount)
				if nextValue > current then
					eventProgress.Stats[progressKey] = nextValue
					changed = true
					applied += 1
				end
			end
		end
	end

	if changed then
		PlayerData.MarkDirty(player)
	end

	return {
		Success = true,
		Applied = applied,
		Message = changed and "ProgressAdded" or "NoActiveMatchingEvent",
		ProgressKey = progressKey,
		Amount = amount,
		Source = source,
	}
end

function EventProgress.AddFromMissionKey(player, missionKey, amount, source)
	local progressKey = MISSION_KEY_MAP[tostring(missionKey or "")]
	if not progressKey then
		return { Success = true, Applied = 0, Message = "NoMappedEventProgress" }
	end
	return EventProgress.Add(player, progressKey, amount, source or ("Mission:" .. tostring(missionKey)))
end

return EventProgress
