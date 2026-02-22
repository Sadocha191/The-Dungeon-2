-- SCRIPT: MissionRemotes.server.lua
-- GDZIE: ServerScriptService/MissionRemotes.server.lua
-- CO: remotes dla systemu misji

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local MissionService = require(serverModules:WaitForChild("MissionService"))
local CurrencyService = require(serverModules:WaitForChild("CurrencyService"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))

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

-- === Reset timers (UTC) ===
local function nextDailyResetAt(now: number): number
	local dt = os.date("!*t", now)
	-- next day at 00:00:00 UTC
	dt.hour, dt.min, dt.sec = 0, 0, 0
	local todayMidnight = os.time(dt)
	return todayMidnight + 24 * 60 * 60
end

local function nextWeeklyResetAt(now: number): number
	-- aligns with MissionService.utcWeekKey(): weeks are 7-day blocks starting Jan 1 (UTC)
	local dt = os.date("!*t", now)
	local yday = dt.yday or 1
	local dayIndex = (yday - 1) % 7
	local daysUntilNextBlock = 7 - dayIndex
	-- next reset at next block start 00:00 UTC
	dt.hour, dt.min, dt.sec = 0, 0, 0
	local midnight = os.time(dt)
	return midnight + daysUntilNextBlock * 24 * 60 * 60
end

RF_GetMissions.OnServerInvoke = function(player: Player)
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
end

RF_ClaimMission.OnServerInvoke = function(player: Player, missionId: string)
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
end

print("[MissionRemotes] Ready")
