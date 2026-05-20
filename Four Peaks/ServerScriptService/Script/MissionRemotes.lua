-- SCRIPT: MissionRemotes.server.lua
-- GDZIE: ServerScriptService/MissionRemotes.server.lua
-- CO: remotes dla systemu misji

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local servicesFolder = ServerScriptService:FindFirstChild("Services")
local ErrorReporter = servicesFolder and servicesFolder:FindFirstChild("ErrorReporter") and require(servicesFolder.ErrorReporter) or nil

local MissionService = require(serverModules:WaitForChild("MissionService"))
local CurrencyService = require(serverModules:WaitForChild("CurrencyService"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))

local function protect(callbackName, context, callback)
	if ErrorReporter then
		return ErrorReporter.WrapCallback(callbackName, callback, context)
	end
	return callback
end

local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctions then
	remoteFunctions = Instance.new("Folder")
	remoteFunctions.Name = "RemoteFunctions"
	remoteFunctions.Parent = ReplicatedStorage
end

local function ensureFunction(name: string): RemoteFunction
	local fn = remoteFunctions:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then return fn end
	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remoteFunctions
	return fn
end

local RF_GetMissions = ensureFunction("RF_GetMissions")
local RF_ClaimMission = ensureFunction("RF_ClaimMission")
local SECONDS_PER_DAY = 24 * 60 * 60

local function utcMidnightTimestamp(now: number): number
	local dt = os.date("!*t", now)
	local secondsIntoDay = (((dt.hour or 0) * 60) + (dt.min or 0)) * 60 + (dt.sec or 0)
	return now - secondsIntoDay
end

-- === Reset timers (UTC) ===
local function nextDailyResetAt(now: number): number
	return utcMidnightTimestamp(now) + SECONDS_PER_DAY
end

local function nextWeeklyResetAt(now: number): number
	local midnight = utcMidnightTimestamp(now)
	local dt = os.date("!*t", midnight)
	local daysSinceMonday = ((dt.wday or 1) + 5) % 7
	local daysUntilNextMonday = 7 - daysSinceMonday
	if daysUntilNextMonday <= 0 then
		daysUntilNextMonday = 7
	end
	return midnight + (daysUntilNextMonday * SECONDS_PER_DAY)
end

RF_GetMissions.OnServerInvoke = protect("MissionService.GetMissions", {
	system = "MissionService",
	phase = "lobby",
}, function(player: Player)
	local now = os.time()
	local missions = MissionService.GetMissions(player)
	local currencies = CurrencyService.GetBalances(player)
	return {
		missions = missions,
		currencies = currencies,
		resets = {
			dailyAt = nextDailyResetAt(now),
			weeklyAt = nextWeeklyResetAt(now),
		},
	}
end)

RF_ClaimMission.OnServerInvoke = protect("MissionService.ClaimMission", {
	system = "MissionService",
	phase = "lobby",
}, function(player: Player, missionId: string)
	if typeof(missionId) ~= "string" then
		return { ok = false, error = "InvalidMission" }
	end

	local ok, err, updatedMission = MissionService.ClaimMission(player, missionId)
	local currencies = CurrencyService.GetBalances(player)
	local data = PlayerData.Get(player)
	local claimCounts = data.Missions and data.Missions.ClaimCounts or {}

	if not ok then
		return {
			ok = false,
			error = err or "Unknown",
			currencies = currencies,
			claimCounts = claimCounts,
		}
	end

	return {
		ok = true,
		currencies = currencies,
		claimCounts = claimCounts,
		updatedMission = updatedMission,
	}
end)

print("[MissionRemotes] Ready")
