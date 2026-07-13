local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local runStarted = ReplicatedStorage:WaitForChild("RunStarted")
local damageIndicatorEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DamageIndicatorEvent")

local WINDOW_SECONDS = 2
local UPDATE_INTERVAL = 0.1
local DESIGN_VIEWPORT = Vector2.new(1280, 720)

local samples = {}
local rollingDamage = 0
local updateAccumulator = 0

local gui = Instance.new("ScreenGui")
gui.Name = "CurrentDpsHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 47
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "DpsPanel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 18, 0.5, 0)
panel.Size = UDim2.fromOffset(170, 54)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Parent = gui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Parent = panel

local label = Instance.new("TextLabel")
label.Name = "DpsLabel"
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBlack
label.Text = "DPS  0"
label.TextColor3 = Color3.fromRGB(244, 247, 252)
label.TextSize = 24
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Center
label.Parent = panel

local textStroke = Instance.new("UIStroke")
textStroke.Name = "TextStroke"
textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
textStroke.Color = Color3.fromRGB(10, 12, 18)
textStroke.Thickness = 2
textStroke.Transparency = 0.08
textStroke.Parent = label

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.AnchorPoint = Vector2.new(0, 0.5)
accent.Position = UDim2.new(0, -8, 0.5, 0)
accent.Size = UDim2.fromOffset(4, 34)
accent.BackgroundColor3 = Color3.fromRGB(235, 90, 90)
accent.BorderSizePixel = 0
accent.Parent = panel

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent

local function formatNumber(value)
	value = math.max(0, tonumber(value) or 0)
	if value >= 1_000_000 then
		return string.format("%.1fM", value / 1_000_000)
	elseif value >= 1_000 then
		return string.format("%.1fK", value / 1_000)
	end
	return tostring(math.floor(value + 0.5))
end

local function clearSamples()
	table.clear(samples)
	rollingDamage = 0
	label.Text = "DPS  0"
end

local viewportConnection = nil
local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or DESIGN_VIEWPORT
	local widthScale = viewport.X / DESIGN_VIEWPORT.X
	local heightScale = viewport.Y / DESIGN_VIEWPORT.Y
	responsiveScale.Scale = math.clamp(math.min(widthScale, heightScale), 0.68, 1)
end

local function bindCamera(camera)
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end

bindCamera(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(Workspace.CurrentCamera)
end)

local function updateVisibility()
	gui.Enabled = runStarted.Value == true
	if not gui.Enabled then
		clearSamples()
	end
end

runStarted:GetPropertyChangedSignal("Value"):Connect(updateVisibility)
updateVisibility()

damageIndicatorEvent.OnClientEvent:Connect(function(payload)
	if runStarted.Value ~= true or typeof(payload) ~= "table" then
		return
	end

	local amount = tonumber(payload.amount)
	if not amount or amount <= 0 then
		return
	end

	local now = os.clock()
	rollingDamage += amount
	table.insert(samples, {
		time = now,
		amount = amount,
	})
end)

RunService.Heartbeat:Connect(function(dt)
	if runStarted.Value ~= true then
		return
	end

	updateAccumulator += dt
	if updateAccumulator < UPDATE_INTERVAL then
		return
	end
	updateAccumulator = 0

	local cutoff = os.clock() - WINDOW_SECONDS
	while samples[1] and samples[1].time < cutoff do
		rollingDamage -= samples[1].amount
		table.remove(samples, 1)
	end
	rollingDamage = math.max(0, rollingDamage)

	local currentDps = rollingDamage / WINDOW_SECONDS
	label.Text = "DPS  " .. formatNumber(currentDps)
end)
