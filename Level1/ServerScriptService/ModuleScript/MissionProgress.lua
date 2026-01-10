-- MissionProgress.lua (Level1 ServerScriptService/ModuleScript)
-- CO: Aktualizacja liczników misji (Daily/Weekly) podczas runów w dungeon.
-- Zapis do globalnego profilu PlayerData (GlobalPlayerProgress_v1), więc Lobby UI widzi postęp.
-- Reset dzienny/tygodniowy (UTC) + kasowanie selection, aby Lobby wylosowało spójne 6/12.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerData = require(serverModules:WaitForChild("PlayerData"))

local MissionProgress = {}

local function utcDayKey(t: number?): number
	local dt = os.date("!*t", t or os.time())
	return (dt.year * 1000) + (dt.yday or 0)
end

local function utcWeekKey(t: number?): number
	local dt = os.date("!*t", t or os.time())
	local week = math.floor(((dt.yday or 1) - 1) / 7) + 1
	return (dt.year * 100) + week
end

local function ensureState(plr: Player)
	local data = PlayerData.Get(plr)
	data.Missions = data.Missions or {}

	local m = data.Missions
	m.DailyKey = tonumber(m.DailyKey) or 0
	m.WeeklyKey = tonumber(m.WeeklyKey) or 0

	m.SelectedDaily = (typeof(m.SelectedDaily) == "table") and m.SelectedDaily or {}
	m.SelectedWeekly = (typeof(m.SelectedWeekly) == "table") and m.SelectedWeekly or {}

	m.CountersDaily = (typeof(m.CountersDaily) == "table") and m.CountersDaily or {}
	m.CountersWeekly = (typeof(m.CountersWeekly) == "table") and m.CountersWeekly or {}

	m.ClaimsDaily = tonumber(m.ClaimsDaily) or 0
	m.ClaimsWeekly = tonumber(m.ClaimsWeekly) or 0

	m.LastClaimTsDaily = tonumber(m.LastClaimTsDaily) or 0
	m.LastClaimTsWeekly = tonumber(m.LastClaimTsWeekly) or 0

	-- reset UTC daily/weekly
	local dKey = utcDayKey()
	if m.DailyKey ~= dKey then
		m.DailyKey = dKey
		m.SelectedDaily = {}
		m.CountersDaily = {}
		m.ClaimsDaily = 0
		m.LastClaimTsDaily = 0
	end

	local wKey = utcWeekKey()
	if m.WeeklyKey ~= wKey then
		m.WeeklyKey = wKey
		m.SelectedWeekly = {}
		m.CountersWeekly = {}
		m.ClaimsWeekly = 0
		m.LastClaimTsWeekly = 0
	end

	return m
end

local function addCounter(tbl: {[string]: any}, key: string, amount: number)
	local cur = tonumber(tbl[key]) or 0
	tbl[key] = cur + amount
end

local function setMax(tbl: {[string]: any}, key: string, value: number)
	local cur = tonumber(tbl[key]) or 0
	if value > cur then
		tbl[key] = value
	end
end

function MissionProgress.Add(plr: Player, key: string, amount: number)
	if not plr or not plr.Parent then return end
	if typeof(key) ~= "string" then return end
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return end

	local m = ensureState(plr)
	addCounter(m.CountersDaily, key, amount)
	addCounter(m.CountersWeekly, key, amount)

	PlayerData.MarkDirty(plr)
end

function MissionProgress.SetMax(plr: Player, key: string, value: number)
	if not plr or not plr.Parent then return end
	if typeof(key) ~= "string" then return end
	value = math.floor(tonumber(value) or 0)
	if value <= 0 then return end

	local m = ensureState(plr)
	setMax(m.CountersDaily, key, value)
	setMax(m.CountersWeekly, key, value)

	PlayerData.MarkDirty(plr)
end

function MissionProgress.OnReward(plr: Player, xp: number, coins: number)
	xp = math.floor(tonumber(xp) or 0)
	coins = math.floor(tonumber(coins) or 0)
	if xp > 0 then MissionProgress.Add(plr, "XP_EARNED", xp) end
	if coins > 0 then MissionProgress.Add(plr, "COINS_EARNED", coins) end
end

function MissionProgress.OnDamage(plr: Player, amount: number, isCrit: boolean)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return end
	MissionProgress.Add(plr, "DAMAGE", amount)
	if isCrit then
		MissionProgress.Add(plr, "CRITS", 1)
		MissionProgress.Add(plr, "CRIT_DAMAGE", amount)
	end
end

function MissionProgress.OnKill(plr: Player, mobModel: Model?)
	MissionProgress.Add(plr, "KILLS", 1)
	if mobModel and mobModel:GetAttribute("IsElite") == true then
		MissionProgress.Add(plr, "ELITE_KILLS", 1)
	end
	-- w obecnym designie run kończy się po 8 falach, więc "BOSSES" liczymy jako ukończone runy (finale)
	if mobModel and mobModel:GetAttribute("IsBoss") == true then
		MissionProgress.Add(plr, "BOSSES", 1)
	end
end

function MissionProgress.OnRunComplete(plr: Player, waves: number, seconds: number, diedThisRun: boolean)
	waves = math.floor(tonumber(waves) or 0)
	seconds = math.floor(tonumber(seconds) or 0)

	MissionProgress.Add(plr, "RUNS", 1)
	MissionProgress.Add(plr, "RUNS_WITH_WEAPON", 1)

	if waves > 0 then
		MissionProgress.Add(plr, "WAVES", waves)
		MissionProgress.SetMax(plr, "WAVE_MAX", waves)
	end

	if seconds > 0 then
		MissionProgress.Add(plr, "SECONDS", seconds)
	end

	if diedThisRun == false then
		MissionProgress.Add(plr, "NO_DEATH_RUNS", 1)
	end

	-- "FAST_RUNS": ukończ run <= 6 minut (360s)
	if seconds > 0 and seconds <= 360 then
		MissionProgress.Add(plr, "FAST_RUNS", 1)
	end

	-- Boss missions: traktujemy ukończenie runa jako "boss" (bo nie ma dedykowanego bossa)
	MissionProgress.Add(plr, "BOSSES", 1)

	PlayerData.Save(plr, false)
end

return MissionProgress
