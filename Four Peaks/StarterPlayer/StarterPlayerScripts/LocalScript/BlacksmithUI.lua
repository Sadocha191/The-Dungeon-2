local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraOffset = Vector3.new(0, 2.5, -8)
local CameraFieldOfView = 45
local CameraRenderStepName = "BlacksmithCameraView"

local HiddenLobbyGuiNames = {
	"Settings",
	"ScreenGuiButtons",
}

local CategoryOrder = {
	"Sword",
	"Scythe",
	"Halberd",
	"Bow",
	"Staff",
	"Pistol",
}

local CategoryLabels = {
	Sword = "Swords",
	Scythe = "Scythes",
	Halberd = "Halberds",
	Bow = "Bows",
	Staff = "Staves",
	Pistol = "Pistols",
}

local TemplateRequiredChildren = {
	"ElementType",
	"Forgable",
	"Locked",
	"RarityName",
	"WeaponIcon",
	"WeaponName",
	"WeaponStat",
	"WeaponType",
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local moduleRoot = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local WeaponConfigs = require(moduleRoot:WaitForChild("WeaponConfigs"))
local MaterialDefinitions = require(moduleRoot:WaitForChild("MaterialDefinitions"))
local BlacksmithTheme = require(moduleRoot:WaitForChild("BlacksmithTheme"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenBlacksmithUI = remoteEvents:WaitForChild("OpenBlacksmithUI")
local BlacksmithSync = remoteEvents:WaitForChild("BlacksmithSync")
local BlacksmithAction = remoteEvents:WaitForChild("BlacksmithAction")

local WEAPON_ICON_FOLDER_NAME = "WeaponIcons"
local ELEMENT_ICON_FOLDER_NAME = "ElementIcons"
local CATEGORY_DEFAULT_ICONS = {
	Sword = "Knight's Oath",
	Scythe = "Reaper's Crescent",
	Halberd = "Warden's Halberd",
	Bow = "Hunter's Longbow",
	Staff = "Apprentice Arcstaff",
	Pistol = "Blackpowder Flintlock",
}
local CURLY_APOSTROPHE = utf8.char(8217)

local function clampInt(value, minValue)
	value = math.floor(tonumber(value) or 0)
	if minValue ~= nil and value < minValue then
		return minValue
	end
	return value
end

local function blendColor(fromColor, toColor, alpha)
	return Color3.new(
		fromColor.R + (toColor.R - fromColor.R) * alpha,
		fromColor.G + (toColor.G - fromColor.G) * alpha,
		fromColor.B + (toColor.B - fromColor.B) * alpha
	)
end

local function getRarityColor(rarity)
	return BlacksmithTheme.GetRarityColor(rarity)
end

local function getElementColor(element)
	return BlacksmithTheme.GetElementColor(element)
end

local function normalizeElementName(element)
	local value = tostring(element or "")
	if value == "Electricity" then
		return "Electric"
	end
	if value == "" then
		return "Physical"
	end
	return value
end

local function readAssetReference(iconObject)
	if not iconObject then
		return nil
	end

	local value = nil
	if iconObject:IsA("StringValue") then
		value = iconObject.Value
	elseif iconObject:IsA("ImageLabel") or iconObject:IsA("ImageButton") then
		value = iconObject.Image
	elseif iconObject:IsA("Decal") or iconObject:IsA("Texture") then
		value = iconObject.Texture
	end

	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function pushUnique(listRef, seen, value)
	if typeof(value) ~= "string" or value == "" or seen[value] then
		return
	end
	seen[value] = true
	table.insert(listRef, value)
end

local function buildTypographyVariants(value)
	local variants = {}
	local seen = {}

	local function push(valueToPush)
		pushUnique(variants, seen, valueToPush)
	end

	push(value)
	if typeof(value) ~= "string" or value == "" then
		return variants
	end

	push(value:gsub("'", CURLY_APOSTROPHE))
	push(value:gsub(CURLY_APOSTROPHE, "'"))

	return variants
end

local function getNamedChildOfClass(parent, name, className)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name and child.ClassName == className then
			return child
		end
	end
	return nil
end

local function collectChildrenOfClass(parent, className)
	local out = {}
	for _, child in ipairs(parent:GetChildren()) do
		if child.ClassName == className then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

local function ensureTextLabel(parent, name, props)
	local label = parent:FindFirstChild(name)
	if label and label:IsA("TextLabel") then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.TextWrapped = props.TextWrapped == true
	label.TextScaled = false
	label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	label.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	label.Font = props.Font or Enum.Font.GothamBold
	label.TextSize = props.TextSize or 14
	label.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	label.Position = props.Position or UDim2.fromScale(0, 0)
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.ZIndex = props.ZIndex or ((parent:IsA("GuiObject") and parent.ZIndex or 1) + 1)
	label.Parent = parent
	return label
end

local gui = playerGui:WaitForChild("BlacksmithGui")
local legacyOverlay = gui:FindFirstChild("overlay")
if legacyOverlay then
	legacyOverlay:Destroy()
end

gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)

local cameraPoint = gui:WaitForChild("BlacksmithCameraPoint")
local mainFrame = gui:WaitForChild("BlacksmithGui")
local backButton = mainFrame:WaitForChild("BackButton"):WaitForChild("BackButton")
local silverLabel = gui:WaitForChild("Silver"):WaitForChild("Frame"):WaitForChild("TextLabel")

backButton.Active = true
backButton.Visible = true

local bottomFrame = mainFrame:WaitForChild("Bottom")
local forgeButton = bottomFrame:WaitForChild("Forge_button")
local forgeButtonText = ensureTextLabel(forgeButton, "ForgeText", {
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Size = UDim2.fromScale(1, 1),
	ZIndex = forgeButton.ZIndex + 1,
})

local materialAmountLabels = {
	bottomFrame:WaitForChild("MaterialAmount1"),
	bottomFrame:WaitForChild("MaterialAmount2"),
	bottomFrame:WaitForChild("MaterialAmount3"),
}

local materialsFrame = bottomFrame:WaitForChild("Materials")
local materialSlots = {
	materialsFrame:WaitForChild("Material_required1"),
	materialsFrame:WaitForChild("Material_required2"),
	materialsFrame:WaitForChild("Material_required3"),
}

local infoInner = mainFrame:WaitForChild("Info"):WaitForChild("Info")
local weaponNameLabel = infoInner:WaitForChild("WeaponName")
local elementTypeLabel = infoInner:WaitForChild("ElementType")
local descriptionLabel = infoInner:WaitForChild("Description")
local passiveLabel = infoInner:WaitForChild("Passive")
local passiveDescLabel = infoInner:WaitForChild("PassiveDesc")
local statLabels = {
	infoInner:WaitForChild("StatName1"),
	infoInner:WaitForChild("StatName2"),
	infoInner:WaitForChild("StatName3"),
	infoInner:WaitForChild("StatName4"),
}

local listRoot = mainFrame:WaitForChild("List")
local categoriesFrame = listRoot:WaitForChild("Categories")
local categoryScroll = getNamedChildOfClass(categoriesFrame, "CategoryList", "ScrollingFrame")
local categoryButtons = categoryScroll and collectChildrenOfClass(categoryScroll, "ImageButton") or {}

local entryScroll = listRoot:WaitForChild("List"):WaitForChild("ScrollingFrame")
local entryLayout = entryScroll:FindFirstChildOfClass("UIListLayout")

local runtimeFolder = gui:FindFirstChild("BlacksmithRuntime")
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "BlacksmithRuntime"
	runtimeFolder.Parent = gui
end

local closeRequested = gui:FindFirstChild("BlacksmithCloseRequested")
if not closeRequested then
	closeRequested = Instance.new("BindableEvent")
	closeRequested.Name = "BlacksmithCloseRequested"
	closeRequested.Parent = gui
end

local popupOverlay = Instance.new("Frame")
popupOverlay.Name = "BlacksmithPopupOverlay"
popupOverlay.Size = UDim2.fromScale(1, 1)
popupOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
popupOverlay.BackgroundTransparency = 0.35
popupOverlay.BorderSizePixel = 0
popupOverlay.Visible = false
popupOverlay.ZIndex = 30
popupOverlay.Parent = gui

local popupCard = Instance.new("Frame")
popupCard.Name = "Card"
popupCard.AnchorPoint = Vector2.new(0.5, 0.5)
popupCard.Position = UDim2.fromScale(0.5, 0.5)
popupCard.Size = UDim2.fromOffset(420, 220)
popupCard.BackgroundColor3 = Color3.fromRGB(18, 22, 29)
popupCard.BorderSizePixel = 0
popupCard.ZIndex = 31
popupCard.Parent = popupOverlay
Instance.new("UICorner", popupCard).CornerRadius = UDim.new(0, 18)

local popupStroke = Instance.new("UIStroke")
popupStroke.Color = Color3.fromRGB(54, 66, 86)
popupStroke.Thickness = 1
popupStroke.Parent = popupCard

local popupTitle = ensureTextLabel(popupCard, "Title", {
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = Color3.fromRGB(246, 246, 246),
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(24, 20),
	Size = UDim2.new(1, -48, 0, 28),
	ZIndex = 32,
})

local popupBody = ensureTextLabel(popupCard, "Body", {
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(220, 220, 220),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	Position = UDim2.fromOffset(24, 60),
	Size = UDim2.new(1, -48, 0, 88),
	ZIndex = 32,
})

local popupPrimaryButton = Instance.new("TextButton")
popupPrimaryButton.Name = "PrimaryButton"
popupPrimaryButton.Position = UDim2.new(0, 24, 1, -58)
popupPrimaryButton.Size = UDim2.new(0.5, -30, 0, 38)
popupPrimaryButton.BackgroundColor3 = Color3.fromRGB(76, 130, 255)
popupPrimaryButton.BorderSizePixel = 0
popupPrimaryButton.AutoButtonColor = true
popupPrimaryButton.Font = Enum.Font.GothamBold
popupPrimaryButton.TextSize = 14
popupPrimaryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
popupPrimaryButton.ZIndex = 32
popupPrimaryButton.Parent = popupCard
Instance.new("UICorner", popupPrimaryButton).CornerRadius = UDim.new(0, 12)

local popupSecondaryButton = Instance.new("TextButton")
popupSecondaryButton.Name = "SecondaryButton"
popupSecondaryButton.AnchorPoint = Vector2.new(1, 0)
popupSecondaryButton.Position = UDim2.new(1, -24, 1, -58)
popupSecondaryButton.Size = UDim2.new(0.5, -30, 0, 38)
popupSecondaryButton.BackgroundColor3 = Color3.fromRGB(44, 50, 62)
popupSecondaryButton.BorderSizePixel = 0
popupSecondaryButton.AutoButtonColor = true
popupSecondaryButton.Font = Enum.Font.GothamBold
popupSecondaryButton.TextSize = 14
popupSecondaryButton.TextColor3 = Color3.fromRGB(238, 238, 238)
popupSecondaryButton.ZIndex = 32
popupSecondaryButton.Parent = popupCard
Instance.new("UICorner", popupSecondaryButton).CornerRadius = UDim.new(0, 12)

local materialTooltip = Instance.new("Frame")
materialTooltip.Name = "MaterialTooltip"
materialTooltip.BackgroundColor3 = Color3.fromRGB(17, 21, 27)
materialTooltip.BackgroundTransparency = 0.06
materialTooltip.BorderSizePixel = 0
materialTooltip.Size = UDim2.fromOffset(260, 116)
materialTooltip.Visible = false
materialTooltip.ZIndex = 40
materialTooltip.Parent = gui
Instance.new("UICorner", materialTooltip).CornerRadius = UDim.new(0, 10)

local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = Color3.fromRGB(69, 76, 89)
tooltipStroke.Thickness = 1
tooltipStroke.Parent = materialTooltip

local tooltipPadding = Instance.new("UIPadding")
tooltipPadding.PaddingTop = UDim.new(0, 12)
tooltipPadding.PaddingBottom = UDim.new(0, 12)
tooltipPadding.PaddingLeft = UDim.new(0, 12)
tooltipPadding.PaddingRight = UDim.new(0, 12)
tooltipPadding.Parent = materialTooltip

local tooltipTitle = ensureTextLabel(materialTooltip, "Title", {
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = Color3.fromRGB(236, 231, 217),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, 0, 0, 24),
	ZIndex = 41,
})

local tooltipDescription = ensureTextLabel(materialTooltip, "Description", {
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(208, 204, 194),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 0, 40),
	ZIndex = 41,
})

local tooltipSource = ensureTextLabel(materialTooltip, "Source", {
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(163, 169, 180),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(0, 74),
	Size = UDim2.new(1, 0, 0, 28),
	ZIndex = 41,
})

local popupConfig = nil
local snapshot = nil
local selectedCategory = nil
local selectedRecipeId = nil
local hiddenLobbyGuiStates = nil
local savedCameraState = nil
local cameraActive = false
local entryTemplate = nil
local runtimeEntryButtons = {}
local hoveredMaterialId = nil
local characterAddedConnection = nil
local characterDescendantAddedConnection = nil
local hiddenCharacterParts = {}
local hiddenCharacterEffects = {}
local hiddenBlacksmithPromptStates = {}
local blacksmithPromptWatcher = nil
local savedMovementState = nil
local folderCache = {
	WeaponIcons = nil,
	ElementIcons = nil,
}
local missingWeaponIconWarnings = {}
local missingElementIconWarnings = {}
local refresh

local function tutorialComplete()
	return player:GetAttribute("TutorialComplete") == true
end

local function closePopup()
	popupConfig = nil
	popupOverlay.Visible = false
end

local function showPopup(config)
	popupConfig = config
	popupTitle.Text = tostring(config.title or "")
	popupBody.Text = tostring(config.body or "")
	popupPrimaryButton.Text = tostring(config.primaryText or "OK")
	popupPrimaryButton.Visible = config.primaryText ~= nil or config.secondaryText == nil
	popupSecondaryButton.Text = tostring(config.secondaryText or "")
	popupSecondaryButton.Visible = config.secondaryText ~= nil
	if popupSecondaryButton.Visible then
		popupPrimaryButton.Position = UDim2.new(0, 24, 1, -58)
		popupPrimaryButton.Size = UDim2.new(0.5, -30, 0, 38)
	else
		popupPrimaryButton.Position = UDim2.new(0, 24, 1, -58)
		popupPrimaryButton.Size = UDim2.new(1, -48, 0, 38)
	end
	popupOverlay.Visible = true
end

popupPrimaryButton.MouseButton1Click:Connect(function()
	if not popupConfig then
		return
	end
	local callback = popupConfig.primaryCallback
	closePopup()
	if typeof(callback) == "function" then
		callback()
	end
end)

popupSecondaryButton.MouseButton1Click:Connect(function()
	if not popupConfig then
		return
	end
	local callback = popupConfig.secondaryCallback
	closePopup()
	if typeof(callback) == "function" then
		callback()
	end
end)

local function hideLobbyUi()
	if hiddenLobbyGuiStates then
		return
	end

	hiddenLobbyGuiStates = {}
	for _, guiName in ipairs(HiddenLobbyGuiNames) do
		local lobbyGui = playerGui:FindFirstChild(guiName)
		if lobbyGui and lobbyGui:IsA("ScreenGui") then
			hiddenLobbyGuiStates[guiName] = lobbyGui.Enabled
			lobbyGui.Enabled = false
		end
	end
end

local function restoreLobbyUi()
	if not hiddenLobbyGuiStates then
		return
	end

	for guiName, wasEnabled in pairs(hiddenLobbyGuiStates) do
		local lobbyGui = playerGui:FindFirstChild(guiName)
		if lobbyGui and lobbyGui:IsA("ScreenGui") then
			lobbyGui.Enabled = wasEnabled
		end
	end

	hiddenLobbyGuiStates = nil
end

local function computeBlacksmithCameraCFrame()
	local targetPosition = cameraPoint.WorldPosition
	local cameraPosition = targetPosition + CameraOffset
	return CFrame.lookAt(cameraPosition, targetPosition)
end

local function applyBlacksmithCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CameraFieldOfView
	camera.CFrame = computeBlacksmithCameraCFrame()
end

local function startBlacksmithCamera()
	if cameraActive then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	savedCameraState = {
		CameraType = camera.CameraType,
		CFrame = camera.CFrame,
		CameraSubject = camera.CameraSubject,
		FieldOfView = camera.FieldOfView,
	}

	cameraActive = true
	RunService:UnbindFromRenderStep(CameraRenderStepName)
	RunService:BindToRenderStep(CameraRenderStepName, Enum.RenderPriority.Camera.Value + 2, applyBlacksmithCamera)
	applyBlacksmithCamera()
end

local function stopBlacksmithCamera()
	if not cameraActive then
		return
	end

	cameraActive = false
	RunService:UnbindFromRenderStep(CameraRenderStepName)

	local camera = Workspace.CurrentCamera
	if camera and savedCameraState then
		camera.CameraType = savedCameraState.CameraType
		camera.CFrame = savedCameraState.CFrame
		camera.CameraSubject = savedCameraState.CameraSubject
		camera.FieldOfView = savedCameraState.FieldOfView
	end

	savedCameraState = nil
end

local function getTooltipViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

local function getMouseGuiPosition()
	local topLeftInset = select(1, GuiService:GetGuiInset())
	local mousePosition = UserInputService:GetMouseLocation()
	return Vector2.new(mousePosition.X - topLeftInset.X, mousePosition.Y - topLeftInset.Y)
end

local function positionTooltip()
	if not materialTooltip.Visible then
		return
	end

	local viewportSize = getTooltipViewportSize()
	local mousePosition = getMouseGuiPosition() + Vector2.new(18, 18)
	local tooltipSize = materialTooltip.AbsoluteSize
	local maxX = math.max(8, viewportSize.X - tooltipSize.X - 8)
	local maxY = math.max(8, viewportSize.Y - tooltipSize.Y - 8)
	local clampedX = math.clamp(mousePosition.X, 8, maxX)
	local clampedY = math.clamp(mousePosition.Y, 8, maxY)
	materialTooltip.Position = UDim2.fromOffset(math.floor(clampedX), math.floor(clampedY))
end

local function hideMaterialTooltip()
	hoveredMaterialId = nil
	materialTooltip.Visible = false
end

local function showMaterialTooltip(materialDef)
	if not materialDef then
		hideMaterialTooltip()
		return
	end

	hoveredMaterialId = materialDef.id
	tooltipTitle.Text = tostring(materialDef.displayName or materialDef.id)
	tooltipDescription.Text = tostring(materialDef.description or "")
	tooltipSource.Text = "Source: " .. tostring(materialDef.source or "Unknown")
	materialTooltip.Visible = true
	task.defer(positionTooltip)
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		positionTooltip()
	end
end)

local function disconnectCharacterVisibilityConnections()
	if characterDescendantAddedConnection then
		characterDescendantAddedConnection:Disconnect()
		characterDescendantAddedConnection = nil
	end
	if characterAddedConnection then
		characterAddedConnection:Disconnect()
		characterAddedConnection = nil
	end
end

local function trackHiddenCharacterPart(part)
	if hiddenCharacterParts[part] == nil then
		hiddenCharacterParts[part] = part.LocalTransparencyModifier
	end
	part.LocalTransparencyModifier = 1
end

local function trackHiddenCharacterEffect(effect)
	local enabled = nil
	if effect:IsA("ParticleEmitter") or effect:IsA("Trail") or effect:IsA("Beam") or effect:IsA("Highlight") then
		enabled = effect.Enabled
	elseif effect:IsA("BillboardGui") or effect:IsA("SurfaceGui") then
		enabled = effect.Enabled
	end

	if enabled == nil then
		return
	end

	if hiddenCharacterEffects[effect] == nil then
		hiddenCharacterEffects[effect] = enabled
	end
	effect.Enabled = false
end

local function hideCharacterDescendant(descendant)
	if descendant:IsA("BasePart") then
		trackHiddenCharacterPart(descendant)
	elseif descendant:IsA("ParticleEmitter")
		or descendant:IsA("Trail")
		or descendant:IsA("Beam")
		or descendant:IsA("Highlight")
		or descendant:IsA("BillboardGui")
		or descendant:IsA("SurfaceGui")
	then
		trackHiddenCharacterEffect(descendant)
	end
end

local function applyLocalCharacterHidden(character)
	if not character then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		hideCharacterDescendant(descendant)
	end

	if characterDescendantAddedConnection then
		characterDescendantAddedConnection:Disconnect()
	end
	characterDescendantAddedConnection = character.DescendantAdded:Connect(function(descendant)
		if gui.Enabled then
			hideCharacterDescendant(descendant)
		end
	end)
end

local function hideLocalCharacter()
	if characterAddedConnection then
		return
	end

	applyLocalCharacterHidden(player.Character)
	characterAddedConnection = player.CharacterAdded:Connect(function(character)
		if not gui.Enabled then
			return
		end
		task.defer(function()
			if gui.Enabled then
				applyLocalCharacterHidden(character)
			end
		end)
	end)
end

local function restoreLocalCharacter()
	disconnectCharacterVisibilityConnections()

	for part, originalTransparency in pairs(hiddenCharacterParts) do
		if part and part.Parent then
			part.LocalTransparencyModifier = originalTransparency
		end
	end
	table.clear(hiddenCharacterParts)

	for effect, originalEnabled in pairs(hiddenCharacterEffects) do
		if effect and effect.Parent and effect.Enabled ~= originalEnabled then
			effect.Enabled = originalEnabled
		end
	end
	table.clear(hiddenCharacterEffects)
end

local function resetFolderCache()
	folderCache.WeaponIcons = nil
	folderCache.ElementIcons = nil
end

local function getFolder(folderName)
	local cached = folderCache[folderName]
	if cached and cached.Parent then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	folderCache[folderName] = folder
	return folder
end

local function resolveIconAsset(folderName, rawCandidates)
	local folder = getFolder(folderName)
	if not folder then
		return nil
	end

	local seen = {}
	local candidates = {}
	for _, candidate in ipairs(rawCandidates or {}) do
		for _, variant in ipairs(buildTypographyVariants(candidate)) do
			pushUnique(candidates, seen, variant)
		end
	end

	for _, candidate in ipairs(candidates) do
		local iconObject = folder:FindFirstChild(candidate)
		local assetRef = readAssetReference(iconObject)
		if assetRef then
			return assetRef
		end
	end

	return nil
end

local function resolveWeaponIconAsset(weaponDef, weaponId, weaponType)
	if not weaponDef then
		return nil
	end

	local candidates = {}
	local seen = {}
	pushUnique(candidates, seen, weaponDef.iconName)
	for _, fallbackName in ipairs(weaponDef.iconFallbackNames or {}) do
		pushUnique(candidates, seen, fallbackName)
	end
	pushUnique(candidates, seen, weaponDef.categoryIconName)
	pushUnique(candidates, seen, CATEGORY_DEFAULT_ICONS[tostring(weaponType or weaponDef.weaponType or "")])

	local assetRef = resolveIconAsset(WEAPON_ICON_FOLDER_NAME, candidates)
	if assetRef then
		missingWeaponIconWarnings[weaponId] = nil
		return assetRef
	end

	if weaponId and not missingWeaponIconWarnings[weaponId] then
		warn("Missing weapon icon:", weaponId, tostring(weaponDef.iconName or ""))
		missingWeaponIconWarnings[weaponId] = true
	end

	return nil
end

local function resolveElementIconAsset(elementName)
	local normalizedElement = normalizeElementName(elementName)
	local assetRef = resolveIconAsset(ELEMENT_ICON_FOLDER_NAME, { normalizedElement })
	if assetRef then
		missingElementIconWarnings[normalizedElement] = nil
		return assetRef
	end

	if not missingElementIconWarnings[normalizedElement] then
		warn("Missing element icon:", normalizedElement)
		missingElementIconWarnings[normalizedElement] = true
	end

	return nil
end

local function snapshotMovementState()
	if savedMovementState then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	savedMovementState = {
		humanoid = humanoid,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		autoRotate = humanoid.AutoRotate,
		platformStand = humanoid.PlatformStand,
	}
end

local function restoreMovementState()
	if not savedMovementState then
		return
	end

	local humanoid = savedMovementState.humanoid
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = savedMovementState.walkSpeed
		humanoid.JumpPower = savedMovementState.jumpPower
		humanoid.AutoRotate = savedMovementState.autoRotate
		humanoid.PlatformStand = savedMovementState.platformStand
	end

	savedMovementState = nil
end

local function getBlacksmithModel()
	local npcs = Workspace:FindFirstChild("NPCs")
	return npcs and (npcs:FindFirstChild("Blacksmith") or npcs:FindFirstChild("BlacksmithNPC")) or nil
end

local function setPromptHidden(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	if hiddenBlacksmithPromptStates[prompt] == nil then
		hiddenBlacksmithPromptStates[prompt] = prompt.Enabled
	end
	prompt.Enabled = false
end

local function hideBlacksmithPrompts()
	if blacksmithPromptWatcher then
		return
	end

	local smith = getBlacksmithModel()
	if not smith then
		return
	end

	for _, descendant in ipairs(smith:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			setPromptHidden(descendant)
		end
	end

	blacksmithPromptWatcher = smith.DescendantAdded:Connect(function(descendant)
		if gui.Enabled and descendant:IsA("ProximityPrompt") then
			setPromptHidden(descendant)
		end
	end)
end

local function restoreBlacksmithPrompts()
	if blacksmithPromptWatcher then
		blacksmithPromptWatcher:Disconnect()
		blacksmithPromptWatcher = nil
	end

	for prompt, wasEnabled in pairs(hiddenBlacksmithPromptStates) do
		if prompt and prompt.Parent then
			prompt.Enabled = wasEnabled
		end
	end
	table.clear(hiddenBlacksmithPromptStates)
end

local function getCraftEntries()
	return snapshot and snapshot.craftEntries or {}
end

local function isFullTemplate(button)
	if not button or not button:IsA("ImageButton") or button.Name ~= "WeaponBackground" then
		return false
	end

	for _, childName in ipairs(TemplateRequiredChildren) do
		if not button:FindFirstChild(childName) then
			return false
		end
	end

	return true
end

local function initializeEntryTemplate()
	if entryTemplate and entryTemplate.Parent then
		return entryTemplate
	end

	local sourceTemplate = nil
	local firstSpacer = nil
	for _, child in ipairs(entryScroll:GetChildren()) do
		if not firstSpacer and child.Name == "WeaponBackgroundSpacer" and child:IsA("GuiObject") then
			firstSpacer = child
		end
		if isFullTemplate(child) then
			sourceTemplate = child
			break
		end
	end

	if not sourceTemplate then
		warn("[BlacksmithUI] Missing authored WeaponBackground template")
		return nil
	end

	if entryLayout and firstSpacer then
		entryLayout.Padding = UDim.new(firstSpacer.Size.Y.Scale, firstSpacer.Size.Y.Offset)
	end

	local storedTemplate = runtimeFolder:FindFirstChild("WeaponBackgroundTemplate")
	if storedTemplate and storedTemplate:IsA("ImageButton") then
		entryTemplate = storedTemplate
	else
		entryTemplate = sourceTemplate:Clone()
		entryTemplate.Name = "WeaponBackgroundTemplate"
		entryTemplate.Visible = false
		entryTemplate.Parent = runtimeFolder
	end

	for _, child in ipairs(entryScroll:GetChildren()) do
		if child ~= entryLayout and (child.Name == "WeaponBackground" or child.Name == "WeaponBackgroundSpacer") then
			child:Destroy()
		end
	end

	return entryTemplate
end

local function clearRuntimeEntryButtons()
	for _, button in ipairs(runtimeEntryButtons) do
		if button and button.Parent then
			button:Destroy()
		end
	end
	table.clear(runtimeEntryButtons)
end

local function buildEntriesByCategory()
	local byCategory = {}
	for _, category in ipairs(CategoryOrder) do
		byCategory[category] = {}
	end

	for _, entry in ipairs(getCraftEntries()) do
		local weaponDef = WeaponConfigs.Get(entry.weaponId)
		local category = tostring(entry.weaponType or (weaponDef and weaponDef.weaponType) or "")
		if byCategory[category] then
			table.insert(byCategory[category], entry)
		end
	end

	return byCategory
end

local function getSelectedCategoryEntries()
	local byCategory = buildEntriesByCategory()
	if not byCategory[selectedCategory] or #byCategory[selectedCategory] == 0 then
		for _, category in ipairs(CategoryOrder) do
			if byCategory[category] and #byCategory[category] > 0 then
				selectedCategory = category
				break
			end
		end
	end
	return byCategory[selectedCategory] or {}
end

local function getSelectedEntry()
	local entries = getSelectedCategoryEntries()
	for _, entry in ipairs(entries) do
		if entry.recipeId == selectedRecipeId then
			return entry
		end
	end
	if entries[1] then
		selectedRecipeId = entries[1].recipeId
	end
	return entries[1]
end

local function buildStatLines(weaponDef)
	local lines = {}
	if not weaponDef then
		return { "-", "-", "-", "-" }
	end

	local stats = weaponDef.stats or {}
	local combat = weaponDef.combat or {}
	lines[#lines + 1] = string.format("ATK %d", clampInt(combat.baseAtk or weaponDef.baseDamage, 0))

	local candidates = {
		{ label = "HP", value = clampInt(stats.HP, 0), suffix = "" },
		{ label = "DEF", value = clampInt(stats.DEF, 0), suffix = "" },
		{ label = "SPD", value = clampInt(stats.SPD, 0), suffix = "%" },
		{ label = "CRIT", value = clampInt(stats.CRIT_RATE, 0), suffix = "%" },
		{ label = "CRIT DMG", value = clampInt(stats.CRIT_DMG, 0), suffix = "%" },
		{ label = "LIFESTEAL", value = clampInt(stats.LIFESTEAL, 0), suffix = "%" },
	}

	for _, candidate in ipairs(candidates) do
		if candidate.value > 0 then
			lines[#lines + 1] = string.format("%s +%d%s", candidate.label, candidate.value, candidate.suffix)
		end
		if #lines >= 4 then
			break
		end
	end

	while #lines < 4 do
		lines[#lines + 1] = "-"
	end

	return lines
end

local function getWeaponDisplayName(weaponDef, entry)
	local value = (weaponDef and (weaponDef.weaponName or weaponDef.name or weaponDef.displayName))
		or (entry and (entry.name or entry.weaponId))
		or ""
	return tostring(value)
end

local function getWeaponTypeLabel(weaponDef, entry, normalizedElement)
	local value = weaponDef and weaponDef.weaponTypeLabel or nil
	if typeof(value) == "string" and value ~= "" then
		return value
	end

	local category = (weaponDef and (weaponDef.category or weaponDef.weaponType)) or (entry and entry.weaponType) or ""
	category = tostring(category or "")
	if category == "" then
		return tostring(normalizedElement or "")
	end

	return string.format("%s %s", tostring(normalizedElement or ""), category)
end

local function bindMaterialTooltip(slotFrame)
	if slotFrame:GetAttribute("TooltipBound") == true then
		return
	end

	slotFrame:SetAttribute("TooltipBound", true)
	slotFrame.Active = true

	slotFrame.MouseEnter:Connect(function()
		if not gui.Enabled or not slotFrame.Visible then
			return
		end
		local materialId = slotFrame:GetAttribute("MaterialId")
		if typeof(materialId) ~= "string" or materialId == "" then
			return
		end
		showMaterialTooltip(MaterialDefinitions.Get(materialId))
	end)

	slotFrame.MouseLeave:Connect(function()
		local materialId = slotFrame:GetAttribute("MaterialId")
		if hoveredMaterialId == materialId then
			hideMaterialTooltip()
		end
	end)
end

for _, slotFrame in ipairs(materialSlots) do
	bindMaterialTooltip(slotFrame)
end

local function setMaterialSlot(slotFrame, textLabel, materialEntry)
	local icon = slotFrame:FindFirstChild("Material_Icon")

	if not materialEntry then
		textLabel.Text = ""
		textLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		slotFrame.Visible = false
		textLabel.Visible = false
		slotFrame:SetAttribute("MaterialId", "")
		if icon and icon:IsA("ImageLabel") then
			icon.Visible = false
			icon.Image = ""
		end
		return
	end

	local owned = clampInt(materialEntry.owned, 0)
	local required = clampInt(materialEntry.amount, 0)
	local missing = clampInt(materialEntry.missing, 0)
	local materialDef = MaterialDefinitions.Get(materialEntry.id)
	local assetRef = materialDef and MaterialDefinitions.GetAssetRef(materialEntry.id) or nil

	textLabel.Text = string.format("%d/%d", owned, required)
	textLabel.TextColor3 = missing > 0 and Color3.fromRGB(255, 152, 152) or Color3.fromRGB(214, 255, 214)
	textLabel.Visible = true
	slotFrame.Visible = true
	slotFrame:SetAttribute("MaterialId", materialDef and materialDef.id or tostring(materialEntry.id or ""))

	if icon and icon:IsA("ImageLabel") and typeof(assetRef) == "string" and assetRef ~= "" then
		icon.Image = assetRef
		icon.Visible = true
	else
		if icon and icon:IsA("ImageLabel") then
			icon.Image = ""
			icon.Visible = false
		end
	end
end

local function renderDetails()
	local entry = getSelectedEntry()
	if not entry then
		silverLabel.Text = snapshot and tostring(clampInt(snapshot.silver, 0)) or "0"
		weaponNameLabel.Text = ""
		elementTypeLabel.Text = ""
		descriptionLabel.Text = ""
		passiveLabel.Text = ""
		passiveDescLabel.Text = ""
		for index = 1, 4 do
			statLabels[index].Text = ""
		end
		for index = 1, 3 do
			setMaterialSlot(materialSlots[index], materialAmountLabels[index], nil)
		end
		forgeButtonText.Text = "Forge"
		forgeButton.Active = false
		forgeButton.AutoButtonColor = false
		forgeButton.ImageColor3 = Color3.fromRGB(110, 110, 110)
		return
	end

	local weaponDef = WeaponConfigs.Get(entry.weaponId)
	local rarityColor = getRarityColor(entry.rarity)
	local element = normalizeElementName((weaponDef and weaponDef.element) or "Physical")

	silverLabel.Text = tostring(clampInt(snapshot and snapshot.silver, 0))
	weaponNameLabel.Text = getWeaponDisplayName(weaponDef, entry)
	weaponNameLabel.TextColor3 = rarityColor
	elementTypeLabel.Text = string.format("Element type: %s", element)
	elementTypeLabel.TextColor3 = getElementColor(element)

	if weaponDef then
		descriptionLabel.Text = weaponDef.description ~= "" and tostring(weaponDef.description) or "No description."
		local passiveName = weaponDef.passiveName ~= "" and tostring(weaponDef.passiveName)
			or (weaponDef.abilityName ~= "" and tostring(weaponDef.abilityName) or "-")
		passiveLabel.Text = "Passive: " .. passiveName
		passiveDescLabel.Text = weaponDef.passiveDescription ~= "" and tostring(weaponDef.passiveDescription)
			or (weaponDef.abilityDescription ~= "" and tostring(weaponDef.abilityDescription) or "No passive description.")
	else
		descriptionLabel.Text = "Weapon definition missing."
		passiveLabel.Text = "Passive: -"
		passiveDescLabel.Text = "-"
	end

	local statLines = buildStatLines(weaponDef)
	for index = 1, 4 do
		statLabels[index].Text = statLines[index] ~= "-" and statLines[index] or ""
	end

	local materials = entry.materials or {}
	for index = 1, 3 do
		setMaterialSlot(materialSlots[index], materialAmountLabels[index], materials[index])
	end

	forgeButton.Active = true
	forgeButton.AutoButtonColor = true
	forgeButton.ImageColor3 = rarityColor

	if entry.unlocked ~= true then
		forgeButtonText.Text = "Locked"
	elseif entry.unique == true and entry.alreadyOwned == true then
		forgeButtonText.Text = "Owned"
	else
		forgeButtonText.Text = "Forge"
	end
end

local function renderEntryButtons()
	clearRuntimeEntryButtons()

	local template = initializeEntryTemplate()
	if not template then
		return
	end

	local entries = getSelectedCategoryEntries()
	local selectedEntry = getSelectedEntry()
	local summaryIcon = MaterialDefinitions.GetSummaryIcon()

	for index, entry in ipairs(entries) do
		local button = template:Clone()
		local weaponDef = WeaponConfigs.Get(entry.weaponId)
		local accent = getRarityColor(entry.rarity)
		local element = normalizeElementName((weaponDef and weaponDef.element) or "Physical")
		local selected = selectedEntry and selectedEntry.recipeId == entry.recipeId

		button.Name = "WeaponBackground"
		button.Visible = true
		button.LayoutOrder = index
		button.Active = true
		button.AutoButtonColor = true
		button.ImageColor3 = selected and blendColor(Color3.fromRGB(255, 255, 255), accent, 0.35) or Color3.fromRGB(255, 255, 255)
		button.Parent = entryScroll

		local weaponIcon = button:FindFirstChild("WeaponIcon")
		if weaponIcon and weaponIcon:IsA("ImageLabel") then
			local weaponIconAsset = resolveWeaponIconAsset(
				weaponDef,
				tostring(entry.weaponId or ""),
				tostring(entry.weaponType or (weaponDef and weaponDef.weaponType) or "")
			)
			if typeof(weaponIconAsset) == "string" and weaponIconAsset ~= "" then
				weaponIcon.Image = weaponIconAsset
				weaponIcon.Visible = true
			else
				weaponIcon.Image = ""
				weaponIcon.Visible = false
			end
		end

		local weaponName = button:FindFirstChild("WeaponName")
		if weaponName and weaponName:IsA("TextLabel") then
			weaponName.Text = getWeaponDisplayName(weaponDef, entry)
		end

		local weaponType = button:FindFirstChild("WeaponType")
		if weaponType and weaponType:IsA("TextLabel") then
			weaponType.Text = getWeaponTypeLabel(weaponDef, entry, element)
		end

		local weaponStat = button:FindFirstChild("WeaponStat")
		if weaponStat and weaponStat:IsA("TextLabel") then
			local combat = weaponDef and weaponDef.combat or {}
			weaponStat.Text = string.format("ATK %d", clampInt(combat.baseAtk or (weaponDef and weaponDef.baseDamage), 0))
		end

		local rarityName = button:FindFirstChild("RarityName")
		if rarityName and rarityName:IsA("TextLabel") then
			rarityName.Text = tostring(entry.rarity or "")
			rarityName.TextColor3 = accent
		end

		local elementIcon = button:FindFirstChild("ElementType")
		if elementIcon and elementIcon:IsA("ImageLabel") then
			local elementIconAsset = resolveElementIconAsset((weaponDef and weaponDef.elementIconName) or element)
			if typeof(elementIconAsset) == "string" and elementIconAsset ~= "" then
				elementIcon.Image = elementIconAsset
				elementIcon.Visible = true
				elementIcon.ImageColor3 = getElementColor(element)
			else
				elementIcon.Image = ""
				elementIcon.Visible = false
			end
		end

		local forgable = button:FindFirstChild("Forgable")
		if forgable and forgable:IsA("Frame") then
			forgable.Visible = entry.unlocked == true

			local materialText = forgable:FindFirstChild("MaterialText")
			if materialText and materialText:IsA("TextLabel") then
				local summary = entry.materialProgressSummary or {}
				materialText.Text = string.format(
					"%d/%d materials",
					clampInt(summary.owned, 0),
					clampInt(summary.required, 0)
				)
				materialText.TextColor3 = clampInt(summary.missing, 0) > 0
					and Color3.fromRGB(228, 128, 118)
					or Color3.fromRGB(184, 218, 166)
			end

			local silverText = forgable:FindFirstChild("SilverText")
			if silverText and silverText:IsA("TextLabel") then
				silverText.Text = string.format("%d silver", clampInt(entry.craftSilverCost, 0))
				silverText.TextColor3 = clampInt(entry.craftSilverMissing, 0) > 0
					and Color3.fromRGB(228, 128, 118)
					or Color3.fromRGB(224, 198, 120)
			end

			local materialIcon = forgable:FindFirstChild("MaterialIcon")
			if materialIcon and materialIcon:IsA("ImageLabel") then
				if typeof(summaryIcon) == "string" and summaryIcon ~= "" then
					materialIcon.Image = summaryIcon
					materialIcon.Visible = true
				else
					materialIcon.Visible = false
				end
			end
		end

		local locked = button:FindFirstChild("Locked")
		if locked and locked:IsA("Frame") then
			locked.Visible = entry.unlocked ~= true
			local lockedText = locked:FindFirstChild("LockedText")
			if lockedText and lockedText:IsA("TextLabel") then
				lockedText.Text = "Locked"
			end
		end

		button.MouseButton1Click:Connect(function()
			selectedRecipeId = entry.recipeId
			refresh()
		end)

		table.insert(runtimeEntryButtons, button)
	end
end

local function renderCategoryButtons()
	local byCategory = buildEntriesByCategory()
	if not selectedCategory then
		for _, category in ipairs(CategoryOrder) do
			if byCategory[category] and #byCategory[category] > 0 then
				selectedCategory = category
				break
			end
		end
	end

	for index, button in ipairs(categoryButtons) do
		local category = CategoryOrder[index]
		local label = ensureTextLabel(button, "CategoryText", {
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Size = UDim2.fromScale(1, 1),
			ZIndex = button.ZIndex + 1,
		})

		if not category then
			button.Visible = false
			continue
		end

		local entryCount = byCategory[category] and #byCategory[category] or 0
		local active = selectedCategory == category
		button.Visible = true
		button.Active = entryCount > 0
		button.AutoButtonColor = entryCount > 0
		button.ImageColor3 = active and Color3.fromRGB(255, 212, 111)
			or (entryCount > 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120))
		label.Text = string.format("%s\n(%d)", tostring(CategoryLabels[category] or category), entryCount)
		label.TextColor3 = active and Color3.fromRGB(24, 28, 34)
			or (entryCount > 0 and Color3.fromRGB(248, 248, 248) or Color3.fromRGB(180, 180, 180))
	end
end

refresh = function()
	renderCategoryButtons()
	renderEntryButtons()
	renderDetails()
end

local function buildMissingMaterialLines(missingMaterials)
	if typeof(missingMaterials) ~= "table" or #missingMaterials == 0 then
		return "You are missing required materials."
	end

	local lines = { "You are missing required materials.", "", "Missing:" }
	for _, entry in ipairs(missingMaterials) do
		lines[#lines + 1] = string.format("%s x%d", tostring(entry.name or entry.id), clampInt(entry.amount, 0))
	end
	return table.concat(lines, "\n")
end

local function showMissingSilverPopup(missingSilver)
	showPopup({
		title = "Not Enough Silver",
		body = string.format("Missing %d silver.", clampInt(missingSilver, 0)),
		primaryText = "OK",
	})
end

local function showMissingMaterialsPopup(missingMaterials)
	showPopup({
		title = "Missing Materials",
		body = buildMissingMaterialLines(missingMaterials),
		primaryText = "OK",
	})
end

local function showGenericPopup(title, body)
	showPopup({
		title = title,
		body = body,
		primaryText = "OK",
	})
end

local function handleServerFailure(result)
	if typeof(result) ~= "table" or result.ok == true then
		return
	end

	local reason = tostring(result.reason or "")
	local details = typeof(result.details) == "table" and result.details or nil
	if reason == "NotEnoughSilver" then
		showMissingSilverPopup(details and details.missingSilver or 0)
	elseif reason == "MissingMaterials" or reason == "MissingMineResources" or reason == "MissingMobMaterials" then
		showMissingMaterialsPopup(details and details.missingMaterials or nil)
	elseif reason == "AlreadyOwned" then
		showGenericPopup("Already Owned", "You already own this weapon.")
	elseif reason == "LevelLocked" then
		showGenericPopup("Level Locked", "Your account level is too low for this recipe.")
	elseif reason == "RecipeLocked" then
		showGenericPopup("Recipe Locked", "Unlock this recipe before forging the weapon.")
	else
		showGenericPopup("Action Failed", reason ~= "" and ("Blacksmith action failed: " .. reason) or "Blacksmith action failed.")
	end
end

local function closeUI()
	if not gui.Enabled then
		return
	end

	print("[BlacksmithUI] Closing blacksmith UI")
	snapshot = nil
	selectedRecipeId = nil
	selectedCategory = nil
	hideMaterialTooltip()
	closePopup()
	refresh()
	stopBlacksmithCamera()
	restoreMovementState()
	restoreLobbyUi()
	restoreLocalCharacter()
	restoreBlacksmithPrompts()
	gui.Enabled = false
end

local function openUI()
	if not tutorialComplete() then
		return
	end
	if gui.Enabled then
		return
	end

	MaterialDefinitions.RefreshAssetRefs()
	resetFolderCache()
	snapshot = nil
	selectedRecipeId = nil
	selectedCategory = nil
	hideMaterialTooltip()
	snapshotMovementState()
	gui.Enabled = true
	hideBlacksmithPrompts()
	hideLobbyUi()
	hideLocalCharacter()
	startBlacksmithCamera()
	BlacksmithAction:FireServer({ type = "request" })
	refresh()
end

local function requestCraftAction(entry)
	if not entry then
		return
	end

	if entry.levelMet == false then
		showGenericPopup("Level Locked", string.format("Reach account level %d first.", clampInt(entry.requiredLevel, 1)))
		return
	end

	if entry.unlocked ~= true then
		showGenericPopup("Recipe Locked", "Find and unlock this weapon recipe before forging it.")
		return
	end

	if entry.unique == true and entry.alreadyOwned == true then
		showGenericPopup("Already Owned", "You already own this weapon.")
		return
	end

	if clampInt(entry.craftSilverMissing, 0) > 0 then
		showMissingSilverPopup(entry.craftSilverMissing)
		return
	end

	if typeof(entry.missingMaterials) == "table" and #entry.missingMaterials > 0 then
		showMissingMaterialsPopup(entry.missingMaterials)
		return
	end

	showPopup({
		title = "Confirm Forge",
		body = string.format(
			"Forge %s for %d silver?",
			getWeaponDisplayName(WeaponConfigs.Get(entry.weaponId), entry),
			clampInt(entry.craftSilverCost, 0)
		),
		primaryText = "Confirm",
		secondaryText = "Cancel",
		primaryCallback = function()
			BlacksmithAction:FireServer({
				type = "craft",
				recipeId = entry.recipeId,
			})
		end,
	})
end

forgeButton.MouseButton1Click:Connect(function()
	requestCraftAction(getSelectedEntry())
end)

for index, button in ipairs(categoryButtons) do
	local category = CategoryOrder[index]
	button.MouseButton1Click:Connect(function()
		if not category then
			return
		end
		local entriesByCategory = buildEntriesByCategory()
		if not entriesByCategory[category] or #entriesByCategory[category] == 0 then
			return
		end
		selectedCategory = category
		selectedRecipeId = nil
		refresh()
	end)
end

local function isPromptInsideBlacksmith(prompt)
	local smith = getBlacksmithModel()
	if not smith then
		return false
	end

	local current = prompt and prompt.Parent
	while current do
		if current == smith then
			return true
		end
		current = current.Parent
	end

	return false
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if not gui.Enabled then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		if popupOverlay.Visible then
			closePopup()
		else
			closeUI()
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, localPlayer)
	if localPlayer ~= player or gui.Enabled then
		return
	end
	if isPromptInsideBlacksmith(prompt) then
		openUI()
	end
end)

OpenBlacksmithUI.OnClientEvent:Connect(function()
	openUI()
end)

BlacksmithSync.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	snapshot = data
	handleServerFailure(data.lastResult)
	refresh()
end)

closeRequested.Event:Connect(function()
	closeUI()
end)

backButton.Activated:Connect(function()
	print("[BlacksmithUI] BackButton clicked")
	closeUI()
end)

script.Destroying:Connect(function()
	hideMaterialTooltip()
	closePopup()
	stopBlacksmithCamera()
	restoreMovementState()
	restoreLobbyUi()
	restoreLocalCharacter()
	restoreBlacksmithPrompts()
end)
