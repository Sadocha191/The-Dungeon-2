local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SCREEN_MARGIN = 20
local EXCLUDED_NAME_PARTS = {
	"loading",
	"teleport",
}
local GENERATED_NAME_PARTS = {
	"hud",
	"toast",
	"summary",
	"reward",
	"reveal",
	"damageindicator",
	"dailylogin",
	"events",
	"guild",
	"chest",
}

local trackedPanels = {}
local trackedDimmers = {}
local processedGuis = {}
local viewportConnection = nil

local function containsNamePart(name, parts)
	local lowerName = string.lower(name)
	for _, part in ipairs(parts) do
		if string.find(lowerName, part, 1, true) then
			return true
		end
	end
	return false
end

local function isGeneratedGui(gui)
	if not gui:IsA("ScreenGui") then
		return false
	end
	if containsNamePart(gui.Name, EXCLUDED_NAME_PARTS) then
		return false
	end
	return containsNamePart(gui.Name, GENERATED_NAME_PARTS)
end

local function isFullScreen(object)
	if not object:IsA("GuiObject") then
		return false
	end
	local size = object.Size
	return size.X.Scale >= 0.9 and size.Y.Scale >= 0.9
end

local function isViewportOverlay(object)
	if not isFullScreen(object) then
		return false
	end

	local parent = object.Parent
	if parent and parent:IsA("ScreenGui") then
		return true
	end

	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local absoluteSize = object.AbsoluteSize
	return absoluteSize.X >= viewport.X * 0.85 and absoluteSize.Y >= viewport.Y * 0.85
end

local function isDarkColor(color)
	local luminance = color.R * 0.2126 + color.G * 0.7152 + color.B * 0.0722
	return luminance <= 0.22
end

local function enforceDimmerRemoval(object)
	if not object.Parent or not isViewportOverlay(object) or not isDarkColor(object.BackgroundColor3) then
		return
	end

	local transparency = object.BackgroundTransparency
	if transparency > 0 and transparency < 1 then
		object.BackgroundTransparency = 1
	end
end

local function trackDimBackground(object)
	if not object:IsA("GuiObject") or not isViewportOverlay(object) then
		return
	end
	if trackedDimmers[object] then
		enforceDimmerRemoval(object)
		return
	end

	trackedDimmers[object] = true
	object:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		enforceDimmerRemoval(object)
	end)
	object:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		enforceDimmerRemoval(object)
	end)
	enforceDimmerRemoval(object)
end

local function getDesignSize(object)
	local width = math.abs(object.Size.X.Offset)
	local height = math.abs(object.Size.Y.Offset)
	local constraint = object:FindFirstChildOfClass("UISizeConstraint")

	if constraint then
		width = math.max(width, constraint.MinSize.X)
		height = math.max(height, constraint.MinSize.Y)
	end

	width = math.max(width, object.AbsoluteSize.X)
	height = math.max(height, object.AbsoluteSize.Y)
	return math.max(1, width), math.max(1, height)
end

local function canScalePanel(object)
	if not object:IsA("GuiObject") or isFullScreen(object) then
		return false
	end

	local parent = object.Parent
	local isTopLevel = parent:IsA("ScreenGui") or (parent:IsA("GuiObject") and isFullScreen(parent))
	if not isTopLevel then
		return false
	end

	local width, height = getDesignSize(object)
	return width >= 160 and height >= 80
end

local function ensurePanelScale(panel)
	if trackedPanels[panel] then
		return
	end

	local scale = panel:FindFirstChild("GeneratedUiResponsiveScale")
	if scale and not scale:IsA("UIScale") then
		scale:Destroy()
		scale = nil
	end
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "GeneratedUiResponsiveScale"
		scale.Parent = panel
	end

	local designWidth, designHeight = getDesignSize(panel)
	trackedPanels[panel] = {
		scale = scale,
		designWidth = designWidth,
		designHeight = designHeight,
	}
end

local function updateScales()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local availableWidth = math.max(1, viewport.X - SCREEN_MARGIN * 2)
	local availableHeight = math.max(1, viewport.Y - SCREEN_MARGIN * 2)

	for panel, state in pairs(trackedPanels) do
		if not panel.Parent then
			trackedPanels[panel] = nil
		else
			state.scale.Scale = math.min(
				availableWidth / state.designWidth,
				availableHeight / state.designHeight,
				1
			)
		end
	end
end

local function processObject(object)
	if not object:IsA("GuiObject") then
		return
	end

	trackDimBackground(object)
	if canScalePanel(object) then
		ensurePanelScale(object)
	end
end

local function rescanGui(gui)
	for _, object in ipairs(gui:GetDescendants()) do
		processObject(object)
	end
	updateScales()
end

local function processGui(gui)
	if not isGeneratedGui(gui) or processedGuis[gui] then
		return
	end
	processedGuis[gui] = true

	rescanGui(gui)

	gui.DescendantAdded:Connect(function(object)
		task.defer(function()
			if not object.Parent then
				return
			end
			processObject(object)
			updateScales()
		end)
	end)

	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			task.defer(rescanGui, gui)
		end
	end)
end

local function bindCamera(camera)
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			updateScales()
			for dimmer in pairs(trackedDimmers) do
				enforceDimmerRemoval(dimmer)
			end
		end)
	end
	updateScales()
end

for _, child in ipairs(playerGui:GetChildren()) do
	if child:IsA("ScreenGui") then
		task.defer(processGui, child)
	end
end

playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		task.defer(processGui, child)
	end
end)

bindCamera(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(Workspace.CurrentCamera)
end)
