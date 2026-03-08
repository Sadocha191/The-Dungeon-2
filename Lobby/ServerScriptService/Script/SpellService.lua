local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local playerDataModule = (ServerScriptService:FindFirstChild("ModuleScript") and ServerScriptService.ModuleScript:FindFirstChild("PlayerData"))
	or (ServerScriptService:FindFirstChild("ModuleScripts") and ServerScriptService.ModuleScripts:FindFirstChild("PlayerData"))
	or ServerScriptService:FindFirstChild("PlayerData")
assert(playerDataModule, "Missing PlayerData module")
local PlayerData = require(playerDataModule)

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

local function getUnlockedTable(plr)
	local data = getPlayerData(plr)
	data.spellsUnlocked = data.spellsUnlocked or {}
	return data.spellsUnlocked
end

local function buildShopPayload(plr)
	local unlocked = getUnlockedTable(plr)
	local payload = {}

	for _, productId in ipairs(SpellDefs.GetShopList()) do
		local product = SpellDefs.GetProduct(productId)
		if product then
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
				costCoins = product.costSouls or product.costCoins or 0,
				color = product.color,
				owned = unlocked[product.id] == true,
				desc = SpellDefs.DescribeShopProduct(product),
			}
		end
	end

	return payload
end

local function grantStarterSpellbook(plr)
	local data = getPlayerData(plr)
	if data.spellbookUnlocked == true then
		return
	end

	data.spellbookUnlocked = true
	data.spellsUnlocked = data.spellsUnlocked or {}

	for _, productId in ipairs(SpellDefs.BASE_STARTER or {}) do
		data.spellsUnlocked[productId] = true
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

	local productId = tostring(payload.id or "")
	local product = SpellDefs.GetProduct(productId)
	if not product then
		WitchShopEvent:FireClient(plr, { type = "ERROR", message = "Unknown spell offer." })
		return
	end

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
	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)

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

_G.Spells_ResetRun = function(plr)
	resetSpellAttrs(plr)
end

Players.PlayerRemoving:Connect(function() end)
