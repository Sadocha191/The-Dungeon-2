-- ProgressService.server.lua (Level1)
-- Fix:
-- - usuwa duplikaty/luźny kod (crash "attempt to index nil with UserId")
-- - run level start 0
-- - spelle losowane po level-up: tylko kupione u wiedźmy (UnlockedSpellsCSV)
-- - orby XP/coins: naliczanie odbywa się przez DropService -> _G.AwardPlayer (na pickup)
-- - pauza runa na czas wyboru spella (PauseState)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- === deps ===
local function findModule(name: string): ModuleScript?
	local roots = { ServerScriptService, ReplicatedStorage }
	for _, root in ipairs(roots) do
		local found = root:FindFirstChild(name, true)
		if found and found:IsA("ModuleScript") then
			return found
		end
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

-- Spell definitions (ReplicatedStorage/ModuleScripts/SpellDefinitions)
local SpellDefs = nil
do
	local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
	if modFolder and modFolder:IsA("Folder") then
		local s = modFolder:FindFirstChild("SpellDefinitions")
		if s and s:IsA("ModuleScript") then
			SpellDefs = safeRequire(s)
		end
	end
end

if not PlayerData then
	error("[ProgressService] Missing PlayerData")
end
if not SpellDefs or not SpellDefs.SPELLS then
	warn("[ProgressService] SpellDefinitions missing; spell rolls will be empty.")
end

-- === remotes ===
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

local Remotes = ensureFolder(ReplicatedStorage, "Remotes")
local PlayerProgressEvent = ensureRemoteEvent(Remotes, "PlayerProgressEvent")
local MissionSummaryEvent = ensureRemoteEvent(Remotes, "MissionSummaryEvent")
local SpellEvent = ensureRemoteEvent(Remotes, "SpellEvent")

-- PauseState used by WaveController
local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end

-- === run state ===
local run = {} -- [uid] = {startT, level, xp, nextXp, coins, kills, ended}
local pending = {} -- [uid] = {token, choices}

local function getRun(plr: Player)
	if not plr then return nil end
	local uid = plr.UserId
	local r = run[uid]
	if not r then
		r = { startT = time(), level = 0, xp = 0, nextXp = 25, coins = 0, kills = 0, ended = false }
		run[uid] = r
	end
	return r
end

local function rollNextRunXp(level: number): number
	return 25 + (level * 18)
end

local function syncHud(plr: Player)
	local r = getRun(plr)
	if not r then return end
	PlayerProgressEvent:FireClient(plr, {
		type = "progress",
		level = r.level,
		xp = r.xp,
		nextXp = r.nextXp,
		coins = r.coins,
	})
end

-- === spells ===
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

local function canOfferSpell(plr: Player, id: string): boolean
	if not SpellDefs or not SpellDefs.SPELLS then return false end
	local def = SpellDefs.SPELLS[id]
	if not def then return false end
	local lv = getSpellLevel(plr, id)
	local maxLv = tonumber(def.maxLevel) or 1
	return lv < maxLv
end

local function rollSpellChoices(plr: Player): {string}
	local unlocked = parseUnlocked(plr)
	local pool = {}
	for _, id in ipairs(unlocked) do
		if canOfferSpell(plr, id) then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then return {} end

	local choices, used = {}, {}
	while #choices < 3 and #choices < #pool do
		local id = pool[math.random(1, #pool)]
		if not used[id] then
			used[id] = true
			table.insert(choices, id)
		end
	end
	return choices
end

local function openSpellMenu(plr: Player)
	local choices = rollSpellChoices(plr)
	if #choices == 0 then return end

	local token = ("%d:%d:%d"):format(plr.UserId, math.floor(os.clock() * 1000), math.random(100000, 999999))
	pending[plr.UserId] = { token = token, choices = choices }

	PauseState.Value = true
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
	if not canOfferSpell(plr, id) then return end

	local lv = getSpellLevel(plr, id)
	plr:SetAttribute(("Spell_%s_Level"):format(id), lv + 1)

	pending[plr.UserId] = nil
	PauseState.Value = false
end)

-- === public: called by DropService on orb pickup ===
function _G.AwardPlayer(plr: Player, xp: number, coins: number)
	if not plr or not plr.Parent then return end
	local r = getRun(plr)
	if not r or r.ended then return end

	xp = math.max(0, math.floor(tonumber(xp) or 0))
	coins = math.max(0, math.floor(tonumber(coins) or 0))

	r.xp += xp
	r.coins += coins

	local leveled = false
	while r.xp >= r.nextXp do
		r.xp -= r.nextXp
		r.level += 1
		r.nextXp = rollNextRunXp(r.level)
		leveled = true
	end

	syncHud(plr)

	if leveled then
		openSpellMenu(plr)
	end
end

-- called by WaveController on kill
function _G.RegisterEnemyKill(_pos: Vector3?)
	for _, plr in ipairs(Players:GetPlayers()) do
		local r = getRun(plr)
		if r and not r.ended then
			r.kills += 1
		end
	end
end

-- === Game Over / End run ===
local TIME_RATE = 0.35
local KILL_RATE = 5

local function endRunForPlayer(plr: Player, reason: string)
	local r = getRun(plr)
	if not r or r.ended then return end
	r.ended = true

	PauseState.Value = false
	pending[plr.UserId] = nil

	local seconds = math.max(0, math.floor(time() - (r.startT or time())))
	local accountXp = math.max(0, math.floor(seconds * TIME_RATE + (r.kills or 0) * KILL_RATE))
	local coinsGained = math.max(0, math.floor(r.coins or 0))

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
	if r then
		r.startT = time()
		r.level = 0
		r.xp = 0
		r.nextXp = 25
		r.coins = 0
		r.kills = 0
		r.ended = false
	end

	-- reset run spell levels
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

print("[ProgressService] Ready (orb pickup + spells on level-up)")
