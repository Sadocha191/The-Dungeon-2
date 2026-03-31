local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent
local frame = gui:WaitForChild("Frame")
local fpsLabel = frame:WaitForChild("FPS")
local fpsTextLabel = frame:WaitForChild("FPSText")
local TOGGLE_KEY = Enum.KeyCode.F3
local MAX_FRAME_SAMPLES = 2400

frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -14, 0, 14)
frame.Size = UDim2.fromOffset(236, 166)
frame.BackgroundColor3 = Color3.fromRGB(7, 10, 14)
frame.BackgroundTransparency = 0.22
frame.BorderSizePixel = 0
frame.Active = true

local function styleLabel(
	label: TextLabel,
	size: UDim2,
	position: UDim2,
	font: Enum.Font,
	textSize: number,
	color: Color3,
	alignment: Enum.TextXAlignment
)
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = alignment
end

styleLabel(
	fpsTextLabel,
	UDim2.new(0, 110, 0, 18),
	UDim2.fromOffset(12, 10),
	Enum.Font.Gotham,
	12,
	Color3.fromRGB(142, 154, 171),
	Enum.TextXAlignment.Left
)
fpsTextLabel.Text = "FPS"
styleLabel(
	fpsLabel,
	UDim2.new(0, 90, 0, 18),
	UDim2.fromOffset(132, 10),
	Enum.Font.GothamSemibold,
	12,
	Color3.fromRGB(236, 242, 248),
	Enum.TextXAlignment.Right
)

local function ensureRow(labelName: string, valueName: string, caption: string, y: number)
	local label = frame:FindFirstChild(labelName)
	if not label then
		label = Instance.new("TextLabel")
		label.Name = labelName
		label.Parent = frame
	end
	local value = frame:FindFirstChild(valueName)
	if not value then
		value = Instance.new("TextLabel")
		value.Name = valueName
		value.Parent = frame
	end
	styleLabel(
		label,
		UDim2.new(0, 118, 0, 18),
		UDim2.fromOffset(12, y),
		Enum.Font.Gotham,
		12,
		Color3.fromRGB(142, 154, 171),
		Enum.TextXAlignment.Left
	)
	label.Text = caption
	styleLabel(
		value,
		UDim2.new(0, 90, 0, 18),
		UDim2.fromOffset(132, y),
		Enum.Font.GothamSemibold,
		12,
		Color3.fromRGB(236, 242, 248),
		Enum.TextXAlignment.Right
	)
	value.Text = "--"
	return value
end

local frameTimeValue = ensureRow("FrametimeLabel", "FrametimeValue", "Frametime", 32)
local lowOneValue = ensureRow("LowOneLabel", "LowOneValue", "1% FPS", 52)
local lowZeroPointZeroOneValue = ensureRow("LowZeroPointZeroOneLabel", "LowZeroPointZeroOneValue", "0.01% FPS", 72)
local npcValue = ensureRow("NpcLabel", "NpcValue", "NPC", 92)
local peakNpcValue = ensureRow("PeakNpcLabel", "PeakNpcValue", "Peak NPC", 112)
local memoryValue = ensureRow("MemoryLabel", "MemoryValue", "Memory", 132)

local hint = frame:FindFirstChild("PerfHint")
if not hint then
	hint = Instance.new("TextLabel")
	hint.Name = "PerfHint"
	hint.Parent = frame
end
styleLabel(
	hint,
	UDim2.new(1, -24, 0, 14),
	UDim2.fromOffset(12, 148),
	Enum.Font.Gotham,
	11,
	Color3.fromRGB(120, 130, 146),
	Enum.TextXAlignment.Left
)
hint.Text = "F3 toggle"

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == TOGGLE_KEY then
		playerGui:SetAttribute("ShowFPSCounter", not (playerGui:GetAttribute("ShowFPSCounter") == true))
	end
end)

local sampleTime = 0
local sampleFrames = 0
local peakNpcCount = 0
local frameSamples = table.create(MAX_FRAME_SAMPLES)
local frameSampleCount = 0
local frameSampleCursor = 1

local function countNpcModels(): number
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return 0
	end
	local count = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			count += 1
		end
	end
	return count
end

local function fpsFromDt(dt: number): number
	return math.max(1, math.floor((1 / math.max(dt, 1e-4)) + 0.5))
end

local function pushFrameSample(dt: number)
	frameSamples[frameSampleCursor] = dt
	frameSampleCursor = (frameSampleCursor % MAX_FRAME_SAMPLES) + 1
	frameSampleCount = math.min(frameSampleCount + 1, MAX_FRAME_SAMPLES)
end

local function computeLowFps(lowFraction: number): number
	if frameSampleCount == 0 then
		return 0
	end
	local ordered = table.create(frameSampleCount)
	for index = 1, frameSampleCount do
		ordered[index] = frameSamples[index]
	end
	table.sort(ordered)
	local worstCount = math.max(1, math.ceil(frameSampleCount * lowFraction))
	local total = 0
	for index = frameSampleCount - worstCount + 1, frameSampleCount do
		total += ordered[index]
	end
	return fpsFromDt(total / worstCount)
end

RunService.RenderStepped:Connect(function(dt)
	pushFrameSample(dt)
	sampleTime += dt
	sampleFrames += 1
	if sampleTime < 0.25 then
		return
	end

	local averageDt = sampleTime / math.max(1, sampleFrames)
	local fps = fpsFromDt(averageDt)
	local frameTimeMs = averageDt * 1000
	local npcCount = countNpcModels()
	peakNpcCount = math.max(peakNpcCount, npcCount)
	local memoryMb = 0
	pcall(function()
		memoryMb = Stats:GetTotalMemoryUsageMb()
	end)

	sampleTime = 0
	sampleFrames = 0

	fpsLabel.Text = tostring(fps)
	frameTimeValue.Text = string.format("%.1f ms", frameTimeMs)
	lowOneValue.Text = tostring(computeLowFps(0.01))
	lowZeroPointZeroOneValue.Text = tostring(computeLowFps(0.0001))
	npcValue.Text = tostring(npcCount)
	peakNpcValue.Text = tostring(peakNpcCount)
	memoryValue.Text = string.format("%.0f MB", memoryMb)
end)
