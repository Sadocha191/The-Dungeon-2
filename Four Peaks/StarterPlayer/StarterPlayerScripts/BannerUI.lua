local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local moduleRoot = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

if not moduleRoot then
	warn("[BannerUI] ReplicatedStorage module folder is missing")
	return
end

local WeaponConfigs = require(moduleRoot:WaitForChild("WeaponConfigs"))
local UiResponsive = require(moduleRoot:WaitForChild("UiResponsive"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")

local OpenBannerUI = remoteEvents:WaitForChild("OpenWeaponBannerUI")
local GetActiveBanners = remoteFunctions:WaitForChild("GetActiveBanners")
local GetGachaState = remoteFunctions:WaitForChild("GetGachaState")
local RollBanner = remoteFunctions:WaitForChild("RollBanner")
local ConvertWeaponPoints = remoteFunctions:WaitForChild("ConvertWeaponPoints")

local weaponIcons = ReplicatedStorage:FindFirstChild("WeaponIcons")
	or ReplicatedStorage:WaitForChild("WeaponIcons", 10)

local COLORS = {
	Backdrop = Color3.fromRGB(4, 3, 8),
	Panel = Color3.fromRGB(12, 10, 18),
	PanelSoft = Color3.fromRGB(19, 15, 28),
	Surface = Color3.fromRGB(24, 18, 35),
	SurfaceBright = Color3.fromRGB(34, 24, 48),
	Border = Color3.fromRGB(91, 67, 113),
	BorderSoft = Color3.fromRGB(55, 43, 70),
	Purple = Color3.fromRGB(163, 78, 255),
	PurpleSoft = Color3.fromRGB(112, 57, 175),
	Gold = Color3.fromRGB(224, 171, 75),
	GoldSoft = Color3.fromRGB(151, 108, 48),
	Text = Color3.fromRGB(244, 239, 249),
	TextSoft = Color3.fromRGB(185, 174, 198),
	TextDim = Color3.fromRGB(132, 120, 145),
	Good = Color3.fromRGB(126, 214, 164),
	Bad = Color3.fromRGB(255, 126, 126),
}

local RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythical = 6,
}

local banners = {}
local state = {}
local recentResults = {}
local selectedBannerId = nil
local isRolling = false
local skipRequested = false
local overlayWaitingForContinue = false
local rotatingTweens = {}

local rarityColorMap = WeaponConfigs.RarityColors or {}

local function hexToColor3(hex)
	hex = tostring(hex or ""):gsub("#", "")
	if #hex ~= 6 then
		return Color3.fromRGB(176, 184, 198)
	end
	return Color3.fromRGB(
		tonumber(hex:sub(1, 2), 16) or 176,
		tonumber(hex:sub(3, 4), 16) or 184,
		tonumber(hex:sub(5, 6), 16) or 198
	)
end

local function getRarityColor(rarity)
	local value = rarityColorMap[tostring(rarity or "")]
	if typeof(value) == "Color3" then
		return value
	end
	if typeof(value) == "string" then
		return hexToColor3(value)
	end
	local fallback = {
		Common = Color3.fromRGB(178, 184, 196),
		Uncommon = Color3.fromRGB(119, 190, 108),
		Rare = Color3.fromRGB(75, 151, 255),
		Epic = Color3.fromRGB(178, 91, 255),
		Legendary = Color3.fromRGB(255, 185, 66),
		Mythical = Color3.fromRGB(255, 90, 145),
	}
	return fallback[tostring(rarity or "")] or Color3.fromRGB(176, 184, 198)
end

local function blendColor(fromColor, toColor, alpha)
	return Color3.new(
		fromColor.R + (toColor.R - fromColor.R) * alpha,
		fromColor.G + (toColor.G - fromColor.G) * alpha,
		fromColor.B + (toColor.B - fromColor.B) * alpha
	)
end

local function clampInt(value)
	local numberValue = math.floor(tonumber(value) or 0)
	return math.max(0, numberValue)
end

local function getWeaponDef(weaponId)
	if WeaponConfigs.Get then
		return WeaponConfigs.Get(weaponId)
	end
	return nil
end

local function clearChildren(parent, preserved)
	for _, child in ipairs(parent:GetChildren()) do
		if not preserved or not preserved[child] then
			child:Destroy()
		end
	end
end

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Parent = instance
	return stroke
end

local function addGradient(instance, firstColor, secondColor, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, firstColor),
		ColorSequenceKeypoint.new(1, secondColor),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

local function createFrame(parent, name, position, size, color, cornerRadius)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	if cornerRadius then
		addCorner(frame, cornerRadius)
	end
	return frame
end

local function createText(parent, name, text, position, size, textSize, font, color, xAlignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font or Enum.Font.Gotham
	label.TextSize = textSize or 14
	label.TextColor3 = color or COLORS.Text
	label.TextXAlignment = xAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = text or ""
	label.Parent = parent
	return label
end

local function createButton(parent, name, text, position, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = COLORS.Text
	button.Text = text
	button.Parent = parent
	addCorner(button, 12)
	addStroke(button, blendColor(color, Color3.new(1, 1, 1), 0.18), 1)
	return button
end

local function createDiamond(parent, position, size, color, transparency)
	local diamond = createFrame(parent, "Rune", position, UDim2.fromOffset(size, size), color, 3)
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Rotation = 45
	diamond.BackgroundTransparency = transparency or 0
	return diamond
end

local function tween(instance, info, properties)
	local handle = TweenService:Create(instance, info, properties)
	handle:Play()
	return handle
end

local function setButtonEnabled(button, enabled, enabledColor)
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = enabled and enabledColor or Color3.fromRGB(55, 50, 62)
	button.TextTransparency = enabled and 0 or 0.35
end

local function createCircularRune(parent, size, color, thickness, transparency)
	local circle = createFrame(parent, "RuneCircle", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(size, size), Color3.new(0, 0, 0), size)
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.BackgroundTransparency = 1
	addStroke(circle, color, thickness, transparency or 0)
	return circle
end

local function startRotating(instance, duration, direction)
	local rotation = (direction or 1) * 360
	local handle = tween(instance, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
		Rotation = rotation,
	})
	table.insert(rotatingTweens, handle)
end

local function stopRotatingTweens()
	for _, handle in ipairs(rotatingTweens) do
		pcall(function()
			handle:Cancel()
		end)
	end
	table.clear(rotatingTweens)
end

local function formatTimeRemaining(endTime)
	local timestamp = tonumber(endTime)
	if not timestamp then
		return "Permanent"
	end
	local remaining = math.max(0, timestamp - os.time())
	if remaining <= 0 then
		return "Ended"
	end
	local days = math.floor(remaining / 86400)
	local hours = math.floor((remaining % 86400) / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	if days > 0 then
		return string.format("%dd %dh remaining", days, hours)
	end
	if hours > 0 then
		return string.format("%dh %dm remaining", hours, minutes)
	end
	return string.format("%dm remaining", math.max(1, minutes))
end

local function resolveWeaponDisplayName(weaponId)
	local def = getWeaponDef(weaponId)
	if def then
		return tostring(def.displayName or def.name or def.id or weaponId)
	end
	return tostring(weaponId or "Unknown Weapon")
end

local function renderWeaponVisual(container, weaponId, accentColor)
	local generated = container:FindFirstChild("GeneratedWeaponContent")
	if not (generated and generated:IsA("Frame")) then
		generated = createFrame(
			container,
			"GeneratedWeaponContent",
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			Color3.new(0, 0, 0)
		)
		generated.BackgroundTransparency = 1
	end
	clearChildren(generated)
	container = generated
	local weaponIdString = tostring(weaponId or "")
	if weaponIdString == "" then
		local placeholder = createText(container, "Placeholder", "?", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 54, Enum.Font.GothamBlack, COLORS.TextDim, Enum.TextXAlignment.Center)
		placeholder.TextYAlignment = Enum.TextYAlignment.Center
		return
	end

	local source = weaponIcons and weaponIcons:FindFirstChild(weaponIdString)
	if source and source:IsA("StringValue") and source.Value ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "WeaponIcon"
		image.BackgroundTransparency = 1
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.86, 0.86)
		image.Image = source.Value
		image.ScaleType = Enum.ScaleType.Fit
		image.ImageColor3 = Color3.fromRGB(255, 255, 255)
		image.Parent = container
		return
	end

	if source and source:IsA("Model") then
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "WeaponViewport"
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Ambient = blendColor(accentColor or COLORS.Purple, Color3.new(1, 1, 1), 0.4)
		viewport.LightColor = Color3.fromRGB(255, 244, 225)
		viewport.LightDirection = Vector3.new(-1, -0.5, -1)
		viewport.Parent = container

		local clone = source:Clone()
		clone.Parent = viewport
		clone:PivotTo(CFrame.Angles(math.rad(-12), math.rad(32), math.rad(8)))

		local camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local _, size = clone:GetBoundingBox()
		local maxDimension = math.max(size.X, size.Y, size.Z)
		local distance = math.max(4, maxDimension * 2.5)
		camera.CFrame = CFrame.new(Vector3.new(distance, distance * 0.3, distance), Vector3.zero)
		return
	end

	local def = getWeaponDef(weaponIdString)
	local fallback = createText(container, "Fallback", tostring((def and def.weaponType) or "?"):sub(1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 54, Enum.Font.GothamBlack, accentColor or COLORS.Purple, Enum.TextXAlignment.Center)
	fallback.TextYAlignment = Enum.TextYAlignment.Center
end

local function getFeaturedWeaponIds(banner)
	local result = {}
	local seen = {}
	for _, weaponId in ipairs((banner and banner.FeaturedWeaponIds) or {}) do
		if typeof(weaponId) == "string" and weaponId ~= "" and not seen[weaponId] then
			seen[weaponId] = true
			table.insert(result, weaponId)
		end
	end
	return result
end

local function getFeaturedDisplayNames(featuredWeaponIds)
	local names = {}
	for _, weaponId in ipairs(featuredWeaponIds) do
		table.insert(names, resolveWeaponDisplayName(weaponId))
	end
	return names
end

local function renderFeaturedWeaponSet(container, featuredWeaponIds, showNames)
	local generated = container:FindFirstChild("GeneratedFeaturedSet")
	if not (generated and generated:IsA("Frame")) then
		generated = createFrame(
			container,
			"GeneratedFeaturedSet",
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			Color3.new(0, 0, 0)
		)
		generated.BackgroundTransparency = 1
	end
	clearChildren(generated)

	local count = #featuredWeaponIds
	if count == 0 then
		renderWeaponVisual(generated, nil, COLORS.Purple)
		return
	end

	local columns = math.ceil(math.sqrt(count))
	local rows = math.ceil(count / columns)
	for index, weaponId in ipairs(featuredWeaponIds) do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local cell = createFrame(
			generated,
			"Featured_" .. tostring(index),
			UDim2.new(column / columns, 2, row / rows, 2),
			UDim2.new(1 / columns, -4, 1 / rows, -4),
			Color3.fromRGB(13, 10, 19),
			8
		)
		local def = getWeaponDef(weaponId)
		local rarityColor = getRarityColor(def and def.rarity)
		addStroke(cell, rarityColor, 1, 0.15)

		local visualHeight = showNames and 0.72 or 1
		local visual = createFrame(
			cell,
			"Visual",
			UDim2.fromScale(0, 0),
			UDim2.new(1, 0, visualHeight, 0),
			Color3.new(0, 0, 0)
		)
		visual.BackgroundTransparency = 1
		renderWeaponVisual(visual, weaponId, rarityColor)

		if showNames then
			local name = createText(
				cell,
				"Name",
				resolveWeaponDisplayName(weaponId),
				UDim2.new(0, 3, visualHeight, 0),
				UDim2.new(1, -6, 1 - visualHeight, 0),
				8,
				Enum.Font.GothamBold,
				COLORS.Text,
				Enum.TextXAlignment.Center
			)
			name.TextScaled = true
			name.TextWrapped = true
		end
	end
end

local gui = playerGui:WaitForChild("BannerUI")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
gui:SetAttribute("Modal", true)
clearChildren(gui)

local overlay = createFrame(gui, "Overlay", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), COLORS.Backdrop)
overlay.BackgroundTransparency = 0.08

local vignette = createFrame(overlay, "Vignette", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(12, 6, 20))
vignette.BackgroundTransparency = 0.36
addGradient(vignette, Color3.fromRGB(31, 15, 48), Color3.fromRGB(4, 3, 8), 90)

local panel = createFrame(overlay, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.94, 0.92), COLORS.Panel, 20)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
local panelSizeConstraint = Instance.new("UISizeConstraint")
panelSizeConstraint.MaxSize = Vector2.new(1180, 720)
panelSizeConstraint.Parent = panel
local panelAspect = Instance.new("UIAspectRatioConstraint")
panelAspect.AspectRatio = 1180 / 720
panelAspect.DominantAxis = Enum.DominantAxis.Height
panelAspect.Parent = panel
addStroke(panel, COLORS.Border, 1.5)
addGradient(panel, Color3.fromRGB(23, 15, 32), Color3.fromRGB(8, 7, 13), 115)
UiResponsive.attachCenteredPanel(panel, Vector2.new(1180, 720))

local topBar = createFrame(panel, "TopBar", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 76), Color3.fromRGB(12, 9, 17))
topBar.BackgroundTransparency = 0.08
local topLine = createFrame(topBar, "TopLine", UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), COLORS.GoldSoft)
topLine.BackgroundTransparency = 0.35

createText(topBar, "HeaderTitle", "SUMMONING ALTAR", UDim2.fromOffset(24, 10), UDim2.fromOffset(420, 30), 25, Enum.Font.GothamBlack, COLORS.Text)
createText(topBar, "HeaderSubtitle", "Call weapons from beyond the veil.", UDim2.fromOffset(24, 40), UDim2.fromOffset(460, 20), 12, Enum.Font.Gotham, COLORS.TextSoft)

local ticketsBadge = createFrame(topBar, "TicketsBadge", UDim2.new(1, -462, 0, 17), UDim2.fromOffset(150, 42), COLORS.Surface, 12)
addStroke(ticketsBadge, COLORS.BorderSoft, 1)
createDiamond(ticketsBadge, UDim2.fromOffset(20, 21), 14, COLORS.Purple, 0)
local ticketsText = createText(ticketsBadge, "TicketsText", "0 Tickets", UDim2.fromOffset(38, 0), UDim2.new(1, -44, 1, 0), 13, Enum.Font.GothamBold, COLORS.Text)

local pointsBadge = createFrame(topBar, "PointsBadge", UDim2.new(1, -304, 0, 17), UDim2.fromOffset(164, 42), COLORS.Surface, 12)
addStroke(pointsBadge, COLORS.BorderSoft, 1)
createText(pointsBadge, "PointsIcon", "WP", UDim2.fromOffset(8, 0), UDim2.fromOffset(32, 42), 11, Enum.Font.GothamBlack, COLORS.Gold, Enum.TextXAlignment.Center)
local pointsText = createText(pointsBadge, "PointsText", "0", UDim2.fromOffset(42, 0), UDim2.new(1, -48, 1, 0), 13, Enum.Font.GothamBold, COLORS.Text)

local convertButton = createButton(topBar, "ConvertButton", "CONVERT", UDim2.new(1, -132, 0, 19), UDim2.fromOffset(62, 38), COLORS.PurpleSoft)
convertButton.TextSize = 10

local closeButton = createButton(topBar, "CloseButton", "X", UDim2.new(1, -20, 0, 19), UDim2.fromOffset(38, 38), Color3.fromRGB(61, 45, 68))
closeButton.AnchorPoint = Vector2.new(1, 0)

local sidebar = createFrame(panel, "Sidebar", UDim2.fromOffset(18, 92), UDim2.fromOffset(250, 610), COLORS.PanelSoft, 16)
addStroke(sidebar, COLORS.BorderSoft, 1)
createText(sidebar, "SidebarTitle", "SUMMONING BANNERS", UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 24), 14, Enum.Font.GothamBold, COLORS.Text)
createText(sidebar, "SidebarHint", "Choose which altar pact to invoke.", UDim2.fromOffset(16, 34), UDim2.new(1, -32, 0, 18), 10, Enum.Font.Gotham, COLORS.TextDim)

local bannerList = Instance.new("ScrollingFrame")
bannerList.Name = "BannerList"
bannerList.Position = UDim2.fromOffset(12, 62)
bannerList.Size = UDim2.new(1, -24, 1, -74)
bannerList.BackgroundTransparency = 1
bannerList.BorderSizePixel = 0
bannerList.ScrollBarThickness = 4
bannerList.ScrollBarImageColor3 = COLORS.PurpleSoft
bannerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
bannerList.CanvasSize = UDim2.new()
bannerList.Parent = sidebar
local bannerListLayout = Instance.new("UIListLayout")
bannerListLayout.Padding = UDim.new(0, 10)
bannerListLayout.Parent = bannerList

local centerColumn = createFrame(panel, "CenterColumn", UDim2.fromOffset(282, 92), UDim2.fromOffset(610, 610), Color3.new(0, 0, 0))
centerColumn.BackgroundTransparency = 1

local altarPanel = createFrame(centerColumn, "AltarPanel", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, -142), Color3.fromRGB(15, 10, 24), 18)
addStroke(altarPanel, COLORS.Border, 1.2)
addGradient(altarPanel, Color3.fromRGB(40, 20, 58), Color3.fromRGB(10, 8, 15), 90)
altarPanel.ClipsDescendants = true

local bannerName = createText(altarPanel, "BannerName", "-", UDim2.fromOffset(20, 12), UDim2.new(1, -40, 0, 30), 23, Enum.Font.GothamBlack, COLORS.Text, Enum.TextXAlignment.Center)
local bannerDescription = createText(altarPanel, "BannerDescription", "Select a banner.", UDim2.fromOffset(40, 43), UDim2.new(1, -80, 0, 38), 12, Enum.Font.Gotham, COLORS.TextSoft, Enum.TextXAlignment.Center)
bannerDescription.TextWrapped = true
bannerDescription.TextYAlignment = Enum.TextYAlignment.Top

local stage = createFrame(altarPanel, "Stage", UDim2.fromScale(0.5, 0.56), UDim2.fromOffset(420, 330), Color3.new(0, 0, 0), 180)
stage.AnchorPoint = Vector2.new(0.5, 0.5)
stage.BackgroundTransparency = 1

local auraBack = createCircularRune(stage, 306, Color3.fromRGB(93, 39, 132), 18, 0.8)
auraBack.BackgroundColor3 = COLORS.Purple
auraBack.BackgroundTransparency = 0.93
local outerRune = createCircularRune(stage, 282, COLORS.Purple, 2, 0.25)
local middleRune = createCircularRune(stage, 230, Color3.fromRGB(198, 119, 255), 1, 0.4)
local innerRune = createCircularRune(stage, 174, COLORS.Gold, 1, 0.45)
startRotating(outerRune, 24, 1)
startRotating(middleRune, 17, -1)
startRotating(innerRune, 12, 1)

for index = 1, 8 do
	local angle = math.rad((index - 1) * 45)
	local radius = 137
	local x = 210 + math.cos(angle) * radius
	local y = 165 + math.sin(angle) * radius
	local rune = createDiamond(stage, UDim2.fromOffset(x, y), index % 2 == 0 and 12 or 9, index % 2 == 0 and COLORS.Purple or COLORS.Gold, 0.12)
	addStroke(rune, Color3.fromRGB(255, 225, 255), 1, 0.4)
end

local featuredVisual = createFrame(stage, "FeaturedVisual", UDim2.fromScale(0.5, 0.46), UDim2.fromOffset(220, 220), Color3.new(0, 0, 0))
featuredVisual.AnchorPoint = Vector2.new(0.5, 0.5)
featuredVisual.BackgroundTransparency = 1

local altarGlow = createFrame(stage, "AltarGlow", UDim2.fromScale(0.5, 0.78), UDim2.fromOffset(260, 62), COLORS.Purple, 99)
altarGlow.AnchorPoint = Vector2.new(0.5, 0.5)
altarGlow.BackgroundTransparency = 0.72
addGradient(altarGlow, COLORS.Purple, Color3.fromRGB(55, 16, 91), 90)

local altarBaseTop = createFrame(stage, "AltarBaseTop", UDim2.fromScale(0.5, 0.82), UDim2.fromOffset(310, 40), Color3.fromRGB(49, 35, 59), 18)
altarBaseTop.AnchorPoint = Vector2.new(0.5, 0.5)
addStroke(altarBaseTop, COLORS.GoldSoft, 1.2)
addGradient(altarBaseTop, Color3.fromRGB(91, 61, 107), Color3.fromRGB(29, 22, 37), 90)
local altarBaseBottom = createFrame(stage, "AltarBaseBottom", UDim2.fromScale(0.5, 0.9), UDim2.fromOffset(246, 46), Color3.fromRGB(28, 22, 34), 12)
altarBaseBottom.AnchorPoint = Vector2.new(0.5, 0.5)
addStroke(altarBaseBottom, COLORS.BorderSoft, 1)
createDiamond(altarBaseBottom, UDim2.fromScale(0.5, 0.5), 24, COLORS.Purple, 0)

local featuredBadge = createFrame(altarPanel, "FeaturedBadge", UDim2.new(0.5, 0, 1, -50), UDim2.fromOffset(300, 34), Color3.fromRGB(35, 22, 49), 12)
featuredBadge.AnchorPoint = Vector2.new(0.5, 0)
addStroke(featuredBadge, COLORS.PurpleSoft, 1)
local featuredBadgeText = createText(featuredBadge, "FeaturedBadgeText", "Featured: -", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), 11, Enum.Font.GothamBold, COLORS.Text, Enum.TextXAlignment.Center)

local actionPanel = createFrame(centerColumn, "ActionPanel", UDim2.new(0, 0, 1, -128), UDim2.new(1, 0, 0, 128), COLORS.PanelSoft, 16)
addStroke(actionPanel, COLORS.BorderSoft, 1)

local summonOne = createButton(actionPanel, "SummonOne", "SUMMON x1", UDim2.fromOffset(18, 18), UDim2.new(0.5, -27, 0, 58), Color3.fromRGB(38, 93, 154))
summonOne.TextSize = 17
local summonTen = createButton(actionPanel, "SummonTen", "SUMMON x10", UDim2.new(0.5, 9, 0, 18), UDim2.new(0.5, -27, 0, 58), Color3.fromRGB(139, 87, 26))
summonTen.TextSize = 17

local summonOneCost = createText(summonOne, "Cost", "1 Ticket", UDim2.new(0, 0, 1, -22), UDim2.new(1, 0, 0, 18), 10, Enum.Font.Gotham, Color3.fromRGB(221, 231, 248), Enum.TextXAlignment.Center)
local summonTenCost = createText(summonTen, "Cost", "10 Tickets", UDim2.new(0, 0, 1, -22), UDim2.new(1, 0, 0, 18), 10, Enum.Font.Gotham, Color3.fromRGB(255, 229, 178), Enum.TextXAlignment.Center)

local pityLabel = createText(actionPanel, "PityLabel", "Legendary guarantee: -", UDim2.fromOffset(18, 82), UDim2.new(1, -36, 0, 18), 11, Enum.Font.GothamBold, COLORS.TextSoft, Enum.TextXAlignment.Center)
local pityBack = createFrame(actionPanel, "PityBack", UDim2.fromOffset(36, 106), UDim2.new(1, -72, 0, 8), Color3.fromRGB(42, 34, 49), 99)
local pityFill = createFrame(pityBack, "PityFill", UDim2.fromOffset(0, 0), UDim2.new(0, 0, 1, 0), COLORS.Gold, 99)

local rightPanel = createFrame(panel, "RightPanel", UDim2.fromOffset(906, 92), UDim2.fromOffset(256, 610), COLORS.PanelSoft, 16)
addStroke(rightPanel, COLORS.BorderSoft, 1)

local featuredInfo = createFrame(rightPanel, "FeaturedInfo", UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 286), COLORS.Surface, 14)
addStroke(featuredInfo, COLORS.Border, 1)
createText(featuredInfo, "Label", "FEATURED WEAPON", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 22), 12, Enum.Font.GothamBold, COLORS.TextSoft, Enum.TextXAlignment.Center)
local featuredInfoVisual = createFrame(featuredInfo, "WeaponVisual", UDim2.fromOffset(16, 38), UDim2.new(1, -32, 0, 142), Color3.fromRGB(15, 11, 23), 12)
addStroke(featuredInfoVisual, COLORS.BorderSoft, 1)
local featuredWeaponName = createText(featuredInfo, "WeaponName", "-", UDim2.fromOffset(14, 184), UDim2.new(1, -28, 0, 24), 15, Enum.Font.GothamBlack, COLORS.Text, Enum.TextXAlignment.Center)
featuredWeaponName.TextWrapped = true
local featuredWeaponRarity = createText(featuredInfo, "WeaponRarity", "-", UDim2.fromOffset(14, 210), UDim2.new(1, -28, 0, 18), 12, Enum.Font.GothamBold, COLORS.Purple, Enum.TextXAlignment.Center)
local featuredWeaponMeta = createText(featuredInfo, "WeaponMeta", "-", UDim2.fromOffset(14, 232), UDim2.new(1, -28, 0, 40), 10, Enum.Font.Gotham, COLORS.TextDim, Enum.TextXAlignment.Center)
featuredWeaponMeta.TextWrapped = true
featuredWeaponMeta.TextYAlignment = Enum.TextYAlignment.Top

local ratesPanel = createFrame(rightPanel, "RatesPanel", UDim2.fromOffset(12, 310), UDim2.new(1, -24, 0, 174), COLORS.Surface, 14)
addStroke(ratesPanel, COLORS.BorderSoft, 1)
createText(ratesPanel, "Title", "POSSIBLE RARITIES", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 22), 12, Enum.Font.GothamBold, COLORS.TextSoft, Enum.TextXAlignment.Center)
local ratesList = createFrame(ratesPanel, "RatesList", UDim2.fromOffset(12, 36), UDim2.new(1, -24, 1, -46), Color3.new(0, 0, 0))
ratesList.BackgroundTransparency = 1
local ratesLayout = Instance.new("UIListLayout")
ratesLayout.Padding = UDim.new(0, 2)
ratesLayout.Parent = ratesList

local guaranteePanel = createFrame(rightPanel, "GuaranteePanel", UDim2.fromOffset(12, 496), UDim2.new(1, -24, 0, 102), COLORS.Surface, 14)
addStroke(guaranteePanel, COLORS.BorderSoft, 1)
createText(guaranteePanel, "Title", "ALTAR GUARANTEE", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 20), 11, Enum.Font.GothamBold, COLORS.TextSoft, Enum.TextXAlignment.Center)
local guaranteeText = createText(guaranteePanel, "GuaranteeText", "-", UDim2.fromOffset(14, 30), UDim2.new(1, -28, 0, 58), 10, Enum.Font.Gotham, COLORS.TextSoft, Enum.TextXAlignment.Center)
guaranteeText.TextWrapped = true
guaranteeText.TextYAlignment = Enum.TextYAlignment.Top

local statusToast = createFrame(panel, "StatusToast", UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(520, 36), Color3.fromRGB(24, 19, 31), 12)
statusToast.AnchorPoint = Vector2.new(0.5, 1)
statusToast.BackgroundTransparency = 0.08
addStroke(statusToast, COLORS.BorderSoft, 1)
local statusText = createText(statusToast, "StatusText", "Choose a banner and summon.", UDim2.fromOffset(14, 0), UDim2.new(1, -28, 1, 0), 11, Enum.Font.Gotham, COLORS.Good, Enum.TextXAlignment.Center)

local rollOverlay = createFrame(gui, "RollOverlay", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(3, 2, 7))
rollOverlay.BackgroundTransparency = 0.05
rollOverlay.Visible = false

local revealPanel = createFrame(rollOverlay, "RevealPanel", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.88), Color3.fromRGB(10, 7, 16), 22)
revealPanel.AnchorPoint = Vector2.new(0.5, 0.5)
local revealConstraint = Instance.new("UISizeConstraint")
revealConstraint.MaxSize = Vector2.new(1020, 620)
revealConstraint.Parent = revealPanel
local revealAspect = Instance.new("UIAspectRatioConstraint")
revealAspect.AspectRatio = 1020 / 620
revealAspect.DominantAxis = Enum.DominantAxis.Height
revealAspect.Parent = revealPanel
addStroke(revealPanel, COLORS.Border, 1.5)
addGradient(revealPanel, Color3.fromRGB(37, 19, 54), Color3.fromRGB(7, 5, 12), 90)
UiResponsive.attachCenteredPanel(revealPanel, Vector2.new(1020, 620))

local revealTitle = createText(revealPanel, "RevealTitle", "THE ALTAR ANSWERS", UDim2.fromOffset(26, 16), UDim2.new(1, -52, 0, 30), 24, Enum.Font.GothamBlack, COLORS.Text, Enum.TextXAlignment.Center)
local revealSubtitle = createText(revealPanel, "RevealSubtitle", "Summoning...", UDim2.fromOffset(26, 48), UDim2.new(1, -52, 0, 20), 12, Enum.Font.Gotham, COLORS.TextSoft, Enum.TextXAlignment.Center)

local skipButton = createButton(revealPanel, "SkipButton", "SKIP", UDim2.new(1, -22, 0, 18), UDim2.fromOffset(82, 34), Color3.fromRGB(59, 45, 68))
skipButton.AnchorPoint = Vector2.new(1, 0)
skipButton.TextSize = 11

local singleRevealStage = createFrame(revealPanel, "SingleRevealStage", UDim2.fromScale(0.5, 0.51), UDim2.fromOffset(470, 420), Color3.new(0, 0, 0), 210)
singleRevealStage.AnchorPoint = Vector2.new(0.5, 0.5)
singleRevealStage.BackgroundTransparency = 1
local revealAura = createCircularRune(singleRevealStage, 326, COLORS.Purple, 22, 0.78)
revealAura.BackgroundColor3 = COLORS.Purple
revealAura.BackgroundTransparency = 0.92
local revealOuterRune = createCircularRune(singleRevealStage, 300, COLORS.Purple, 3, 0.2)
local revealMiddleRune = createCircularRune(singleRevealStage, 236, COLORS.Gold, 1.5, 0.35)
startRotating(revealOuterRune, 9, 1)
startRotating(revealMiddleRune, 6, -1)
local revealWeaponVisual = createFrame(singleRevealStage, "WeaponVisual", UDim2.fromScale(0.5, 0.43), UDim2.fromOffset(260, 260), Color3.new(0, 0, 0))
revealWeaponVisual.AnchorPoint = Vector2.new(0.5, 0.5)
revealWeaponVisual.BackgroundTransparency = 1
local revealWeaponName = createText(singleRevealStage, "WeaponName", "", UDim2.fromOffset(30, 324), UDim2.new(1, -60, 0, 32), 21, Enum.Font.GothamBlack, COLORS.Text, Enum.TextXAlignment.Center)
local revealRarity = createText(singleRevealStage, "Rarity", "", UDim2.fromOffset(30, 358), UDim2.new(1, -60, 0, 22), 14, Enum.Font.GothamBold, COLORS.Purple, Enum.TextXAlignment.Center)

local resultsGrid = createFrame(revealPanel, "ResultsGrid", UDim2.fromOffset(26, 88), UDim2.new(1, -52, 1, -160), Color3.new(0, 0, 0))
resultsGrid.BackgroundTransparency = 1
resultsGrid.Visible = false
local resultsGridLayout = Instance.new("UIGridLayout")
resultsGridLayout.CellPadding = UDim2.fromOffset(12, 12)
resultsGridLayout.CellSize = UDim2.fromOffset(176, 220)
resultsGridLayout.FillDirectionMaxCells = 5
resultsGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
resultsGridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
resultsGridLayout.Parent = resultsGrid

local revealSummary = createText(revealPanel, "RevealSummary", "", UDim2.new(0, 26, 1, -22), UDim2.new(1, -220, 0, 42), 11, Enum.Font.Gotham, COLORS.TextSoft)
revealSummary.AnchorPoint = Vector2.new(0, 1)

local continueButton = createButton(revealPanel, "ContinueButton", "CONTINUE", UDim2.new(1, -26, 1, -22), UDim2.fromOffset(154, 42), COLORS.PurpleSoft)
continueButton.AnchorPoint = Vector2.new(1, 1)
continueButton.Visible = false

local function setStatus(text, isGood)
	statusText.Text = tostring(text or "")
	statusText.TextColor3 = isGood == false and COLORS.Bad or COLORS.Good
	statusToast.Visible = true
	statusToast.BackgroundTransparency = 0.08
	tween(statusToast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -14),
	})
end

local function updateWallet()
	local currencies = state.Currencies or {}
	ticketsText.Text = string.format("%d Tickets", clampInt(currencies.Tickets))
	pointsText.Text = string.format("%d W.P", clampInt(currencies.WeaponPoints))
end

local function renderRates(rates)
	clearChildren(ratesList, { [ratesLayout] = true })
	local entries = {}
	for rarity, rate in pairs(rates or {}) do
		table.insert(entries, {
			Rarity = rarity,
			Rate = tonumber(rate) or 0,
		})
	end
	table.sort(entries, function(a, b)
		local orderA = RARITY_ORDER[tostring(a.Rarity)] or 999
		local orderB = RARITY_ORDER[tostring(b.Rarity)] or 999
		if orderA == orderB then
			return tostring(a.Rarity) < tostring(b.Rarity)
		end
		return orderA > orderB
	end)

	for _, entry in ipairs(entries) do
		if entry.Rate > 0 then
			local row = createFrame(ratesList, tostring(entry.Rarity), UDim2.new(), UDim2.new(1, 0, 0, 22), Color3.new(0, 0, 0))
			row.BackgroundTransparency = 1
			createDiamond(row, UDim2.fromOffset(9, 11), 8, getRarityColor(entry.Rarity), 0)
			createText(row, "Rarity", tostring(entry.Rarity), UDim2.fromOffset(22, 0), UDim2.new(0.62, -22, 1, 0), 10, Enum.Font.GothamBold, getRarityColor(entry.Rarity))
			createText(row, "Rate", string.format("%.2f%%", entry.Rate * 100), UDim2.new(0.62, 0, 0, 0), UDim2.new(0.38, 0, 1, 0), 10, Enum.Font.Gotham, COLORS.TextSoft, Enum.TextXAlignment.Right)
		end
	end
end

local function updateActionButtons()
	local banner = banners[selectedBannerId]
	local currencies = state.Currencies or {}
	local tickets = clampInt(currencies.Tickets)
	local weaponPoints = clampInt(currencies.WeaponPoints)
	local cost = clampInt(banner and banner.Cost and banner.Cost.Amount)
	local active = banner and banner.Active ~= false and not isRolling and cost > 0
	setButtonEnabled(summonOne, active and tickets >= cost, Color3.fromRGB(38, 93, 154))
	setButtonEnabled(summonTen, active and tickets >= cost * 10, Color3.fromRGB(139, 87, 26))
	setButtonEnabled(convertButton, not isRolling and weaponPoints >= 100, COLORS.PurpleSoft)
end

local function renderSelectedBanner()
	local banner = banners[selectedBannerId]
	if not banner then
		bannerName.Text = "NO ACTIVE ALTAR"
		bannerDescription.Text = "No summoning banner is currently available."
		featuredBadgeText.Text = "Featured: -"
		renderFeaturedWeaponSet(featuredVisual, {}, false)
		renderFeaturedWeaponSet(featuredInfoVisual, {}, true)
		featuredWeaponName.Text = "-"
		featuredWeaponRarity.Text = "-"
		featuredWeaponMeta.Text = "-"
		pityLabel.Text = "Legendary guarantee: -"
		pityFill.Size = UDim2.new(0, 0, 1, 0)
		guaranteeText.Text = "No active guarantee."
		renderRates(nil)
		updateActionButtons()
		return
	end

	bannerName.Text = string.upper(tostring(banner.DisplayName or selectedBannerId))
	bannerDescription.Text = tostring(banner.Description or "Call a weapon from beyond the veil.")
	local cost = clampInt(banner.Cost and banner.Cost.Amount)
	summonOneCost.Text = string.format("%d Ticket%s", cost, cost == 1 and "" or "s")
	summonTenCost.Text = string.format("%d Tickets", cost * 10)

	local featuredWeaponIds = getFeaturedWeaponIds(banner)
	local weaponId = featuredWeaponIds[1]
	local weaponDef = getWeaponDef(weaponId)
	local rarity = (weaponDef and weaponDef.rarity) or (banner.Pity and banner.Pity.TargetRarity) or "Legendary"
	local rarityColor = getRarityColor(rarity)
	local featuredNames = getFeaturedDisplayNames(featuredWeaponIds)
	local displayName = resolveWeaponDisplayName(weaponId)

	featuredBadgeText.Text = "Featured: " .. table.concat(featuredNames, "  •  ")
	featuredBadgeText.TextColor3 = rarityColor
	featuredBadgeText.TextScaled = #featuredWeaponIds > 1
	renderFeaturedWeaponSet(featuredVisual, featuredWeaponIds, false)
	renderFeaturedWeaponSet(featuredInfoVisual, featuredWeaponIds, true)
	featuredWeaponName.Text = #featuredWeaponIds == 1
		and displayName
		or string.format("%d FEATURED WEAPONS", #featuredWeaponIds)

	local rarityNames = {}
	local seenRarities = {}
	for _, featuredId in ipairs(featuredWeaponIds) do
		local featuredDef = getWeaponDef(featuredId)
		local featuredRarity = tostring((featuredDef and featuredDef.rarity) or rarity)
		if not seenRarities[featuredRarity] then
			seenRarities[featuredRarity] = true
			table.insert(rarityNames, featuredRarity)
		end
	end
	featuredWeaponRarity.Text = table.concat(rarityNames, " • ")
	featuredWeaponRarity.TextColor3 = rarityColor
	local weaponType = weaponDef and tostring(weaponDef.weaponType or "Weapon") or "Weapon"
	local element = weaponDef and tostring(weaponDef.element or weaponDef.Element or "") or ""
	if #featuredWeaponIds == 1 then
		featuredWeaponMeta.Text = element ~= ""
			and string.format("%s • %s\nIncreased featured rate", element, weaponType)
			or string.format("%s\nIncreased featured rate", weaponType)
	else
		featuredWeaponMeta.Text = table.concat(featuredNames, " • ") .. "\nAll listed weapons share the featured rate"
	end

	outerRune:FindFirstChildOfClass("UIStroke").Color = rarityColor
	middleRune:FindFirstChildOfClass("UIStroke").Color = blendColor(rarityColor, Color3.new(1, 1, 1), 0.24)
	altarGlow.BackgroundColor3 = rarityColor
	featuredInfo:FindFirstChildOfClass("UIStroke").Color = rarityColor

	local pityConfig = banner.Pity or {}
	local pityState = (state.Pity or {})[selectedBannerId] or {}
	local hardPity = clampInt(pityConfig.HardPity)
	local pityCount = clampInt(pityState.Count)
	local remaining = hardPity > 0 and math.max(0, hardPity - pityCount) or 0
	local progress = hardPity > 0 and math.clamp(pityCount / hardPity, 0, 1) or 0
	local targetRarity = tostring(pityConfig.TargetRarity or rarity)
	pityLabel.Text = hardPity > 0
		and string.format("Guaranteed %s in %d summon%s", targetRarity, remaining, remaining == 1 and "" or "s")
		or "No hard guarantee configured"
	pityFill.BackgroundColor3 = getRarityColor(targetRarity)
	tween(pityFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(progress, 0, 1, 0),
	})

	if pityState.FeaturedFail == true then
		guaranteeText.Text = string.format("Your next %s pull is guaranteed to be a featured weapon.", targetRarity)
		guaranteeText.TextColor3 = COLORS.Gold
	else
		local featuredRate = math.floor(((tonumber(banner.FeaturedRate) or 0) * 100) + 0.5)
		guaranteeText.Text = string.format("Featured chance on %s: %d%%\nHard pity: %d summons", targetRarity, featuredRate, hardPity)
		guaranteeText.TextColor3 = COLORS.TextSoft
	end

	renderRates(banner.RarityRates)
	updateActionButtons()
end

local function renderBannerList()
	clearChildren(bannerList, { [bannerListLayout] = true })
	local ordered = {}
	for id, banner in pairs(banners) do
		table.insert(ordered, { Id = id, Banner = banner })
	end
	table.sort(ordered, function(a, b)
		local activeA = a.Banner.Active ~= false
		local activeB = b.Banner.Active ~= false
		if activeA ~= activeB then
			return activeA
		end
		local startA = tonumber(a.Banner.StartTime) or 0
		local startB = tonumber(b.Banner.StartTime) or 0
		if startA ~= startB then
			return startA > startB
		end
		return tostring(a.Banner.DisplayName or a.Id) < tostring(b.Banner.DisplayName or b.Id)
	end)

	for _, item in ipairs(ordered) do
		local id = item.Id
		local banner = item.Banner
		local selected = id == selectedBannerId
		local featuredIds = getFeaturedWeaponIds(banner)
		local featuredId = featuredIds[1]
		local featuredDef = getWeaponDef(featuredId)
		local rarity = (featuredDef and featuredDef.rarity) or (banner.Pity and banner.Pity.TargetRarity) or "Legendary"
		local rarityColor = getRarityColor(rarity)

		local button = createButton(bannerList, id, "", UDim2.new(), UDim2.new(1, 0, 0, 92), selected and blendColor(COLORS.SurfaceBright, rarityColor, 0.16) or COLORS.Surface)
		button.Text = ""
		button.AutoButtonColor = false
		local buttonStroke = button:FindFirstChildOfClass("UIStroke")
		buttonStroke.Color = selected and rarityColor or COLORS.BorderSoft
		buttonStroke.Thickness = selected and 1.5 or 1

		createFrame(button, "Accent", UDim2.fromOffset(0, 0), UDim2.fromOffset(5, 92), rarityColor, 6)
		local miniVisual = createFrame(button, "MiniVisual", UDim2.fromOffset(12, 10), UDim2.fromOffset(64, 72), Color3.fromRGB(13, 10, 19), 10)
		addStroke(miniVisual, blendColor(rarityColor, COLORS.BorderSoft, 0.45), 1)
		renderFeaturedWeaponSet(miniVisual, featuredIds, false)

		local title = createText(button, "Title", tostring(banner.DisplayName or id), UDim2.fromOffset(86, 6), UDim2.new(1, -96, 0, 28), 11, Enum.Font.GothamBold, COLORS.Text)
		title.TextWrapped = true
		title.TextYAlignment = Enum.TextYAlignment.Top
		local featuredSummary = createText(
			button,
			"FeaturedSummary",
			"Featured: " .. table.concat(getFeaturedDisplayNames(featuredIds), ", "),
			UDim2.fromOffset(86, 34),
			UDim2.new(1, -96, 0, 16),
			8,
			Enum.Font.Gotham,
			COLORS.TextSoft
		)
		featuredSummary.TextTruncate = Enum.TextTruncate.AtEnd
		local timerText = banner.Active ~= false and formatTimeRemaining(banner.EndTime) or "Unavailable"
		createText(button, "Timer", timerText, UDim2.fromOffset(86, 50), UDim2.new(1, -96, 0, 16), 9, Enum.Font.Gotham, banner.Active ~= false and COLORS.Gold or COLORS.Bad)
		local cost = clampInt(banner.Cost and banner.Cost.Amount)
		createText(button, "Cost", string.format("%d ticket%s per summon", cost, cost == 1 and "" or "s"), UDim2.fromOffset(86, 68), UDim2.new(1, -96, 0, 14), 8, Enum.Font.Gotham, COLORS.TextDim)

		button.MouseButton1Click:Connect(function()
			if isRolling then
				return
			end
			selectedBannerId = id
			renderBannerList()
			renderSelectedBanner()
		end)
	end
end

local function fetchBanners()
	local ok, result = pcall(function()
		return GetActiveBanners:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		banners = result
	else
		banners = {}
		setStatus("Could not load summoning banners.", false)
	end

	if not selectedBannerId or not banners[selectedBannerId] then
		selectedBannerId = nil
		local ids = {}
		for id, banner in pairs(banners) do
			if banner.Active ~= false then
				table.insert(ids, id)
			end
		end
		if #ids == 0 then
			for id in pairs(banners) do
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		selectedBannerId = ids[1]
	end

	renderBannerList()
	renderSelectedBanner()
end

local function fetchState()
	local ok, result = pcall(function()
		return GetGachaState:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		state = result
	else
		state = {}
		setStatus("Could not load your summoning state.", false)
	end
	updateWallet()
	renderSelectedBanner()
end

local function formatRollError(code)
	local messages = {
		InvalidBanner = "That summoning banner no longer exists.",
		BannerInactive = "That summoning banner is currently inactive.",
		NotEnoughTickets = "You do not have enough tickets.",
		PersistenceUnavailable = "Your account data is unavailable. Rejoin before spending currency.",
		Busy = "Another account transaction is still processing.",
		RateLimited = "You are summoning too quickly. Try again.",
		ServerError = "The altar failed to respond. Your request was not completed.",
	}
	return messages[tostring(code)] or "Summoning failed."
end

local function formatConvertError(code)
	local messages = {
		Min100 = "You need at least 100 Weapon Points to convert.",
		NotEnoughWP = "You do not have enough Weapon Points.",
		PersistenceUnavailable = "Your account data is unavailable. Rejoin before converting currency.",
		Busy = "Another account transaction is still processing.",
		RateLimited = "You are converting too quickly. Try again.",
		ServerError = "Currency conversion failed on the server.",
	}
	return messages[tostring(code)] or "Currency conversion failed."
end

local function getHighestResult(results)
	local best = results and results[1]
	local bestRank = best and (RARITY_ORDER[tostring(best.Rarity)] or 0) or 0
	for _, result in ipairs(results or {}) do
		local rank = RARITY_ORDER[tostring(result.Rarity)] or 0
		if rank > bestRank or (rank == bestRank and result.Featured == true and best and best.Featured ~= true) then
			best = result
			bestRank = rank
		end
	end
	return best
end

local function createResultCard(parent, result)
	local rarity = tostring(result.Rarity or "Common")
	local rarityColor = getRarityColor(rarity)
	local card = createFrame(parent, "ResultCard", UDim2.new(), UDim2.fromOffset(176, 220), COLORS.Surface, 14)
	addStroke(card, rarityColor, result.Featured and 2 or 1)
	addGradient(card, blendColor(COLORS.Surface, rarityColor, 0.18), Color3.fromRGB(12, 10, 18), 90)
	createFrame(card, "Accent", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 5), rarityColor, 6)
	local visual = createFrame(card, "Visual", UDim2.fromOffset(12, 16), UDim2.new(1, -24, 0, 126), Color3.fromRGB(13, 10, 19), 10)
	addStroke(visual, blendColor(rarityColor, COLORS.BorderSoft, 0.35), 1)
	renderWeaponVisual(visual, result.WeaponId, rarityColor)
	local name = createText(card, "Name", resolveWeaponDisplayName(result.WeaponId), UDim2.fromOffset(10, 148), UDim2.new(1, -20, 0, 36), 10, Enum.Font.GothamBold, COLORS.Text, Enum.TextXAlignment.Center)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	createText(card, "Rarity", rarity, UDim2.fromOffset(10, 184), UDim2.new(1, -20, 0, 18), 10, Enum.Font.GothamBold, rarityColor, Enum.TextXAlignment.Center)
	if result.Featured == true then
		local featured = createFrame(card, "Featured", UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(92, 20), Color3.fromRGB(71, 45, 21), 99)
		featured.AnchorPoint = Vector2.new(0.5, 1)
		addStroke(featured, COLORS.Gold, 1)
		createText(featured, "Text", "FEATURED", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 9, Enum.Font.GothamBlack, COLORS.Gold, Enum.TextXAlignment.Center)
	end
	return card
end

local function buildRollSummary(results)
	local rarityCounts = {}
	local featuredCount = 0
	for _, result in ipairs(results or {}) do
		local rarity = tostring(result.Rarity or "Common")
		rarityCounts[rarity] = (rarityCounts[rarity] or 0) + 1
		if result.Featured == true then
			featuredCount += 1
		end
	end
	local entries = {}
	for rarity, amount in pairs(rarityCounts) do
		table.insert(entries, { Rarity = rarity, Amount = amount })
	end
	table.sort(entries, function(a, b)
		return (RARITY_ORDER[a.Rarity] or 0) > (RARITY_ORDER[b.Rarity] or 0)
	end)
	local parts = {}
	for _, entry in ipairs(entries) do
		table.insert(parts, string.format("%d %s", entry.Amount, entry.Rarity))
	end
	if featuredCount > 0 then
		table.insert(parts, string.format("%d Featured", featuredCount))
	end
	return table.concat(parts, "  •  ")
end

local function showResultGrid(results)
	singleRevealStage.Visible = false
	resultsGrid.Visible = true
	clearChildren(resultsGrid, { [resultsGridLayout] = true })
	local count = #results
	if count == 1 then
		resultsGridLayout.CellSize = UDim2.fromOffset(250, 320)
		resultsGridLayout.FillDirectionMaxCells = 1
	else
		resultsGridLayout.CellSize = UDim2.fromOffset(176, 220)
		resultsGridLayout.FillDirectionMaxCells = 5
	end
	for _, result in ipairs(results) do
		createResultCard(resultsGrid, result)
	end
	revealSummary.Text = buildRollSummary(results)
	continueButton.Visible = true
	skipButton.Visible = false
	overlayWaitingForContinue = true
end

local function playSummonReveal(results)
	rollOverlay.Visible = true
	resultsGrid.Visible = false
	singleRevealStage.Visible = true
	continueButton.Visible = false
	skipButton.Visible = true
	revealSummary.Text = ""
	revealTitle.Text = "THE ALTAR ANSWERS"
	revealSubtitle.Text = string.format("Drawing %d weapon%s from beyond the veil...", #results, #results == 1 and "" or "s")

	local focusResult = getHighestResult(results)
	local rarity = focusResult and tostring(focusResult.Rarity or "Common") or "Common"
	local rarityColor = getRarityColor(rarity)
	revealAura.BackgroundColor3 = rarityColor
	revealOuterRune:FindFirstChildOfClass("UIStroke").Color = rarityColor
	revealMiddleRune:FindFirstChildOfClass("UIStroke").Color = blendColor(rarityColor, COLORS.Gold, 0.3)
	revealWeaponName.Text = ""
	revealRarity.Text = ""
	renderWeaponVisual(revealWeaponVisual, nil, rarityColor)

	revealWeaponVisual.Size = UDim2.fromOffset(110, 110)
	revealAura.Size = UDim2.fromOffset(326, 326)
	revealAura.BackgroundTransparency = 0.98
	tween(revealAura, TweenInfo.new(skipRequested and 0.03 or 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.82,
		Size = UDim2.fromOffset(360, 360),
	})
	tween(revealWeaponVisual, TweenInfo.new(skipRequested and 0.03 or 0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(260, 260),
	})

	if not skipRequested then
		task.wait(0.5)
	end
	if focusResult then
		renderWeaponVisual(revealWeaponVisual, focusResult.WeaponId, rarityColor)
		revealWeaponName.Text = resolveWeaponDisplayName(focusResult.WeaponId)
		revealRarity.Text = focusResult.Featured and (rarity .. " • FEATURED") or rarity
		revealRarity.TextColor3 = rarityColor
	end

	if not skipRequested then
		task.wait(#results == 1 and 1.05 or 0.65)
	end
	showResultGrid(results)

	while overlayWaitingForContinue do
		task.wait()
	end
	rollOverlay.Visible = false
end

local function openUI()
	gui.Enabled = true
	setStatus("Choose a banner and summon.", true)
	fetchBanners()
	fetchState()
end

local function closeUI()
	if isRolling or overlayWaitingForContinue then
		return
	end
	gui.Enabled = false
end

local function doRoll(amount)
	if isRolling or not selectedBannerId then
		return
	end
	local banner = banners[selectedBannerId]
	if not banner then
		setStatus("No summoning banner is selected.", false)
		return
	end

	isRolling = true
	skipRequested = false
	updateActionButtons()
	setStatus(string.format("The altar is processing summon x%d...", amount), true)

	local ok, success, payload = pcall(function()
		return RollBanner:InvokeServer(selectedBannerId, amount)
	end)
	if not ok or success ~= true or typeof(payload) ~= "table" then
		isRolling = false
		updateActionButtons()
		setStatus(formatRollError(payload), false)
		return
	end

	state.Pity = payload.Pity or state.Pity
	state.Currencies = payload.Currencies or state.Currencies
	recentResults = payload.Results or {}
	updateWallet()
	renderSelectedBanner()
	playSummonReveal(recentResults)

	isRolling = false
	updateActionButtons()
	setStatus("Summoning complete.", true)
end

closeButton.MouseButton1Click:Connect(closeUI)
convertButton.MouseButton1Click:Connect(function()
	if isRolling then
		return
	end
	local available = clampInt((state.Currencies or {}).WeaponPoints)
	local amount = math.floor(available / 100) * 100
	if amount <= 0 then
		setStatus("You need at least 100 Weapon Points to convert.", false)
		return
	end
	local ok, response = pcall(function()
		return ConvertWeaponPoints:InvokeServer(amount)
	end)
	if not ok or typeof(response) ~= "table" then
		setStatus("Currency conversion failed.", false)
		return
	end
	if response.ok == true then
		state.Currencies = response.balances or state.Currencies
		updateWallet()
		updateActionButtons()
		setStatus(string.format("Converted %d Weapon Points into %d ticket(s).", clampInt(response.spentWP), clampInt(response.converted)), true)
	else
		setStatus(formatConvertError(response.error), false)
	end
end)

summonOne.MouseButton1Click:Connect(function()
	doRoll(1)
end)

summonTen.MouseButton1Click:Connect(function()
	doRoll(10)
end)

skipButton.MouseButton1Click:Connect(function()
	if isRolling then
		skipRequested = true
	end
end)

continueButton.MouseButton1Click:Connect(function()
	if overlayWaitingForContinue then
		overlayWaitingForContinue = false
	end
end)

OpenBannerUI.OnClientEvent:Connect(openUI)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui.Enabled then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		if overlayWaitingForContinue then
			overlayWaitingForContinue = false
			return
		end
		closeUI()
	end
end)

updateWallet()
renderSelectedBanner()

script.Destroying:Connect(stopRotatingTweens)
