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
local PauseMenuEvent = ensureRemoteEvent(Remotes, "PauseMenuEvent")

-- PauseState (shared)
local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end
local RunStarted = ReplicatedStorage:FindFirstChild("RunStarted")
if not RunStarted then
	RunStarted = Instance.new("BoolValue")
	RunStarted.Name = "RunStarted"
	RunStarted.Value = false
	RunStarted.Parent = ReplicatedStorage
end

-- Run state
local run = {} -- [uid] = {startT, pausedTotal, pauseStart, runLevel, runXp, nextXp, runSilver, coinsEarned, kills, ended, banished, pendingLevelUps}
local pending = {} -- [uid] = {token, offers}

-- extra per-run stats used by missions
-- fields per run (best-effort):
-- startClock, rerollsUsed, skipsUsed, minHpRatio, lastDamageClock, maxNoDamageStreak,
-- lowHpSeconds, damageTaken, healAmount, bossNoHit20Failed, killTimes,
-- multikill30_5Done, multikill60_20Done


-- Party shared progression (Multi)
local party = {} -- [partyId] = {level, xp, nextXp, pendingLevelUps, inLevelUp, waitingFor = {[uid]=true}}
local manualPauseUsers = {} -- [uid] = true while a player has pause UI open

local function hasActiveRunPlayers(): boolean
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.Parent and candidate:GetAttribute("RunEnded") ~= true then
			return true
		end
	end

	return false
end

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

local function recomputePauseState()
	for _ in pairs(manualPauseUsers) do
		PauseState.Value = true
		return
	end

	for _, r in pairs(run) do
		if r.pauseStart then
			PauseState.Value = true
			return
		end
	end

	PauseState.Value = false
end


local openSpellMenu -- forward declaration

local function startPartyLevelUp(partyId: string)
	local p = getPartyState(partyId)
	if p.inLevelUp then return end

	local members = getPartyPlayers(partyId)
	if #members == 0 then return end

	p.inLevelUp = true
	p.waitingFor = {}

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
	recomputePauseState()

	if next(p.waitingFor) == nil then
		for _, member in ipairs(members) do
			local r = getRun(member)
			if r.pauseStart then
				r.pausedTotal += (now - r.pauseStart)
				r.pauseStart = nil
			end
		end
		recomputePauseState()
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
	level = math.max(0, math.floor(tonumber(level) or 0))
	return 90 + (level * 48) + math.floor((level * level) * 3)
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
			coinsEarned = 0,
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
			bossSpawnClock = nil,
			bossSpawnRunSeconds = nil,
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

				local bossSpawnClock = tonumber(r.bossSpawnClock)
				if bossSpawnClock and now >= bossSpawnClock and now <= bossSpawnClock + 20 then
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

local function runSecondsPrecise(plr: Player): number
	local r = getRun(plr)
	local t = time() - (r.startT or time())
	if r.pauseStart then
		t -= (time() - r.pauseStart)
	end
	t -= (r.pausedTotal or 0)
	return math.max(0, t)
end

local function runSeconds(plr: Player): number
	return math.floor(runSecondsPrecise(plr))
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

local function getSpellUpgradePower(plr: Player, id: string): number
	return tonumber(plr:GetAttribute(("Spell_%s_UpgradePower"):format(id))) or 0
end

local function getSpellBaseMultiplier(plr: Player, id: string): number
	return tonumber(plr:GetAttribute(("Spell_%s_BaseMultiplier"):format(id))) or 0
end

local function getSpellBasePower(plr: Player, id: string): number
	return tonumber(plr:GetAttribute(("Spell_%s_BasePower"):format(id))) or 0
end

local function setSpellState(plr: Player, id: string, level: number, upgradePower: number, baseMultiplier: number, basePower: number)
	plr:SetAttribute(("Spell_%s_Level"):format(id), level)
	plr:SetAttribute(("Spell_%s_UpgradePower"):format(id), upgradePower)
	plr:SetAttribute(("Spell_%s_BaseMultiplier"):format(id), baseMultiplier)
	plr:SetAttribute(("Spell_%s_BasePower"):format(id), basePower)
end

local function clearSpellState(plr: Player, id: string)
	setSpellState(plr, id, 0, 0, 0, 0)
end

local function buildActiveSet(plr: Player): {[string]: boolean}
	local active = {}
	if not SpellDefs or not SpellDefs.SPELLS then
		return active
	end
	for id in pairs(SpellDefs.SPELLS) do
		if getSpellLevel(plr, id) > 0 then
			active[id] = true
		end
	end
	return active
end

local function countOwnedByType(plr: Player, spellType: string): number
	if not SpellDefs or not SpellDefs.SPELLS then
		return 0
	end
	local count = 0
	for id, def in pairs(SpellDefs.SPELLS) do
		if def.spellType == spellType and getSpellLevel(plr, id) > 0 then
			count += 1
		end
	end
	return count
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

	local activeSet = buildActiveSet(plr)
	if lv == 0 and SpellDefs.IsIngredientBlockedByCombo and SpellDefs.IsIngredientBlockedByCombo(id, activeSet) then
		return false
	end

	if lv == 0 and countOwnedByType(plr, def.spellType or "Magic") >= (SpellDefs.GetTypeLimit and SpellDefs.GetTypeLimit(def.spellType) or SpellDefs.MAX_RUN_SPELLS or 10) then
		return false
	end

	return true
end

local function pauseBegin(plr: Player)
	local r = getRun(plr)
	if r.pauseStart then return end
	r.pauseStart = time()
	recomputePauseState()
end

local function pauseEnd(plr: Player)
	local r = getRun(plr)
	if not r.pauseStart then
		recomputePauseState()
		return
	end
	r.pausedTotal += (time() - r.pauseStart)
	r.pauseStart = nil
	recomputePauseState()
end

PauseMenuEvent.OnServerEvent:Connect(function(plr: Player, action)
	if not plr or plr.Parent ~= Players then
		return
	end

	if action == "pause" then
		if plr:GetAttribute("RunEnded") == true or RunStarted.Value ~= true then
			manualPauseUsers[plr.UserId] = nil
			recomputePauseState()
			return
		end
		manualPauseUsers[plr.UserId] = true
	elseif action == "resume" then
		manualPauseUsers[plr.UserId] = nil
	else
		return
	end

	recomputePauseState()
end)


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
		recomputePauseState()

		if p.pendingLevelUps > 0 then
			p.pendingLevelUps -= 1
		end
		p.inLevelUp = false

		if p.pendingLevelUps > 0 then
			startPartyLevelUp(pid)
		end
	end
end


local QUALITY_ORDER = SpellDefs and SpellDefs.GetQualityOrder and SpellDefs.GetQualityOrder() or { "Common", "Uncommon", "Rare", "Epic" }

local function rollRarity(weights: table): string
	local r = math.random()
	local acc = 0
	for _, key in ipairs(QUALITY_ORDER) do
		acc += (weights[key] or 0)
		if r <= acc then return key end
	end
	return "Common"
end

local function strongestUnlockedProducts(plr: Player)
	return SpellDefs.ResolveUnlockedProducts(parseUnlocked(plr))
end

local function buildElementCounts(activeSet: {[string]: boolean}): {[string]: number}
	local counts = {}
	for spellId in pairs(activeSet) do
		local def = SpellDefs.SPELLS[spellId]
		if def and def.element then
			counts[def.element] = (counts[def.element] or 0) + 1
		end
	end
	return counts
end

local function candidateScore(plr: Player, spellId: string, offerType: string, activeSet: {[string]: boolean}, elementCounts: {[string]: number}): number
	local def = SpellDefs.SPELLS[spellId]
	if not def then
		return 0
	end

	local score = offerType == "upgrade" and 1.20 or 1.00
	score += (elementCounts[def.element] or 0) * 0.22
	score += def.spellType == "Physical" and 0.10 or 0.05

	local synergyResult = SpellDefs.GetSynergyHint and SpellDefs.GetSynergyHint(spellId, activeSet) or nil
	if synergyResult then
		score += offerType == "new" and 2.40 or 0.75
	end

	if def.isCombo then
		score += 0.90
	end

	local level = getSpellLevel(plr, spellId)
	if offerType == "upgrade" then
		score += math.max(0, 0.45 - (level * 0.05))
	end

	return score
end

local function buildOfferCandidates(plr: Player)
	local candidates = {}
	local seen = {}
	local activeSet = buildActiveSet(plr)
	local elementCounts = buildElementCounts(activeSet)

	for familyId, product in pairs(strongestUnlockedProducts(plr)) do
		if canOffer(plr, familyId) then
			local offerType = getSpellLevel(plr, familyId) > 0 and "upgrade" or "new"
			candidates[#candidates + 1] = {
				spellId = familyId,
				productId = product.id,
				offerType = offerType,
				score = candidateScore(plr, familyId, offerType, activeSet, elementCounts),
			}
			seen[familyId] = true
		end
	end

	for spellId, def in pairs(SpellDefs.SPELLS) do
		if def.isCombo and getSpellLevel(plr, spellId) > 0 and canOffer(plr, spellId) and not seen[spellId] then
			candidates[#candidates + 1] = {
				spellId = spellId,
				offerType = "upgrade",
				score = candidateScore(plr, spellId, "upgrade", activeSet, elementCounts),
			}
		end
	end

	return candidates, activeSet
end

local function drawWeighted(candidates: {any})
	local total = 0
	for _, candidate in ipairs(candidates) do
		total += math.max(0.01, tonumber(candidate.score) or 0.01)
	end
	if total <= 0 then
		return nil
	end

	local roll = math.random() * total
	local acc = 0
	for index, candidate in ipairs(candidates) do
		acc += math.max(0.01, tonumber(candidate.score) or 0.01)
		if roll <= acc then
			table.remove(candidates, index)
			return candidate
		end
	end
	return table.remove(candidates, #candidates)
end

local function makeOfferPayload(plr: Player, candidate: any, activeSet: {[string]: boolean})
	local def = SpellDefs.SPELLS[candidate.spellId]
	if not def then
		return nil
	end

	local synergyResult = SpellDefs.GetSynergyHint and SpellDefs.GetSynergyHint(candidate.spellId, activeSet) or nil
	local payload = {
		spellId = candidate.spellId,
		productId = candidate.productId,
		offerType = candidate.offerType,
		name = def.name,
		spellType = def.spellType,
		element = def.element,
		attackType = def.attackType,
		color = SpellDefs.GetSpellColor(def),
		synergyResult = synergyResult,
	}

	if candidate.offerType == "new" then
		local product = SpellDefs.GetProduct(candidate.productId)
		if not product then
			return nil
		end
		local baseVariant = SpellDefs.BASE_VARIANT_QUALITIES[product.baseQuality]
		payload.quality = product.baseQuality
		payload.cardQuality = product.cardQuality or "Common"
		payload.subtitle = baseVariant and baseVariant.label or "Base Spell"
		payload.desc = SpellDefs.DescribeNewOffer(product)
	else
		local quality = rollRarity(SpellDefs.RARITY_WEIGHTS or { Common = 1 })
		local qualityDef = SpellDefs.UPGRADE_QUALITIES[quality] or SpellDefs.UPGRADE_QUALITIES.Common
		payload.quality = quality
		payload.cardQuality = quality
		payload.subtitle = qualityDef.label
		payload.desc = SpellDefs.DescribeUpgradeOffer(def, quality, getSpellLevel(plr, candidate.spellId))
	end

	if synergyResult and SpellDefs.SPELLS[synergyResult] then
		payload.desc = string.format("%s\nSynergy: merges with your current build into %s.", payload.desc, SpellDefs.SPELLS[synergyResult].name)
	end

	return payload
end

local function rollOffers(plr: Player)
	if not SpellDefs or not SpellDefs.SPELLS then
		return {}
	end

	local candidates, activeSet = buildOfferCandidates(plr)
	local offers = {}

	for _ = 1, 3 do
		local candidate = drawWeighted(candidates)
		if not candidate then
			break
		end
		local offer = makeOfferPayload(plr, candidate, activeSet)
		if offer then
			offers[#offers + 1] = offer
		end
	end

	return offers
end

local function resolveSynergies(plr: Player)
	if not SpellDefs or not SpellDefs.SYNERGIES then
		return
	end

	local changed = true
	while changed do
		changed = false
		for _, synergy in ipairs(SpellDefs.SYNERGIES) do
			local a = synergy.ingredients[1]
			local b = synergy.ingredients[2]
			local resultId = synergy.resultId
			if getSpellLevel(plr, a) > 0 and getSpellLevel(plr, b) > 0 and getSpellLevel(plr, resultId) <= 0 then
				local resultDef = SpellDefs.SPELLS[resultId]
				local resultLevel = math.clamp(math.max(getSpellLevel(plr, a), getSpellLevel(plr, b)), 1, resultDef and resultDef.maxLevel or 6)
				local resultUpgradePower = getSpellUpgradePower(plr, a) + getSpellUpgradePower(plr, b) + 0.75
				local resultBaseMultiplier = math.max(getSpellBaseMultiplier(plr, a), getSpellBaseMultiplier(plr, b), 1) + 0.06
				local resultBasePower = math.max(getSpellBasePower(plr, a), getSpellBasePower(plr, b)) + 0.50

				clearSpellState(plr, a)
				clearSpellState(plr, b)
				setSpellState(plr, resultId, resultLevel, resultUpgradePower, resultBaseMultiplier, resultBasePower)
				changed = true
				break
			end
		end
	end
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
	local function offered(spellId: string)
		for _, off in ipairs(p.offers or {}) do
			if off.spellId == spellId then
				return off
			end
		end
		return nil
	end

	if t == "pick" then
		local id = tostring(payload.spellId or "")
		if id == "" then return end
		local offer = offered(id)
		if not offer then return end
		if not canOffer(plr, id) then return end

		if offer.offerType == "new" then
			local product = SpellDefs.GetProduct(tostring(offer.productId or ""))
			if not product then return end
			setSpellState(plr, id, 1, 0, tonumber(product.baseMultiplier) or 1, tonumber(product.basePower) or 0)
		else
			local qualityDef = SpellDefs.UPGRADE_QUALITIES[tostring(offer.quality or "Common")] or SpellDefs.UPGRADE_QUALITIES.Common
			local nextLevel = math.clamp(getSpellLevel(plr, id) + 1, 1, (SpellDefs.SPELLS[id] and SpellDefs.SPELLS[id].maxLevel) or 6)
			local baseMultiplier = math.max(getSpellBaseMultiplier(plr, id), 1)
			setSpellState(
				plr,
				id,
				nextLevel,
				getSpellUpgradePower(plr, id) + (qualityDef.power or 1),
				baseMultiplier,
				getSpellBasePower(plr, id)
			)
		end

		resolveSynergies(plr)

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
local STAT_HP_PER_LEVEL = 6
local STAT_SPEED_PER_LEVEL = 0.30
local STAT_ATK_PCT_PER_LEVEL = 0.04 -- slightly stronger per-level ramp so leveling feels more impactful

local function applyRunStatsNow(plr: Player)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local baseHp = tonumber(plr:GetAttribute("BaseMaxHP")) or 100
	local baseSpd = tonumber(plr:GetAttribute("BaseWalkSpeed")) or 21

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

local function addRunCoins(plr: Player, amount: number)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return
	end

	local r = getRun(plr)
	if r.ended then
		return
	end

	r.runSilver += amount
	r.coinsEarned = math.max(0, math.floor(tonumber(r.coinsEarned) or 0)) + amount
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
		addRunCoins(plr, coins)

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
	addRunCoins(plr, coins)

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

function _G.RegisterEnemyKill(_pos: Vector3?, killer: Player?)
	if not killer or killer.Parent ~= Players or killer:GetAttribute("RunEnded") == true then
		return
	end

	local r = getRun(killer)
	if r.ended then
		return
	end

	r.kills += 1

	local now = os.clock()
	r.killTimes = r.killTimes or {}
	table.insert(r.killTimes, now)

	local kt = r.killTimes
	local j = 1
	for i = 1, #kt do
		if now - kt[i] <= 20 then
			kt[j] = kt[i]
			j += 1
		end
	end
	for i = j, #kt do
		kt[i] = nil
	end

	if not r.multikill30_5Done then
		local c5 = 0
		for i = #kt, 1, -1 do
			if now - kt[i] <= 5 then
				c5 += 1
			else
				break
			end
		end
		if c5 >= 30 then
			r.multikill30_5Done = true
		end
	end

	if not r.multikill60_20Done and #kt >= 60 then
		r.multikill60_20Done = true
	end

	syncHud(killer)
end

function _G.NotifyBossSpawn()
	local spawnSeconds = nil
	if type(_G.GetRunSeconds) == "function" then
		spawnSeconds = tonumber(_G.GetRunSeconds())
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("RunEnded") ~= true then
			local r = getRun(plr)
			if not r.ended then
				r.bossSpawnClock = os.clock()
				r.bossSpawnRunSeconds = spawnSeconds or runSeconds(plr)
				r.bossNoHit20Failed = false
			end
		end
	end
end

function _G.GetAverageRunLevel(): number
	local total = 0
	local count = 0

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Parent and plr:GetAttribute("RunEnded") ~= true then
			local r = getRun(plr)
			if not r.ended then
				total += math.max(0, math.floor(tonumber(r.runLevel) or 0))
				count += 1
			end
		end
	end

	if count <= 0 then
		return 0
	end

	return total / count
end

-- GameOver / account XP
local TIME_RATE = 0.35
local KILL_RATE = 5

local function getLevelKey(plr: Player): string
	local levelKey = plr:GetAttribute("LevelKey")
	if typeof(levelKey) == "string" and levelKey ~= "" then
		return levelKey
	end

	return "AshenWastes"
end

local function endRunForPlayer(plr: Player, reason: string)
	local r = getRun(plr)
	if r.ended then return end
	r.ended = true
	plr:SetAttribute("RunEnded", true)
	pending[plr.UserId] = nil
	manualPauseUsers[plr.UserId] = nil

	pauseEnd(plr)
	if not hasActiveRunPlayers() then
		RunStarted.Value = false
	end

	local preciseSeconds = runSecondsPrecise(plr)
	local seconds = math.floor(preciseSeconds)
	local accountXp = math.max(0, math.floor(seconds * TIME_RATE + (r.kills or 0) * KILL_RATE))
	-- Gold coins are run-only. Convert a larger share into lobby silver so hard runs feel more rewarding.
	local goldSilver = math.max(0, math.floor(r.runSilver or 0))
	local runCoinsEarned = math.max(0, math.floor(r.coinsEarned or 0))
	local coinsGained = math.max(0, math.floor(goldSilver * 0.6))

	local d = PlayerData.Get(plr)
	d.xp = (tonumber(d.xp) or 0) + accountXp
	d.silver = (tonumber(d.silver) or 0) + coinsGained

	if tonumber(d.level) and tonumber(d.nextXp) and PlayerData.RollNextXp then
		while d.xp >= d.nextXp do
			d.xp -= d.nextXp
			d.level += 1
			d.nextXp = PlayerData.RollNextXp(d.level)
		end
	end

	if PlayerData.UpdateLevelRecord then
		pcall(function()
			PlayerData.UpdateLevelRecord(
				plr,
				getLevelKey(plr),
				r.kills or 0,
				preciseSeconds,
				reason == "Victory"
			)
		end)
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

		local bossSpawnAt = tonumber(r.bossSpawnRunSeconds)
		local bossSpawned = bossSpawnAt ~= nil and bossSpawnAt >= 0
		local extra = {
			coinsGained = coinsGained,
			runCoinsEarned = runCoinsEarned,
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
			bossNoHit20 = (not diedThisRun) and bossSpawned and seconds >= (bossSpawnAt + 20) and (r.bossNoHit20Failed ~= true),
			bossClutch = (not diedThisRun) and hpRatio < 0.30,
			burst90 = (not diedThisRun) and bossSpawned and seconds >= bossSpawnAt and seconds <= (bossSpawnAt + 90),
			burst120 = (not diedThisRun) and bossSpawned and seconds >= bossSpawnAt and seconds <= (bossSpawnAt + 120),
			noRerollWin = (not diedThisRun) and (r.rerollsUsed or 0) == 0,
			max1RerollWin = (not diedThisRun) and (r.rerollsUsed or 0) <= 1,
			max1SkipWin = (not diedThisRun) and (r.skipsUsed or 0) <= 1,
			level10 = (r.runLevel or 0) >= 10,
			spells3 = spellsCount >= 3,
			hp50plusWin = (not diedThisRun) and (r.minHpRatio or 1) >= 0.50,
			winStreak3 = (r.winStreak or 0) >= 3,
		}

		pcall(function() MissionProgress.OnRunComplete(plr, 0, seconds, diedThisRun, extra) end)
		pcall(function() MissionProgress.OnReward(plr, accountXp, runCoinsEarned) end)
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
	r.coinsEarned = 0
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
	r.bossSpawnClock = nil
	r.bossSpawnRunSeconds = nil
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
			plr:SetAttribute(("Spell_%s_UpgradePower"):format(id), 0)
			plr:SetAttribute(("Spell_%s_BaseMultiplier"):format(id), 0)
			plr:SetAttribute(("Spell_%s_BasePower"):format(id), 0)
		end
	end

	syncHud(plr)
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	manualPauseUsers[plr.UserId] = nil
	run[plr.UserId] = nil
	pending[plr.UserId] = nil
	recomputePauseState()
end)

print("[ProgressService] Ready (v15)")

