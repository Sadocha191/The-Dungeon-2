local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local playerProgressEvent = remoteEvents:FindFirstChild("PlayerProgressEvent") or remoteEvents:WaitForChild("PlayerProgressEvent", 5)

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local levelNameByKey = {}
if moduleFolder then
	local ok, levelsModule = pcall(function()
		return require(moduleFolder:WaitForChild("Levels"))
	end)
	if ok and levelsModule and typeof(levelsModule.GetAll) == "function" then
		for _, entry in ipairs(levelsModule.GetAll()) do
			if typeof(entry) == "table" then
				local levelName = tostring(entry.name or entry.key or entry.instanceName or "Unknown")
				if entry.key then
					levelNameByKey[tostring(entry.key)] = levelName
				end
				if entry.instanceName then
					levelNameByKey[tostring(entry.instanceName)] = levelName
				end
			end
		end
	end
end

local function prettifyLevelKey(levelKey)
	local raw = tostring(levelKey or "Unknown")
	raw = raw:gsub("(%l)(%u)", "%1 %2")
	raw = raw:gsub("_", " ")
	return raw
end

local function resolveLevelName(levelKey)
	return levelNameByKey[tostring(levelKey)] or prettifyLevelKey(levelKey)
end

local function addCorner(inst, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
	return corner
end

local function addStroke(inst, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Parent = inst
	return stroke
end

local function formatNumber(value)
	local numberValue = math.floor(tonumber(value) or 0)
	local formatted = tostring(numberValue)
	while true do
		local replaced, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return formatted
end

local function formatTime(secondsValue)
	local seconds = tonumber(secondsValue)
	if not seconds or seconds <= 0 then
		return "--"
	end

	local minutes = math.floor(seconds / 60)
	local secondsWhole = math.floor(seconds % 60)
	local hundredths = math.floor((seconds - math.floor(seconds)) * 100)
	return string.format("%02d:%02d.%02d", minutes, secondsWhole, hundredths)
end

local progress = {
	level = 1,
	xp = 0,
	nextXp = 120,
	silver = 0,
	levelRecords = {},
}

gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)

local root = gui:FindFirstChild("Frame")
if not (root and root:IsA("Frame")) then
	root = Instance.new("Frame")
	root.Name = "Frame"
	root.Parent = gui
end

root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
root.BackgroundTransparency = 0.35
root.BorderSizePixel = 0
root.Active = true

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0, 640, 0, 430)
panel.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
panel.BorderSizePixel = 0
panel.Parent = root
addCorner(panel, 22)
addStroke(panel, Color3.fromRGB(86, 98, 118), 0.12)

local panelGradient = Instance.new("UIGradient")
panelGradient.Rotation = 90
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 29, 42)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 15, 24)),
})
panelGradient.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(24, 22)
header.Size = UDim2.new(1, -48, 0, 104)
header.Parent = panel

local avatar = Instance.new("ImageLabel")
avatar.BackgroundColor3 = Color3.fromRGB(28, 36, 52)
avatar.BorderSizePixel = 0
avatar.Size = UDim2.fromOffset(80, 80)
avatar.Position = UDim2.fromOffset(0, 6)
avatar.Parent = header
addCorner(avatar, 22)
addStroke(avatar, Color3.fromRGB(95, 111, 137), 0.18)

local nameLabel = Instance.new("TextLabel")
nameLabel.BackgroundTransparency = 1
nameLabel.Position = UDim2.fromOffset(100, 8)
nameLabel.Size = UDim2.new(1, -170, 0, 32)
nameLabel.Font = Enum.Font.GothamBlack
nameLabel.TextSize = 28
nameLabel.TextColor3 = Color3.fromRGB(244, 247, 252)
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Text = player.DisplayName
nameLabel.Parent = header

local handleLabel = Instance.new("TextLabel")
handleLabel.BackgroundTransparency = 1
handleLabel.Position = UDim2.fromOffset(100, 42)
handleLabel.Size = UDim2.new(1, -170, 0, 20)
handleLabel.Font = Enum.Font.Gotham
handleLabel.TextSize = 14
handleLabel.TextColor3 = Color3.fromRGB(178, 188, 202)
handleLabel.TextXAlignment = Enum.TextXAlignment.Left
handleLabel.Text = "@" .. player.Name
handleLabel.Parent = header

local raceBadge = Instance.new("TextLabel")
raceBadge.BackgroundColor3 = Color3.fromRGB(39, 50, 70)
raceBadge.BorderSizePixel = 0
raceBadge.Position = UDim2.fromOffset(100, 70)
raceBadge.Size = UDim2.fromOffset(170, 28)
raceBadge.Font = Enum.Font.GothamBold
raceBadge.TextSize = 13
raceBadge.TextColor3 = Color3.fromRGB(234, 240, 248)
raceBadge.Text = "Race: Unknown"
raceBadge.Parent = header
addCorner(raceBadge, 13)

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(30, 38, 52)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.TextColor3 = Color3.fromRGB(237, 241, 247)
closeButton.Text = "X"
closeButton.Parent = header
addCorner(closeButton, 12)
addStroke(closeButton, Color3.fromRGB(86, 98, 120), 0.2)

local subheading = Instance.new("TextLabel")
subheading.BackgroundTransparency = 1
subheading.Position = UDim2.fromOffset(24, 124)
subheading.Size = UDim2.new(1, -48, 0, 22)
subheading.Font = Enum.Font.Gotham
subheading.TextSize = 13
subheading.TextColor3 = Color3.fromRGB(175, 185, 199)
subheading.TextXAlignment = Enum.TextXAlignment.Left
subheading.Text = "Quick view of your current lobby progress and best tracked level records."
subheading.Parent = panel

local cards = Instance.new("Frame")
cards.BackgroundTransparency = 1
cards.Position = UDim2.fromOffset(24, 158)
cards.Size = UDim2.new(1, -48, 0, 160)
cards.Parent = panel

local cardsLayout = Instance.new("UIGridLayout")
cardsLayout.CellPadding = UDim2.fromOffset(12, 12)
cardsLayout.CellSize = UDim2.new(0.5, -6, 0, 74)
cardsLayout.Parent = cards

local function createCard(titleText)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	card.BorderSizePixel = 0
	card.Parent = cards
	addCorner(card, 18)
	addStroke(card, Color3.fromRGB(72, 84, 104), 0.2)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 16)
	title.Font = Enum.Font.Gotham
	title.TextSize = 12
	title.TextColor3 = Color3.fromRGB(170, 181, 196)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.Parent = card

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromOffset(16, 28)
	value.Size = UDim2.new(1, -32, 0, 26)
	value.Font = Enum.Font.GothamBlack
	value.TextSize = 24
	value.TextColor3 = Color3.fromRGB(245, 248, 252)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Text = "--"
	value.Parent = card

	local detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(16, 54)
	detail.Size = UDim2.new(1, -32, 0, 14)
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 11
	detail.TextColor3 = Color3.fromRGB(144, 158, 176)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.Text = ""
	detail.Parent = card

	return value, detail
end

local levelValue, levelDetail = createCard("Level")
local silverValue, silverDetail = createCard("Silver")
local highscoreValue, highscoreDetail = createCard("Best Highscore")
local speedrunValue, speedrunDetail = createCard("Fastest Clear")

local progressCard = Instance.new("Frame")
progressCard.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
progressCard.BorderSizePixel = 0
progressCard.Position = UDim2.fromOffset(24, 330)
progressCard.Size = UDim2.new(1, -48, 0, 74)
progressCard.Parent = panel
addCorner(progressCard, 18)
addStroke(progressCard, Color3.fromRGB(72, 84, 104), 0.2)

local progressTitle = Instance.new("TextLabel")
progressTitle.BackgroundTransparency = 1
progressTitle.Position = UDim2.fromOffset(16, 12)
progressTitle.Size = UDim2.new(0.5, 0, 0, 16)
progressTitle.Font = Enum.Font.GothamBold
progressTitle.TextSize = 13
progressTitle.TextColor3 = Color3.fromRGB(235, 240, 247)
progressTitle.TextXAlignment = Enum.TextXAlignment.Left
progressTitle.Text = "XP Progress"
progressTitle.Parent = progressCard

local progressValue = Instance.new("TextLabel")
progressValue.BackgroundTransparency = 1
progressValue.AnchorPoint = Vector2.new(1, 0)
progressValue.Position = UDim2.new(1, -16, 0, 12)
progressValue.Size = UDim2.new(0.5, -16, 0, 16)
progressValue.Font = Enum.Font.Gotham
progressValue.TextSize = 12
progressValue.TextColor3 = Color3.fromRGB(170, 181, 196)
progressValue.TextXAlignment = Enum.TextXAlignment.Right
progressValue.Text = "0 / 120"
progressValue.Parent = progressCard

local progressBar = Instance.new("Frame")
progressBar.BackgroundColor3 = Color3.fromRGB(37, 45, 61)
progressBar.BorderSizePixel = 0
progressBar.Position = UDim2.fromOffset(16, 36)
progressBar.Size = UDim2.new(1, -32, 0, 14)
progressBar.Parent = progressCard
addCorner(progressBar, 7)

local progressFill = Instance.new("Frame")
progressFill.BackgroundColor3 = Color3.fromRGB(112, 178, 255)
progressFill.BorderSizePixel = 0
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.Parent = progressBar
addCorner(progressFill, 7)

local footerLabel = Instance.new("TextLabel")
footerLabel.BackgroundTransparency = 1
footerLabel.Position = UDim2.fromOffset(16, 54)
footerLabel.Size = UDim2.new(1, -32, 0, 14)
footerLabel.Font = Enum.Font.Gotham
footerLabel.TextSize = 11
footerLabel.TextColor3 = Color3.fromRGB(144, 158, 176)
footerLabel.TextXAlignment = Enum.TextXAlignment.Left
footerLabel.Text = "Press Esc to close."
footerLabel.Parent = progressCard

local function requestProgressSync()
	if not playerProgressEvent then
		return
	end

	pcall(function()
		playerProgressEvent:FireServer({ type = "requestSync" })
	end)
end

local function getSummary()
	local trackedLevels = 0
	local bestHighscore = 0
	local bestHighscoreLevel = nil
	local fastestClear = nil
	local fastestLevel = nil

	for levelKey, record in pairs(progress.levelRecords or {}) do
		if typeof(record) == "table" then
			local highscore = math.max(0, math.floor(tonumber(record.highscore or record.kills or 0) or 0))
			local speedrun = tonumber(record.speedrun)
			if speedrun and speedrun <= 0 then
				speedrun = nil
			end

			if highscore > 0 or speedrun then
				trackedLevels += 1
			end

			if highscore > bestHighscore then
				bestHighscore = highscore
				bestHighscoreLevel = levelKey
			end

			if speedrun and (not fastestClear or speedrun < fastestClear) then
				fastestClear = speedrun
				fastestLevel = levelKey
			end
		end
	end

	return trackedLevels, bestHighscore, bestHighscoreLevel, fastestClear, fastestLevel
end

local function render()
	nameLabel.Text = player.DisplayName
	handleLabel.Text = "@" .. player.Name

	local raceName = tostring(player:GetAttribute("Race") or "Unknown")
	if raceName == "" or raceName == "-" then
		raceName = "Unknown"
	end
	raceBadge.Text = "Race: " .. raceName

	local trackedLevels, bestHighscore, bestHighscoreLevel, fastestClear, fastestLevel = getSummary()
	local xp = math.max(0, math.floor(tonumber(progress.xp) or 0))
	local nextXp = math.max(1, math.floor(tonumber(progress.nextXp) or 1))
	local fillRatio = math.clamp(xp / nextXp, 0, 1)

	levelValue.Text = tostring(math.max(1, math.floor(tonumber(progress.level) or 1)))
	levelDetail.Text = string.format("%d tracked level%s", trackedLevels, trackedLevels == 1 and "" or "s")

	silverValue.Text = formatNumber(progress.silver)
	silverDetail.Text = "Current lobby currency"

	highscoreValue.Text = bestHighscore > 0 and formatNumber(bestHighscore) or "--"
	highscoreDetail.Text = bestHighscoreLevel and resolveLevelName(bestHighscoreLevel) or "No level highscore yet"

	speedrunValue.Text = fastestClear and formatTime(fastestClear) or "--"
	speedrunDetail.Text = fastestLevel and resolveLevelName(fastestLevel) or "No completed run yet"

	progressValue.Text = string.format("%s / %s XP", formatNumber(xp), formatNumber(nextXp))
	progressFill.Size = UDim2.fromScale(fillRatio, 1)
end

local function refreshAvatar()
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
	end)

	if ok then
		avatar.Image = content
	end
end

local function openUI()
	gui.Enabled = true
	requestProgressSync()
	render()
end

local function closeUI()
	gui.Enabled = false
end

local function toggleUI()
	if gui.Enabled then
		closeUI()
	else
		openUI()
	end
end

local lastScreenButtonsNonce = nil
local function handleScreenButtonsRequest()
	local nonce = gui:GetAttribute("ScreenButtonsNonce")
	if nonce == nil or nonce == lastScreenButtonsNonce then
		return
	end

	lastScreenButtonsNonce = nonce

	local action = gui:GetAttribute("ScreenButtonsAction")
	if action == "open" then
		openUI()
	elseif action == "close" then
		closeUI()
	elseif action == "toggle" then
		toggleUI()
	end
end

closeButton.Activated:Connect(closeUI)
root.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local x = input.Position.X
	local y = input.Position.Y
	local panelMin = panel.AbsolutePosition
	local panelMax = panelMin + panel.AbsoluteSize
	local clickedInsidePanel = x >= panelMin.X and x <= panelMax.X and y >= panelMin.Y and y <= panelMax.Y
	if not clickedInsidePanel then
		closeUI()
	end
end)

if playerProgressEvent then
	playerProgressEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or payload.type ~= "progress" then
			return
		end

		progress.level = tonumber(payload.level) or progress.level
		progress.xp = tonumber(payload.xp) or progress.xp
		progress.nextXp = tonumber(payload.nextXp) or progress.nextXp
		progress.silver = tonumber(payload.silver or payload.coins) or progress.silver
		progress.levelRecords = typeof(payload.levelRecords) == "table" and payload.levelRecords or progress.levelRecords
		render()
	end)
end

player:GetAttributeChangedSignal("Race"):Connect(render)
player:GetPropertyChangedSignal("DisplayName"):Connect(render)
gui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(handleScreenButtonsRequest)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)

refreshAvatar()
requestProgressSync()
handleScreenButtonsRequest()
render()
