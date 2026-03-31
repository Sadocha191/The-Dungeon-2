-- MissionsUI.lua (LocalScript)
-- Otwiera misje po promcie Knight, ale tylko po ukończeniu tutoriala.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local moduleRoot = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local UiResponsive = require(moduleRoot:WaitForChild("UiResponsive"))

local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local RF_GetMissions = remoteFunctions:WaitForChild("RF_GetMissions")
local RF_ClaimMission = remoteFunctions:WaitForChild("RF_ClaimMission")
local RF_GetTutorialState = remoteFunctions:WaitForChild("RF_GetTutorialState")

local DAILY_MAX = 6
local WEEKLY_MAX = 12

local dailyResetAt: number? = nil
local weeklyResetAt: number? = nil
local currentTab = "Daily"

local THEME = table.freeze({
	overlay = Color3.fromRGB(4, 6, 11),
	panel = Color3.fromRGB(10, 14, 22),
	panelEdge = Color3.fromRGB(78, 90, 108),
	panelAlt = Color3.fromRGB(18, 23, 35),
	panelAltSoft = Color3.fromRGB(26, 33, 47),
	card = Color3.fromRGB(17, 22, 33),
	cardSoft = Color3.fromRGB(25, 30, 44),
	cardBorder = Color3.fromRGB(60, 73, 95),
	text = Color3.fromRGB(245, 247, 250),
	textSoft = Color3.fromRGB(198, 205, 216),
	textMuted = Color3.fromRGB(145, 156, 173),
	daily = Color3.fromRGB(220, 169, 91),
	dailySoft = Color3.fromRGB(120, 85, 38),
	weekly = Color3.fromRGB(111, 157, 255),
	weeklySoft = Color3.fromRGB(45, 72, 120),
	claim = Color3.fromRGB(105, 194, 129),
	claimSoft = Color3.fromRGB(33, 73, 43),
	completed = Color3.fromRGB(92, 179, 120),
	completedSoft = Color3.fromRGB(29, 62, 40),
	tabBg = Color3.fromRGB(22, 28, 40),
	tabBorder = Color3.fromRGB(54, 66, 85),
	buttonDark = Color3.fromRGB(34, 41, 58),
	buttonDarkBorder = Color3.fromRGB(67, 78, 98),
})

local function formatCountdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return ("%02d:%02d:%02d"):format(h, m, s)
end

local function tutorialComplete(): boolean
	local ok, t = pcall(function()
		return RF_GetTutorialState:InvokeServer()
	end)
	if not ok or typeof(t) ~= "table" then
		return false
	end
	return t.Complete == true
end

local function addCorner(inst: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
	return corner
end

local function addStroke(inst: Instance, color: Color3, thickness: number?, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 1
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Parent = inst
	return stroke
end

local function colorSequence(colors)
	if #colors == 2 then
		return ColorSequence.new(colors[1], colors[2])
	end

	local points = {}
	local denom = math.max(1, #colors - 1)
	for index, color in ipairs(colors) do
		points[#points + 1] = ColorSequenceKeypoint.new((index - 1) / denom, color)
	end
	return ColorSequence.new(points)
end

local function numberSequence(values)
	if #values == 2 then
		return NumberSequence.new(values[1], values[2])
	end

	local points = {}
	local denom = math.max(1, #values - 1)
	for index, value in ipairs(values) do
		points[#points + 1] = NumberSequenceKeypoint.new((index - 1) / denom, value)
	end
	return NumberSequence.new(points)
end

local function addGradient(inst: Instance, rotation: number, colors, transparencies)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Color = colorSequence(colors)
	if transparencies then
		gradient.Transparency = numberSequence(transparencies)
	end
	gradient.Parent = inst
	return gradient
end

local function getProgressInfo(mission: any)
	local prog = (typeof(mission) == "table") and mission.Progress
	if typeof(prog) ~= "table" then
		return 0, 0, 0
	end

	local current = math.max(0, math.floor(tonumber(prog.Current) or 0))
	local target = math.max(0, math.floor(tonumber(prog.Target) or 0))
	if target <= 0 then
		return current, target, 0
	end
	return current, target, math.clamp(current / target, 0, 1)
end

local function formatProgress(mission: any): string
	local current, target = getProgressInfo(mission)
	if target <= 0 then
		return "No tracked progress"
	end
	return ("%d / %d complete"):format(current, target)
end

local function getMissionState(mission: any)
	local claimCount = tonumber(mission.ClaimCount) or 0
	local repeatable = mission.Repeatable == true
	local completed = claimCount > 0 and not repeatable
	local claimable = mission.Claimable == true and not completed
	local current, target, fraction = getProgressInfo(mission)
	if completed and target > 0 then
		current = target
		fraction = 1
	end
	return {
		claimable = claimable,
		completed = completed,
		current = current,
		target = target,
		fraction = fraction,
	}
end

local function buildRewardParts(reward: any)
	local parts = {}
	if typeof(reward) ~= "table" then
		return parts
	end

	local silver = tonumber(reward.Silver) or 0
	local wp = tonumber(reward.WeaponPoints) or 0

	if silver > 0 then
		parts[#parts + 1] = {
			text = ("Silver +%d"):format(silver),
			fill = Color3.fromRGB(89, 66, 26),
			stroke = Color3.fromRGB(178, 134, 62),
			textColor = Color3.fromRGB(255, 234, 186),
		}
	end
	if wp > 0 then
		parts[#parts + 1] = {
			text = ("WP +%d"):format(wp),
			fill = Color3.fromRGB(41, 59, 96),
			stroke = Color3.fromRGB(94, 130, 210),
			textColor = Color3.fromRGB(214, 228, 255),
		}
	end

	return parts
end

local function summarizeMissions(missions)
	local summary = {
		total = #missions,
		claimable = 0,
		completed = 0,
	}

	for _, mission in ipairs(missions) do
		local state = getMissionState(mission)
		if state.claimable then
			summary.claimable += 1
		end
		if state.completed then
			summary.completed += 1
		end
	end

	return summary
end

local function setButtonInteractable(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.Selectable = enabled
end

-- ===== UI =====
local gui = playerGui:WaitForChild("MissionsGui")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
gui:SetAttribute("Modal", true)

local overlay = gui:WaitForChild("overlay")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = THEME.overlay
overlay.BackgroundTransparency = 0.24
overlay.BorderSizePixel = 0
overlay.Parent = gui
addGradient(overlay, 90, {
	Color3.fromRGB(6, 8, 13),
	Color3.fromRGB(3, 5, 9),
})

local panel = overlay:WaitForChild("panel")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.9)
panel.BackgroundColor3 = THEME.panel
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = overlay
addCorner(panel, 24)
local panelSizeConstraint = Instance.new("UISizeConstraint", panel)
panelSizeConstraint.MaxSize = Vector2.new(1080, 620)
local panelAspect = Instance.new("UIAspectRatioConstraint", panel)
panelAspect.AspectRatio = 1080 / 620
panelAspect.DominantAxis = Enum.DominantAxis.Height
addStroke(panel, THEME.panelEdge, 1, 0.15)
addGradient(panel, 90, {
	Color3.fromRGB(15, 20, 31),
	Color3.fromRGB(9, 12, 18),
})
UiResponsive.attachCenteredPanel(panel, Vector2.new(1080, 620))

local headerCard = Instance.new("Frame")
headerCard.Position = UDim2.fromOffset(20, 20)
headerCard.Size = UDim2.new(1, -40, 0, 110)
headerCard.BackgroundColor3 = THEME.panelAlt
headerCard.BorderSizePixel = 0
headerCard.Parent = panel
addCorner(headerCard, 20)
addStroke(headerCard, THEME.cardBorder, 1, 0.22)
addGradient(headerCard, 0, {
	Color3.fromRGB(31, 24, 17),
	Color3.fromRGB(18, 24, 39),
	Color3.fromRGB(14, 18, 29),
})

local headerAccent = Instance.new("Frame")
headerAccent.Size = UDim2.new(1, 0, 0, 4)
headerAccent.BackgroundColor3 = THEME.daily
headerAccent.BorderSizePixel = 0
headerAccent.Parent = headerCard
addCorner(headerAccent, 12)

local eyebrow = Instance.new("TextLabel")
eyebrow.BackgroundTransparency = 1
eyebrow.Position = UDim2.fromOffset(20, 14)
eyebrow.Size = UDim2.fromOffset(200, 16)
eyebrow.Font = Enum.Font.GothamBold
eyebrow.TextSize = 11
eyebrow.TextColor3 = Color3.fromRGB(255, 216, 153)
eyebrow.TextXAlignment = Enum.TextXAlignment.Left
eyebrow.Text = "KNIGHT'S BOARD"
eyebrow.Parent = headerCard

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(20, 28)
title.Size = UDim2.new(1, -280, 0, 34)
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.TextColor3 = THEME.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Daily Dispatch"
title.Parent = headerCard

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(20, 64)
subtitle.Size = UDim2.new(1, -300, 0, 32)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextColor3 = THEME.textSoft
subtitle.TextWrapped = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.Text = "Track rotating contracts, finish runs, and cash out mission rewards straight from the lobby."
subtitle.Parent = headerCard

local resetInfo = Instance.new("Frame")
resetInfo.AnchorPoint = Vector2.new(1, 0)
resetInfo.Position = UDim2.new(1, -64, 0, 18)
resetInfo.Size = UDim2.fromOffset(250, 34)
resetInfo.BackgroundColor3 = Color3.fromRGB(20, 25, 36)
resetInfo.BorderSizePixel = 0
resetInfo.Parent = headerCard
addCorner(resetInfo, 17)
addStroke(resetInfo, THEME.cardBorder, 1, 0.22)

local resetInfoText = Instance.new("TextLabel")
resetInfoText.BackgroundTransparency = 1
resetInfoText.Position = UDim2.fromOffset(14, 0)
resetInfoText.Size = UDim2.new(1, -28, 1, 0)
resetInfoText.Font = Enum.Font.GothamMedium
resetInfoText.TextSize = 12
resetInfoText.TextColor3 = THEME.textSoft
resetInfoText.TextXAlignment = Enum.TextXAlignment.Center
resetInfoText.Text = ""
resetInfoText.Parent = resetInfo

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -18, 0, 16)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.BackgroundColor3 = Color3.fromRGB(28, 33, 46)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(224, 230, 238)
closeBtn.Text = "X"
closeBtn.Parent = panel
addCorner(closeBtn, 12)
addStroke(closeBtn, THEME.buttonDarkBorder, 1, 0.18)

local tabsWrap = Instance.new("Frame")
tabsWrap.BackgroundTransparency = 1
tabsWrap.Position = UDim2.fromOffset(20, 144)
tabsWrap.Size = UDim2.new(1, -40, 0, 44)
tabsWrap.Parent = panel

local tabsRail = Instance.new("Frame")
tabsRail.Size = UDim2.fromOffset(360, 44)
tabsRail.BackgroundColor3 = THEME.tabBg
tabsRail.BorderSizePixel = 0
tabsRail.Parent = tabsWrap
addCorner(tabsRail, 18)
addStroke(tabsRail, THEME.tabBorder, 1, 0.18)

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 10)
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabsLayout.Parent = tabsRail

local tabsPadding = Instance.new("UIPadding")
tabsPadding.PaddingLeft = UDim.new(0, 8)
tabsPadding.PaddingRight = UDim.new(0, 8)
tabsPadding.PaddingTop = UDim.new(0, 6)
tabsPadding.PaddingBottom = UDim.new(0, 6)
tabsPadding.Parent = tabsRail

local function makeTab(text: string)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(167, 32)
	button.BackgroundColor3 = THEME.tabBg
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = Color3.fromRGB(242, 246, 252)
	button.Text = text
	button.Parent = tabsRail
	addCorner(button, 14)
	local stroke = addStroke(button, THEME.tabBorder, 1, 0.2)
	local gradient = addGradient(button, 90, {
		Color3.fromRGB(26, 32, 46),
		Color3.fromRGB(19, 24, 35),
	})
	return {
		button = button,
		stroke = stroke,
		gradient = gradient,
	}
end

local tabDaily = makeTab("Daily")
local tabWeekly = makeTab("Weekly")

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(20, 200)
body.Size = UDim2.new(1, -40, 1, -220)
body.Parent = panel

local function makeValueChip(parent: Instance, accent: Color3, labelText: string)
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromOffset(128, 40)
	chip.BackgroundColor3 = Color3.fromRGB(18, 23, 34)
	chip.BorderSizePixel = 0
	chip.Parent = parent
	addCorner(chip, 14)
	addStroke(chip, accent, 1, 0.35)

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromOffset(12, 4)
	value.Size = UDim2.new(1, -24, 0, 20)
	value.Font = Enum.Font.GothamBlack
	value.TextSize = 18
	value.TextColor3 = THEME.text
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Text = "0"
	value.Parent = chip

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 22)
	label.Size = UDim2.new(1, -24, 0, 14)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	label.TextColor3 = THEME.textMuted
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.Parent = chip

	return {
		frame = chip,
		value = value,
		label = label,
	}
end

local function makeMissionPage(parent: Instance, titleText: string, subtitleText: string, accent: Color3, accentSoft: Color3, emptyText: string)
	local page = Instance.new("Frame")
	page.BackgroundTransparency = 1
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent

	local summary = Instance.new("Frame")
	summary.Size = UDim2.new(1, 0, 0, 0)
	summary.BackgroundColor3 = THEME.panelAlt
	summary.BorderSizePixel = 0
	summary.Parent = page
	summary.Visible = false
	addCorner(summary, 20)
	addStroke(summary, accent, 1, 0.28)
	addGradient(summary, 0, {
		accentSoft,
		THEME.panelAlt,
		THEME.panelAltSoft,
	})

	local summaryAccent = Instance.new("Frame")
	summaryAccent.Size = UDim2.new(0, 5, 1, -28)
	summaryAccent.Position = UDim2.fromOffset(14, 14)
	summaryAccent.BackgroundColor3 = accent
	summaryAccent.BorderSizePixel = 0
	summaryAccent.Parent = summary
	addCorner(summaryAccent, 6)

	local summaryTitle = Instance.new("TextLabel")
	summaryTitle.BackgroundTransparency = 1
	summaryTitle.Position = UDim2.fromOffset(32, 16)
	summaryTitle.Size = UDim2.new(1, -260, 0, 24)
	summaryTitle.Font = Enum.Font.GothamBlack
	summaryTitle.TextSize = 20
	summaryTitle.TextColor3 = THEME.text
	summaryTitle.TextXAlignment = Enum.TextXAlignment.Left
	summaryTitle.Text = titleText
	summaryTitle.Parent = summary

	local summarySubtitle = Instance.new("TextLabel")
	summarySubtitle.BackgroundTransparency = 1
	summarySubtitle.Position = UDim2.fromOffset(32, 42)
	summarySubtitle.Size = UDim2.new(1, -300, 0, 34)
	summarySubtitle.Font = Enum.Font.Gotham
	summarySubtitle.TextSize = 12
	summarySubtitle.TextColor3 = THEME.textSoft
	summarySubtitle.TextWrapped = true
	summarySubtitle.TextXAlignment = Enum.TextXAlignment.Left
	summarySubtitle.TextYAlignment = Enum.TextYAlignment.Top
	summarySubtitle.Text = subtitleText
	summarySubtitle.Parent = summary

	local resetPill = Instance.new("Frame")
	resetPill.AnchorPoint = Vector2.new(1, 0)
	resetPill.Position = UDim2.new(1, -18, 0, 18)
	resetPill.Size = UDim2.fromOffset(190, 28)
	resetPill.BackgroundColor3 = Color3.fromRGB(18, 23, 34)
	resetPill.BorderSizePixel = 0
	resetPill.Parent = summary
	addCorner(resetPill, 14)
	addStroke(resetPill, accent, 1, 0.3)

	local resetText = Instance.new("TextLabel")
	resetText.BackgroundTransparency = 1
	resetText.Position = UDim2.fromOffset(12, 0)
	resetText.Size = UDim2.new(1, -24, 1, 0)
	resetText.Font = Enum.Font.GothamBold
	resetText.TextSize = 11
	resetText.TextColor3 = THEME.textSoft
	resetText.TextXAlignment = Enum.TextXAlignment.Center
	resetText.Text = ""
	resetText.Parent = resetPill

	local chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Position = UDim2.fromOffset(32, 74)
	chips.Size = UDim2.new(1, -50, 0, 40)
	chips.Parent = summary

	local chipsLayout = Instance.new("UIListLayout")
	chipsLayout.FillDirection = Enum.FillDirection.Horizontal
	chipsLayout.Padding = UDim.new(0, 10)
	chipsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	chipsLayout.Parent = chips

	local missionCountChip = makeValueChip(chips, accent, "MISSIONS")
	local claimableChip = makeValueChip(chips, THEME.claim, "READY")
	local completedChip = makeValueChip(chips, THEME.completed, "DONE")

	local listShell = Instance.new("Frame")
	listShell.Position = UDim2.fromOffset(0, 0)
	listShell.Size = UDim2.new(1, 0, 1, 0)
	listShell.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	listShell.BorderSizePixel = 0
	listShell.Parent = page
	addCorner(listShell, 20)
	addStroke(listShell, THEME.cardBorder, 1, 0.24)

	local listHeader = Instance.new("TextLabel")
	listHeader.BackgroundTransparency = 1
	listHeader.Position = UDim2.fromOffset(18, 16)
	listHeader.Size = UDim2.new(1, -36, 0, 22)
	listHeader.Font = Enum.Font.GothamBold
	listHeader.TextSize = 14
	listHeader.TextColor3 = THEME.text
	listHeader.TextXAlignment = Enum.TextXAlignment.Left
	listHeader.Text = "Board Entries"
	listHeader.Parent = listShell

	local listSubheader = Instance.new("TextLabel")
	listSubheader.BackgroundTransparency = 1
	listSubheader.Position = UDim2.fromOffset(18, 38)
	listSubheader.Size = UDim2.new(1, -36, 0, 18)
	listSubheader.Font = Enum.Font.Gotham
	listSubheader.TextSize = 12
	listSubheader.TextColor3 = THEME.textMuted
	listSubheader.TextXAlignment = Enum.TextXAlignment.Left
	listSubheader.Text = "Claimable missions light up when their objective is complete."
	listSubheader.Parent = listShell

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(18, 68)
	list.Size = UDim2.new(1, -36, 1, -84)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = accent
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = listShell

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingBottom = UDim.new(0, 10)
	listPadding.Parent = list

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = list

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	emptyLabel.Position = UDim2.fromScale(0.5, 0.5)
	emptyLabel.Size = UDim2.new(1, -64, 0, 48)
	emptyLabel.Font = Enum.Font.GothamMedium
	emptyLabel.TextSize = 13
	emptyLabel.TextColor3 = THEME.textMuted
	emptyLabel.TextWrapped = true
	emptyLabel.Text = emptyText
	emptyLabel.Visible = false
	emptyLabel.Parent = listShell

	return {
		page = page,
		resetText = resetText,
		missionCountChip = missionCountChip,
		claimableChip = claimableChip,
		completedChip = completedChip,
		list = list,
		emptyLabel = emptyLabel,
		accent = accent,
	}
end

local dailyPage = makeMissionPage(
	body,
	"Daily Contracts",
	"Six rotating objectives for fast silver, weapon point income, and a clean mission board every day.",
	THEME.daily,
	THEME.dailySoft,
	"No daily missions are available right now."
)

local weeklyPage = makeMissionPage(
	body,
	"Weekly Orders",
	"Longer objectives with bigger payouts. Treat these like anchor goals for several runs.",
	THEME.weekly,
	THEME.weeklySoft,
	"No weekly missions are available right now."
)
weeklyPage.page.Visible = false

local function applyTabStyle(tabRef, active: boolean, accent: Color3)
	tabRef.button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(242, 246, 252)
	tabRef.button.BackgroundColor3 = active and accent or Color3.fromRGB(58, 69, 92)
	tabRef.stroke.Color = active and accent or Color3.fromRGB(168, 180, 204)
	tabRef.stroke.Transparency = active and 0.03 or 0.08
	tabRef.gradient.Color = active and colorSequence({
		Color3.new(
			math.min(accent.R + 0.08, 1),
			math.min(accent.G + 0.08, 1),
			math.min(accent.B + 0.08, 1)
		),
		accent,
	}) or colorSequence({
		Color3.fromRGB(39, 47, 64),
		Color3.fromRGB(23, 29, 40),
	})
end

local function setTab(which: string)
	currentTab = which
	local dailyActive = which == "Daily"
	dailyPage.page.Visible = dailyActive
	weeklyPage.page.Visible = not dailyActive
	applyTabStyle(tabDaily, dailyActive, THEME.daily)
	applyTabStyle(tabWeekly, not dailyActive, THEME.weekly)
	headerAccent.BackgroundColor3 = dailyActive and THEME.daily or THEME.weekly
	title.Text = dailyActive and "Daily Dispatch" or "Weekly Orders"
	subtitle.Text = dailyActive
		and "Track rotating contracts, finish runs, and cash out mission rewards straight from the lobby."
		or "Check long-form weekly objectives, stack progress across runs, and collect heavier payouts."
end

tabDaily.button.MouseButton1Click:Connect(function()
	setTab("Daily")
end)

tabWeekly.button.MouseButton1Click:Connect(function()
	setTab("Weekly")
end)

local function clearList(list: ScrollingFrame)
	for _, ch in ipairs(list:GetChildren()) do
		if ch:GetAttribute("MissionRow") == true then
			ch:Destroy()
		end
	end
end

local function makeMissionRow(parentList: ScrollingFrame, mission: any, onClaim)
	local state = getMissionState(mission)
	local accent = mission.Type == "Weekly" and THEME.weekly or THEME.daily
	local accentSoft = mission.Type == "Weekly" and THEME.weeklySoft or THEME.dailySoft
	if state.claimable then
		accent = THEME.claim
		accentSoft = THEME.claimSoft
	elseif state.completed then
		accent = THEME.completed
		accentSoft = THEME.completedSoft
	end

	local row = Instance.new("Frame")
	row:SetAttribute("MissionRow", true)
	row.Size = UDim2.new(1, 0, 0, 126)
	row.BackgroundColor3 = THEME.card
	row.BorderSizePixel = 0
	row.Parent = parentList
	addCorner(row, 18)
	addStroke(row, THEME.cardBorder, 1, 0.22)
	addGradient(row, 0, {
		accentSoft,
		THEME.card,
		THEME.cardSoft,
	})

	local accentBar = Instance.new("Frame")
	accentBar.Position = UDim2.fromOffset(14, 14)
	accentBar.Size = UDim2.new(0, 5, 1, -28)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = row
	addCorner(accentBar, 6)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(30, 14)
	titleLabel.Size = UDim2.new(1, -210, 0, 22)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = THEME.text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = tostring(mission.Title or mission.Id or "Mission")
	titleLabel.Parent = row

	local rewardHolder = Instance.new("Frame")
	rewardHolder.AnchorPoint = Vector2.new(1, 0)
	rewardHolder.Position = UDim2.new(1, -142, 0, 16)
	rewardHolder.Size = UDim2.fromOffset(0, 24)
	rewardHolder.BackgroundTransparency = 1
	rewardHolder.Parent = row

	local rewardLayout = Instance.new("UIListLayout")
	rewardLayout.FillDirection = Enum.FillDirection.Horizontal
	rewardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rewardLayout.Padding = UDim.new(0, 6)
	rewardLayout.Parent = rewardHolder

	for _, rewardPart in ipairs(buildRewardParts(mission.Reward)) do
		local pill = Instance.new("Frame")
		pill.BackgroundColor3 = rewardPart.fill
		pill.BorderSizePixel = 0
		pill.Parent = rewardHolder
		addCorner(pill, 11)
		addStroke(pill, rewardPart.stroke, 1, 0.12)

		local rewardText = Instance.new("TextLabel")
		rewardText.BackgroundTransparency = 1
		rewardText.Position = UDim2.fromOffset(10, 0)
		rewardText.Size = UDim2.new(1, -20, 1, 0)
		rewardText.Font = Enum.Font.GothamBold
		rewardText.TextSize = 11
		rewardText.TextColor3 = rewardPart.textColor
		rewardText.TextXAlignment = Enum.TextXAlignment.Center
		rewardText.Text = rewardPart.text
		rewardText.Parent = pill

		local rewardBounds = TextService:GetTextSize(rewardPart.text, 11, Enum.Font.GothamBold, Vector2.new(200, 18))
		pill.Size = UDim2.fromOffset(rewardBounds.X + 24, 22)
	end

	local description = Instance.new("TextLabel")
	description.BackgroundTransparency = 1
	description.Position = UDim2.fromOffset(30, 40)
	description.Size = UDim2.new(1, -210, 0, 34)
	description.Font = Enum.Font.Gotham
	description.TextSize = 12
	description.TextColor3 = THEME.textSoft
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.Text = tostring(mission.Description or "")
	description.Parent = row

	local progressText = Instance.new("TextLabel")
	progressText.BackgroundTransparency = 1
	progressText.Position = UDim2.fromOffset(30, 82)
	progressText.Size = UDim2.new(1, -210, 0, 16)
	progressText.Font = Enum.Font.GothamBold
	progressText.TextSize = 11
	progressText.TextColor3 = THEME.textMuted
	progressText.TextXAlignment = Enum.TextXAlignment.Left
	progressText.Text = formatProgress(mission)
	progressText.Parent = row

	local progressTrack = Instance.new("Frame")
	progressTrack.Position = UDim2.fromOffset(30, 102)
	progressTrack.Size = UDim2.new(1, -210, 0, 10)
	progressTrack.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
	progressTrack.BorderSizePixel = 0
	progressTrack.Parent = row
	addCorner(progressTrack, 5)
	addStroke(progressTrack, THEME.cardBorder, 1, 0.5)

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(state.fraction, 0, 1, 0)
	progressFill.BackgroundColor3 = accent
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack
	addCorner(progressFill, 5)
	addGradient(progressFill, 0, {
		Color3.new(
			math.min(accent.R + 0.1, 1),
			math.min(accent.G + 0.1, 1),
			math.min(accent.B + 0.1, 1)
		),
		accent,
	})

	local claim = Instance.new("TextButton")
	claim.AnchorPoint = Vector2.new(1, 1)
	claim.Position = UDim2.new(1, -16, 1, -14)
	claim.Size = UDim2.fromOffset(116, 38)
	claim.BorderSizePixel = 0
	claim.Font = Enum.Font.GothamBold
	claim.TextSize = 13
	claim.TextColor3 = Color3.fromRGB(255, 255, 255)
	claim.Parent = row
	addCorner(claim, 14)

	local statusPill = Instance.new("Frame")
	statusPill.AnchorPoint = Vector2.new(1, 0)
	statusPill.Position = UDim2.new(1, -16, 0, 54)
	statusPill.Size = UDim2.fromOffset(116, 24)
	statusPill.BorderSizePixel = 0
	statusPill.Parent = row
	addCorner(statusPill, 12)

	local statusText = Instance.new("TextLabel")
	statusText.BackgroundTransparency = 1
	statusText.Size = UDim2.fromScale(1, 1)
	statusText.Font = Enum.Font.GothamBold
	statusText.TextSize = 10
	statusText.Parent = statusPill

	if state.completed then
		claim.BackgroundColor3 = THEME.completed
		claim.Text = "Claimed"
		setButtonInteractable(claim, false)
		statusPill.BackgroundColor3 = THEME.completedSoft
		statusText.Text = "DONE"
		statusText.TextColor3 = Color3.fromRGB(196, 255, 213)
	elseif state.claimable then
		claim.BackgroundColor3 = THEME.claim
		claim.Text = "Claim"
		setButtonInteractable(claim, true)
		statusPill.BackgroundColor3 = THEME.claimSoft
		statusText.Text = "READY"
		statusText.TextColor3 = Color3.fromRGB(199, 255, 213)
	else
		claim.BackgroundColor3 = THEME.buttonDark
		claim.Text = "In Progress"
		setButtonInteractable(claim, false)
		statusPill.BackgroundColor3 = Color3.fromRGB(25, 31, 43)
		statusText.Text = "ACTIVE"
		statusText.TextColor3 = THEME.textMuted
	end

	claim.MouseButton1Click:Connect(function()
		if state.claimable then
			onClaim(mission)
		end
	end)
end

local function updatePageSummary(pageRef, missions, resetAt, labelPrefix)
	local summary = summarizeMissions(missions)
	pageRef.missionCountChip.value.Text = tostring(summary.total)
	pageRef.claimableChip.value.Text = tostring(summary.claimable)
	pageRef.completedChip.value.Text = tostring(summary.completed)
	pageRef.resetText.Text = resetAt and (labelPrefix .. " " .. formatCountdown(resetAt - os.time())) or (labelPrefix .. " --:--:--")
	pageRef.emptyLabel.Visible = #missions == 0
end

local function getPayload()
	local ok, payload = pcall(function()
		return RF_GetMissions:InvokeServer()
	end)
	if not ok then
		warn("[MissionsUI] RF_GetMissions error:", payload)
		return nil
	end
	return payload
end

local function claimMission(id: string): boolean
	local ok, payload = pcall(function()
		return RF_ClaimMission:InvokeServer(id)
	end)
	if not ok then
		warn("[MissionsUI] RF_ClaimMission error:", payload)
		return false
	end
	return (typeof(payload) == "table" and payload.ok == true) or false
end

local function refreshUI()
	clearList(dailyPage.list)
	clearList(weeklyPage.list)

	local payload = getPayload()
	if typeof(payload) ~= "table" then
		return
	end

	if typeof(payload.resets) == "table" then
		dailyResetAt = tonumber(payload.resets.dailyAt)
		weeklyResetAt = tonumber(payload.resets.weeklyAt)
	end

	local missions = payload.missions
	if typeof(missions) ~= "table" then
		return
	end

	local daily, weekly = {}, {}
	for _, mission in ipairs(missions) do
		if typeof(mission) == "table" then
			if mission.Type == "Daily" then
				daily[#daily + 1] = mission
			elseif mission.Type == "Weekly" then
				weekly[#weekly + 1] = mission
			end
		end
	end

	while #daily > DAILY_MAX do
		table.remove(daily)
	end
	while #weekly > WEEKLY_MAX do
		table.remove(weekly)
	end

	local function onClaim(mission)
		local id = tostring(mission.Id or "")
		if id == "" then
			return
		end
		if claimMission(id) then
			refreshUI()
		end
	end

	for _, mission in ipairs(daily) do
		makeMissionRow(dailyPage.list, mission, onClaim)
	end
	for _, mission in ipairs(weekly) do
		makeMissionRow(weeklyPage.list, mission, onClaim)
	end

	updatePageSummary(dailyPage, daily, dailyResetAt, "Refresh in")
	updatePageSummary(weeklyPage, weekly, weeklyResetAt, "Refresh in")
end

local timerConn: RBXScriptConnection? = nil
local function updateResetLabels(now: number)
	dailyPage.resetText.Text = dailyResetAt and ("Refresh in " .. formatCountdown(dailyResetAt - now)) or "Refresh in --:--:--"
	weeklyPage.resetText.Text = weeklyResetAt and ("Refresh in " .. formatCountdown(weeklyResetAt - now)) or "Refresh in --:--:--"

	if dailyResetAt and weeklyResetAt then
		resetInfoText.Text = ("Daily %s   |   Weekly %s"):format(
			formatCountdown(dailyResetAt - now),
			formatCountdown(weeklyResetAt - now)
		)
	elseif dailyResetAt then
		resetInfoText.Text = "Daily " .. formatCountdown(dailyResetAt - now)
	elseif weeklyResetAt then
		resetInfoText.Text = "Weekly " .. formatCountdown(weeklyResetAt - now)
	else
		resetInfoText.Text = ""
	end
end

local function startTimer()
	if timerConn then
		timerConn:Disconnect()
	end
	local acc = 0
	timerConn = RunService.Heartbeat:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		updateResetLabels(os.time())
	end)
end

local function openUI()
	if not tutorialComplete() then
		return
	end
	gui.Enabled = true
	setTab("Daily")
	refreshUI()
	updateResetLabels(os.time())
	startTimer()
end

local function closeUI()
	gui.Enabled = false
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
		if gui.Enabled then
			closeUI()
		else
			openUI()
		end
	end
end

gui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(handleScreenButtonsRequest)
handleScreenButtonsRequest()

closeBtn.MouseButton1Click:Connect(closeUI)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then closeUI() end
end)

local function isPromptInsideKnight(prompt: ProximityPrompt): boolean
	local npcs = workspace:FindFirstChild("NPCs")
	local knight = npcs and npcs:FindFirstChild("Knight")
	if not knight then return false end
	local p = prompt and prompt.Parent
	while p do
		if p == knight then return true end
		p = p.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if isPromptInsideKnight(prompt) then
		openUI()
	end
end)

setTab("Daily")
