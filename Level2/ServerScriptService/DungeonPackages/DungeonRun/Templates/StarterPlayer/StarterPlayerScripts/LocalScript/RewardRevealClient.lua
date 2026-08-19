local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local waveStatusEvent = remotes:WaitForChild("WaveStatusEvent")

local RARITY_COLORS = {
	Common = Color3.fromRGB(206, 206, 206),
	Uncommon = Color3.fromRGB(88, 214, 121),
	Rare = Color3.fromRGB(79, 172, 255),
	Epic = Color3.fromRGB(185, 111, 255),
	Legendary = Color3.fromRGB(255, 177, 66),
	Mythical = Color3.fromRGB(255, 84, 129),
}

local KIND_COLORS = {
	chest = Color3.fromRGB(255, 187, 94),
	statue = Color3.fromRGB(124, 233, 223),
}

local function getAccentColor(rarity, revealKind)
	return RARITY_COLORS[tostring(rarity or "")] or KIND_COLORS[tostring(revealKind or "")] or Color3.fromRGB(109, 176, 255)
end

local gui = Instance.new("ScreenGui")
gui.Name = "RewardRevealGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 72
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(4, 6, 10)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.57)
card.Size = UDim2.fromOffset(640, 280)
card.BackgroundColor3 = Color3.fromRGB(13, 16, 24)
card.BackgroundTransparency = 0.12
card.BorderSizePixel = 0
card.Parent = dim

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 24)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 1
cardStroke.Transparency = 0.16
cardStroke.Color = Color3.fromRGB(109, 176, 255)
cardStroke.Parent = card

local cardSizeConstraint = Instance.new("UISizeConstraint")
cardSizeConstraint.MaxSize = Vector2.new(640, 280)
cardSizeConstraint.MinSize = Vector2.new(420, 220)
cardSizeConstraint.Parent = card

local cardAspect = Instance.new("UIAspectRatioConstraint")
cardAspect.AspectRatio = 640 / 280
cardAspect.DominantAxis = Enum.DominantAxis.Width
cardAspect.Parent = card

local cardScale = Instance.new("UIScale")
cardScale.Scale = 0.9
cardScale.Parent = card

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 6)
accentBar.BackgroundColor3 = Color3.fromRGB(109, 176, 255)
accentBar.BorderSizePixel = 0
accentBar.Parent = card

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(0, 24)
accentCorner.Parent = accentBar

local header = Instance.new("TextLabel")
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(24, 20)
header.Size = UDim2.new(1, -140, 0, 20)
header.Font = Enum.Font.GothamBold
header.TextSize = 13
header.TextColor3 = Color3.fromRGB(156, 168, 190)
header.TextXAlignment = Enum.TextXAlignment.Left
header.Text = "REWARD DRAW"
header.Parent = card

local sourcePill = Instance.new("TextLabel")
sourcePill.Position = UDim2.fromOffset(24, 46)
sourcePill.Size = UDim2.fromOffset(164, 28)
sourcePill.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
sourcePill.BorderSizePixel = 0
sourcePill.Font = Enum.Font.GothamBold
sourcePill.TextSize = 12
sourcePill.TextColor3 = Color3.fromRGB(242, 245, 250)
sourcePill.Text = "Treasure Chest"
sourcePill.Parent = card

local sourceCorner = Instance.new("UICorner")
sourceCorner.CornerRadius = UDim.new(0, 12)
sourceCorner.Parent = sourcePill

local rarityPill = Instance.new("TextLabel")
rarityPill.AnchorPoint = Vector2.new(1, 0)
rarityPill.Position = UDim2.new(1, -68, 0, 46)
rarityPill.Size = UDim2.fromOffset(120, 28)
rarityPill.BackgroundColor3 = Color3.fromRGB(109, 176, 255)
rarityPill.BorderSizePixel = 0
rarityPill.Font = Enum.Font.GothamBold
rarityPill.TextSize = 12
rarityPill.TextColor3 = Color3.fromRGB(16, 18, 24)
rarityPill.Text = "Rare"
rarityPill.Parent = card

local rarityCorner = Instance.new("UICorner")
rarityCorner.CornerRadius = UDim.new(0, 12)
rarityCorner.Parent = rarityPill

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -18, 0, 16)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.TextColor3 = Color3.fromRGB(244, 247, 252)
closeButton.Text = "X"
closeButton.Parent = card

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeButton

local rollText = Instance.new("TextLabel")
rollText.BackgroundTransparency = 1
rollText.Position = UDim2.fromOffset(24, 94)
rollText.Size = UDim2.new(1, -48, 0, 58)
rollText.Font = Enum.Font.GothamBlack
rollText.TextSize = 30
rollText.TextColor3 = Color3.fromRGB(245, 247, 252)
rollText.TextWrapped = true
rollText.Text = "Scanning reward..."
rollText.Parent = card

local description = Instance.new("TextLabel")
description.BackgroundTransparency = 1
description.Position = UDim2.fromOffset(24, 160)
description.Size = UDim2.new(1, -48, 0, 46)
description.Font = Enum.Font.Gotham
description.TextSize = 14
description.TextColor3 = Color3.fromRGB(190, 199, 214)
description.TextWrapped = true
description.TextXAlignment = Enum.TextXAlignment.Left
description.TextYAlignment = Enum.TextYAlignment.Top
description.Text = ""
description.Parent = card

local detailPill = Instance.new("TextLabel")
detailPill.Position = UDim2.fromOffset(24, 226)
detailPill.Size = UDim2.fromOffset(154, 26)
detailPill.BackgroundColor3 = Color3.fromRGB(23, 29, 42)
detailPill.BorderSizePixel = 0
detailPill.Font = Enum.Font.GothamBold
detailPill.TextSize = 11
detailPill.TextColor3 = Color3.fromRGB(216, 223, 235)
detailPill.Text = ""
detailPill.Parent = card

local detailCorner = Instance.new("UICorner")
detailCorner.CornerRadius = UDim.new(0, 11)
detailCorner.Parent = detailPill

local footerText = Instance.new("TextLabel")
footerText.AnchorPoint = Vector2.new(1, 1)
footerText.Position = UDim2.new(1, -24, 1, -18)
footerText.Size = UDim2.fromOffset(180, 18)
footerText.BackgroundTransparency = 1
footerText.Font = Enum.Font.GothamMedium
footerText.TextSize = 11
footerText.TextColor3 = Color3.fromRGB(140, 150, 168)
footerText.TextXAlignment = Enum.TextXAlignment.Right
footerText.Text = "Press X to skip"
footerText.Parent = card

local revealQueue = {}
local revealRunning = false
local skipRoll = false
local closeReveal = false
local revealPhase = "idle"

local function setCardAccent(color)
	accentBar.BackgroundColor3 = color
	cardStroke.Color = color
	rarityPill.BackgroundColor3 = color
end

local function setPreview(entry, payload, isFinal)
	local accent = getAccentColor(entry.rarity or payload.rarity, payload.revealKind)
	setCardAccent(accent)
	rarityPill.Text = string.upper(tostring(entry.rarity or payload.rarity or payload.revealKind or "Reward"))
	rarityPill.TextColor3 = isFinal and Color3.fromRGB(15, 18, 24) or Color3.fromRGB(28, 30, 38)
	sourcePill.Text = tostring(payload.sourceName or "Reward")
	header.Text = string.upper(tostring(payload.headerText or "Reward Draw"))
	rollText.Text = tostring(entry.label or payload.itemName or "Reward")
	description.Text = isFinal and tostring(payload.description or "A new reward has been locked in.") or "Rolling..."
	detailPill.Text = tostring(payload.detailText or "")
	detailPill.Visible = detailPill.Text ~= ""
end

local function buildSequence(payload)
	local sequence = {}
	if typeof(payload.candidates) == "table" then
		for _, entry in ipairs(payload.candidates) do
			if typeof(entry) == "table" and tostring(entry.label or "") ~= "" then
				table.insert(sequence, {
					label = tostring(entry.label),
					rarity = tostring(entry.rarity or payload.rarity or ""),
				})
			end
		end
	end

	if #sequence == 0 then
		table.insert(sequence, {
			label = "Attuning reward...",
			rarity = tostring(payload.rarity or ""),
		})
	end

	return sequence
end

local function showReveal(payload)
	gui.Enabled = true
	dim.BackgroundTransparency = 1
	card.Position = UDim2.fromScale(0.5, 0.57)
	card.BackgroundTransparency = 0.2
	cardScale.Scale = 0.9
	revealPhase = "rolling"
	skipRoll = false
	closeReveal = false

	local sequence = buildSequence(payload)
	local finalEntry = {
		label = tostring(payload.itemName or "Reward"),
		rarity = tostring(payload.rarity or ""),
	}

	setPreview(sequence[1], payload, false)

	TweenService:Create(dim, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.45,
	}):Play()
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.12,
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	local rollDuration = math.max(0.55, tonumber(payload.rollDuration) or 0.95)
	local startedAt = os.clock()
	local index = 1

	while not skipRoll and (os.clock() - startedAt) < rollDuration do
		local alpha = math.clamp((os.clock() - startedAt) / rollDuration, 0, 1)
		local entry = sequence[((index - 1) % #sequence) + 1]
		setPreview(entry, payload, false)
		cardScale.Scale = 0.985 + (math.sin(index * 0.75) * 0.015)
		index += 1
		task.wait(0.045 + (alpha * 0.05))
	end

	revealPhase = "revealed"
	setPreview(finalEntry, payload, true)
	cardScale.Scale = 1.035
	TweenService:Create(cardScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	local holdDuration = math.max(1.1, tonumber(payload.holdDuration) or 1.75)
	local holdStartedAt = os.clock()
	while not closeReveal and (os.clock() - holdStartedAt) < holdDuration do
		task.wait(0.05)
	end

	revealPhase = "closing"
	TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0.24,
		Position = UDim2.fromScale(0.5, 0.48),
	}):Play()
	TweenService:Create(cardScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.96,
	}):Play()

	task.wait(0.2)
	gui.Enabled = false
	revealPhase = "idle"
end

local function processQueue()
	if revealRunning then
		return
	end

	revealRunning = true
	while #revealQueue > 0 do
		local nextPayload = table.remove(revealQueue, 1)
		showReveal(nextPayload)
	end
	revealRunning = false
end

closeButton.MouseButton1Click:Connect(function()
	if revealPhase == "rolling" then
		skipRoll = true
	elseif revealPhase == "revealed" then
		closeReveal = true
	end
end)

waveStatusEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "rewardReveal" then
		return
	end

	table.insert(revealQueue, payload)
	processQueue()
end)
