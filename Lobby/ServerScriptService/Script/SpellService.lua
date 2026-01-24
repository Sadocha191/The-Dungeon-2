-- SpellService.server.lua (ServerScriptService/Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- PlayerData
local playerDataModule = (ServerScriptService:FindFirstChild("ModuleScript") and ServerScriptService.ModuleScript:FindFirstChild("PlayerData"))
	or (ServerScriptService:FindFirstChild("ModuleScripts") and ServerScriptService.ModuleScripts:FindFirstChild("PlayerData"))
	or ServerScriptService:FindFirstChild("PlayerData")
assert(playerDataModule, "Missing PlayerData module")
local PlayerData = require(playerDataModule)

-- Spell defs
local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts")
local SpellDefs = require(moduleFolder:WaitForChild("SpellDefinitions"))

-- Remotes
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(name: string): RemoteEvent
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r :: any
end

local SpellEvent = getRemote("SpellEvent")         -- level-up (3 choices)
local WitchShopEvent = getRemote("WitchShopEvent") -- shop UI + buy

-- Run state (per serwer/instancję)
local runOwned: {[number]: {[string]: number}} = {} -- [uid][spellId] = level
local pending: {[number]: {token: string, choices: {[string]: boolean}}} = {}

local function getRunTable(plr: Player)
	local uid = plr.UserId
	runOwned[uid] = runOwned[uid] or {}
	return runOwned[uid]
end

local function getUnlockedTable(plr: Player)
	local d = PlayerData.Get(plr)
	d.spellsUnlocked = d.spellsUnlocked or {}
	return d.spellsUnlocked
end

local function setSpellAttr(plr: Player, spellId: string, level: number)
	-- proste hooki pod inne systemy (opcjonalnie)
	plr:SetAttribute(("Spell_%s_Level"):format(spellId), level)
end

local function clearAllSpellAttrs(plr: Player)
	for id,_ in pairs(SpellDefs.SPELLS) do
		plr:SetAttribute(("Spell_%s_Level"):format(id), 0)
	end
end

local function unlockSpell(plr: Player, spellId: string)
	if not SpellDefs.IsValid(spellId) then return false end
	local d = PlayerData.Get(plr)
	d.spellsUnlocked = d.spellsUnlocked or {}
	if d.spellsUnlocked[spellId] == true then
		return false
	end
	d.spellsUnlocked[spellId] = true
	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)
	return true
end

local function grantStarterSpellbook(plr: Player)
	local d = PlayerData.Get(plr)
	if d.spellbookUnlocked == true then
		return
	end

	d.spellbookUnlocked = true
	d.spellsUnlocked = d.spellsUnlocked or {}

	for _, spellId in ipairs(SpellDefs.BASE_STARTER) do
		d.spellsUnlocked[spellId] = true
	end

	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)
end

local function buildShopPayload(plr: Player)
	local d = PlayerData.Get(plr)
	local unlocked = d.spellsUnlocked or {}
	local list = SpellDefs.GetShopList()
	local out = {}

	for _, id in ipairs(list) do
		local def = SpellDefs.Get(id)
		table.insert(out, {
			id = id,
			name = def.name,
			category = def.category,
			costCoins = def.costCoins or 0,
			owned = unlocked[id] == true,
		})
	end

	return out
end

local function rollSpellChoices(plr: Player)
	local unlocked = getUnlockedTable(plr)
	local owned = getRunTable(plr)

	local upgrades = {}
	local news = {}

	-- New spells (unlocked but not in run)
	for spellId, ok in pairs(unlocked) do
		if ok == true and owned[spellId] == nil then
			table.insert(news, spellId)
		end
	end

	-- Upgrades (in run, not max)
	for spellId, lv in pairs(owned) do
		local def = SpellDefs.Get(spellId)
		if def and lv < (def.maxLevel or 8) then
			table.insert(upgrades, spellId)
		end
	end

	-- limit run spells
	local runCount = 0
	for _ in pairs(owned) do runCount += 1 end

	local canAddNew = runCount < SpellDefs.MAX_RUN_SPELLS

	-- helper pick
	local function pickRandom(t)
		if #t == 0 then return nil end
		local idx = math.random(1, #t)
		local val = t[idx]
		table.remove(t, idx)
		return val
	end

	local picks = {}
	local pickedSet = {}

	-- prefer: 2 upgrades + 1 new (jeśli możliwe)
	for _=1,3 do
		local chosen

		-- jeśli nie możemy już dodawać nowych, tylko upgrade
		if not canAddNew then
			chosen = pickRandom(upgrades)
		else
			-- ważenie: jeśli mamy upgrade’y, preferuj upgrade
			if #upgrades > 0 and (#news == 0 or math.random() < 0.65) then
				chosen = pickRandom(upgrades)
			else
				chosen = pickRandom(news) or pickRandom(upgrades)
			end
		end

		-- brak kandydatów
		if not chosen then break end

		-- dedupe
		if pickedSet[chosen] then
			-- spróbuj jeszcze raz w tej iteracji
		else
			pickedSet[chosen] = true
			table.insert(picks, chosen)
		end
	end

	-- jeśli wyszło mniej niż 3, dopełnij czym się da
	while #picks < 3 do
		local fallback = pickRandom(upgrades) or (canAddNew and pickRandom(news)) or nil
		if not fallback then break end
		if not pickedSet[fallback] then
			pickedSet[fallback] = true
			table.insert(picks, fallback)
		end
	end

	-- map do UI
	local uiChoices = {}
	for _, spellId in ipairs(picks) do
		local def = SpellDefs.Get(spellId)
		if def then
			local lv = owned[spellId] or 0
			local nextText = def.nextDesc and def.nextDesc(lv) or "Upgrade."
			table.insert(uiChoices, {
				id = spellId,
				name = def.name,
				desc = nextText, -- ważne: gotowy tekst (bez %d)
				value = nil,
				rarity = (def.base and "Base Spell" or "Spell"),
				color = (def.base and SpellDefs.COLOR_BASE or SpellDefs.COLOR_SHOP),
			})
		end
	end

	return uiChoices
end

local function openSpellChoice(plr: Player)
	local token = ("%d_%d"):format(plr.UserId, math.floor(os.clock()*1000))
	local choices = rollSpellChoices(plr)

	-- jeśli nie ma absolutnie nic do wyboru, nie otwieraj
	if #choices == 0 then return end

	local allowed = {}
	for _, c in ipairs(choices) do
		allowed[c.id] = true
	end

	pending[plr.UserId] = { token = token, choices = allowed }
	SpellEvent:FireClient(plr, { type = "SHOW", token = token, choices = choices })
end

local function applyPick(plr: Player, token: string, spellId: string)
	local pend = pending[plr.UserId]
	if not pend then return end
	if pend.token ~= token then return end
	if pend.choices[spellId] ~= true then return end

	local owned = getRunTable(plr)
	local def = SpellDefs.Get(spellId)
	if not def then return end

	local current = owned[spellId] or 0
	local nextLv = math.clamp(current + 1, 1, def.maxLevel or 8)
	owned[spellId] = nextLv

	-- ustaw atrybut do runtime (opcjonalny hook)
	setSpellAttr(plr, spellId, nextLv)

	pending[plr.UserId] = nil
end

-- ======== Remotes wiring ========

SpellEvent.OnServerEvent:Connect(function(plr: Player, payload)
	if typeof(payload) ~= "table" then return end
	if payload.type == "PICK" then
		applyPick(plr, tostring(payload.token or ""), tostring(payload.id or ""))
	end
end)

WitchShopEvent.OnServerEvent:Connect(function(plr: Player, payload)
	if typeof(payload) ~= "table" then return end
	local d = PlayerData.Get(plr)

	-- gating: shop dopiero po tutorialu
	if d.tutorialCompleted ~= true then
		WitchShopEvent:FireClient(plr, { type = "INFO", message = "Finish the tutorial first." })
		return
	end

	if payload.type == "OPEN" then
		WitchShopEvent:FireClient(plr, {
			type = "OPEN",
			coins = d.coins,
			spells = buildShopPayload(plr),
		})
		return
	end

	if payload.type == "BUY" then
		local spellId = tostring(payload.id or "")
		local def = SpellDefs.Get(spellId)
		if not def or def.base == true then return end

		d.spellsUnlocked = d.spellsUnlocked or {}
		if d.spellsUnlocked[spellId] == true then
			WitchShopEvent:FireClient(plr, { type = "BOUGHT", id = spellId, coins = d.coins })
			return
		end

		local cost = math.max(0, tonumber(def.costCoins) or 0)
		if d.coins < cost then
			WitchShopEvent:FireClient(plr, { type = "ERROR", message = "Not enough coins." })
			return
		end

		d.coins -= cost
		d.spellsUnlocked[spellId] = true

		PlayerData.MarkDirty(plr)
		PlayerData.Save(plr, false)

		WitchShopEvent:FireClient(plr, {
			type = "BOUGHT",
			id = spellId,
			coins = d.coins,
			spells = buildShopPayload(plr),
		})
	end
end)

-- ======== Public hooki (dla innych skryptów) ========
_G.Spells_OpenChoice = openSpellChoice
_G.Spells_GrantStarterBook = grantStarterSpellbook
_G.Spells_ResetRun = function(plr: Player)
	runOwned[plr.UserId] = {}
	pending[plr.UserId] = nil
	clearAllSpellAttrs(plr)
end

Players.PlayerRemoving:Connect(function(plr)
	runOwned[plr.UserId] = nil
	pending[plr.UserId] = nil
end)
