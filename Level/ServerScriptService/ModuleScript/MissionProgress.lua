-- MissionProgress.lua (Level1 ServerScriptService/ModuleScript)
-- CO: Aktualizacja liczników misji (Daily/Weekly) podczas runów w dungeon.
-- Zapis do globalnego profilu PlayerData (GlobalPlayerProgress_v1), więc Lobby UI widzi postęp.
-- Reset dzienny/tygodniowy (UTC) + kasowanie selection, aby Lobby wylosowało spójne 6/12.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerData = require(serverModules:WaitForChild("PlayerData"))
local MissionState = require(serverModules:WaitForChild("MissionState"))

local DailyMissionService = nil
do
	local serviceModule = serverModules:FindFirstChild("DailyMissionService")
	if serviceModule and serviceModule:IsA("ModuleScript") then
		local ok, service = pcall(require, serviceModule)
		if ok then
			DailyMissionService = service
		else
			warn("[MissionProgress] Failed to load DailyMissionService:", service)
		end
	end
end

local MissionProgress = {}
local EventProgress = nil
do
	local eventProgressModule = serverModules:FindFirstChild("EventProgress")
	if eventProgressModule and eventProgressModule:IsA("ModuleScript") then
		local ok, service = pcall(require, eventProgressModule)
		if ok then
			EventProgress = service
		else
			warn("[MissionProgress] Failed to load EventProgress:", service)
		end
	end
end


local function ensureState(plr: Player)
	return MissionState.Ensure(plr)
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

local function queueDailyMissionSync(plr: Player, key: string)
	if DailyMissionService and DailyMissionService.QueueSync then
		DailyMissionService.QueueSync(plr, key)
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
	queueDailyMissionSync(plr, key)

	if EventProgress and typeof(EventProgress.AddFromMissionKey) == "function" then
		local ok, err = pcall(EventProgress.AddFromMissionKey, plr, key, amount, "MissionProgress")
		if not ok then
			warn("[MissionProgress] Event progress update failed:", err)
		end
	end
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
	queueDailyMissionSync(plr, key)
end

function MissionProgress.OnReward(plr: Player, xp: number, coins: number)
	xp = math.floor(tonumber(xp) or 0)
	coins = math.floor(tonumber(coins) or 0)
	if xp > 0 then MissionProgress.Add(plr, "XP_EARNED", xp) end
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
		-- Revenge: elite kill within 10s after player took damage (best-effort)
		local lastD = tonumber(plr:GetAttribute("LastDamageClock")) or 0
		if lastD > 0 and (os.clock() - lastD) <= 10 then
			MissionProgress.Add(plr, "REVENGE_ELITE", 1)
		end
	end
	-- Boss progress liczymy tylko za ukończony run (OnRunComplete),
	-- żeby uniknąć podwójnego naliczania przy mapach z realnym bossem.
end

-- extraStats (optional table) can include:
--  coinsGained, runCoinsEarned, runLevel, rerollsUsed, skipsUsed, damageTaken, healAmount,
--  lowHpSeconds, maxNoDamageStreak, minHpRatio,
--  bossNoHit20, bossClutch, burst90, burst120,
--  noRerollWin, max1RerollWin, max1SkipWin, level10,
--  multikill30_5, multikill60_20, spells3, winStreak3
function MissionProgress.OnRunComplete(plr: Player, waves: number, seconds: number, diedThisRun: boolean, extraStats: any?)
	waves = math.floor(tonumber(waves) or 0)
	seconds = math.floor(tonumber(seconds) or 0)

	MissionProgress.Add(plr, "RUNS", 1)
	MissionProgress.Add(plr, "RUNS_WITH_WEAPON", 1)

	-- Tryb horde jest czasowy, ale utrzymujemy liczniki WAVE* pod stare questy:
	-- 1 pseudo-fala = 30 sekund aktywnej gry.
	local pseudoWaves = waves
	if pseudoWaves <= 0 and seconds > 0 then
		pseudoWaves = math.max(1, math.floor(seconds / 30))
	end
	if pseudoWaves > 0 then
		MissionProgress.Add(plr, "WAVES", pseudoWaves)
		MissionProgress.SetMax(plr, "WAVE_MAX", pseudoWaves)
	end

	if seconds > 0 then
		MissionProgress.Add(plr, "SECONDS", seconds)
	end

	if diedThisRun == false then
		MissionProgress.Add(plr, "NO_DEATH_RUNS", 1)
	end

	-- "FAST_RUNS": zgodnie z MissionConfigs -> ukończ run <= 12 minut (720s)
	if seconds > 0 and seconds <= 720 then
		MissionProgress.Add(plr, "FAST_RUNS", 1)
	end

	-- Optional per-run derived stats
	if typeof(extraStats) == "table" then
		local runCoinsEarned = math.floor(tonumber(extraStats.runCoinsEarned) or tonumber(extraStats.coinsGained) or 0)
		if runCoinsEarned > 0 then
			MissionProgress.SetMax(plr, "COINS_RUN_MAX", runCoinsEarned)
		end
		if extraStats.bossNoHit20 then MissionProgress.Add(plr, "BOSS_NO_HIT_20S", 1) end
		if extraStats.bossClutch then MissionProgress.Add(plr, "BOSS_CLUTCH", 1) end
		if extraStats.burst90 then MissionProgress.Add(plr, "BOSS_BURST_90", 1) end
		if extraStats.burst120 then MissionProgress.Add(plr, "BOSS_BURST_120", 1) end
		if extraStats.noRerollWin then MissionProgress.Add(plr, "NO_REROLL_WINS", 1) end
		if extraStats.max1RerollWin then MissionProgress.Add(plr, "MAX1_REROLL_WINS", 1) end
		if extraStats.max1SkipWin then MissionProgress.Add(plr, "MAX1_SKIP_WINS", 1) end
		if extraStats.hp50plusWin then MissionProgress.Add(plr, "HP50PLUS_WINS", 1) end
		if extraStats.winStreak3 then MissionProgress.Add(plr, "WIN_STREAK_3", 1) end
	end

	if diedThisRun == false then
		MissionProgress.Add(plr, "BOSSES", 1)
	end

	PlayerData.Save(plr, false)
end

return MissionProgress
