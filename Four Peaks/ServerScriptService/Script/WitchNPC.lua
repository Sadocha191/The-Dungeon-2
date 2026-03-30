local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function tryRequire(instance)
	if not instance then
		return nil
	end
	local ok, mod = pcall(require, instance)
	return ok and mod or nil
end

local function findModuleByName(name)
	for _, root in ipairs({ game:GetService("ServerScriptService"), ReplicatedStorage, workspace }) do
		local found = root:FindFirstChild(name, true)
		if found and found:IsA("ModuleScript") then
			local mod = tryRequire(found)
			if mod then
				return mod
			end
		end
	end
	return nil
end

local PlayerData = findModuleByName("PlayerData")
local SpellDefinitions = findModuleByName("SpellDefinitions")

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local remote = remoteEvents:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteEvents
	return remote
end

local WitchShopEvent = ensureRemoteEvent("WitchShopEvent")

local function findWitchModel()
	local npcs = workspace:FindFirstChild("NPCs")
	if not npcs then
		return nil
	end
	local witch = npcs:FindFirstChild("Witch") or npcs:FindFirstChild("Wiedzma")
	return witch and witch:IsA("Model") and witch or nil
end

local function findPromptInModel(model)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("ProximityPrompt") then
			return child
		end
	end
	return nil
end

local function findFirstBasePart(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

local function ensurePrompt(model)
	local prompt = findPromptInModel(model)
	if prompt then
		return prompt
	end

	local part = findFirstBasePart(model)
	if not part then
		return nil
	end

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

local function buildShopPayload(plr)
	local data = PlayerData and PlayerData.Get and PlayerData.Get(plr) or nil
	local unlocked = data and data.spellsUnlocked or {}
	local payload = {}

	for _, productId in ipairs(SpellDefinitions and SpellDefinitions.GetShopList and SpellDefinitions.GetShopList() or {}) do
		local product = SpellDefinitions and SpellDefinitions.GetProduct and SpellDefinitions.GetProduct(productId) or nil
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
				owned = unlocked[product.id] == true,
				desc = SpellDefinitions.DescribeShopProduct(product),
				color = product.color,
			}
		end
	end

	return payload
end

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

prompt.Triggered:Connect(function(plr)
	local data = PlayerData and PlayerData.Get and PlayerData.Get(plr) or nil

	if data and data.spellbookUnlocked ~= true and _G.Spells_GrantStarterBook then
		pcall(function()
			_G.Spells_GrantStarterBook(plr)
		end)
		data = PlayerData.Get(plr)
	end

	if plr:GetAttribute("TutorialComplete") ~= true then
		return
	end

	WitchShopEvent:FireClient(plr, {
		type = "OPEN",
		souls = data and data.souls or 0,
		spells = buildShopPayload(plr),
	})
end)
