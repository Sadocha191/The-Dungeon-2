local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MIN_SCALE = 0.55
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

local function isDarkColor(color)
	local luminance = color.R * 0.2126 + color.G * 0.7152 + color.B * 0.0722
	return luminance <= 0.22
end

local function removeDimBackground(object)
	if not object:IsA("GuiObject") or not isFullScreen(object) then
		return
	end
	if object.BackgroundTransparency <= 0 or object.BackgroundTransparency >= 1 then
		return
	end
	if isDarkColor(object.BackgroundColor3) then
		object.BackgroundTransparency = 1
	end
end

local function getDesignSize(object)
	local width = math.abs(object.Size.X.Offset)
	local height = math.abs(object.Size.Y.Offset)
	if width < 1 then
		width = object.AbsoluteSize.X
	end
	if height < 1 then
		height = object.AbsoluteSize.Y
	end
	return math.max(1, width), math.max(1, height)
end

local function canScalePanel(object)
	if not object:IsA("GuiObject") or isFullScreen(object) then
		return false
	end
	local size = object.Size
	if math.abs(size.X.Offset) < 160 or math.abs(size.Y.Offset) < 80 then
		return false
	end
	if size.X.Scale > 0.25 or size.Y.Scale > 0.25 then
		return false
	end

	local parent = object.Parent
	return parent:IsA("ScreenGui") or (parent:IsA("GuiObject") and isFullScreen(parent))
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
			state.scale.Scale = math.clamp(math.min(
				availableWidth / state.designWidth,
				availableHeight / state.designHeight,
				1
			), MIN_SCALE, 1)
		end
	end
end

local function processGui(gui)
	if not isGeneratedGui(gui) then
		return
	end

	for _, object in ipairs(gui:GetDescendants()) do
		if object:IsA("GuiObject") then
			removeDimBackground(object)
			if canScalePanel(object) then
				ensurePanelScale(object)
			end
		end
	end

	gui.DescendantAdded:Connect(function(object)
		task.defer(function()
			if not object.Parent or not object:IsA("GuiObject") then
				return
			end
			removeDimBackground(object)
			if canScalePanel(object) then
				ensurePanelScale(object)
				updateScales()
			end
		end)
	end)

	updateScales()
end

local function bindCamera(camera)
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
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
