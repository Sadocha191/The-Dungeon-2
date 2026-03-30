local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local CraftingService = require(serverModules:WaitForChild("CraftingService"))
local WeaponCatalog = require(serverModules:WaitForChild("WeaponCatalog"))

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

local OpenBlacksmithUI = ensureRemote("OpenBlacksmithUI")
local BlacksmithSync = ensureRemote("BlacksmithSync")
local BlacksmithAction = ensureRemote("BlacksmithAction")

local WeaponTemplates = ServerStorage:FindFirstChild("WeaponTemplates")

local function findAnyBasePart(model)
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function setupBlacksmithPrompt()
	local npcs = workspace:FindFirstChild("NPCs")
	local blacksmith = npcs and npcs:FindFirstChild("Blacksmith")
	if not (blacksmith and blacksmith:IsA("Model")) then
		warn("[BlacksmithService] Missing workspace.NPCs.Blacksmith")
		return
	end

	local part = findAnyBasePart(blacksmith)
	if not part then
		warn("[BlacksmithService] Blacksmith has no BasePart")
		return
	end

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end

	prompt.ObjectText = "Blacksmith"
	prompt.ActionText = "Craft / Upgrade"

	prompt.Triggered:Connect(function(player)
		OpenBlacksmithUI:FireClient(player)
	end)
end

local function isWeaponTool(inst)
	if not inst:IsA("Tool") then
		return false
	end
	if typeof(inst:GetAttribute("WeaponType")) == "string" then
		return true
	end
	if typeof(inst:GetAttribute("WeaponInstanceId")) == "string" then
		return true
	end
	return WeaponTemplates and WeaponTemplates:FindFirstChild(inst.Name, true) ~= nil
end

local function clearWeaponTools(container)
	if not container then
		return
	end
	for _, inst in ipairs(container:GetChildren()) do
		if isWeaponTool(inst) then
			inst:Destroy()
		end
	end
end

local function applyInstanceAttributes(tool, inst)
	tool:SetAttribute("WeaponInstanceId", inst.instanceId)
	tool:SetAttribute("WeaponLevel", tonumber(inst.level) or 1)
	tool:SetAttribute("WeaponPrefix", tostring(inst.prefix or "Standard"))
	if typeof(inst.rollStats) == "table" then
		for key, value in pairs(inst.rollStats) do
			if typeof(key) == "string" and typeof(value) == "number" then
				tool:SetAttribute("Roll_" .. key, value)
			end
		end
	end
end

local function equipWeaponInstance(player, instanceId)
	if not PlayerStateStore.Get(player) then
		PlayerStateStore.Load(player)
	end
	local inst = PlayerStateStore.GetWeaponInstance(player, instanceId)
	if not inst then
		return false
	end

	local template = WeaponCatalog.FindTemplate(inst.weaponId)
	if not template then
		warn("[BlacksmithService] Missing weapon template:", inst.weaponId)
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then
		warn("[BlacksmithService] No Backpack for", player.Name)
		return false
	end

	clearWeaponTools(backpack)
	clearWeaponTools(player.Character)

	local clone = template:Clone()
	WeaponCatalog.PrepareTool(clone, inst.weaponId)
	applyInstanceAttributes(clone, inst)
	clone.Parent = backpack

	PlayerStateStore.SetEquippedWeaponInstance(player, instanceId)
	PlayerStateStore.EnsureOwnedWeapon(player, inst.weaponId)
	return true
end

local function sync(player, result)
	local snapshot = CraftingService.BuildBlacksmithSnapshot(player)
	if result then
		snapshot.lastResult = result
	end
	BlacksmithSync:FireClient(player, snapshot)
end

setupBlacksmithPrompt()

BlacksmithAction.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	local actionType = tostring(payload.type or "")
	if actionType == "request" then
		sync(player)
		return
	end

	local ok = false
	local details = nil
	local reason = nil
	local equippedBefore = nil
	local playerState = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if playerState then
		equippedBefore = playerState.EquippedWeaponInstanceId
	end

	if actionType == "unlockRecipe" then
		ok, details = CraftingService.UnlockRecipe(player, tostring(payload.recipeId or ""))
		if ok ~= true then
			reason = details
		end
	elseif actionType == "craft" then
		ok, details = CraftingService.CraftRecipe(player, tostring(payload.recipeId or ""))
		if ok ~= true then
			reason = details
		elseif not (typeof(equippedBefore) == "string" and equippedBefore ~= "") and typeof(details.instanceId) == "string" then
			equipWeaponInstance(player, details.instanceId)
		end
	elseif actionType == "upgrade" then
		ok, details = CraftingService.TryUpgradeWeapon(player, tostring(payload.instanceId or ""), tonumber(payload.steps) or 1)
		if ok ~= true then
			reason = typeof(details) == "string" and details or "UpgradeFailed"
		end
	elseif actionType == "sell" then
		ok, details = CraftingService.SellWeaponInstance(player, tostring(payload.instanceId or ""))
		if ok ~= true then
			reason = details
		elseif equippedBefore ~= nil and tostring(payload.instanceId or "") == tostring(equippedBefore) then
			local updatedState = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
			local nextEquippedId = updatedState and updatedState.EquippedWeaponInstanceId or nil
			if typeof(nextEquippedId) == "string" and nextEquippedId ~= "" then
				if not equipWeaponInstance(player, nextEquippedId) then
					clearWeaponTools(player:FindFirstChildOfClass("Backpack"))
					clearWeaponTools(player.Character)
				end
			else
				clearWeaponTools(player:FindFirstChildOfClass("Backpack"))
				clearWeaponTools(player.Character)
			end
		end
	else
		reason = "UnknownAction"
	end

	sync(player, {
		type = actionType,
		ok = ok == true,
		reason = reason,
		details = ok == true and details or nil,
	})
end)

Players.PlayerAdded:Connect(function(player)
	PlayerStateStore.Load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerStateStore.Save(player, true)
end)

print("[BlacksmithService] Ready")
