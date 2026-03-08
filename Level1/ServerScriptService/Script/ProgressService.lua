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
local run = {} -- [uid] = {startT, pausedTotal, pauseStart, runLevel, runXp, nextXp, runSilver, kills, ended, banished, pendingLevelUps}
local pending = {} -- [uid] = {token, offers}

-- extra per-run stats used by missions
-- fields per run (best-effort):
-- startClock, rerollsUsed, skipsUsed, minHpRatio, lastDamageClock, maxNoDamageStreak,
-- lowHpSeconds, damageTaken, healAmount, bossNoHit20Failed, killTimes,
-- multikill30_5Done, multikill60_20Done


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
	local v = plr:GetAttribute("RunMode")
	if typeof(v) ~= "string" then return false end
	v = string.lower(v)
	return v == "multi"
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
		if openSpellMenu(member) then
			p.waitingFor[member.UserId] = true
		end
	end

	if next(p.waitingFor) == nil then
		for _, member in ipairs(members) do
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
			startPartyLevelUp(partyId)
		end
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
			startClock = os.clock(),
			pausedTotal = 0,
			pauseStart = nil,
			runLevel = 0,
			runXp = 0,
			nextXp = rollNextRunXp(0),
			runSilver = 0,
			kills = 0,
			rerollsUsed = 0,
			skipsUsed = 0,
			minHpRatio = 1,
			lastDamageClock = nil,
			maxNoDamageStreak = 0,
			lowHpSeconds = 0,
			damageTaken = 0,
			healAmount = 0,
			bossNoHit20Failed = false,
			killTimes = {},
			multikill30_5Done = false,
			multikill60_20Done = false,
			ended = false,
			banished = {}, -- [spellId]=true
			pendingLevelUps = 0,
		}
		run[uid] = r
	end
	return r
end

local function hookHealthForMissions(plr: Player)
	local function attach(char: Model)
		local r = getRun(plr)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local lastHealth = hum.Health
		r.minHpRatio = 1
		plr:SetAttribute("LastDamageClock", 0)

		hum.HealthChanged:Connect(function(newHealth)
			local now = os.clock()
			local maxH = hum.MaxHealth > 0 and hum.MaxHealth or 1
			local ratio = newHealth / maxH
			if ratio < (r.minHpRatio or 1) then
				r.minHpRatio = ratio
			end

			local delta = newHealth - lastHealth
			if delta < 0 then
				local dmg = math.floor(-delta)
				r.damageTaken = (r.damageTaken or 0) + dmg
				plr:SetAttribute("LastDamageClock", now)

				local streakStart = r.lastDamageClock or (r.startClock or now)
				r.maxNoDamageStreak = math.max(r.maxNoDamageStreak or 0, now - streakStart)
				r.lastDamageClock = now

				-- boss no-hit window (first 20s after 20:00)
				local bossSpawnClock = (r.startClock or now) + 1200
				if now >= bossSpawnClock and now <= bossSpawnClock + 20 then
					r.bossNoHit20Failed = true
				end
			elseif delta > 0 then
				r.healAmount = (r.healAmount or 0) + math.floor(delta)
			end

			lastHealth = newHealth
		end)

		-- low HP sampling (4Hz)
		task.spawn(function()
			while char.Parent and hum.Parent and hum.Health > 0 do
				local rr = getRun(plr)
				if rr.ended then break end
				if PauseState.Value then
					task.wait(0.25)
					continue
				end
				local maxH = hum.MaxHealth > 0 and hum.MaxHealth or 1
				if (hum.Health / maxH) < 0.30 then
					rr.lowHpSeconds = (rr.lowHpSeconds or 0) + 0.25
				end
				task.wait(0.25)
			end
		end)
	end

	if plr.Character then attach(plr.Character) end
	plr.CharacterAdded:Connect(attach)
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
	local d = PlayerData.Get(plr)
	PlayerProgressEvent:FireClient(plr, {
		type = "progress",
		level = r.runLevel,
		xp = r.runXp,
		nextXp = r.nextXp,
		coins = r.runSilver,
		kills = r.kills,
		souls = (d and tonumber(d.souls)) or 0,
	})
end


PlayerProgressEvent.OnServerEvent:Connect(function(plr: Player, payload: any)
	if not plr or not plr.Parent then
		return
	end

	if payload == nil then
		syncHud(plr)
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	local t = tostring(payload.type or "")
	if t == "requestSync" or t == "request" or t == "sync" then
		syncHud(plr)
	end
end)
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
		local r = getRun(plr)
		if r.pendingLevelUps > 0 then
			r.pendingLevelUps -= 1
		end
		if r.pendingLevelUps > 0 then
			openSpellMenu(plr)
		else
			pauseEnd(plr)
		end
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
	local picked = {}

	for _ = 1, 3 do
		local pickedId, pickedRarity

		-- retry: wylosuj rarity, ale tylko jeśli w tej puli jest jeszcze unikalny spell
		for attempt = 1, 25 do
			local rarity = rollRarity(weights)
			local pool = pools[rarity]
			if pool and #pool > 0 then
				for _ = 1, 10 do
					local candidate = pool[math.random(1, #pool)]
					if candidate and not picked[candidate] then
						pickedId = candidate
						pickedRarity = rarity
						break
					end
				end
				if pickedId then break end
			end
		end

		-- fallback: dowolna niepusta pula z jeszcze nieużytym spell'em
		if not pickedId then
			for _, rarity in ipairs(RARITY_ORDER) do
				local pool = pools[rarity]
				if pool and #pool > 0 then
					for _, candidate in ipairs(pool) do
						if candidate and not picked[candidate] then
							pickedId = candidate
							pickedRarity = rarity
							break
						end
					end
					if pickedId then break end
				end
			end
		end

		if pickedId then
			picked[pickedId] = true
			table.insert(offers, { spellId = pickedId, rarity = pickedRarity or "Common" })
		end
	end

	return offers
end

openSpellMenu = function(plr: Player)
	local offers = rollOffers(plr)
	if #offers == 0 then
		if not isMulti(plr) then
			local r = getRun(plr)
			r.pendingLevelUps = 0
			pending[plr.UserId] = nil
			pauseEnd(plr)
		end
		return false
	end

	local token = ("%d:%d:%d"):format(plr.UserId, math.floor(os.clock()*1000), math.random(100000,999999))
	pending[plr.UserId] = { token = token, offers = offers }

	if not isMulti(plr) then
		pauseBegin(plr)
	end
	SpellEvent:FireClient(plr, { type = "offer", token = token, offers = offers })
	return true
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

		-- Missions: count picked upgrades
		if MissionProgress and MissionProgress.Add then
			pcall(function() MissionProgress.Add(plr, "UPGRADES_CHOSEN", 1) end)
		end

		pending[plr.UserId] = nil
		finishUpgrade(plr)
		return
	end

	if t == "skip" then
		local r = getRun(plr)
		r.skipsUsed = (r.skipsUsed or 0) + 1
		if MissionProgress and MissionProgress.Add then
			pcall(function() MissionProgress.Add(plr, "SKIPS_USED", 1) end)
		end
		pending[plr.UserId] = nil
		finishUpgrade(plr)
		return
	end

	if t == "reroll" then
		local r = getRun(plr)
		if (r.rerollsUsed or 0) >= 1 then
			return
		end
		r.rerollsUsed = (r.rerollsUsed or 0) + 1
		plr:SetAttribute("RunRerollsUsed", r.rerollsUsed)
		if MissionProgress and MissionProgress.Add then
			pcall(function() MissionProgress.Add(plr, "REROLLS_USED", 1) end)
		end
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
			finishUpgrade(plr)
			return
		end

		local token = newToken(plr)
		pending[plr.UserId] = { token = token, offers = offers }
		SpellEvent:FireClient(plr, { type="offer", token=token, offers=offers })
		return
	end
end)


-- === Run stat growth (per level) ===
local STAT_HP_PER_LEVEL = 8
local STAT_SPEED_PER_LEVEL = 0.35
local STAT_ATK_PCT_PER_LEVEL = 0.04 -- 4% per level (applies to weapon base ATK & spells where supported)

local function applyRunStatsNow(plr: Player)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local baseHp = tonumber(plr:GetAttribute("BaseMaxHP")) or 100
	local baseSpd = tonumber(plr:GetAttribute("BaseWalkSpeed")) or 16

	local bonusHp = tonumber(plr:GetAttribute("RunBonusHP")) or 0
	local bonusSpd = tonumber(plr:GetAttribute("RunBonusSpeed")) or 0

	hum.MaxHealth = baseHp + bonusHp
	if hum.Health > hum.MaxHealth then hum.Health = hum.MaxHealth end
	hum.WalkSpeed = baseSpd + bonusSpd

	-- scale equipped weapon ATK (best-effort, no breaking if templates ignore it)
	local atkMult = tonumber(plr:GetAttribute("RunAtkMult")) or 1
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local unscaledBase = tool:GetAttribute("BaseATK_Unscaled")
			local unscaledPer = tool:GetAttribute("ATKPerLevel_Unscaled")
			if not unscaledBase then
				unscaledBase = tool:GetAttribute("BaseATK")
				if typeof(unscaledBase) == "number" then
					tool:SetAttribute("BaseATK_Unscaled", unscaledBase)
				end
			end
			if not unscaledPer then
				unscaledPer = tool:GetAttribute("ATKPerLevel")
				if typeof(unscaledPer) == "number" then
					tool:SetAttribute("ATKPerLevel_Unscaled", unscaledPer)
				end
			end
			if typeof(unscaledBase) == "number" then
				tool:SetAttribute("BaseATK", unscaledBase * atkMult)
			end
			if typeof(unscaledPer) == "number" then
				tool:SetAttribute("ATKPerLevel", unscaledPer * atkMult)
			end
		end
	end
end

local function grantLevelStatGains(plr: Player, levelsGained: number)
	if levelsGained <= 0 then return end
	local bonusHp = tonumber(plr:GetAttribute("RunBonusHP")) or 0
	local bonusSpd = tonumber(plr:GetAttribute("RunBonusSpeed")) or 0
	local atkMult = tonumber(plr:GetAttribute("RunAtkMult")) or 1

	bonusHp += STAT_HP_PER_LEVEL * levelsGained
	bonusSpd += STAT_SPEED_PER_LEVEL * levelsGained
	atkMult *= (1 + STAT_ATK_PCT_PER_LEVEL) ^ levelsGained

	plr:SetAttribute("RunBonusHP", bonusHp)
	plr:SetAttribute("RunBonusSpeed", bonusSpd)
	plr:SetAttribute("RunAtkMult", atkMult)

	applyRunStatsNow(plr)
end

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
		r.runSilver += coins

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
			-- apply stat gains to all party members (server-side)
			for _, member in ipairs(getPartyPlayers(pid)) do
				grantLevelStatGains(member, leveledCount)
			end
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
	r.runSilver += coins

	local leveledCount = 0
	while r.runXp >= r.nextXp do
		r.runXp -= r.nextXp
		r.runLevel += 1
		grantLevelStatGains(plr, 1)
		r.nextXp = rollNextRunXp(r.runLevel)
		leveledCount += 1
	end

	syncHud(plr)

	if leveledCount > 0 then
		r.pendingLevelUps = math.max(0, tonumber(r.pendingLevelUps) or 0) + leveledCount
		if not pending[plr.UserId] then
			openSpellMenu(plr)
		end
	end
end


function _G.GetRunCoins(plr: Player): number
	if not plr or not plr.Parent then return 0 end
	local r = getRun(plr)
	return math.max(0, math.floor(tonumber(r.runSilver) or 0))
end

function _G.TrySpendRunCoins(plr: Player, coins: number): boolean
	if not plr or not plr.Parent then return false end
	coins = math.max(0, math.floor(tonumber(coins) or 0))
	if coins <= 0 then return true end

	local r = getRun(plr)
	if r.ended then return false end
	if r.runSilver < coins then
		syncHud(plr)
		return false
	end

	r.runSilver -= coins
	syncHud(plr)
	return true
end
-- Public API for soul orbs (DropService calls _G.AwardSouls)
function _G.AwardSouls(plr: Player, souls: number)
	if not plr or not plr.Parent then return end
	souls = math.max(0, math.floor(tonumber(souls) or 0))
	if souls <= 0 then return end

	local d = PlayerData.Get(plr)
	d.souls = (tonumber(d.souls) or 0) + souls
	if PlayerData.MarkDirty then PlayerData.MarkDirty(plr) end

	-- don't spam hard saves for every orb; just sync HUD
	syncHud(plr)
end

function _G.RegisterEnemyKill(_pos: Vector3?)
	for _, plr in ipairs(Players:GetPlayers()) do
		local r = getRun(plr)
		if not r.ended then
			r.kills += 1
			-- multikill windows (shared kills in current design)
			local now = os.clock()
			r.killTimes = r.killTimes or {}
			table.insert(r.killTimes, now)
			-- prune older than 20s
			local kt = r.killTimes
			local j = 1
			for i = 1, #kt do
				if now - kt[i] <= 20 then
					kt[j] = kt[i]
					j += 1
				end
			end
			for i = j, #kt do kt[i] = nil end

			-- 30 kills / 5s
			if not r.multikill30_5Done then
				local c5 = 0
				for i = #kt, 1, -1 do
					if now - kt[i] <= 5 then c5 += 1 else break end
				end
				if c5 >= 30 then
					r.multikill30_5Done = true
				end
			end
			-- 60 kills / 20s
			if not r.multikill60_20Done and #kt >= 60 then
				r.multikill60_20Done = true
			end
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
	-- Gold coins are run-only. Convert to lobby silver at 1/3.
	local goldSilver = math.max(0, math.floor(r.runSilver or 0))
	local coinsGained = math.max(0, math.floor(goldSilver / 3))

	local d = PlayerData.Get(plr)
	d.xp = (tonumber(d.xp) or 0) + accountXp
	-- PlayerData.coins is now SILVER
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
		coinsGained = coinsGained, -- silver gained
		goldEarned = goldSilver,
		accountXp = accountXp,
		accountLevel = tonumber(d.level) or 1,
	})
	if MissionProgress and MissionProgress.OnRunComplete then
		local diedThisRun = (reason ~= "Victory")
		-- finalize no-damage streak
		local nowClock = os.clock()
		local streakStart = r.lastDamageClock or (r.startClock or nowClock)
		r.maxNoDamageStreak = math.max(r.maxNoDamageStreak or 0, nowClock - streakStart)

		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		local maxH = (hum and hum.MaxHealth > 0) and hum.MaxHealth or 1
		local hpRatio = (hum and hum.Health or 0) / maxH

		-- count spells active (>= 3 different spells leveled)
		local spellsCount = 0
		if SpellDefs and SpellDefs.SPELLS then
			for id, _ in pairs(SpellDefs.SPELLS) do
				local lv = tonumber(plr:GetAttribute(("Spell_%s_Level"):format(id))) or 0
				if lv > 0 then spellsCount += 1 end
			end
		end

		-- win streak (simple server memory per session)
		r.winStreak = r.winStreak or 0
		if diedThisRun then
			r.winStreak = 0
		else
			r.winStreak += 1
		end

		local extra = {
			coinsGained = coinsGained,
			runLevel = r.runLevel or 0,
			rerollsUsed = r.rerollsUsed or 0,
			skipsUsed = r.skipsUsed or 0,
			damageTaken = r.damageTaken or 0,
			healAmount = r.healAmount or 0,
			lowHpSeconds = r.lowHpSeconds or 0,
			minHpRatio = r.minHpRatio or 1,
			multikill30_5 = r.multikill30_5Done == true,
			multikill60_20 = r.multikill60_20Done == true,
			noDamage5min = (r.maxNoDamageStreak or 0) >= 300,
			bossNoHit20 = (not diedThisRun) and seconds >= 1200 and (r.bossNoHit20Failed ~= true),
			bossClutch = (not diedThisRun) and hpRatio < 0.30,
			burst90 = (not diedThisRun) and seconds >= 1200 and seconds <= 1290,
			burst120 = (not diedThisRun) and seconds >= 1200 and seconds <= 1320,
			noRerollWin = (not diedThisRun) and (r.rerollsUsed or 0) == 0,
			max1RerollWin = (not diedThisRun) and (r.rerollsUsed or 0) <= 1,
			max1SkipWin = (not diedThisRun) and (r.skipsUsed or 0) <= 1,
			level10 = (r.runLevel or 0) >= 10,
			spells3 = spellsCount >= 3,
			hp50plusWin = (not diedThisRun) and (r.minHpRatio or 1) >= 0.50,
			winStreak3 = (r.winStreak or 0) >= 3,
		}

		pcall(function() MissionProgress.OnRunComplete(plr, 0, seconds, diedThisRun, extra) end)
		pcall(function() MissionProgress.OnReward(plr, accountXp, coinsGained) end)
	end
end

_G.EndRunForPlayer = endRunForPlayer

Players.PlayerAdded:Connect(function(plr: Player)
	run[plr.UserId] = nil
	pending[plr.UserId] = nil
	plr:SetAttribute("RunEnded", false)
	hookHealthForMissions(plr)

	local r = getRun(plr)
	r.startT = time()
	r.startClock = os.clock()
	r.pausedTotal = 0
	r.pauseStart = nil
	r.runLevel = 0
	r.runXp = 0
	r.nextXp = rollNextRunXp(0)
	r.runSilver = 0
	r.kills = 0
	r.rerollsUsed = 0
	r.skipsUsed = 0
	r.minHpRatio = 1
	r.lastDamageClock = nil
	r.maxNoDamageStreak = 0
	r.lowHpSeconds = 0
	r.damageTaken = 0
	r.healAmount = 0
	r.bossNoHit20Failed = false
	r.killTimes = {}
	r.multikill30_5Done = false
	r.multikill60_20Done = false
	r.ended = false
	r.banished = {}
	r.pendingLevelUps = 0
	plr:SetAttribute("RunRerollsUsed", 0)

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

