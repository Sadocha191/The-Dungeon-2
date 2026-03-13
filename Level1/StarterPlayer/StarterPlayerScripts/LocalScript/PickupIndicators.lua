local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pickupIndicatorEvent = remotes:WaitForChild("PickupIndicatorEvent")

local AGGREGATE_TIMEOUT = 0.75
local FADE_DURATION = 0.32
local POP_DURATION = 0.18
local RISE_DISTANCE = 0.55
local BASE_STROKE_TRANSPARENCY = 0.10

local INDICATOR_CONFIG = {
	xp = {
		label = "XP",
		color = Color3.fromRGB(96, 165, 250),
		strokeColor = Color3.fromRGB(17, 32, 71),
		offset = Vector3.new(-1.25, 4.7, 0),
	},
	coins = {
		label = "Coins",
		color = Color3.fromRGB(255, 210, 80),
		strokeColor = Color3.fromRGB(102, 62, 10),
		offset = Vector3.new(0, 5.2, 0),
	},
	souls = {
		label = "Souls",
		color = Color3.fromRGB(190, 150, 255),
		strokeColor = Color3.fromRGB(38, 22, 85),
		offset = Vector3.new(1.25, 4.9, 0),
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(194, 115, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 170, 255)),
		}),
	},
}

local function formatNumber(value: number): string
	local raw = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	local reversed = string.reverse(raw):gsub("(%d%d%d)", "%1,")
	reversed = reversed:gsub(",$", "")
	return string.reverse(reversed)
end

local function getAdornee(): BasePart?
	local char = plr.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local indicators = {}

local function refreshAdornee()
	local adornee = getAdornee()
	for _, state in pairs(indicators) do
		state.gui.Adornee = adornee
		if state.active then
			state.gui.Enabled = adornee ~= nil
		end
	end
end

local function updateText(state)
	state.label.Text = string.format("+%s %s", formatNumber(state.amount), state.config.label)
end

local function createIndicator(kind: string, config)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PickupIndicator_" .. kind
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 90
	billboard.Size = UDim2.fromOffset(230, 64)
	billboard.StudsOffset = config.offset
	billboard.Enabled = false
	billboard.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.TextStrokeColor3 = config.strokeColor
	label.TextColor3 = config.color
	label.Text = ""
	label.Parent = billboard

	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MaxTextSize = 28
	textSizeConstraint.MinTextSize = 14
	textSizeConstraint.Parent = label

	if config.gradient then
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		local gradient = Instance.new("UIGradient")
		gradient.Color = config.gradient
		gradient.Rotation = -18
		gradient.Parent = label
	end

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = label

	indicators[kind] = {
		gui = billboard,
		label = label,
		scale = scale,
		config = config,
		amount = 0,
		active = false,
		startedAt = 0,
		lastGainAt = 0,
		popAt = 0,
	}
end

for kind, config in pairs(INDICATOR_CONFIG) do
	createIndicator(kind, config)
end

refreshAdornee()

plr.CharacterAdded:Connect(function(char)
	task.defer(function()
		char:WaitForChild("Head", 2)
		refreshAdornee()
	end)
end)

plr.CharacterRemoving:Connect(function()
	for _, state in pairs(indicators) do
		state.gui.Adornee = nil
		if state.active then
			state.gui.Enabled = false
		end
	end
end)

pickupIndicatorEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local kind = tostring(payload.kind or "")
	local amount = math.max(0, math.floor(tonumber(payload.amount) or 0))
	local state = indicators[kind]
	if not state or amount <= 0 then
		return
	end

	local now = os.clock()
	if not state.active or (now - state.lastGainAt) > AGGREGATE_TIMEOUT then
		state.amount = 0
		state.startedAt = now
	end

	state.amount += amount
	state.active = true
	state.lastGainAt = now
	state.popAt = now

	updateText(state)
	state.scale.Scale = 1.14
	state.label.TextTransparency = 0
	state.label.TextStrokeTransparency = BASE_STROKE_TRANSPARENCY
	state.gui.StudsOffset = state.config.offset
	state.gui.Enabled = state.gui.Adornee ~= nil
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, state in pairs(indicators) do
		if not state.active then
			continue
		end

		local sinceLastGain = now - state.lastGainAt
		if sinceLastGain >= (AGGREGATE_TIMEOUT + FADE_DURATION) then
			state.active = false
			state.amount = 0
			state.gui.Enabled = false
			state.label.Text = ""
			state.scale.Scale = 1
			continue
		end

		local fadeAlpha = 0
		if sinceLastGain > AGGREGATE_TIMEOUT then
			fadeAlpha = math.clamp((sinceLastGain - AGGREGATE_TIMEOUT) / FADE_DURATION, 0, 1)
		end

		local popAlpha = math.clamp((now - state.popAt) / POP_DURATION, 0, 1)
		local popLift = (1 - popAlpha) * 0.32
		local lifeAlpha = math.clamp((now - state.startedAt) / (AGGREGATE_TIMEOUT + FADE_DURATION), 0, 1)
		local rise = lifeAlpha * RISE_DISTANCE

		state.gui.Enabled = state.gui.Adornee ~= nil
		state.gui.StudsOffset = state.config.offset + Vector3.new(0, rise + popLift, 0)
		state.label.TextTransparency = fadeAlpha
		state.label.TextStrokeTransparency = BASE_STROKE_TRANSPARENCY + ((1 - BASE_STROKE_TRANSPARENCY) * fadeAlpha)
		state.scale.Scale = 1 + ((1 - popAlpha) * 0.14)
	end
end)
