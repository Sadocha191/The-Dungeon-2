assert(plugin, "This script must be run as a Roblox Studio plugin.")

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local REVIEWED_TAG = "MeshCollisionReviewed"
local LEGACY_CHANGED_TAG = "MeshCollisionChanged"
local SETTINGS_PREFIX = "MeshCollisionBrowserLite_"
local DEFAULT_TIP = "Tip: hover a button to see what it does."

local COLORS = {
	Bg = Color3.fromRGB(24, 24, 28),
	Panel = Color3.fromRGB(34, 34, 40),
	Text = Color3.fromRGB(240, 240, 245),
	Muted = Color3.fromRGB(170, 170, 180),
	Button = Color3.fromRGB(58, 58, 70),
	Blue = Color3.fromRGB(70, 125, 255),
	Green = Color3.fromRGB(65, 170, 100),
	Orange = Color3.fromRGB(220, 145, 55),
	Red = Color3.fromRGB(210, 80, 80),
	Purple = Color3.fromRGB(145, 95, 220),
	Yellow = Color3.fromRGB(230, 190, 70),
}

local FIDELITY_LABELS = {
	[Enum.CollisionFidelity.Default] = "Default",
	[Enum.CollisionFidelity.Hull] = "Hull",
	[Enum.CollisionFidelity.Box] = "Box",
	[Enum.CollisionFidelity.PreciseConvexDecomposition] = "Precise",
}

local function getSavedSetting(key, defaultValue)
	local success, value = pcall(function()
		return plugin:GetSetting(SETTINGS_PREFIX .. key)
	end)
	if success and value ~= nil and typeof(value) == typeof(defaultValue) then
		return value
	end
	return defaultValue
end

local settings = {
	sameName = getSavedSetting("SameName", false),
	confirmLarge = getSavedSetting("ConfirmLarge", true),
	threshold = math.max(2, math.floor(getSavedSetting("Threshold", 10))),
	modelByModel = getSavedSetting("ModelByModel", true),
	skipTagged = getSavedSetting("SkipTagged", true),
	autoAdvance = getSavedSetting("AutoAdvance", true),
}

local state = {
	allMeshes = {},
	browseMeshes = {},
	filteredMeshes = {},
	currentIndex = 0,
	currentFilter = nil,
	autoFocus = true,
	preview = nil,
	pending = nil,
	activeTab = "Browser",
	message = "Ready. Click Rescan to browse Workspace.",
}

local function saveSetting(key, value)
	pcall(function()
		plugin:SetSetting(SETTINGS_PREFIX .. key, value)
	end)
end

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	false,
	460,
	720,
	420,
	620
)
local widget = plugin:CreateDockWidgetPluginGuiAsync("MeshCollisionBrowser_Lite_Final", widgetInfo)
widget.Title = "Mesh Collision Browser Lite"

local toolbar = plugin:CreateToolbar("Mesh Collision Browser Lite")
local toolbarButton = toolbar:CreateButton(
	"MeshCollisionBrowserLiteButton",
	"Browse MeshPart CollisionFidelity",
	"",
	"Collision Lite"
)
toolbarButton.ClickableWhenViewportHidden = true

local root = Instance.new("Frame")
root.BackgroundColor3 = COLORS.Bg
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = widget

local function roundCorners(object)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = object
end

local function makeLabel(parent, text, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color or COLORS.Text
	label.TextSize = textSize or 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent, text, color)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or COLORS.Button
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamSemibold
	button.Text = text
	button.TextColor3 = COLORS.Text
	button.TextSize = 13
	button.TextWrapped = true
	button.Parent = parent
	roundCorners(button)
	return button
end

local headerPanel = Instance.new("Frame")
headerPanel.BackgroundColor3 = COLORS.Panel
headerPanel.BorderSizePixel = 0
headerPanel.Position = UDim2.new(0, 10, 0, 10)
headerPanel.Size = UDim2.new(1, -20, 0, 58)
headerPanel.Parent = root
roundCorners(headerPanel)

local headerTitle = makeLabel(
	headerPanel,
	"Mesh Collision Browser Lite",
	UDim2.new(0, 10, 0, 7),
	UDim2.new(1, -20, 0, 25),
	19,
	COLORS.Text
)
headerTitle.Font = Enum.Font.GothamBold
makeLabel(
	headerPanel,
	"Browse and preview MeshPart collision fidelity",
	UDim2.new(0, 10, 0, 32),
	UDim2.new(1, -20, 0, 18),
	12,
	COLORS.Muted
)

local tabPanel = Instance.new("Frame")
tabPanel.BackgroundColor3 = COLORS.Panel
tabPanel.BorderSizePixel = 0
tabPanel.Position = UDim2.new(0, 10, 0, 76)
tabPanel.Size = UDim2.new(1, -20, 0, 48)
tabPanel.Parent = root
roundCorners(tabPanel)

local browserTabButton = makeButton(tabPanel, "Browser", COLORS.Blue)
browserTabButton.Position = UDim2.new(0, 8, 0, 7)
browserTabButton.Size = UDim2.new(0.5, -12, 0, 34)
local settingsTabButton = makeButton(tabPanel, "Settings")
settingsTabButton.Position = UDim2.new(0.5, 4, 0, 7)
settingsTabButton.Size = UDim2.new(0.5, -12, 0, 34)

local function makeScrollView()
	local view = Instance.new("ScrollingFrame")
	view.BackgroundTransparency = 1
	view.BorderSizePixel = 0
	view.Position = UDim2.new(0, 10, 0, 132)
	view.Size = UDim2.new(1, -20, 1, -142)
	view.CanvasSize = UDim2.new(0, 0, 0, 0)
	view.AutomaticCanvasSize = Enum.AutomaticSize.Y
	view.ScrollBarThickness = 6
	view.ScrollBarImageColor3 = COLORS.Muted
	view.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	view.Parent = root

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 7)
	padding.Parent = view

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = view
	return view
end

local browserView = makeScrollView()
local settingsView = makeScrollView()
settingsView.Visible = false

local stackOrders = {}
local function stackObject(parent, object)
	stackOrders[parent] = (stackOrders[parent] or 0) + 1
	object.LayoutOrder = stackOrders[parent]
	return object
end

local function makePanel(parent, height)
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(1, -2, 0, height)
	panel.Parent = parent
	roundCorners(panel)
	stackObject(parent, panel)
	return panel
end

local function makeSectionTitle(parent, text)
	local label = makeLabel(parent, text, UDim2.new(), UDim2.new(1, -2, 0, 22), 13, COLORS.Text)
	label.Font = Enum.Font.GothamSemibold
	stackObject(parent, label)
	return label
end

local function makeGrid(parent, columns, cellHeight)
	local gap = 8
	local rowSafety = 2
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.new(0, 8, 0, 8)
	holder.Size = UDim2.new(1, -16, 1, -16)
	holder.Parent = parent

	local grid = Instance.new("UIGridLayout")
	local reservedWidth = gap * (columns - 1) + rowSafety * columns
	grid.CellPadding = UDim2.new(0, gap, 0, gap)
	grid.CellSize = UDim2.new(1 / columns, -(reservedWidth / columns), 0, cellHeight)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = columns
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder
	return holder
end

local statusPanel = makePanel(browserView, 146)
local statusHeading = makeLabel(statusPanel, "STATUS", UDim2.new(0, 10, 0, 7), UDim2.new(1, -20, 0, 16), 11, COLORS.Blue)
statusHeading.Font = Enum.Font.GothamBold
local statusLabel = makeLabel(statusPanel, "", UDim2.new(0, 10, 0, 27), UDim2.new(1, -20, 1, -33), 12, COLORS.Text)
statusLabel.TextWrapped = true
statusLabel.TextYAlignment = Enum.TextYAlignment.Top

local tipPanel = makePanel(browserView, 58)
local tipLabel = makeLabel(tipPanel, DEFAULT_TIP, UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 1, -16), 12, COLORS.Muted)
tipLabel.TextWrapped = true

local function addTooltip(button, tooltipText)
	button.MouseEnter:Connect(function()
		tipLabel.Text = "Tip: " .. tooltipText
	end)
	button.MouseLeave:Connect(function()
		tipLabel.Text = DEFAULT_TIP
	end)
end

local actionPanel = makePanel(browserView, 58)
local actionGrid = makeGrid(actionPanel, 2, 42)
local rescanButton = makeButton(actionGrid, "Rescan")
rescanButton.LayoutOrder = 1
local autoFocusButton = makeButton(actionGrid, "Auto Focus: ON", COLORS.Green)
autoFocusButton.LayoutOrder = 2

local navigationPanel = makePanel(browserView, 58)
local navigationGrid = makeGrid(navigationPanel, 2, 42)
local previousButton = makeButton(navigationGrid, "Previous")
previousButton.LayoutOrder = 1
local nextButton = makeButton(navigationGrid, "Next")
nextButton.LayoutOrder = 2

makeSectionTitle(browserView, "Show MeshParts with:")
local filterPanel = makePanel(browserView, 128)
local filterGrid = makeGrid(filterPanel, 2, 32)
local allFilterButton = makeButton(filterGrid, "All")
allFilterButton.LayoutOrder = 1
local defaultFilterButton = makeButton(filterGrid, "Default")
defaultFilterButton.LayoutOrder = 2
local hullFilterButton = makeButton(filterGrid, "Hull")
hullFilterButton.LayoutOrder = 3
local boxFilterButton = makeButton(filterGrid, "Box")
boxFilterButton.LayoutOrder = 4
local preciseFilterButton = makeButton(filterGrid, "Precise")
preciseFilterButton.LayoutOrder = 5

makeSectionTitle(browserView, "Preview / Confirm selected MeshPart:")
local setPanel = makePanel(browserView, 104)
local setGrid = makeGrid(setPanel, 2, 40)
local setDefaultButton = makeButton(setGrid, "Default")
setDefaultButton.LayoutOrder = 1
local setHullButton = makeButton(setGrid, "Hull", COLORS.Orange)
setHullButton.LayoutOrder = 2
local setBoxButton = makeButton(setGrid, "Box", COLORS.Green)
setBoxButton.LayoutOrder = 3
local setPreciseButton = makeButton(setGrid, "Precise", COLORS.Red)
setPreciseButton.LayoutOrder = 4

local confirmOverlay = Instance.new("Frame")
confirmOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
confirmOverlay.BackgroundTransparency = 0.28
confirmOverlay.BorderSizePixel = 0
confirmOverlay.Position = UDim2.new(0, 0, 0, 0)
confirmOverlay.Size = UDim2.fromScale(1, 1)
confirmOverlay.Visible = false
confirmOverlay.ZIndex = 20
confirmOverlay.Parent = root

local confirmPanel = Instance.new("Frame")
confirmPanel.AnchorPoint = Vector2.new(0.5, 0.5)
confirmPanel.BackgroundColor3 = COLORS.Panel
confirmPanel.BorderSizePixel = 0
confirmPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmPanel.Size = UDim2.new(1, -40, 0, 176)
confirmPanel.ZIndex = 21
confirmPanel.Parent = confirmOverlay
roundCorners(confirmPanel)

local confirmHeading = makeLabel(confirmPanel, "CONFIRM OPERATION", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 18), 12, COLORS.Yellow)
confirmHeading.Font = Enum.Font.GothamBold
confirmHeading.ZIndex = 22
local confirmLabel = makeLabel(confirmPanel, "", UDim2.new(0, 14, 0, 40), UDim2.new(1, -28, 0, 76), 12, COLORS.Text)
confirmLabel.TextWrapped = true
confirmLabel.TextYAlignment = Enum.TextYAlignment.Top
confirmLabel.ZIndex = 22
local confirmActionHolder = Instance.new("Frame")
confirmActionHolder.BackgroundTransparency = 1
confirmActionHolder.Position = UDim2.new(0, 14, 1, -48)
confirmActionHolder.Size = UDim2.new(1, -28, 0, 36)
confirmActionHolder.ZIndex = 22
confirmActionHolder.Parent = confirmPanel
local confirmButton = makeButton(confirmActionHolder, "Confirm", COLORS.Red)
confirmButton.Size = UDim2.new(0.5, -4, 1, 0)
confirmButton.ZIndex = 23
local cancelButton = makeButton(confirmActionHolder, "Cancel")
cancelButton.Position = UDim2.new(0.5, 4, 0, 0)
cancelButton.Size = UDim2.new(0.5, -4, 1, 0)
cancelButton.ZIndex = 23

makeSectionTitle(settingsView, "General Settings")

local function makeSettingRow(labelText)
	local panel = makePanel(settingsView, 54)
	local label = makeLabel(panel, labelText, UDim2.new(0, 10, 0, 6), UDim2.new(0.67, -15, 1, -12), 12, COLORS.Text)
	label.TextWrapped = true
	local button = makeButton(panel, "OFF")
	button.Position = UDim2.new(0.67, 0, 0, 10)
	button.Size = UDim2.new(0.33, -10, 0, 34)
	return button
end

local sameNameToggle = makeSettingRow("Change meshes with the same name")
local confirmLargeToggle = makeSettingRow("Confirm large changes")

local thresholdPanel = makePanel(settingsView, 62)
makeLabel(thresholdPanel, "Confirmation threshold", UDim2.new(0, 10, 0, 8), UDim2.new(0.55, -10, 0, 42), 12, COLORS.Text)
local thresholdBox = Instance.new("TextBox")
thresholdBox.BackgroundColor3 = COLORS.Button
thresholdBox.BorderSizePixel = 0
thresholdBox.Position = UDim2.new(0.55, 0, 0, 13)
thresholdBox.Size = UDim2.new(0.2, -6, 0, 34)
thresholdBox.Font = Enum.Font.GothamSemibold
thresholdBox.Text = tostring(settings.threshold)
thresholdBox.TextColor3 = COLORS.Text
thresholdBox.TextSize = 13
thresholdBox.ClearTextOnFocus = false
thresholdBox.Parent = thresholdPanel
roundCorners(thresholdBox)
local thresholdSaveButton = makeButton(thresholdPanel, "Save", COLORS.Blue)
thresholdSaveButton.Position = UDim2.new(0.75, 4, 0, 13)
thresholdSaveButton.Size = UDim2.new(0.25, -14, 0, 34)

local modelByModelToggle = makeSettingRow("Browse model by model")
local skipTaggedToggle = makeSettingRow("Skip reviewed meshes (next scan)")
local autoAdvanceToggle = makeSettingRow("Auto advance after confirm")

makeSectionTitle(settingsView, "Reviewed Mesh Tags")
local tagInfoPanel = makePanel(settingsView, 72)
local tagInfoLabel = makeLabel(
	tagInfoPanel,
	"Confirmed decisions add MeshCollisionReviewed. Skip reviewed meshes applies on the next scan. Reset clears progress.",
	UDim2.new(0, 10, 0, 8),
	UDim2.new(1, -20, 1, -16),
	12,
	COLORS.Muted
)
tagInfoLabel.TextWrapped = true
local resetPanel = makePanel(settingsView, 58)
local resetTagsButton = makeButton(resetPanel, "Reset Reviewed Tags", COLORS.Red)
resetTagsButton.Position = UDim2.new(0, 8, 0, 8)
resetTagsButton.Size = UDim2.new(1, -16, 0, 42)

local filterButtons = {
	allFilterButton,
	defaultFilterButton,
	hullFilterButton,
	boxFilterButton,
	preciseFilterButton,
}
local filterButtonForValue = {
	[Enum.CollisionFidelity.Default] = defaultFilterButton,
	[Enum.CollisionFidelity.Hull] = hullFilterButton,
	[Enum.CollisionFidelity.Box] = boxFilterButton,
	[Enum.CollisionFidelity.PreciseConvexDecomposition] = preciseFilterButton,
}
local setButtonColors = {
	[setDefaultButton] = COLORS.Button,
	[setHullButton] = COLORS.Orange,
	[setBoxButton] = COLORS.Green,
	[setPreciseButton] = COLORS.Red,
}
local setButtonForValue = {
	[Enum.CollisionFidelity.Default] = setDefaultButton,
	[Enum.CollisionFidelity.Hull] = setHullButton,
	[Enum.CollisionFidelity.Box] = setBoxButton,
	[Enum.CollisionFidelity.PreciseConvexDecomposition] = setPreciseButton,
}

addTooltip(rescanButton, "Scans Workspace again and rebuilds the MeshPart list.")
addTooltip(autoFocusButton, "Toggles automatic camera focus. If OFF, the mesh is only selected and you can press F manually.")
addTooltip(previousButton, "Moves to the previous MeshPart in the current filtered list.")
addTooltip(nextButton, "Moves to the next MeshPart in the current filtered list.")
addTooltip(allFilterButton, "Shows all MeshParts regardless of CollisionFidelity.")
addTooltip(defaultFilterButton, "Shows only MeshParts using Default collision.")
addTooltip(hullFilterButton, "Shows only MeshParts using Hull collision.")
addTooltip(boxFilterButton, "Shows only MeshParts using Box collision. Usually best for simple props.")
addTooltip(preciseFilterButton, "Shows only MeshParts using Precise collision. Usually the most expensive option.")
addTooltip(setDefaultButton, "First click previews Default collision. Second click confirms it.")
addTooltip(setHullButton, "First click previews Hull collision. Second click confirms it.")
addTooltip(setBoxButton, "First click previews Box collision. Second click confirms it.")
addTooltip(setPreciseButton, "First click previews Precise collision. Second click confirms it.")

local function fidelityName(fidelity)
	return FIDELITY_LABELS[fidelity] or "Unknown"
end

local function filterName()
	return state.currentFilter and fidelityName(state.currentFilter) or "All"
end

local function safeGetCollisionFidelity(mesh)
	if not mesh or not mesh.Parent or not mesh:IsA("MeshPart") then
		return nil
	end
	local success, value = pcall(function()
		return mesh.CollisionFidelity
	end)
	if success then
		return value
	end
	return nil
end

local function safeSetCollisionFidelity(mesh, fidelity)
	if not mesh or not mesh.Parent or not mesh:IsA("MeshPart") then
		return false
	end
	local success, errorMessage = pcall(function()
		mesh.CollisionFidelity = fidelity
	end)
	if not success then
		warn("Mesh Collision Browser Lite could not write CollisionFidelity for " .. mesh.Name .. ": " .. tostring(errorMessage))
		return false
	end
	return true
end

local function focusCameraOnMesh(mesh)
	local camera = Workspace.CurrentCamera
	if not camera or not mesh or not mesh.Parent then
		return
	end
	local success, target, size = pcall(function()
		return mesh.Position, mesh.Size
	end)
	if not success then
		return
	end
	local currentLookDirection = camera.CFrame.LookVector
	if currentLookDirection.Magnitude < 0.01 then
		currentLookDirection = Vector3.new(0, 0, -1)
	end
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = math.clamp(maxSize * 2.5, 8, 120)
	local cameraPosition = target - currentLookDirection.Unit * distance
	camera.CFrame = CFrame.lookAt(cameraPosition, target)
	camera.Focus = CFrame.new(target)
end

local function forceCollisionViewRefresh(mesh)
	Selection:Set({})
	task.wait()
	if mesh and mesh.Parent then
		Selection:Set({ mesh })
	end
end

local function findNearestModel(mesh)
	local ancestor = mesh.Parent
	while ancestor and ancestor ~= Workspace do
		if ancestor:IsA("Model") then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function getNavigationGroup(mesh)
	return findNearestModel(mesh) or mesh.Parent or mesh
end

local function isReviewed(mesh)
	return mesh and mesh.Parent and CollectionService:HasTag(mesh, REVIEWED_TAG)
end

local function groupDisplayName(mesh)
	local model = findNearestModel(mesh)
	if model then
		return "Model: " .. model.Name
	end
	local parent = mesh.Parent
	return parent and ("Parent: " .. parent.Name .. " (standalone)") or mesh.Name
end

local function updateToggle(button, enabled)
	button.Text = enabled and "ON" or "OFF"
	button.BackgroundColor3 = enabled and COLORS.Green or COLORS.Button
end

local function updateSettingsUi()
	updateToggle(sameNameToggle, settings.sameName)
	updateToggle(confirmLargeToggle, settings.confirmLarge)
	updateToggle(modelByModelToggle, settings.modelByModel)
	updateToggle(skipTaggedToggle, settings.skipTagged)
	updateToggle(autoAdvanceToggle, settings.autoAdvance)
	thresholdBox.Text = tostring(settings.threshold)
end

local function updateFilterButtonStates()
	for _, button in ipairs(filterButtons) do
		button.BackgroundColor3 = COLORS.Button
	end
	local activeButton = state.currentFilter == nil and allFilterButton or filterButtonForValue[state.currentFilter]
	if activeButton then
		activeButton.BackgroundColor3 = COLORS.Blue
	end
end

local function updateSetButtonStates()
	for button, color in pairs(setButtonColors) do
		button.BackgroundColor3 = color
	end
	if state.preview then
		local activeButton = setButtonForValue[state.preview.target]
		if activeButton then
			activeButton.BackgroundColor3 = COLORS.Yellow
		end
	end
end

local function updateAutoFocusButton()
	autoFocusButton.Text = state.autoFocus and "Auto Focus: ON" or "Auto Focus: OFF"
	autoFocusButton.BackgroundColor3 = state.autoFocus and COLORS.Green or COLORS.Orange
end

local function updateTabStates()
	browserView.Visible = state.activeTab == "Browser"
	settingsView.Visible = state.activeTab == "Settings"
	browserTabButton.BackgroundColor3 = state.activeTab == "Browser" and COLORS.Blue or COLORS.Button
	settingsTabButton.BackgroundColor3 = state.activeTab == "Settings" and COLORS.Blue or COLORS.Button
end

local function currentMesh()
	return state.filteredMeshes[state.currentIndex]
end

local function meshMatchesFilter(mesh)
	return state.currentFilter == nil or safeGetCollisionFidelity(mesh) == state.currentFilter
end

local function includeByTag(mesh)
	if not settings.skipTagged then
		return true
	end
	return not isReviewed(mesh)
end

local function sortMeshes(meshes)
	table.sort(meshes, function(left, right)
		if settings.modelByModel then
			local leftGroup = getNavigationGroup(left):GetFullName()
			local rightGroup = getNavigationGroup(right):GetFullName()
			if leftGroup ~= rightGroup then
				return leftGroup < rightGroup
			end
		end
		return left:GetFullName() < right:GetFullName()
	end)
end

local function rebuildMeshList(preferredMesh)
	local rebuilt = {}
	for _, mesh in ipairs(state.browseMeshes) do
		if mesh.Parent and meshMatchesFilter(mesh) then
			table.insert(rebuilt, mesh)
		end
	end
	sortMeshes(rebuilt)
	state.filteredMeshes = rebuilt

	local preferredIndex = preferredMesh and table.find(rebuilt, preferredMesh)
	if preferredIndex then
		state.currentIndex = preferredIndex
	elseif #rebuilt == 0 then
		state.currentIndex = 0
	elseif state.currentIndex < 1 then
		state.currentIndex = 1
	elseif state.currentIndex > #rebuilt then
		state.currentIndex = #rebuilt
	end
end

local function refreshUi(selectMesh)
	updateFilterButtonStates()
	updateSetButtonStates()
	updateAutoFocusButton()
	updateSettingsUi()
	updateTabStates()
	confirmOverlay.Visible = state.pending ~= nil
	if state.pending then
		confirmLabel.Text = state.pending.summary
	end

	local mesh = currentMesh()
	if not mesh then
		statusLabel.Text = string.format(
			"0 / 0   | Filter: %s\nMeshPart: None\nCollisionFidelity: -\nGroup: -   | Reviewed tag: -\n%s",
			filterName(),
			state.message
		)
		if selectMesh ~= false then
			Selection:Set({})
		end
		return
	end

	statusLabel.Text = string.format(
		"%d / %d   | Filter: %s\nMeshPart: %s\nCollisionFidelity: %s\nGroup: %s\nReviewed tag: %s\n%s",
		state.currentIndex,
		#state.filteredMeshes,
		filterName(),
		mesh.Name,
		fidelityName(safeGetCollisionFidelity(mesh)),
		groupDisplayName(mesh),
		isReviewed(mesh) and "Yes" or "No",
		state.message
	)
	if selectMesh ~= false then
		Selection:Set({ mesh })
		if state.autoFocus then
			focusCameraOnMesh(mesh)
		end
	end
end

local function setFidelityWithWaypoints(mesh, fidelity, actionName)
	local original = safeGetCollisionFidelity(mesh)
	if original == nil then
		return false, false
	end
	if original == fidelity then
		return true, false
	end
	ChangeHistoryService:SetWaypoint(actionName .. " - Before")
	if not safeSetCollisionFidelity(mesh, fidelity) then
		return false, false
	end
	ChangeHistoryService:SetWaypoint(actionName)
	return true, true
end

local function cancelPreview()
	local preview = state.preview
	if not preview then
		return
	end
	state.preview = nil
	local current = safeGetCollisionFidelity(preview.mesh)
	if current == preview.target and preview.original ~= preview.target then
		local success, changed = setFidelityWithWaypoints(
			preview.mesh,
			preview.original,
			"Mesh Collision Browser Lite - Cancel Preview"
		)
		if success and changed then
			forceCollisionViewRefresh(preview.mesh)
		end
	end
	updateSetButtonStates()
end

local function rejectIfPending()
	if state.pending then
		state.message = "Confirm or cancel the pending operation first."
		refreshUi(false)
		return true
	end
	return false
end

local function migrateLegacyTags()
	local migratedMeshes = 0
	local removedMarkers = 0
	local hasMutation = false
	for _, taggedObject in ipairs(CollectionService:GetTagged(LEGACY_CHANGED_TAG)) do
		if taggedObject:IsDescendantOf(Workspace) and (taggedObject:IsA("Model") or taggedObject:IsA("MeshPart")) then
			if not hasMutation then
				ChangeHistoryService:SetWaypoint("Mesh Collision Browser Lite - Migrate Tags - Before")
				hasMutation = true
			end
			if taggedObject:IsA("MeshPart") then
				if not CollectionService:HasTag(taggedObject, REVIEWED_TAG) then
					CollectionService:AddTag(taggedObject, REVIEWED_TAG)
					migratedMeshes += 1
				end
			else
				for _, descendant in ipairs(taggedObject:GetDescendants()) do
					if descendant:IsA("MeshPart") and not CollectionService:HasTag(descendant, REVIEWED_TAG) then
						CollectionService:AddTag(descendant, REVIEWED_TAG)
						migratedMeshes += 1
					end
				end
			end
			CollectionService:RemoveTag(taggedObject, LEGACY_CHANGED_TAG)
			removedMarkers += 1
		end
	end
	if hasMutation then
		ChangeHistoryService:SetWaypoint("Mesh Collision Browser Lite - Migrate Tags")
	end
	return migratedMeshes, removedMarkers
end

local function scanMeshes(messageOverride)
	if rejectIfPending() then
		return
	end
	cancelPreview()
	local migratedMeshes, removedMarkers = migrateLegacyTags()
	state.allMeshes = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("MeshPart") then
			table.insert(state.allMeshes, descendant)
		end
	end
	sortMeshes(state.allMeshes)
	state.browseMeshes = {}
	for _, mesh in ipairs(state.allMeshes) do
		if includeByTag(mesh) then
			table.insert(state.browseMeshes, mesh)
		end
	end
	state.currentIndex = 1
	rebuildMeshList()
	state.message = messageOverride or string.format("Scanned Workspace: %d MeshParts found.", #state.allMeshes)
	if removedMarkers > 0 then
		state.message ..= string.format(" Migrated %d legacy tags to %d reviewed meshes.", removedMarkers, migratedMeshes)
	end
	refreshUi(true)
end

local function setFilter(fidelity)
	if rejectIfPending() then
		return
	end
	cancelPreview()
	state.currentFilter = fidelity
	state.currentIndex = 1
	rebuildMeshList()
	state.message = "Showing " .. filterName() .. " MeshParts."
	refreshUi(true)
end

local function moveToIndex(nextIndex, message)
	if #state.filteredMeshes == 0 then
		state.currentIndex = 0
		state.message = "No MeshParts match the current filter."
		refreshUi(true)
		return
	end
	state.currentIndex = nextIndex
	state.message = message
	refreshUi(true)
end

local function navigate(step)
	if rejectIfPending() then
		return
	end
	cancelPreview()
	rebuildMeshList(currentMesh())
	if #state.filteredMeshes == 0 then
		state.message = "No MeshParts match the current filter."
		refreshUi(true)
		return
	end
	local nextIndex = ((state.currentIndex - 1 + step) % #state.filteredMeshes) + 1
	moveToIndex(nextIndex, "Browsing filtered MeshParts.")
end

local function addReviewedTag(mesh)
	if not mesh or not mesh.Parent then
		return false
	end
	if not CollectionService:HasTag(mesh, REVIEWED_TAG) then
		CollectionService:AddTag(mesh, REVIEWED_TAG)
		return true
	end
	return false
end

local function createChangeItems(mesh, target)
	local candidates = {}
	if settings.sameName then
		for _, scopedMesh in ipairs(state.allMeshes) do
			if scopedMesh.Parent and scopedMesh.Name == mesh.Name then
				table.insert(candidates, scopedMesh)
			end
		end
	else
		table.insert(candidates, mesh)
	end

	local items = {}
	for _, candidate in ipairs(candidates) do
		local original = candidate == mesh and state.preview and state.preview.original or safeGetCollisionFidelity(candidate)
		if original ~= nil then
			table.insert(items, {
				mesh = candidate,
				original = original,
			})
		end
	end
	return items
end

local function countAffectedItems(items, target)
	local affected = 0
	for _, item in ipairs(items) do
		if item.original ~= target or not isReviewed(item.mesh) then
			affected += 1
		end
	end
	return affected
end

local function advanceAfterConfirmation(confirmedMesh, oldIndex, previousList)
	rebuildMeshList(confirmedMesh)
	if not settings.autoAdvance then
		refreshUi(true)
		return
	end
	if #state.filteredMeshes == 0 then
		state.currentIndex = 0
		refreshUi(true)
		return
	end
	local nextIndex = nil
	for offset = 1, #previousList do
		local candidate = previousList[((oldIndex - 1 + offset) % #previousList) + 1]
		local candidateIndex = table.find(state.filteredMeshes, candidate)
		if candidateIndex then
			nextIndex = candidateIndex
			break
		end
	end
	nextIndex = nextIndex or 1
	moveToIndex(nextIndex, state.message)
end

local function applyConfirmedChanges(items, target, actionName, confirmedMesh)
	local oldIndex = state.currentIndex
	local previousList = table.clone(state.filteredMeshes)
	local preview = state.preview
	state.preview = nil
	local changed = 0
	local reviewed = 0
	local mutated = false
	local willMutate = false

	for _, item in ipairs(items) do
		local current = safeGetCollisionFidelity(item.mesh)
		local alreadyPreviewed = preview and item.mesh == preview.mesh and current == target
		if (not alreadyPreviewed and current ~= nil and current ~= target) or not isReviewed(item.mesh) then
			willMutate = true
			break
		end
	end
	if willMutate then
		ChangeHistoryService:SetWaypoint(actionName .. " - Before")
	end
	for _, item in ipairs(items) do
		local current = safeGetCollisionFidelity(item.mesh)
		local success = false
		if preview and item.mesh == preview.mesh and current == target then
			success = true
		elseif item.original == target then
			success = true
		elseif current == target then
			success = true
		elseif current ~= nil and current ~= target then
			success = safeSetCollisionFidelity(item.mesh, target)
			mutated = mutated or success
		end
		if success then
			if item.original ~= target then
				changed += 1
			end
			if addReviewedTag(item.mesh) then
				reviewed += 1
				mutated = true
			end
		end
	end
	if mutated and willMutate then
		ChangeHistoryService:SetWaypoint(actionName)
	end
	state.message = string.format("Confirmed %s: changed %d, reviewed %d MeshParts.", fidelityName(target), changed, reviewed)
	advanceAfterConfirmation(confirmedMesh, oldIndex, previousList)
end

local function openPending(pending)
	state.pending = pending
	state.message = "Review the confirmation panel before continuing."
	refreshUi(false)
end

local function previewOrConfirmFidelity(fidelity)
	if rejectIfPending() then
		return
	end
	local mesh = currentMesh()
	if not mesh then
		state.message = "No MeshPart selected in the filtered list."
		refreshUi(true)
		return
	end

	if state.preview and state.preview.mesh == mesh and state.preview.target == fidelity then
		local items = createChangeItems(mesh, fidelity)
		local affectedCount = countAffectedItems(items, fidelity)
		if settings.sameName and settings.confirmLarge and affectedCount >= settings.threshold then
			openPending({
				kind = "change",
				items = items,
				target = fidelity,
				mesh = mesh,
				actionName = "Mesh Collision Browser Lite - Same Name " .. fidelityName(fidelity),
				summary = string.format(
					"Review %d MeshParts named \"%s\" for %s.\nScope: Workspace\n%d new edits or review tags. Threshold is %d.",
					#items,
					mesh.Name,
					fidelityName(fidelity),
					affectedCount,
					settings.threshold
				),
			})
			return
		end
		applyConfirmedChanges(items, fidelity, "Mesh Collision Browser Lite - Confirm " .. fidelityName(fidelity), mesh)
		return
	end

	if state.preview then
		cancelPreview()
	end
	local original = safeGetCollisionFidelity(mesh)
	if original == nil then
		state.message = "Unable to read CollisionFidelity for the selected MeshPart."
		refreshUi(true)
		return
	end
	state.preview = {
		mesh = mesh,
		original = original,
		target = fidelity,
	}
	if original ~= fidelity then
		local success, changed = setFidelityWithWaypoints(
			mesh,
			fidelity,
			"Mesh Collision Browser Lite - Preview " .. fidelityName(fidelity)
		)
		if not success then
			state.preview = nil
			state.message = "Preview could not be applied."
			refreshUi(true)
			return
		end
		if changed then
			forceCollisionViewRefresh(mesh)
		end
	end
	state.message = "Previewing " .. fidelityName(fidelity) .. ". Click again to confirm."
	refreshUi(true)
end

local function collectReviewedTagTargets()
	local targets = {}
	for _, mesh in ipairs(state.allMeshes) do
		if isReviewed(mesh) then
			table.insert(targets, mesh)
		end
	end
	return targets
end

local function requestResetTags()
	if rejectIfPending() then
		return
	end
	cancelPreview()
	local targets = collectReviewedTagTargets()
	if #targets == 0 then
		state.message = "No MeshCollisionReviewed tags found in Workspace."
		refreshUi(false)
		return
	end
	state.activeTab = "Browser"
	openPending({
		kind = "resetTags",
		targets = targets,
		summary = string.format(
			"Remove MeshCollisionReviewed from %d MeshParts?\nScope: Workspace\nWarning: reviewed progress will be cleared.",
			#targets
		),
	})
end

local function confirmPendingOperation()
	local pending = state.pending
	if not pending then
		return
	end
	state.pending = nil
	if pending.kind == "change" then
		applyConfirmedChanges(pending.items, pending.target, pending.actionName, pending.mesh)
		return
	end
	local removed = 0
	ChangeHistoryService:SetWaypoint("Mesh Collision Browser Lite - Reset Reviewed Tags - Before")
	for _, target in ipairs(pending.targets) do
		if target.Parent and CollectionService:HasTag(target, REVIEWED_TAG) then
			CollectionService:RemoveTag(target, REVIEWED_TAG)
			removed += 1
		end
	end
	if removed > 0 then
		ChangeHistoryService:SetWaypoint("Mesh Collision Browser Lite - Reset Reviewed Tags")
	end
	scanMeshes(string.format("Reset %d MeshCollisionReviewed tags.", removed))
end

local function cancelPendingOperation()
	if not state.pending then
		return
	end
	local wasChange = state.pending.kind == "change"
	state.pending = nil
	if wasChange then
		cancelPreview()
	end
	state.message = "Operation cancelled."
	refreshUi(true)
end

local function switchTab(tabName)
	if rejectIfPending() then
		return
	end
	if tabName == "Settings" then
		cancelPreview()
	end
	state.activeTab = tabName
	refreshUi(false)
end

local function setBooleanSetting(field, key, value)
	if rejectIfPending() then
		return
	end
	cancelPreview()
	settings[field] = value
	saveSetting(key, value)
	if field == "modelByModel" then
		state.currentIndex = 1
		rebuildMeshList()
	end
	if field == "skipTagged" then
		state.message = "Setting saved. Skip reviewed meshes applies on the next scan."
	else
		state.message = "Settings updated."
	end
	refreshUi(true)
end

local function saveThreshold()
	if rejectIfPending() then
		return
	end
	local value = tonumber(thresholdBox.Text)
	if not value or value < 2 or value % 1 ~= 0 then
		thresholdBox.Text = tostring(settings.threshold)
		state.message = "Threshold must be a whole number of at least 2."
		refreshUi(false)
		return
	end
	settings.threshold = math.max(2, math.floor(value))
	saveSetting("Threshold", settings.threshold)
	state.message = "Confirmation threshold saved."
	refreshUi(false)
end

rescanButton.Activated:Connect(function()
	scanMeshes()
end)
autoFocusButton.Activated:Connect(function()
	if rejectIfPending() then
		return
	end
	state.autoFocus = not state.autoFocus
	state.message = state.autoFocus and "Auto Focus enabled." or "Auto Focus disabled. Press F to focus manually."
	refreshUi(true)
end)
previousButton.Activated:Connect(function()
	navigate(-1)
end)
nextButton.Activated:Connect(function()
	navigate(1)
end)
allFilterButton.Activated:Connect(function()
	setFilter(nil)
end)
defaultFilterButton.Activated:Connect(function()
	setFilter(Enum.CollisionFidelity.Default)
end)
hullFilterButton.Activated:Connect(function()
	setFilter(Enum.CollisionFidelity.Hull)
end)
boxFilterButton.Activated:Connect(function()
	setFilter(Enum.CollisionFidelity.Box)
end)
preciseFilterButton.Activated:Connect(function()
	setFilter(Enum.CollisionFidelity.PreciseConvexDecomposition)
end)
setDefaultButton.Activated:Connect(function()
	previewOrConfirmFidelity(Enum.CollisionFidelity.Default)
end)
setHullButton.Activated:Connect(function()
	previewOrConfirmFidelity(Enum.CollisionFidelity.Hull)
end)
setBoxButton.Activated:Connect(function()
	previewOrConfirmFidelity(Enum.CollisionFidelity.Box)
end)
setPreciseButton.Activated:Connect(function()
	previewOrConfirmFidelity(Enum.CollisionFidelity.PreciseConvexDecomposition)
end)
browserTabButton.Activated:Connect(function()
	switchTab("Browser")
end)
settingsTabButton.Activated:Connect(function()
	switchTab("Settings")
end)
sameNameToggle.Activated:Connect(function()
	setBooleanSetting("sameName", "SameName", not settings.sameName)
end)
confirmLargeToggle.Activated:Connect(function()
	setBooleanSetting("confirmLarge", "ConfirmLarge", not settings.confirmLarge)
end)
modelByModelToggle.Activated:Connect(function()
	setBooleanSetting("modelByModel", "ModelByModel", not settings.modelByModel)
end)
skipTaggedToggle.Activated:Connect(function()
	setBooleanSetting("skipTagged", "SkipTagged", not settings.skipTagged)
end)
autoAdvanceToggle.Activated:Connect(function()
	setBooleanSetting("autoAdvance", "AutoAdvance", not settings.autoAdvance)
end)
thresholdSaveButton.Activated:Connect(saveThreshold)
thresholdBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		saveThreshold()
	end
end)
resetTagsButton.Activated:Connect(requestResetTags)
confirmButton.Activated:Connect(confirmPendingOperation)
cancelButton.Activated:Connect(cancelPendingOperation)

toolbarButton.Click:Connect(function()
	if widget.Enabled then
		state.pending = nil
		cancelPreview()
		widget.Enabled = false
	else
		widget.Enabled = true
		state.activeTab = "Browser"
		scanMeshes()
	end
end)

widget:BindToClose(function()
	state.pending = nil
	cancelPreview()
	widget.Enabled = false
end)

plugin.Unloading:Connect(function()
	cancelPreview()
end)

updateSettingsUi()
refreshUi(false)
if widget.Enabled then
	scanMeshes()
end
