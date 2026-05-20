local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local CraftingService = require(serverModules:WaitForChild("CraftingService"))
local WeaponCatalog = require(serverModules:WaitForChild("WeaponCatalog"))
local servicesFolder = ServerScriptService:FindFirstChild("Services")
local ErrorReporter = servicesFolder and servicesFolder:FindFirstChild("ErrorReporter") and require(servicesFolder.ErrorReporter) or nil

local function protect(callbackName, context, callback)
	if ErrorReporter then
		return ErrorReporter.WrapCallback(callbackName, callback, context)
	end
	return callback
end

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
local blacksmithPrompt: ProximityPrompt? = nil
local blacksmithPromptConnection: RBXScriptConnection? = nil
local promptEnsureScheduled = false

local function tutorialComplete(player: Player): boolean
	return player:GetAttribute("TutorialComplete") == true
end

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

local function bindBlacksmithPrompt(prompt: ProximityPrompt)
	if blacksmithPrompt == prompt and blacksmithPromptConnection and blacksmithPromptConnection.Connected then
		return
	end

	if blacksmithPromptConnection then
		blacksmithPromptConnection:Disconnect()
		blacksmithPromptConnection = nil
	end

	blacksmithPrompt = prompt
	blacksmithPromptConnection = prompt.Triggered:Connect(protect("BlacksmithService.PromptTriggered", {
		system = "BlacksmithService",
		phase = "lobby",
	}, function(player)
		if not tutorialComplete(player) then
			return
		end
		OpenBlacksmithUI:FireClient(player)
	end))
end

local function ensureBlacksmithPrompt()
	local npcs = workspace:FindFirstChild("NPCs")
	local blacksmith = npcs and npcs:FindFirstChild("Blacksmith")
	if not (blacksmith and blacksmith:IsA("Model")) then
		return nil
	end

	local part = findAnyBasePart(blacksmith)
	if not part then
		return nil
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
	bindBlacksmithPrompt(prompt)
	return prompt
end

local function scheduleBlacksmithPromptEnsure()
	if promptEnsureScheduled then
		return
	end

	promptEnsureScheduled = true
	task.defer(function()
		promptEnsureScheduled = false
		ensureBlacksmithPrompt()
	end)
end

local function watchBlacksmithPrompt()
	scheduleBlacksmithPromptEnsure()

	workspace.ChildAdded:Connect(function(child)
		if child.Name == "NPCs" then
			scheduleBlacksmithPromptEnsure()
		end
	end)

	workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Blacksmith" or descendant:IsA("ProximityPrompt") then
			scheduleBlacksmithPromptEnsure()
		end
	end)

	workspace.DescendantRemoving:Connect(function(descendant)
		if descendant == blacksmithPrompt then
			if blacksmithPromptConnection then
				blacksmithPromptConnection:Disconnect()
				blacksmithPromptConnection = nil
			end
			blacksmithPrompt = nil
			scheduleBlacksmithPromptEnsure()
		end
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

watchBlacksmithPrompt()

BlacksmithAction.OnServerEvent:Connect(protect("BlacksmithService.ActionRemote", {
	system = "BlacksmithService",
	phase = "lobby",
}, function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if not tutorialComplete(player) then
		return
	end

	local actionType = tostring(payload.type or "")
	if actionType == "request" then
		sync(player)
		return
	end

	local ok = false
	local details = nil
	local resultDetails = nil
	local reason = nil
	local equippedBefore = nil
	local playerState = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if playerState then
		equippedBefore = playerState.EquippedWeaponInstanceId
	end

	if actionType == "unlockRecipe" then
		ok, details = CraftingService.UnlockRecipe(player, tostring(payload.recipeId or ""))
		if ok ~= true then
			if typeof(details) == "table" then
				reason = tostring(details.reason or "UnlockFailed")
				resultDetails = details
			else
				reason = details
			end
		end
	elseif actionType == "craft" then
		ok, details = CraftingService.CraftRecipe(player, tostring(payload.recipeId or ""))
		if ok ~= true then
			if typeof(details) == "table" then
				reason = tostring(details.reason or "CraftFailed")
				resultDetails = details
			else
				reason = details
			end
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
		details = ok == true and details or resultDetails,
	})
end))

Players.PlayerAdded:Connect(protect("BlacksmithService.PlayerAdded", {
	system = "BlacksmithService",
	phase = "lobby",
}, function(player)
	PlayerStateStore.Load(player)
end))

Players.PlayerRemoving:Connect(protect("BlacksmithService.PlayerRemoving", {
	system = "BlacksmithService",
	phase = "lobby",
}, function(player)
	PlayerStateStore.Save(player, true)
end))

print("[BlacksmithService] Ready")
