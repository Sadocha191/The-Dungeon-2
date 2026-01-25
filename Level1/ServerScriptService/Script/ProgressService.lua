-- ProgressService.server.lua (Level1)
-- v14:
-- - slower run leveling
-- - pauses RUN timer + wave spawns during spell choice (PauseState), but enemies keep moving (WaveController handles that)
-- - spell unlock/upgrade logic respects MAX_RUN_SPELLS (distinct spells)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function ensureFolder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then return f end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local r = parent:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then return r end
	r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = parent
	return r
end

local function findModule(name: string): ModuleScript?
	for _, root in ipairs({ServerScriptService, ReplicatedStorage}) do
		local found = root:FindFirstChild(name, true)
		if found and found:IsA("ModuleScript") then return found end
	end
	return nil
end

local function safeRequire(ms: ModuleScript?)
	if not ms then return nil end
	local ok, mod = pcall(require, ms)
	if ok then return mod end
	warn("[ProgressService] require failed:", ms:GetFullName(), mod)
	return nil
end

local PlayerData = safeRequire(findModule("PlayerData"))
local MissionProgress = safeRequire(findModule("MissionProgress"))

if not PlayerData then
	error("[ProgressService] Missing PlayerData module")
end

-- Spell defs
local SpellDefs
do
	local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
	if modFolder and modFolder:IsA("Folder") then
		local s = modFolder:FindFirstChild("SpellDefinitions")
		if s and s:IsA("ModuleScript") then
			SpellDefs = safeRequire(s)
		end
	end
end

-- Remotes
local Remotes = ensureFolder(ReplicatedStorage, "Remotes")
local PlayerProgressEvent = ensureRemoteEvent(Remotes, "PlayerProgressEvent")
local MissionSummaryEvent = ensureRemoteEvent(Remotes, "MissionSummaryEvent")
local SpellEvent = ensureRemoteEvent(Remotes, "SpellEvent")

-- PauseState (shared)
local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end

-- Run state
local run = {} -- [uid] = {startT, pausedTotal, pauseStart, runLevel, runXp, nextXp, runCoins, kills, ended}

local function rollNextRunXp(level: number): number
	-- wolniej niż wcześniej: szybkie pierwsze lvle, ale nie "co chwilę"
	-- L1: 70, L2: 105, L3: 140...
	return 70 + (level * 35)
end

local function getRun(plr: Player)
	local uid = plr.UserId
	local r = run[uid]
	if not r then
		r = {
			startT = time(),
			pausedTotal = 0,
			pauseStart = nil,
			runLevel = 0,
			runXp = 0,
			nextXp = rollNextRunXp(0),
			runCoins = 0,
			kills = 0,
			ended = false,
		}
		run[uid] = r
	end
	return r
end

local function runSeconds(plr: Player): number
	local r = getRun(plr)
	local t = time() - (r.startT or time())
	if r.pauseStart then
		t -= (time() - r.pauseStart)
	end
	t -= (r.pausedTotal or 0)
	return math.max(0, math.floor(t))
end

local function syncHud(plr: Player)
	local r = getRun(plr)
	-- HUD expects: type="progress" and fields level/xp/nextXp/coins
	PlayerProgressEvent:FireClient(plr, {
		type = "progress",
		level = r.runLevel,
		xp = r.runXp,
		nextXp = r.nextXp,
		coins = r.runCoins,
		kills = r.kills,
	})
end

local function parseUnlocked(plr: Player): {string}
	local csv = plr:GetAttribute("UnlockedSpellsCSV")
	if typeof(csv) ~= "string" or csv == "" then return {} end
	local out = {}
	for tok in string.gmatch(csv, "([^,]+)") do
		tok = string.gsub(tok, "^%s+", "")
		tok = string.gsub(tok, "%s+$", "")
		if tok ~= "" then table.insert(out, tok) end
	end
	return out
end

local function getSpellLevel(plr: Player, id: string): number
	return tonumber(plr:GetAttribute(("Spell_%s_Level"):format(id))) or 0
end

local function distinctOwnedCount(plr: Player): number
	if not SpellDefs or not SpellDefs.SPELLS then return 0 end
	local n = 0
	for id, _ in pairs(SpellDefs.SPELLS) do
		if getSpellLevel(plr, id) > 0 then n += 1 end
	end
	return n
end

local function canOffer(plr: Player, id: string): boolean
	if not SpellDefs or not SpellDefs.SPELLS then return false end
	local def = SpellDefs.SPELLS[id]
	if not def then return false end

	local lv = getSpellLevel(plr, id)
	local maxLv = tonumber(def.maxLevel) or 1
	if lv >= maxLv then return false end

	-- limit distinct spells (unlock only if slot available)
	local maxSpells = tonumber(SpellDefs.MAX_RUN_SPELLS) or 6
	if lv == 0 and distinctOwnedCount(plr) >= maxSpells then
		return false
	end

	return true
end

local pending = {} -- [uid] = {token, choices}

local function rollChoices(plr: Player): {string}
	local unlocked = parseUnlocked(plr)
	local pool = {}

	for _, id in ipairs(unlocked) do
		if canOffer(plr, id) then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then return {} end

	local choices = {}
	local used = {}
	while #choices < 3 and #choices < #pool do
		local id = pool[math.random(1, #pool)]
		if not used[id] then
			used[id] = true
			table.insert(choices, id)
		end
	end
	return choices
end

local function pauseBegin(plr: Player)
	local r = getRun(plr)
	if r.pauseStart then return end
	PauseState.Value = true
	r.pauseStart = time()
end

local function pauseEnd(plr: Player)
	local r = getRun(plr)
	if not r.pauseStart then return end
	r.pausedTotal += (time() - r.pauseStart)
	r.pauseStart = nil
	PauseState.Value = false
end

local function openSpellMenu(plr: Player)
	local choices = rollChoices(plr)
	if #choices == 0 then return end

	local token = ("%d:%d:%d"):format(plr.UserId, math.floor(os.clock()*1000), math.random(100000,999999))
	pending[plr.UserId] = { token = token, choices = choices }

	pauseBegin(plr)
	SpellEvent:FireClient(plr, { type = "offer", token = token, choices = choices })
end

SpellEvent.OnServerEvent:Connect(function(plr: Player, payload: any)
	if typeof(payload) ~= "table" or payload.type ~= "pick" then return end
	local p = pending[plr.UserId]
	if not p or payload.token ~= p.token then return end

	local id = tostring(payload.spellId or "")
	if id == "" then return end

	local ok = false
	for _, c in ipairs(p.choices) do
		if c == id then ok = true break end
	end
	if not ok then return end
	if not canOffer(plr, id) then return end

	local lv = getSpellLevel(plr, id)
	plr:SetAttribute(("Spell_%s_Level"):format(id), lv + 1)

	pending[plr.UserId] = nil
	pauseEnd(plr)
end)

-- Public API for orbs (DropService calls _G.AwardPlayer)
function _G.AwardPlayer(plr: Player, xp: number, coins: number)
	if not plr or not plr.Parent then return end
	local r = getRun(plr)
	if r.ended then return end

	xp = math.max(0, math.floor(tonumber(xp) or 0))
	coins = math.max(0, math.floor(tonumber(coins) or 0))

	r.runXp += xp
	r.runCoins += coins

	local leveled = false
	while r.runXp >= r.nextXp do
		r.runXp -= r.nextXp
		r.runLevel += 1
		r.nextXp = rollNextRunXp(r.runLevel)
		leveled = true
	end

	syncHud(plr)

	if leveled then
		openSpellMenu(plr)
	end
end

function _G.RegisterEnemyKill(_pos: Vector3?)
	for _, plr in ipairs(Players:GetPlayers()) do
		local r = getRun(plr)
		if not r.ended then
			r.kills += 1
			syncHud(plr)
		end
	end
end

-- GameOver / account XP (as before)
local TIME_RATE = 0.35
local KILL_RATE = 5

local function endRunForPlayer(plr: Player, reason: string)
	local r = getRun(plr)
	if r.ended then return end
	r.ended = true

	-- ensure unpause accounting
	pauseEnd(plr)

	local seconds = runSeconds(plr)
	local accountXp = math.max(0, math.floor(seconds * TIME_RATE + (r.kills or 0) * KILL_RATE))
	local coinsGained = math.max(0, math.floor(r.runCoins or 0))

	local d = PlayerData.Get(plr)
	d.xp = (tonumber(d.xp) or 0) + accountXp
	d.coins = (tonumber(d.coins) or 0) + coinsGained

	if tonumber(d.level) and tonumber(d.nextXp) and PlayerData.RollNextXp then
		while d.xp >= d.nextXp do
			d.xp -= d.nextXp
			d.level += 1
			d.nextXp = PlayerData.RollNextXp(d.level)
		end
	end

	if PlayerData.MarkDirty then PlayerData.MarkDirty(plr) end
	if PlayerData.Save then pcall(function() PlayerData.Save(plr, true) end) end

	MissionSummaryEvent:FireClient(plr, {
		type = "gameover",
		reason = reason,
		time = seconds,
		kills = r.kills or 0,
		coinsGained = coinsGained,
		accountXp = accountXp,
		accountLevel = tonumber(d.level) or 1,
	})
	if MissionProgress and MissionProgress.OnRunComplete then
		pcall(function() MissionProgress.OnRunComplete(plr, 0, seconds, true) end)
	end
end

_G.EndRunForPlayer = endRunForPlayer

Players.PlayerAdded:Connect(function(plr: Player)
	run[plr.UserId] = nil
	pending[plr.UserId] = nil

	local r = getRun(plr)
	r.startT = time()
	r.pausedTotal = 0
	r.pauseStart = nil
	r.runLevel = 0
	r.runXp = 0
	r.nextXp = rollNextRunXp(0)
	r.runCoins = 0
	r.kills = 0
	r.ended = false

	-- reset spell levels for this run (only known defs)
	if SpellDefs and SpellDefs.SPELLS then
		for id, _ in pairs(SpellDefs.SPELLS) do
			plr:SetAttribute(("Spell_%s_Level"):format(id), 0)
		end
	end

	syncHud(plr)
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	run[plr.UserId] = nil
	pending[plr.UserId] = nil
end)

print("[ProgressService] Ready (v14)")
