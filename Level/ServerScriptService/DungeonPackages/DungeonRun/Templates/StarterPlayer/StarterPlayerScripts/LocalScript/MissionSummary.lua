local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local missionSummaryEvent = remotes:WaitForChild("MissionSummaryEvent")
local returnToLobby = ReplicatedStorage:FindFirstChild("ReturnToLobby")
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local TeleportOverlayController = moduleFolder and require(moduleFolder:WaitForChild("TeleportOverlayController"))

local gui = Instance.new("ScreenGui")
gui.Name = "MissionSummary"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 80
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(5, 6, 10)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Parent = gui

local dimGradient = Instance.new("UIGradient")
dimGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 12, 18)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 5, 8)),
})
dimGradient.Rotation = 90
dimGradient.Parent = dim

local vignette = Instance.new("Frame")
vignette.AnchorPoint = Vector2.new(0.5, 0.5)
vignette.Position = UDim2.fromScale(0.5, 0.5)
vignette.Size = UDim2.fromScale(1.15, 1.15)
vignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignette.BackgroundTransparency = 0.55
vignette.BorderSizePixel = 0
vignette.Parent = dim

local vignetteCorner = Instance.new("UICorner")
vignetteCorner.CornerRadius = UDim.new(1, 0)
vignetteCorner.Parent = vignette

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.53)
card.Size = UDim2.fromOffset(760, 460)
card.BackgroundColor3 = Color3.fromRGB(14, 17, 24)
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.Parent = dim

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 24)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 1
cardStroke.Transparency = 0.15
cardStroke.Color = Color3.fromRGB(108, 176, 255)
cardStroke.Parent = card

local cardSizeConstraint = Instance.new("UISizeConstraint")
cardSizeConstraint.MaxSize = Vector2.new(760, 460)
cardSizeConstraint.MinSize = Vector2.new(520, 340)
cardSizeConstraint.Parent = card

local cardAspect = Instance.new("UIAspectRatioConstraint")
cardAspect.AspectRatio = 760 / 460
cardAspect.DominantAxis = Enum.DominantAxis.Width
cardAspect.Parent = card

local cardScale = Instance.new("UIScale")
cardScale.Scale = 0.92
cardScale.Parent = card

local topAccent = Instance.new("Frame")
topAccent.Size = UDim2.new(1, 0, 0, 7)
topAccent.BackgroundColor3 = Color3.fromRGB(108, 176, 255)
topAccent.BorderSizePixel = 0
topAccent.Parent = card

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(0, 24)
accentCorner.Parent = topAccent

local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(28, 26)
header.Size = UDim2.new(1, -56, 0, 88)
header.Parent = card

local heading = Instance.new("TextLabel")
heading.BackgroundTransparency = 1
heading.Position = UDim2.fromOffset(0, 0)
heading.Size = UDim2.new(1, -160, 0, 28)
heading.Font = Enum.Font.GothamBold
heading.TextSize = 14
heading.TextColor3 = Color3.fromRGB(157, 169, 190)
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Text = "RUN SUMMARY"
heading.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(0, 24)
title.Size = UDim2.new(1, -180, 0, 36)
title.Font = Enum.Font.GothamBlack
title.TextSize = 30
title.TextColor3 = Color3.fromRGB(245, 247, 251)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "The Dungeon Fell Silent"
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(0, 58)
subtitle.Size = UDim2.new(1, -180, 0, 24)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextColor3 = Color3.fromRGB(189, 198, 214)
subtitle.TextWrapped = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "Rewards from this run are now locked in."
subtitle.Parent = header

local resultPill = Instance.new("TextLabel")
resultPill.AnchorPoint = Vector2.new(1, 0)
resultPill.Position = UDim2.new(1, -54, 0, 30)
resultPill.Size = UDim2.fromOffset(132, 34)
resultPill.BackgroundColor3 = Color3.fromRGB(44, 118, 94)
resultPill.BorderSizePixel = 0
resultPill.Font = Enum.Font.GothamBold
resultPill.TextSize = 14
resultPill.TextColor3 = Color3.fromRGB(245, 247, 251)
resultPill.Text = "VICTORY"
resultPill.Parent = card

local resultCorner = Instance.new("UICorner")
resultCorner.CornerRadius = UDim.new(0, 12)
resultCorner.Parent = resultPill

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -18, 0, 18)
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

local statsFrame = Instance.new("Frame")
statsFrame.BackgroundTransparency = 1
statsFrame.Position = UDim2.fromOffset(28, 130)
statsFrame.Size = UDim2.new(1, -56, 1, -204)
statsFrame.Parent = card

local statsLayout = Instance.new("UIGridLayout")
statsLayout.CellPadding = UDim2.fromOffset(14, 14)
statsLayout.CellSize = UDim2.new(0.5, -7, 0, 86)
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsFrame

local footer = Instance.new("Frame")
footer.BackgroundTransparency = 1
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.Position = UDim2.new(0.5, 0, 1, -22)
footer.Size = UDim2.new(1, -56, 0, 60)
footer.Parent = card

local footerHint = Instance.new("TextLabel")
footerHint.BackgroundTransparency = 1
footerHint.Position = UDim2.new(0, 0, 0, 0)
footerHint.Size = UDim2.new(1, -232, 1, 0)
footerHint.Font = Enum.Font.Gotham
footerHint.TextSize = 13
footerHint.TextColor3 = Color3.fromRGB(168, 179, 196)
footerHint.TextWrapped = true
footerHint.TextXAlignment = Enum.TextXAlignment.Left
footerHint.Text = "Your account progress is already saved. You can leave now or inspect the summary for a moment."
footerHint.Parent = footer

local primaryButton = Instance.new("TextButton")
primaryButton.AnchorPoint = Vector2.new(1, 0.5)
primaryButton.Position = UDim2.new(1, 0, 0.5, 0)
primaryButton.Size = UDim2.fromOffset(220, 42)
primaryButton.BackgroundColor3 = Color3.fromRGB(109, 176, 255)
primaryButton.BorderSizePixel = 0
primaryButton.Font = Enum.Font.GothamBold
primaryButton.TextSize = 15
primaryButton.TextColor3 = Color3.fromRGB(7, 10, 16)
primaryButton.Text = returnToLobby and "Return To Lobby" or "Close"
primaryButton.Parent = footer

local primaryCorner = Instance.new("UICorner")
primaryCorner.CornerRadius = UDim.new(0, 14)
primaryCorner.Parent = primaryButton

local statCards = {}
local counterTokens = {}

local function formatInteger(value)
	local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	local reversed = string.reverse(text):gsub("(%d%d%d)", "%1,")
	reversed = reversed:gsub(",$", "")
	return string.reverse(reversed)
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%02d:%02d", minutes, remainder)
end

local function createStatCard(order, headingText, accentColor)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundColor3 = Color3.fromRGB(19, 24, 34)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = statsFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.55
	stroke.Color = accentColor
	stroke.Parent = frame

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 5, 1, -18)
	accent.Position = UDim2.new(0, 10, 0, 9)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel = 0
	accent.Parent = frame

	local accentRound = Instance.new("UICorner")
	accentRound.CornerRadius = UDim.new(1, 0)
	accentRound.Parent = accent

	local headingLabel = Instance.new("TextLabel")
	headingLabel.BackgroundTransparency = 1
	headingLabel.Position = UDim2.fromOffset(26, 14)
	headingLabel.Size = UDim2.new(1, -42, 0, 18)
	headingLabel.Font = Enum.Font.GothamMedium
	headingLabel.TextSize = 13
	headingLabel.TextColor3 = Color3.fromRGB(152, 166, 186)
	headingLabel.TextXAlignment = Enum.TextXAlignment.Left
	headingLabel.Text = headingText
	headingLabel.Parent = frame

	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.Position = UDim2.fromOffset(26, 34)
	valueLabel.Size = UDim2.new(1, -42, 0, 34)
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 24
	valueLabel.TextColor3 = Color3.fromRGB(244, 247, 252)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Text = "--"
	valueLabel.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.96
	scale.Parent = frame

	return {
		frame = frame,
		valueLabel = valueLabel,
		scale = scale,
	}
end

statCards.time = createStatCard(1, "Run Time", Color3.fromRGB(109, 176, 255))
statCards.kills = createStatCard(2, "Enemies Defeated", Color3.fromRGB(255, 122, 122))
statCards.silver = createStatCard(3, "Silver Gained", Color3.fromRGB(255, 211, 104))
statCards.gold = createStatCard(4, "Run Gold", Color3.fromRGB(255, 171, 74))
statCards.xp = createStatCard(5, "Account XP", Color3.fromRGB(112, 231, 170))
statCards.level = createStatCard(6, "Account Level", Color3.fromRGB(189, 132, 255))

local function animateCardPop(cardInfo, delaySec)
	task.delay(delaySec, function()
		if not gui.Enabled then
			return
		end
		cardInfo.scale.Scale = 0.93
		TweenService:Create(cardInfo.scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)
end

local function animateCounter(cardInfo, targetValue, formatter, duration)
	local token = {}
	counterTokens[cardInfo] = token

	local startedAt = os.clock()
	duration = math.max(0.25, tonumber(duration) or 0.7)

	task.spawn(function()
		while gui.Enabled and counterTokens[cardInfo] == token do
			local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			local eased = 1 - ((1 - alpha) * (1 - alpha) * (1 - alpha))
			local currentValue = math.floor(targetValue * eased + 0.5)
			cardInfo.valueLabel.Text = formatter(currentValue)
			if alpha >= 1 then
				break
			end
			task.wait()
		end

		if counterTokens[cardInfo] == token then
			cardInfo.valueLabel.Text = formatter(targetValue)
		end
	end)
end

local function closeSummary()
	if returnToLobby and returnToLobby:IsA("RemoteEvent") then
		if TeleportOverlayController and TeleportOverlayController.Show then
			TeleportOverlayController.Show("Teleporting...")
		end
		returnToLobby:FireServer()
	else
		gui.Enabled = false
	end
end

primaryButton.MouseButton1Click:Connect(closeSummary)
closeButton.MouseButton1Click:Connect(closeSummary)

local function showSummary(payload)
	local reason = tostring(payload.reason or "Game Over")
	local timeValue = math.max(0, math.floor(tonumber(payload.time) or 0))
	local killsValue = math.max(0, math.floor(tonumber(payload.kills) or 0))
	local silverValue = math.max(0, math.floor(tonumber(payload.coinsGained) or 0))
	local goldValue = math.max(0, math.floor(tonumber(payload.goldEarned) or 0))
	local xpValue = math.max(0, math.floor(tonumber(payload.accountXp) or 0))
	local levelValue = math.max(1, math.floor(tonumber(payload.accountLevel) or 1))

	local isVictory = string.lower(reason) == "victory"
	local themeColor = isVictory and Color3.fromRGB(92, 196, 138) or Color3.fromRGB(255, 111, 111)
	local accentColor = isVictory and Color3.fromRGB(109, 176, 255) or Color3.fromRGB(255, 126, 96)

	gui.Enabled = true
	dim.BackgroundTransparency = 1
	card.BackgroundTransparency = 0.25
	cardScale.Scale = 0.92
	card.Position = UDim2.fromScale(0.5, 0.56)
	cardStroke.Color = accentColor
	topAccent.BackgroundColor3 = accentColor

	resultPill.BackgroundColor3 = themeColor
	resultPill.Text = isVictory and "VICTORY" or "RUN FAILED"
	title.Text = isVictory and "Run Cleared" or "Expedition Failed"
	subtitle.Text = isVictory
		and "The team secured the exit. Rewards and progression from this run have been banked."
		or "The dungeon pushed back. Your progress for this attempt has already been recorded."

	for _, cardInfo in pairs(statCards) do
		cardInfo.valueLabel.Text = "--"
		cardInfo.scale.Scale = 0.96
	end

	TweenService:Create(dim, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.26,
	}):Play()
	TweenService:Create(card, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.08,
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	TweenService:Create(cardScale, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	animateCardPop(statCards.time, 0.05)
	animateCardPop(statCards.kills, 0.09)
	animateCardPop(statCards.silver, 0.13)
	animateCardPop(statCards.gold, 0.17)
	animateCardPop(statCards.xp, 0.21)
	animateCardPop(statCards.level, 0.25)

	animateCounter(statCards.time, timeValue, formatTime, 0.8)
	animateCounter(statCards.kills, killsValue, formatInteger, 0.72)
	animateCounter(statCards.silver, silverValue, formatInteger, 0.75)
	animateCounter(statCards.gold, goldValue, formatInteger, 0.78)
	animateCounter(statCards.xp, xpValue, formatInteger, 0.82)
	animateCounter(statCards.level, levelValue, formatInteger, 0.66)
end

missionSummaryEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "gameover" then
		return
	end
	showSummary(payload)
end)
