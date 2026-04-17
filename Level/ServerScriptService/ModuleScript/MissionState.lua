local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerData = require(serverModules:WaitForChild("PlayerData"))

local MissionState = {}
local SECONDS_PER_DAY = 24 * 60 * 60

function MissionState.UtcMidnightTimestamp(t: number?): number
	local now = t or os.time()
	local dt = os.date("!*t", now)
	local secondsIntoDay = (((dt.hour or 0) * 60) + (dt.min or 0)) * 60 + (dt.sec or 0)
	return now - secondsIntoDay
end

function MissionState.UtcDayKey(t: number?): number
	local dt = os.date("!*t", t or os.time())
	return (dt.year * 1000) + (dt.yday or 0)
end

function MissionState.UtcWeekKey(t: number?): number
	local midnight = MissionState.UtcMidnightTimestamp(t)
	local dt = os.date("!*t", midnight)
	local daysSinceMonday = ((dt.wday or 1) + 5) % 7
	local monday = os.date("!*t", midnight - (daysSinceMonday * SECONDS_PER_DAY))
	return (monday.year * 10000) + (monday.month * 100) + (monday.day or 0)
end

function MissionState.Ensure(plr: Player)
	local data = PlayerData.Get(plr)
	data.Missions = data.Missions or {}

	local missions = data.Missions
	missions.DailyKey = tonumber(missions.DailyKey) or 0
	missions.WeeklyKey = tonumber(missions.WeeklyKey) or 0

	missions.SelectedDaily = (typeof(missions.SelectedDaily) == "table") and missions.SelectedDaily or {}
	missions.SelectedWeekly = (typeof(missions.SelectedWeekly) == "table") and missions.SelectedWeekly or {}

	missions.CountersDaily = (typeof(missions.CountersDaily) == "table") and missions.CountersDaily or {}
	missions.CountersWeekly = (typeof(missions.CountersWeekly) == "table") and missions.CountersWeekly or {}

	missions.ClaimsDaily = tonumber(missions.ClaimsDaily) or 0
	missions.ClaimsWeekly = tonumber(missions.ClaimsWeekly) or 0

	missions.LastClaimTsDaily = tonumber(missions.LastClaimTsDaily) or 0
	missions.LastClaimTsWeekly = tonumber(missions.LastClaimTsWeekly) or 0

	local dirty = false

	local dailyKey = MissionState.UtcDayKey()
	if missions.DailyKey ~= dailyKey then
		missions.DailyKey = dailyKey
		missions.SelectedDaily = {}
		missions.CountersDaily = {}
		missions.ClaimsDaily = 0
		missions.LastClaimTsDaily = 0
		dirty = true
	end

	local weeklyKey = MissionState.UtcWeekKey()
	if missions.WeeklyKey ~= weeklyKey then
		missions.WeeklyKey = weeklyKey
		missions.SelectedWeekly = {}
		missions.CountersWeekly = {}
		missions.ClaimsWeekly = 0
		missions.LastClaimTsWeekly = 0
		dirty = true
	end

	if dirty then
		PlayerData.MarkDirty(plr)
	end

	return missions, dirty
end

return MissionState
