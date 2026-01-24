-- WitchNPC.server.lua (Lobby)
-- Odpowiada za:
-- 1) gating sklepu po tutorialu (ATTR: TutorialComplete)
-- 2) nadanie starter spellbooka przy pierwszej interakcji (jeśli masz _G.Spells_GrantStarterBook)
-- 3) otwieranie UI klientowi przez WitchShopEvent:FireClient({type="OPEN", coins=..., spells=...})

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== Helpers: safe require ==========
local function tryRequire(instance: Instance?)
	if not instance then return nil end
	local ok, mod = pcall(require, instance)
	if ok then return mod end
	return nil
end

local function findModuleByName(name: string): any
	local candidates = {
		game:GetService("ServerScriptService"),
		ReplicatedStorage,
		workspace,
	}

	for _, root in ipairs(candidates) do
		local found = root:FindFirstChild(name, true)
		if found and found:IsA("ModuleScript") then
			local mod = tryRequire(found)
			if mod then return mod end
		end
	end

	return nil
end

-- Wymagane moduły
local PlayerData = findModuleByName("PlayerData")
if not PlayerData then
	warn("[WitchNPC] Missing PlayerData module (ModuleScript named 'PlayerData').")
end

local SpellDefinitions = findModuleByName("SpellDefinitions")
if not SpellDefinitions then
	warn("[WitchNPC] Missing SpellDefinitions module (ModuleScript named 'SpellDefinitions').")
end

-- ========== Remotes folder ==========
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name: string): RemoteEvent
	local r = remoteEvents:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remoteEvents
	return r
end

local WitchShopEvent = ensureRemoteEvent("WitchShopEvent")

-- ========== Locate Witch + Prompt ==========
local function findWitchModel(): Model?
	local npcs = workspace:FindFirstChild("NPCs")
	if not npcs then return nil end

	local witch = npcs:FindFirstChild("Witch") or npcs:FindFirstChild("Wiedzma")
	if witch and witch:IsA("Model") then return witch end
	return nil
end

local function findPromptInModel(m: Model): ProximityPrompt?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d
		end
	end
	return nil
end

local function findFirstBasePart(m: Model): BasePart?
	if m.PrimaryPart then return m.PrimaryPart end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

local function ensurePrompt(m: Model): ProximityPrompt?
	local prompt = findPromptInModel(m)
	if prompt then return prompt end

	local part = findFirstBasePart(m)
	if not part then return nil end

	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WitchPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Witch"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	return prompt
end

-- ========== Build shop payload ==========
local function getPlayerData(plr: Player)
	if PlayerData and PlayerData.Get then
		local ok, d = pcall(PlayerData.Get, plr)
		if ok then return d end
	end
	return nil
end

local function getShopList(): {string}
	if SpellDefinitions and SpellDefinitions.GetShopList then
		local ok, list = pcall(SpellDefinitions.GetShopList)
		if ok and typeof(list) == "table" then
			return list
		end
	end
	return {}
end

local function getSpellDef(id: string)
	if SpellDefinitions and SpellDefinitions.Get then
		local ok, def = pcall(SpellDefinitions.Get, id)
		if ok and typeof(def) == "table" then
			return def
		end
	end
	return nil
end

local function buildShopPayload(plr: Player, d)
	local unlocked = d and d.spellsUnlocked or {}
	local list = getShopList()

	local out = {}
	for _, id in ipairs(list) do
		local def = getSpellDef(id) or {}
		out[#out+1] = {
			id = id,
			name = def.name or id,
			category = def.category or "Spell",
			costCoins = def.costCoins or 0,
			owned = unlocked[id] == true,
			desc = def.desc or def.description or "",
		}
	end
	return out
end

-- ========== Main behavior ==========
local witch = findWitchModel()
if not witch then
	warn("[WitchNPC] Witch model not found. Expected workspace.NPCs.Witch or workspace.NPCs.Wiedzma")
	return
end

local prompt = ensurePrompt(witch)
if not prompt then
	warn("[WitchNPC] No BasePart in Witch model to attach ProximityPrompt.")
	return
end

prompt.Triggered:Connect(function(plr: Player)
	local d = getPlayerData(plr)

	-- Starter book (jeśli masz hook)
	if d and d.spellbookUnlocked ~= true and _G.Spells_GrantStarterBook then
		pcall(function()
			_G.Spells_GrantStarterBook(plr)
		end)
	end

	-- Gating po tutorialu (na atrybucie)
	if plr:GetAttribute("TutorialComplete") ~= true then
		WitchShopEvent:FireClient(plr, {
			type = "INFO",
			message = "Finish the tutorial to access the witch shop."
		})
		return
	end

	WitchShopEvent:FireClient(plr, {
		type = "OPEN",
		coins = (d and d.coins) or 0,
		spells = buildShopPayload(plr, d),
	})
end)
