-- MODULE: MissionService.lua
-- GDZIE: ServerScriptService/ModuleScript/MissionService.lua
-- CO: system misji (Daily/Weekly) + losowanie 6/12 + claim + postęp z counterów

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local replicatedModules = ReplicatedStorage:WaitForChild("ModuleScripts")
local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local MissionConfigs = require(replicatedModules:WaitForChild("MissionConfigs"))
local CurrencyService = require(serverModules:WaitForChild("CurrencyService"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))

local MissionService = {}

local DAILY_COUNT = 6
local WEEKLY_COUNT = 12

local function utcDayKey(t: number?): number
	local dt = os.date("!*t", t or os.time())
	return (dt.year * 1000) + (dt.yday or 0)
end

local function utcWeekKey(t: number?): number
	local dt = os.date("!*t", t or os.time())
	local week = math.floor(((dt.yday or 1) - 1) / 7) + 1
	return (dt.year * 100) + week
end

local function ensureMissionState(player: Player)
	local data = PlayerData.Get(player)
	data.Missions = data.Missions or {}

	local m = data.Missions
	m.ClaimCounts = m.ClaimCounts or {}
	m.Progress = m.Progress or {} -- legacy

	m.CountersDaily = m.CountersDaily or {}
	m.CountersWeekly = m.CountersWeekly or {}
	m.WeeklyWeaponRuns = m.WeeklyWeaponRuns or {}

	m.DailyKey = tonumber(m.DailyKey) or 0
	m.WeeklyKey = tonumber(m.WeeklyKey) or 0

	m.SelectedDaily = (typeof(m.SelectedDaily) == "table") and m.SelectedDaily or {}
	m.SelectedWeekly = (typeof(m.SelectedWeekly) == "table") and m.SelectedWeekly or {}

	m.LastResetDaily = tonumber(m.LastResetDaily) or 0
	m.LastResetWeekly = tonumber(m.LastResetWeekly) or 0

	return m
end

local function shuffleWithSeed(list, seed: number)
	local r = Random.new(seed)
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = r:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

local function pickIds(defsList, count: number, seed: number)
	local shuffled = shuffleWithSeed(defsList, seed)
	local picked = {}
	for i = 1, math.min(count, #shuffled) do
		table.insert(picked, shuffled[i].Id)
	end
	return picked
end

local function resetDailyIfNeeded(player: Player, state)
	local now = os.time()
	local dayKey = utcDayKey(now)
	if state.DailyKey == dayKey then return end

	state.DailyKey = dayKey
	state.LastResetDaily = now
	state.CountersDaily = {}

	for _, def in ipairs(MissionConfigs.GetPool("Daily")) do
		state.ClaimCounts[def.Id] = nil
	end

	local seed = (player.UserId % 1000000) + dayKey * 1000003
	state.SelectedDaily = pickIds(MissionConfigs.GetPool("Daily"), DAILY_COUNT, seed)

	PlayerData.MarkDirty(player)
end

local function resetWeeklyIfNeeded(player: Player, state)
	local now = os.time()
	local weekKey = utcWeekKey(now)
	if state.WeeklyKey == weekKey then return end

	state.WeeklyKey = weekKey
	state.LastResetWeekly = now
	state.CountersWeekly = {}
	state.WeeklyWeaponRuns = {}

	for _, def in ipairs(MissionConfigs.GetPool("Weekly")) do
		state.ClaimCounts[def.Id] = nil
	end

	local seed = (player.UserId % 1000000) + weekKey * 2000003
	state.SelectedWeekly = pickIds(MissionConfigs.GetPool("Weekly"), WEEKLY_COUNT, seed)

	PlayerData.MarkDirty(player)
end

local function ensureSelectionFresh(player: Player, state)
	resetDailyIfNeeded(player, state)
	resetWeeklyIfNeeded(player, state)

	if #state.SelectedDaily == 0 then
		local seed = (player.UserId % 1000000) + state.DailyKey * 1000003
		state.SelectedDaily = pickIds(MissionConfigs.GetPool("Daily"), DAILY_COUNT, seed)
		PlayerData.MarkDirty(player)
	end

	if #state.SelectedWeekly == 0 then
		local seed = (player.UserId % 1000000) + state.WeeklyKey * 2000003
		state.SelectedWeekly = pickIds(MissionConfigs.GetPool("Weekly"), WEEKLY_COUNT, seed)
		PlayerData.MarkDirty(player)
	end
end

local function getCounter(state, scope: string, key: string): number
	local counters = (scope == "Daily") and state.CountersDaily or state.CountersWeekly
	return tonumber(counters[key]) or 0
end

local function maxWeeklyWeaponRuns(state): number
	local best = 0
	for _, v in pairs(state.WeeklyWeaponRuns or {}) do
		best = math.max(best, tonumber(v) or 0)
	end
	return best
end

local function getProgressForMission(missionDef, state)
	local goal = missionDef.Goal
	if typeof(goal) ~= "table" then
		return 0, 0
	end

	local scope = missionDef.Type
	local target = tonumber(goal.Target) or 0

	if goal.Type == "Counter" then
		local key = tostring(goal.Key or "")
		return getCounter(state, scope, key), target
	elseif goal.Type == "MaxCounter" then
		local key = tostring(goal.Key or "")
		return getCounter(state, scope, key), target
	elseif goal.Type == "WeaponRunsAny" then
		return maxWeeklyWeaponRuns(state), target
	end

	return 0, target
end

local function isClaimable(missionDef, state): boolean
	local current, target = getProgressForMission(missionDef, state)
	if target <= 0 then return false end

	local claimCount = tonumber(state.ClaimCounts[missionDef.Id]) or 0
	if (not missionDef.Repeatable) and claimCount > 0 then
		return false
	end

	return current >= target
end

local function buildMissionPayload(missionDef, state)
	local current, target = getProgressForMission(missionDef, state)
	local claimCount = tonumber(state.ClaimCounts[missionDef.Id]) or 0

	return {
		Id = missionDef.Id,
		Type = missionDef.Type,
		Title = missionDef.Title,
		Description = missionDef.Description,
		Reward = missionDef.Reward,
		Repeatable = missionDef.Repeatable,
		Goal = missionDef.Goal,
		Progress = { Current = current, Target = target },
		Claimable = isClaimable(missionDef, state),
		ClaimCount = claimCount,
	}
end

function MissionService.GetMissions(player: Player)
	local state = ensureMissionState(player)
	ensureSelectionFresh(player, state)

	local out = {}

	for _, id in ipairs(state.SelectedDaily) do
		local def = MissionConfigs.Get(id)
		if def then table.insert(out, buildMissionPayload(def, state)) end
	end

	for _, id in ipairs(state.SelectedWeekly) do
		local def = MissionConfigs.Get(id)
		if def then table.insert(out, buildMissionPayload(def, state)) end
	end

	return out
end

function MissionService.ClaimMission(player: Player, missionId: string)
	local def = MissionConfigs.Get(missionId)
	if not def then
		return false, "MissionNotFound"
	end

	local state = ensureMissionState(player)
	ensureSelectionFresh(player, state)

	local function selectedContains(list, id)
		for _, v in ipairs(list) do
			if v == id then return true end
		end
		return false
	end

	if def.Type == "Daily" and not selectedContains(state.SelectedDaily, missionId) then
		return false, "NotSelected"
	end
	if def.Type == "Weekly" and not selectedContains(state.SelectedWeekly, missionId) then
		return false, "NotSelected"
	end

	if not isClaimable(def, state) then
		return false, "NotClaimable"
	end

	local reward = def.Reward or {}
	local coins = math.max(0, math.floor(tonumber(reward.Coins) or 0))
	local weaponPoints = math.max(0, math.floor(tonumber(reward.WeaponPoints) or 0))

	if coins > 0 then CurrencyService.AddCoins(player, coins) end
	if weaponPoints > 0 then CurrencyService.AddWeaponPoints(player, weaponPoints) end

	state.ClaimCounts[missionId] = (tonumber(state.ClaimCounts[missionId]) or 0) + 1

	-- weekly: "Complete 5 daily quests"
	if def.Type == "Daily" then
		state.CountersWeekly.DAILY_CLAIMS = (tonumber(state.CountersWeekly.DAILY_CLAIMS) or 0) + 1
	end

	PlayerData.MarkDirty(player)

	return true, nil, buildMissionPayload(def, state)
end

return MissionService
