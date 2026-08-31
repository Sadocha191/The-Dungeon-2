local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local playerDataModule = (ServerScriptService:FindFirstChild("ModuleScript") and ServerScriptService.ModuleScript:FindFirstChild("PlayerData"))
	or (ServerScriptService:FindFirstChild("ModuleScripts") and ServerScriptService.ModuleScripts:FindFirstChild("PlayerData"))
	or ServerScriptService:FindFirstChild("PlayerData")
assert(playerDataModule, "Missing PlayerData module")
local PlayerData = require(playerDataModule)
local pickupToastModule = (ServerScriptService:FindFirstChild("ModuleScript") and ServerScriptService.ModuleScript:FindFirstChild("PickupToastService"))
	or (ServerScriptService:FindFirstChild("ModuleScripts") and ServerScriptService.ModuleScripts:FindFirstChild("PickupToastService"))
	or ServerScriptService:FindFirstChild("PickupToastService")
assert(pickupToastModule, "Missing PickupToastService module")
local PickupToastService = require(pickupToastModule)

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local SpellDefs = require(moduleFolder:WaitForChild("SpellDefinitions"))

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local remote = remoteEvents:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteEvents
	return remote
end

local SpellEvent = ensureRemote("SpellEvent")
local WitchShopEvent = ensureRemote("WitchShopEvent")

local function getPlayerData(plr)
	return PlayerData.Get(plr)
end

local function sanitizeUnlockedSpells(data)
	local raw = typeof(data.spellsUnlocked) == "table" and data.spellsUnlocked or {}
	local cleaned = {}
	local changed = typeof(data.spellsUnlocked) ~= "table"

	for rawId, unlocked in pairs(raw) do
		if unlocked == true and typeof(rawId) == "string" and rawId ~= "" then
			local normalizedId = SpellDefs.NormalizeProductId and SpellDefs.NormalizeProductId(rawId) or rawId
			local product = SpellDefs.GetProduct and SpellDefs.GetProduct(normalizedId) or nil
			if product then
				cleaned[product.id] = true
				if product.id ~= rawId then
					changed = true
				end
			else
				changed = true
			end
		elseif unlocked ~= nil then
			changed = true
		end
	end

	for id in pairs(cleaned) do
		if raw[id] ~= true then
			changed = true
			break
		end
	end

	data.spellsUnlocked = cleaned

	-- The current spell system no longer has a pre-run spell loadout. Clear old
	-- saved selections once so stale prototype spell ids cannot keep resurfacing.
	if typeof(data.spellLoadout) == "table" and #data.spellLoadout > 0 then
		data.spellLoadout = {}
		changed = true
	end
	if data.spellLoadoutConfigured == true then
		data.spellLoadoutConfigured = false
		changed = true
	end

	return cleaned, changed
end

local function sanitizePlayerSpells(plr, saveNow)
	if not plr or plr.Parent ~= Players then
		return {}
	end
	local data = getPlayerData(plr)
	local unlocked, changed = sanitizeUnlockedSpells(data)
	if changed then
		PlayerData.MarkDirty(plr)
		if saveNow then
			PlayerData.Save(plr, false)
		end
	end
	return unlocked
end

local function getUnlockedTable(plr)
	return sanitizePlayerSpells(plr, false)
end

local function buildShopPayload(plr)
	local unlocked = getUnlockedTable(plr)
	local payload = {}

	for _, productId in ipairs(SpellDefs.GetShopList()) do
		local product = SpellDefs.GetProduct(productId)
		if product then
			local baseVariant = SpellDefs.BASE_VARIANT_QUALITIES[product.baseQuality]
			local rarity = product.cardQuality or (baseVariant and baseVariant.cardQuality) or "Common"
			payload[#payload + 1] = {
				id = product.id,
				familyId = product.familyId,
				name = product.name,
				displayName = product.displayName,
				category = product.category,
				spellType = product.spellType,
				element = product.element,
				attackType = product.attackType,
				baseQuality = product.baseQuality,
				cardQuality = rarity,
				rarity = rarity,
				costCoins = product.costSouls or product.costCoins or 0,
				color = product.color,
				owned = unlocked[product.id] == true,
				desc = SpellDefs.DescribeShopProduct(product),
				iconGlyph = product.iconGlyph,
				artMotif = product.artMotif,
				loreDescription = product.loreDescription,
				gameplayDescription = product.gameplayDescription,
				visualDirection = product.visualDirection,
				frameStyle = product.frameStyle,
				codexCategory = product.codexCategory,
				witchbookAccent = product.witchbookAccent,
				presentation = product.presentation or SpellDefs.GetPresentation(product),
				visualProfile = product.visualProfile or SpellDefs.GetVisualProfile(product),
				statLines = SpellDefs.GetSpellStatLines(product.familyId, {
					level = 1,
					baseMultiplier = product.baseMultiplier,
					basePower = product.basePower,
				}),
				upgradeLevels = SpellDefs.GetSpellUpgradeLevels(product.familyId),
				combinations = SpellDefs.GetSynergiesFor(product.familyId),
			}
		end
	end

	return payload
end

local function grantStarterSpellbook(plr)
	local data = getPlayerData(plr)
	local _, migrated = sanitizeUnlockedSpells(data)
	if data.spellbookUnlocked == true then
		if migrated then
			PlayerData.MarkDirty(plr)
			PlayerData.Save(plr, false)
		end
		return
	end

	data.spellbookUnlocked = true
	data.spellsUnlocked = data.spellsUnlocked or {}

	for _, productId in ipairs(SpellDefs.BASE_STARTER or {}) do
		local wasUnlocked = data.spellsUnlocked[productId] == true
		data.spellsUnlocked[productId] = true
		if not wasUnlocked then
			PickupToastService.PushSpell(plr, productId, "Starter Spell", 1)
			if PlayerData.DiscoverCodex then
				local product = SpellDefs.GetProduct(productId)
				PlayerData.DiscoverCodex(plr, "Spells", product and product.familyId or productId, "starter_spellbook")
			end
		end
	end

	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)
end

local function resetSpellAttrs(plr)
	for id in pairs(SpellDefs.SPELLS) do
		plr:SetAttribute(("Spell_%s_Level"):format(id), 0)
		plr:SetAttribute(("Spell_%s_UpgradePower"):format(id), 0)
		plr:SetAttribute(("Spell_%s_BaseMultiplier"):format(id), 0)
		plr:SetAttribute(("Spell_%s_BasePower"):format(id), 0)
	end
end

SpellEvent.OnServerEvent:Connect(function() end)

WitchShopEvent.OnServerEvent:Connect(function(plr, payload)
	if typeof(payload) ~= "table" then
		return
	end

	local data = getPlayerData(plr)
	sanitizeUnlockedSpells(data)
	if plr:GetAttribute("TutorialComplete") ~= true then
		WitchShopEvent:FireClient(plr, { type = "INFO", message = "Finish the tutorial first." })
		return
	end

	if payload.type == "OPEN" then
		WitchShopEvent:FireClient(plr, {
			type = "OPEN",
			souls = tonumber(data.souls) or 0,
			spells = buildShopPayload(plr),
		})
		return
	end

	if payload.type ~= "BUY" then
		return
	end

	local requestedId = tostring(payload.id or "")
	local normalizedId = SpellDefs.NormalizeProductId and SpellDefs.NormalizeProductId(requestedId) or requestedId
	local product = SpellDefs.GetProduct(normalizedId)
	if not product then
		WitchShopEvent:FireClient(plr, { type = "ERROR", message = "Unknown spell offer." })
		return
	end
	local productId = product.id

	data.spellsUnlocked = data.spellsUnlocked or {}
	if data.spellsUnlocked[productId] == true then
		WitchShopEvent:FireClient(plr, {
			type = "BOUGHT",
			id = productId,
			souls = tonumber(data.souls) or 0,
			spells = buildShopPayload(plr),
		})
		return
	end

	local cost = math.max(0, tonumber(product.costSouls or product.costCoins) or 0)
	if (tonumber(data.souls) or 0) < cost then
		WitchShopEvent:FireClient(plr, { type = "ERROR", message = "Not enough souls." })
		return
	end

	data.souls = (tonumber(data.souls) or 0) - cost
	data.spellsUnlocked[productId] = true
	if PlayerData.DiscoverCodex then
		PlayerData.DiscoverCodex(plr, "Spells", product.familyId, "witch_shop")
	end
	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)
	PickupToastService.PushSpell(plr, productId, "Spell Unlocked", 1)

	WitchShopEvent:FireClient(plr, {
		type = "BOUGHT",
		id = productId,
		souls = tonumber(data.souls) or 0,
		spells = buildShopPayload(plr),
	})
end)

_G.Spells_OpenChoice = function()
	return false
end

_G.Spells_GrantStarterBook = grantStarterSpellbook
_G.Spells_SanitizeUnlocked = function(plr)
	return sanitizePlayerSpells(plr, false)
end

_G.Spells_ResetRun = function(plr)
	resetSpellAttrs(plr)
end

local function migratePlayer(plr)
	task.defer(function()
		if plr.Parent == Players then
			sanitizePlayerSpells(plr, true)
		end
	end)
end

Players.PlayerAdded:Connect(migratePlayer)
for _, plr in ipairs(Players:GetPlayers()) do
	migratePlayer(plr)
end

Players.PlayerRemoving:Connect(function() end)
