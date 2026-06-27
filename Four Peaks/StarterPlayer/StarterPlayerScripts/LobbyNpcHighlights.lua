local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts")
local Config = require(moduleFolder:WaitForChild("LobbyPresentationConfig"))

local NPC_FOLDER_NAME = "NPCs"
local HIGHLIGHT_NAME = "LobbyNpcHighlight"

local INTERACTIVE_NPC_NAMES = {
	Blacksmith = true,
	Witch = true,
	Wiedzma = true,
	Knight = true,
	CharacterCreatorNPC = true,
	CharacterCreationNPC = true,
	WeaponBannerNPC = true,
	MissionNPC = true,
}

local highlightRange = math.max(1, tonumber(Config.NpcHighlightRange) or 15)
local fadeSpeed = math.max(1, tonumber(Config.NpcHighlightFadeSpeed) or 10)
local fillTransparency = math.clamp(tonumber(Config.NpcHighlightFillTransparency) or 1, 0, 1)
local visibleOutlineTransparency = math.clamp(tonumber(Config.NpcHighlightVisibleOutlineTransparency) or 0, 0, 1)
local hiddenOutlineTransparency = math.clamp(tonumber(Config.NpcHighlightHiddenOutlineTransparency) or 1, 0, 1)

local tracked = {}
local npcFolderConnection: RBXScriptConnection? = nil
local npcDescendantConnection: RBXScriptConnection? = nil

local function getNpcFolder(): Instance?
	return workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function getLocalRoot(): BasePart?
	local character = localPlayer.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local primary = character.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end

	return nil
end

local function findRootPart(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local primary = model.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function hasPrompt(model: Model): boolean
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			return true
		end
	end
	return false
end

local function getTopLevelNpcModel(instance: Instance): Model?
	local npcFolder = getNpcFolder()
	if not npcFolder then
		return nil
	end

	local current: Instance? = instance
	while current and current ~= npcFolder do
		local parent = current.Parent
		if parent == npcFolder and current:IsA("Model") then
			return current
		end
		current = parent
	end

	return nil
end

local function isInteractiveNpc(model: Model): boolean
	local npcFolder = getNpcFolder()
	if not npcFolder or not model:IsDescendantOf(npcFolder) then
		return false
	end

	if getTopLevelNpcModel(model) ~= model then
		return false
	end

	if Players:GetPlayerFromCharacter(model) then
		return false
	end

	if INTERACTIVE_NPC_NAMES[model.Name] then
		return true
	end

	if typeof(model:GetAttribute("TutorialNpcId")) == "string" then
		return true
	end

	return hasPrompt(model)
end

local function configureHighlight(highlight: Highlight, model: Model)
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = fillTransparency
	highlight.OutlineTransparency = hiddenOutlineTransparency
	highlight.Enabled = false
end

local function ensureHighlight(model: Model): Highlight
	local existing = model:FindFirstChild(HIGHLIGHT_NAME)
	if existing and existing:IsA("Highlight") then
		configureHighlight(existing, model)
		return existing
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	configureHighlight(highlight, model)
	highlight.Parent = model
	return highlight
end

local function trackModel(model: Model)
	if tracked[model] or not isInteractiveNpc(model) then
		return
	end

	tracked[model] = {
		highlight = ensureHighlight(model),
		rootPart = findRootPart(model),
		alpha = 0,
	}
end

local function scanNpcFolder()
	local npcFolder = getNpcFolder()
	if not npcFolder then
		return
	end

	for _, child in ipairs(npcFolder:GetChildren()) do
		if child:IsA("Model") then
			trackModel(child)
		end
	end
end

local function bindNpcFolder(folder: Instance)
	if npcDescendantConnection then
		npcDescendantConnection:Disconnect()
		npcDescendantConnection = nil
	end

	npcDescendantConnection = folder.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			task.defer(function()
				trackModel(instance)
			end)
			return
		end

		if instance:IsA("ProximityPrompt") then
			local model = getTopLevelNpcModel(instance)
			if model then
				trackModel(model)
			end
		end
	end)

	scanNpcFolder()
end

local existingNpcFolder = getNpcFolder()
if existingNpcFolder then
	bindNpcFolder(existingNpcFolder)
end

npcFolderConnection = workspace.ChildAdded:Connect(function(child)
	if child.Name == NPC_FOLDER_NAME then
		bindNpcFolder(child)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local localRoot = getLocalRoot()
	local blend = math.clamp(dt * fadeSpeed, 0, 1)

	for model, state in pairs(tracked) do
		local highlight: Highlight = state.highlight
		if not model.Parent or not highlight.Parent then
			tracked[model] = nil
			if highlight.Parent then
				highlight:Destroy()
			end
			continue
		end

		local rootPart = state.rootPart
		if not rootPart or not rootPart.Parent then
			rootPart = findRootPart(model)
			state.rootPart = rootPart
		end

		local targetAlpha = 0
		if localRoot and rootPart then
			local distance = (localRoot.Position - rootPart.Position).Magnitude
			if distance <= highlightRange then
				targetAlpha = 1
			end
		end

		state.alpha += (targetAlpha - state.alpha) * blend

		if state.alpha > 0.01 or targetAlpha > 0 then
			highlight.Enabled = true
			highlight.FillTransparency = fillTransparency
			highlight.OutlineTransparency = hiddenOutlineTransparency
				+ (visibleOutlineTransparency - hiddenOutlineTransparency) * state.alpha
		else
			state.alpha = 0
			highlight.Enabled = false
			highlight.OutlineTransparency = hiddenOutlineTransparency
		end
	end
end)

script.Destroying:Connect(function()
	if npcFolderConnection then
		npcFolderConnection:Disconnect()
	end
	if npcDescendantConnection then
		npcDescendantConnection:Disconnect()
	end
	for model, state in pairs(tracked) do
		if state.highlight and state.highlight.Parent then
			state.highlight:Destroy()
		end
		tracked[model] = nil
	end
end)

print("[LobbyNpcHighlights] Ready")
