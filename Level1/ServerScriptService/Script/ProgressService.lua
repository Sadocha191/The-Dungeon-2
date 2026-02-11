-- ProgressService.server.lua (Level1)
-- v15:
-- - weighted rarity offers (Common/Uncommon/Rare/Epic)
-- - duplicates allowed
-- - skip/reroll/banish supported
-- - pauses run during choice (PauseState)

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
local run = {} -- [uid] = {startT, pausedTotal, pauseStart, runLevel, runXp, nextXp, runCoins, kills, ended, banished}
local pending = {} -- [uid] = {token, offers}

-- Party shared progression (Multi)
local party = {} -- [partyId] = {level, xp, nextXp, pendingLevelUps, inLevelUp, waitingFor = {[uid]=true}}

local function getPartyId(plr: Player): string?
	local pid = plr:GetAttribute("PartyId")
	if typeof(pid) == "string" and pid ~= "" then
		return pid
	end
	return nil
end

local function isMulti(plr: Player): boolean
	return plr:GetAttribute("RunMode") == "Multi"
end

local function getPartyState(partyId: string)
	local p = party[partyId]
	if p then return p end
	p = {
		level = 1,
		xp = 0,
		nextXp = rollNextRunXp(1),
		pendingLevelUps = 0,
		inLevelUp = false,
		waitingFor = {},
	}
	party[partyId] = p
	return p
end

local function getPartyPlayers(partyId: string): {Player}
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("RunMode") == "Multi" and plr:GetAttribute("PartyId") == partyId then
			local r = getRun(plr)
			if not r.ended then
				table.insert(list, plr)
			end
		end
	end
	return list
end

local function syncPartyHud(partyId: string)
	local p = party[partyId]
	if not p then return end
	for _, plr in ipairs(getPartyPlayers(partyId)) do
		local r = getRun(plr)
		r.runLevel = p.level
		r.runXp = p.xp
		r.nextXp = p.nextXp
		syncHud(plr)
	end
end


local openSpellMenu -- forward declaration

local function startPartyLevelUp(partyId: string)
	local p = getPartyState(partyId)
	if p.inLevelUp then return end

	local members = getPartyPlayers(partyId)
	if #members == 0 then return end

	p.inLevelUp = true
	p.waitingFor = {}

	-- pause globally
	PauseState.Value = true
	local now = time()
	for _, member in ipairs(members) do
		local r = getRun(member)
		if not r.pauseStart then
			r.pauseStart = now
		end
		p.waitingFor[member.UserId] = true
		openSpellMenu(member)
	end
end

local function rollNextRunXp(level: number): number
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
			banished = {}, -- [spellId]=true
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

	local r = getRun(plr)
	if r.banished and r.banished[id] then
		return false
	end

	local lv = getSpellLevel(plr, id)
	local maxLv = tonumber(def.maxLevel) or 1
	if lv >= maxLv then return false end

	local maxSpells = tonumber(SpellDefs.MAX_RUN_SPELLS) or 6
	if lv == 0 and distinctOwnedCount(plr) >= maxSpells then
		return false
	end

	return true
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


local function finishUpgrade(plr: Player)
	-- Single: normal unpause per player
	if not isMulti(plr) then
		pauseEnd(plr)
		return
	end

	local pid = getPartyId(plr)
	if not pid then
		pauseEnd(plr)
		return
	end

	local p = getPartyState(pid)
	p.waitingFor[plr.UserId] = nil

	-- If everyone picked, unpause globally and handle queued level-ups
	if next(p.waitingFor) == nil then
		local now = time()
		for _, member in ipairs(getPartyPlayers(pid)) do
			local r = getRun(member)
			if r.pauseStart then
				r.pausedTotal += (now - r.pauseStart)
				r.pauseStart = nil
			end
		end
		PauseState.Value = false

		if p.pendingLevelUps > 0 then
			p.pendingLevelUps -= 1
		end
		p.inLevelUp = false

		if p.pendingLevelUps > 0 then
			startPartyLevelUp(pid)
		end
	end
end


-- rarity rolling
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic" }

local function rollRarity(weights: table): string
	local r = math.random()
	local acc = 0
	for _, key in ipairs(RARITY_ORDER) do
		acc += (weights[key] or 0)
		if r <= acc then return key end
	end
	return "Common"
end

local function buildPoolsByRarity(plr: Player)
	local unlocked = parseUnlocked(plr)
	local pools = { Common = {}, Uncommon = {}, Rare = {}, Epic = {} }

	for _, id in ipairs(unlocked) do
		if canOffer(plr, id) then
			local def = SpellDefs.SPELLS[id]
			local rarity = (def and def.rarity) or "Common"
			if not pools[rarity] then rarity = "Common" end
			table.insert(pools[rarity], id)
		end
	end

	return pools
end

local function rollOffers(plr: Player)
	if not SpellDefs or not SpellDefs.SPELLS then return {} end

	local pools = buildPoolsByRarity(plr)
	local weights = SpellDefs.RARITY_WEIGHTS or { Common=1, Uncommon=0, Rare=0, Epic=0 }

	local offers = {}

	for _ = 1, 3 do
		local pickedId, pickedRarity

		-- retry: wylosuj rarity, ale tylko jeśli w tej puli coś jest
		for attempt = 1, 25 do
			local rarity = rollRarity(weights)
			local pool = pools[rarity]
			if pool and #pool > 0 then
				pickedId = pool[math.random(1, #pool)]
				pickedRarity = rarity
				break
			end
		end

		-- fallback: dowolna niepusta pula
		if not pickedId then
			for _, rarity in ipairs(RARITY_ORDER) do
				local pool = pools[rarity]
				if pool and #pool > 0 then
					pickedId = pool[math.random(1, #pool)]
					pickedRarity = rarity
					break
				end
			end
		end

		if pickedId then
			table.insert(offers, { spellId = pickedId, rarity = pickedRarity or "Common" })
		end
	end

	return offers
end

openSpellMenu = function(plr: Player)
	local offers = rollOffers(plr)
	if #offers == 0 then return end

	local token = ("%d:%d:%d"):format(plr.UserId, math.floor(os.clock()*1000), math.random(100000,999999))
	pending[plr.UserId] = { token = token, offers = offers }

	if not isMulti(plr) then
		pauseBegin(plr)
	end
	SpellEvent:FireClient(plr, { type = "offer", token = token, offers = offers })
end

local function newToken(plr: Player): string
	return ("%d:%d:%d"):format(plr.UserId, math.floor(os.clock()*1000), math.random(100000,999999))
end

SpellEvent.OnServerEvent:Connect(function(plr: Player, payload: any)
	if typeof(payload) ~= "table" then return end
	local p = pending[plr.UserId]
	if not p or payload.token ~= p.token then return end

	local t = tostring(payload.type or "")

	-- helper: sprawdź czy spell był w aktualnych ofertach (walidacja)
	local function offered(spellId: string): boolean
		for _, off in ipairs(p.offers or {}) do
			if off.spellId == spellId then
				return true
			end
		end
		return false
	end

	if t == "pick" then
		local id = tostring(payload.spellId or "")
		if id == "" then return end
		if not offered(id) then return end
		if not canOffer(plr, id) then return end

		local lv = getSpellLevel(plr, id)
		plr:SetAttribute(("Spell_%s_Level"):format(id), lv + 1)

		pending[plr.UserId] = nil
		finishUpgrade(plr)
		return
	end

	if t == "skip" then
		pending[plr.UserId] = nil
		finishUpgrade(plr)
		return
	end

	if t == "reroll" then
		local offers = rollOffers(plr)
		if #offers == 0 then return end

		local token = newToken(plr)
		pending[plr.UserId] = { token = token, offers = offers }
		SpellEvent:FireClient(plr, { type="offer", token=token, offers=offers })
		return
	end

	if t == "banish" then
		local id = tostring(payload.spellId or "")
		if id == "" then return end
		if not offered(id) then return end

		local r = getRun(plr)
		r.banished[id] = true

		local offers = rollOffers(plr)
		if #offers == 0 then
			-- jeśli po banishu nie ma już nic do oferowania, po prostu zamknij
			pending[plr.UserId] = nil
			pauseEnd(plr)
			return
		end

		local token = newToken(plr)
		pending[plr.UserId] = { token = token, offers = offers }
		SpellEvent:FireClient(plr, { type="offer", token=token, offers=offers })
		return
	end
end)

-- Public API for orbs (DropService calls _G.AwardPlayer)
function _G.AwardPlayer(plr: Player, xp: number, coins: number)
	if not plr or not plr.Parent then return end

	xp = math.max(0, math.floor(tonumber(xp) or 0))
	coins = math.max(0, math.floor(tonumber(coins) or 0))

	-- Multiplayer: shared party XP/Level
	if isMulti(plr) then
		local pid = getPartyId(plr)
		if not pid then return end

		local p = getPartyState(pid)

		-- coins nadal per gracz (jak było)
		local r = getRun(plr)
		if r.ended then return end
		r.runCoins += coins

		p.xp += xp

		-- queue level-ups
		local leveledCount = 0
		while p.xp >= p.nextXp do
			p.xp -= p.nextXp
			p.level += 1
			p.nextXp = rollNextRunXp(p.level)
			leveledCount += 1
		end

		if leveledCount > 0 then
			p.pendingLevelUps += leveledCount
			-- start only if not already in level-up flow
			if not p.inLevelUp then
				startPartyLevelUp(pid)
			end
		end

		syncPartyHud(pid)
		return
	end

	-- Single: original behavior (per player)
	local r = getRun(plr)
	if r.ended then return end

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

-- GameOver / account XP
local TIME_RATE = 0.35
local KILL_RATE = 5

local function endRunForPlayer(plr: Player, reason: string)
	local r = getRun(plr)
	if r.ended then return end
	r.ended = true
	plr:SetAttribute("RunEnded", true)

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
	plr:SetAttribute("RunEnded", false)

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
	r.banished = {}

	-- reset spell levels for this run
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

print("[ProgressService] Ready (v15)")
