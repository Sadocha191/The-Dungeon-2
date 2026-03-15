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

local WeaponConfigs = require(moduleRoot:WaitForChild("WeaponConfigs"))
local BannerConfigs = require(moduleRoot:WaitForChild("BannerConfigs"))
local UiResponsive = require(moduleRoot:WaitForChild("UiResponsive"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")

local OpenBannerUI = remoteEvents:WaitForChild("OpenWeaponBannerUI")
local GetActiveBanners = remoteFunctions:WaitForChild("GetActiveBanners")
local GetGachaState = remoteFunctions:WaitForChild("GetGachaState")
local RollBanner = remoteFunctions:WaitForChild("RollBanner")
local ConvertWeaponPoints = remoteFunctions:WaitForChild("ConvertWeaponPoints")

local weaponIcons = ReplicatedStorage:FindFirstChild("WeaponIcons") or ReplicatedStorage:WaitForChild("WeaponIcons", 10)

local baseCardColor = Color3.fromRGB(24, 28, 38)
local panelColor = Color3.fromRGB(15, 18, 26)
local panelSoftColor = Color3.fromRGB(22, 26, 38)
local surfaceColor = Color3.fromRGB(19, 22, 31)

local banners = {}
local state = {}
local recentResults = {}
local selectedBannerId = nil
local isRolling = false
local skipRequested = false
local overlayWaitingForContinue = false
local overlayCards = {}

local rarityColorMap = WeaponConfigs.RarityColors or {}

local function hexToColor3(hex)
	hex = tostring(hex or ""):gsub("#", "")
	if #hex ~= 6 then
		return Color3.fromRGB(255, 255, 255)
	end
	return Color3.fromRGB(
		tonumber(hex:sub(1, 2), 16) or 255,
		tonumber(hex:sub(3, 4), 16) or 255,
		tonumber(hex:sub(5, 6), 16) or 255
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
	return Color3.fromRGB(176, 184, 198)
end

local function blendColor(fromColor, toColor, alpha)
	return Color3.new(
		fromColor.R + (toColor.R - fromColor.R) * alpha,
		fromColor.G + (toColor.G - fromColor.G) * alpha,
		fromColor.B + (toColor.B - fromColor.B) * alpha
	)
end

local function clampInt(value)
	value = math.floor(tonumber(value) or 0)
	if value < 0 then
		return 0
	end
	return value
end

local function weightedChoice(pool)
	local totalWeight = 0
	for _, entry in ipairs(pool or {}) do
		totalWeight += tonumber(entry.Weight) or 1
	end
	if totalWeight <= 0 then
		return nil
	end
	local pick = Random.new():NextNumber(0, totalWeight)
	local cursor = 0
	for _, entry in ipairs(pool or {}) do
		cursor += tonumber(entry.Weight) or 1
		if pick <= cursor then
			return entry
		end
	end
	return pool and pool[#pool] or nil
end

local function getClientBannerConfig(bannerId)
	local defs = BannerConfigs.Banners or {}
	return defs[bannerId]
end

local function pickDecoyResult(bannerId)
	local banner = getClientBannerConfig(bannerId)
	local pool = banner and banner.Pool or nil
	if typeof(pool) == "table" and #pool > 0 then
		local picked = weightedChoice(pool)
		if picked then
			return {
				WeaponId = picked.WeaponId,
				Rarity = picked.Rarity,
				Featured = false,
			}
		end
	end
	local allWeapons = WeaponConfigs.GetAll and WeaponConfigs.GetAll() or {}
	if #allWeapons > 0 then
		local def = allWeapons[Random.new():NextInteger(1, #allWeapons)]
		return {
			WeaponId = def.id,
			Rarity = def.rarity,
			Featured = false,
		}
	end
	return {
		WeaponId = "Unknown",
		Rarity = "Common",
		Featured = false,
	}
end

local function getWeaponDef(weaponId)
	if WeaponConfigs.Get then
		return WeaponConfigs.Get(weaponId)
	end
	return nil
end

local function clearContainer(container, preserve)
	for _, child in ipairs(container:GetChildren()) do
		if not preserve or not preserve[child] then
			child:Destroy()
		end
	end
end

local function tween(instance, info, props)
	local handle = TweenService:Create(instance, info, props)
	handle:Play()
	return handle
end

local function tweenAndWait(instance, info, props)
	local handle = tween(instance, info, props)
	handle.Completed:Wait()
	return handle
end

local gui = playerGui:WaitForChild("BannerUI")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
gui:SetAttribute("Modal", true)

local overlay = gui:WaitForChild("Overlay")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
overlay.BackgroundTransparency = 0.18
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = overlay:WaitForChild("Panel")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.9)
panel.BackgroundColor3 = panelColor
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 20)
local panelSizeConstraint = Instance.new("UISizeConstraint", panel)
panelSizeConstraint.MaxSize = Vector2.new(1120, 680)
local panelAspect = Instance.new("UIAspectRatioConstraint", panel)
panelAspect.AspectRatio = 1120 / 680
panelAspect.DominantAxis = Enum.DominantAxis.Height
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(48, 58, 78)
panelStroke.Thickness = 1
local panelGradient = Instance.new("UIGradient", panel)
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 24, 36)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 15, 24)),
})
panelGradient.Rotation = 90
UiResponsive.attachCenteredPanel(panel, Vector2.new(1120, 680))

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -20, 0, 18)
closeButton.Size = UDim2.fromOffset(36, 36)
closeButton.BackgroundColor3 = Color3.fromRGB(35, 39, 52)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.TextColor3 = Color3.fromRGB(236, 238, 244)
closeButton.Text = "X"
closeButton.Parent = panel
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 12)

local headerTitle = Instance.new("TextLabel")
headerTitle.BackgroundTransparency = 1
headerTitle.Position = UDim2.fromOffset(20, 18)
headerTitle.Size = UDim2.new(1, -92, 0, 28)
headerTitle.Font = Enum.Font.GothamBlack
headerTitle.TextSize = 24
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.TextColor3 = Color3.fromRGB(248, 247, 241)
headerTitle.Text = "Weapon Banner Hall"
headerTitle.Parent = panel

local headerSubtitle = Instance.new("TextLabel")
headerSubtitle.BackgroundTransparency = 1
headerSubtitle.Position = UDim2.fromOffset(20, 50)
headerSubtitle.Size = UDim2.new(1, -92, 0, 18)
headerSubtitle.Font = Enum.Font.Gotham
headerSubtitle.TextSize = 12
headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
headerSubtitle.TextColor3 = Color3.fromRGB(176, 182, 196)
headerSubtitle.Text = "Featured weapons, pity tracking and animated reveals for every pull."
headerSubtitle.Parent = panel

local walletFrame = Instance.new("Frame")
walletFrame.Position = UDim2.fromOffset(20, 82)
walletFrame.Size = UDim2.new(1, -40, 0, 72)
walletFrame.BackgroundColor3 = panelSoftColor
walletFrame.BorderSizePixel = 0
walletFrame.Parent = panel
Instance.new("UICorner", walletFrame).CornerRadius = UDim.new(0, 16)
local walletStroke = Instance.new("UIStroke", walletFrame)
walletStroke.Color = Color3.fromRGB(44, 56, 78)
walletStroke.Thickness = 1

local currencyText = Instance.new("TextLabel")
currencyText.BackgroundTransparency = 1
currencyText.Position = UDim2.fromOffset(16, 12)
currencyText.Size = UDim2.new(1, -220, 0, 20)
currencyText.Font = Enum.Font.GothamBold
currencyText.TextSize = 14
currencyText.TextXAlignment = Enum.TextXAlignment.Left
currencyText.TextColor3 = Color3.fromRGB(245, 245, 245)
currencyText.Text = "Tickets: 0 | WeaponPoints: 0"
currencyText.Parent = walletFrame

local statusText = Instance.new("TextLabel")
statusText.BackgroundTransparency = 1
statusText.Position = UDim2.fromOffset(16, 36)
statusText.Size = UDim2.new(1, -220, 0, 20)
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 12
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.TextColor3 = Color3.fromRGB(164, 201, 174)
statusText.Text = "Open a banner to start pulling."
statusText.Parent = walletFrame

local convertButton = Instance.new("TextButton")
convertButton.Name = "ConvertButton"
convertButton.AnchorPoint = Vector2.new(1, 0.5)
convertButton.Position = UDim2.new(1, -16, 0.5, 0)
convertButton.Size = UDim2.fromOffset(188, 38)
convertButton.BackgroundColor3 = Color3.fromRGB(72, 90, 136)
convertButton.BorderSizePixel = 0
convertButton.Font = Enum.Font.GothamBold
convertButton.TextSize = 13
convertButton.TextColor3 = Color3.fromRGB(245, 245, 245)
convertButton.Text = "Convert W.P to Tickets"
convertButton.Parent = walletFrame
Instance.new("UICorner", convertButton).CornerRadius = UDim.new(0, 12)

local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Position = UDim2.fromOffset(20, 174)
sidebar.Size = UDim2.fromOffset(270, 486)
sidebar.BackgroundColor3 = surfaceColor
sidebar.BorderSizePixel = 0
sidebar.Parent = panel
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 16)
local sidebarStroke = Instance.new("UIStroke", sidebar)
sidebarStroke.Color = Color3.fromRGB(42, 52, 72)
sidebarStroke.Thickness = 1

local sidebarTitle = Instance.new("TextLabel")
sidebarTitle.BackgroundTransparency = 1
sidebarTitle.Position = UDim2.fromOffset(14, 14)
sidebarTitle.Size = UDim2.new(1, -28, 0, 18)
sidebarTitle.Font = Enum.Font.GothamBold
sidebarTitle.TextSize = 14
sidebarTitle.TextXAlignment = Enum.TextXAlignment.Left
sidebarTitle.TextColor3 = Color3.fromRGB(235, 236, 241)
sidebarTitle.Text = "Active Banners"
sidebarTitle.Parent = sidebar

local sidebarHint = Instance.new("TextLabel")
sidebarHint.BackgroundTransparency = 1
sidebarHint.Position = UDim2.fromOffset(14, 34)
sidebarHint.Size = UDim2.new(1, -28, 0, 16)
sidebarHint.Font = Enum.Font.Gotham
sidebarHint.TextSize = 11
sidebarHint.TextXAlignment = Enum.TextXAlignment.Left
sidebarHint.TextColor3 = Color3.fromRGB(164, 170, 182)
sidebarHint.Text = "Pick a banner to inspect its pool and pity."
sidebarHint.Parent = sidebar

local bannerList = Instance.new("ScrollingFrame")
bannerList.Name = "BannerList"
bannerList.Position = UDim2.fromOffset(12, 60)
bannerList.Size = UDim2.new(1, -24, 1, -72)
bannerList.BackgroundTransparency = 1
bannerList.BorderSizePixel = 0
bannerList.ScrollBarThickness = 6
bannerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
bannerList.Parent = sidebar

local bannerListLayout = Instance.new("UIListLayout", bannerList)
bannerListLayout.Padding = UDim.new(0, 10)

local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromOffset(306, 174)
content.Size = UDim2.new(1, -326, 1, -194)
content.BackgroundTransparency = 1
content.Parent = panel

local heroFrame = Instance.new("Frame")
heroFrame.Name = "HeroFrame"
heroFrame.Size = UDim2.new(1, 0, 1, 0)
heroFrame.BackgroundColor3 = surfaceColor
heroFrame.BorderSizePixel = 0
heroFrame.Parent = content
Instance.new("UICorner", heroFrame).CornerRadius = UDim.new(0, 16)
local heroStroke = Instance.new("UIStroke", heroFrame)
heroStroke.Color = Color3.fromRGB(42, 52, 72)
heroStroke.Thickness = 1
local heroGradient = Instance.new("UIGradient", heroFrame)
heroGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 30, 44)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 20, 30)),
})
heroGradient.Rotation = 45

local bannerName = Instance.new("TextLabel")
bannerName.BackgroundTransparency = 1
bannerName.Position = UDim2.fromOffset(16, 16)
bannerName.Size = UDim2.new(1, -284, 0, 28)
bannerName.Font = Enum.Font.GothamBlack
bannerName.TextSize = 24
bannerName.TextXAlignment = Enum.TextXAlignment.Left
bannerName.TextColor3 = Color3.fromRGB(247, 245, 239)
bannerName.Text = "-"
bannerName.Parent = heroFrame

local costBadge = Instance.new("TextLabel")
costBadge.AnchorPoint = Vector2.new(1, 0)
costBadge.Position = UDim2.new(1, -16, 0, 16)
costBadge.Size = UDim2.fromOffset(240, 32)
costBadge.BackgroundColor3 = Color3.fromRGB(31, 38, 52)
costBadge.BorderSizePixel = 0
costBadge.Font = Enum.Font.GothamBold
costBadge.TextSize = 12
costBadge.TextColor3 = Color3.fromRGB(242, 238, 222)
costBadge.Text = "Cost: -"
costBadge.Parent = heroFrame
Instance.new("UICorner", costBadge).CornerRadius = UDim.new(0, 12)

local bannerDesc = Instance.new("TextLabel")
bannerDesc.BackgroundTransparency = 1
bannerDesc.Position = UDim2.fromOffset(16, 52)
bannerDesc.Size = UDim2.new(1, -284, 0, 42)
bannerDesc.Font = Enum.Font.Gotham
bannerDesc.TextSize = 13
bannerDesc.TextWrapped = true
bannerDesc.TextXAlignment = Enum.TextXAlignment.Left
bannerDesc.TextYAlignment = Enum.TextYAlignment.Top
bannerDesc.TextColor3 = Color3.fromRGB(196, 201, 213)
bannerDesc.Text = "-"
bannerDesc.Parent = heroFrame

local pityTitle = Instance.new("TextLabel")
pityTitle.BackgroundTransparency = 1
pityTitle.Position = UDim2.fromOffset(16, 110)
pityTitle.Size = UDim2.new(1, -284, 0, 18)
pityTitle.Font = Enum.Font.GothamBold
pityTitle.TextSize = 12
pityTitle.TextXAlignment = Enum.TextXAlignment.Left
pityTitle.TextColor3 = Color3.fromRGB(234, 234, 240)
pityTitle.Text = "Pity"
pityTitle.Parent = heroFrame

local pityText = Instance.new("TextLabel")
pityText.BackgroundTransparency = 1
pityText.Position = UDim2.fromOffset(16, 130)
pityText.Size = UDim2.new(1, -284, 0, 18)
pityText.Font = Enum.Font.Gotham
pityText.TextSize = 12
pityText.TextXAlignment = Enum.TextXAlignment.Left
pityText.TextColor3 = Color3.fromRGB(172, 179, 194)
pityText.Text = "-"
pityText.Parent = heroFrame

local pityBarBack = Instance.new("Frame")
pityBarBack.Position = UDim2.fromOffset(16, 156)
pityBarBack.Size = UDim2.new(1, -284, 0, 12)
pityBarBack.BackgroundColor3 = Color3.fromRGB(31, 36, 49)
pityBarBack.BorderSizePixel = 0
pityBarBack.Parent = heroFrame
Instance.new("UICorner", pityBarBack).CornerRadius = UDim.new(0, 999)

local pityBarFill = Instance.new("Frame")
pityBarFill.Size = UDim2.new(0, 0, 1, 0)
pityBarFill.BackgroundColor3 = Color3.fromRGB(130, 166, 255)
pityBarFill.BorderSizePixel = 0
pityBarFill.Parent = pityBarBack
Instance.new("UICorner", pityBarFill).CornerRadius = UDim.new(0, 999)

local ratesTitle = Instance.new("TextLabel")
ratesTitle.BackgroundTransparency = 1
ratesTitle.Position = UDim2.fromOffset(16, 184)
ratesTitle.Size = UDim2.new(1, -284, 0, 18)
ratesTitle.Font = Enum.Font.GothamBold
ratesTitle.TextSize = 12
ratesTitle.TextXAlignment = Enum.TextXAlignment.Left
ratesTitle.TextColor3 = Color3.fromRGB(234, 234, 240)
ratesTitle.Text = "Drop Rates"
ratesTitle.Parent = heroFrame

local ratesWrap = Instance.new("Frame")
ratesWrap.Position = UDim2.fromOffset(16, 208)
ratesWrap.Size = UDim2.new(1, -284, 0, 34)
ratesWrap.BackgroundTransparency = 1
ratesWrap.Parent = heroFrame

local ratesLayout = Instance.new("UIListLayout", ratesWrap)
ratesLayout.FillDirection = Enum.FillDirection.Horizontal
ratesLayout.Padding = UDim.new(0, 8)

local rollOne = Instance.new("TextButton")
rollOne.Name = "RollOneButton"
rollOne.Position = UDim2.fromOffset(16, 248)
rollOne.Size = UDim2.fromOffset(150, 44)
rollOne.BackgroundColor3 = Color3.fromRGB(58, 109, 190)
rollOne.BorderSizePixel = 0
rollOne.Font = Enum.Font.GothamBold
rollOne.TextSize = 13
rollOne.TextColor3 = Color3.fromRGB(245, 245, 245)
rollOne.Text = "Pull x1"
rollOne.Parent = heroFrame
Instance.new("UICorner", rollOne).CornerRadius = UDim.new(0, 14)

local rollTen = Instance.new("TextButton")
rollTen.Name = "RollTenButton"
rollTen.Position = UDim2.fromOffset(178, 248)
rollTen.Size = UDim2.fromOffset(150, 44)
rollTen.BackgroundColor3 = Color3.fromRGB(88, 80, 200)
rollTen.BorderSizePixel = 0
rollTen.Font = Enum.Font.GothamBold
rollTen.TextSize = 13
rollTen.TextColor3 = Color3.fromRGB(245, 245, 245)
rollTen.Text = "Pull x10"
rollTen.Parent = heroFrame
Instance.new("UICorner", rollTen).CornerRadius = UDim.new(0, 14)

local featuredFrame = Instance.new("Frame")
featuredFrame.Name = "FeaturedFrame"
featuredFrame.AnchorPoint = Vector2.new(1, 0)
featuredFrame.Position = UDim2.new(1, -16, 0, 16)
featuredFrame.Size = UDim2.fromOffset(244, 260)
featuredFrame.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
featuredFrame.BorderSizePixel = 0
featuredFrame.Parent = heroFrame
Instance.new("UICorner", featuredFrame).CornerRadius = UDim.new(0, 16)
local featuredStroke = Instance.new("UIStroke", featuredFrame)
featuredStroke.Color = Color3.fromRGB(52, 70, 98)
featuredStroke.Thickness = 1

local featuredTitle = Instance.new("TextLabel")
featuredTitle.BackgroundTransparency = 1
featuredTitle.Position = UDim2.fromOffset(12, 10)
featuredTitle.Size = UDim2.new(1, -24, 0, 18)
featuredTitle.Font = Enum.Font.GothamBold
featuredTitle.TextSize = 13
featuredTitle.TextXAlignment = Enum.TextXAlignment.Left
featuredTitle.TextColor3 = Color3.fromRGB(240, 240, 244)
featuredTitle.Text = "Featured Pulls"
featuredTitle.Parent = featuredFrame

local featuredHint = Instance.new("TextLabel")
featuredHint.BackgroundTransparency = 1
featuredHint.Position = UDim2.fromOffset(12, 30)
featuredHint.Size = UDim2.new(1, -24, 0, 16)
featuredHint.Font = Enum.Font.Gotham
featuredHint.TextSize = 11
featuredHint.TextXAlignment = Enum.TextXAlignment.Left
featuredHint.TextColor3 = Color3.fromRGB(165, 170, 182)
featuredHint.Text = "Preview of focus weapons on this banner."
featuredHint.Parent = featuredFrame

local featuredStrip = Instance.new("ScrollingFrame")
featuredStrip.Name = "FeaturedStrip"
featuredStrip.Position = UDim2.fromOffset(10, 56)
featuredStrip.Size = UDim2.new(1, -20, 1, -66)
featuredStrip.BackgroundTransparency = 1
featuredStrip.BorderSizePixel = 0
featuredStrip.ScrollBarThickness = 4
featuredStrip.AutomaticCanvasSize = Enum.AutomaticSize.X
featuredStrip.ScrollingDirection = Enum.ScrollingDirection.X
featuredStrip.CanvasSize = UDim2.new(0, 0, 0, 0)
featuredStrip.Parent = featuredFrame

local featuredLayout = Instance.new("UIListLayout", featuredStrip)
featuredLayout.FillDirection = Enum.FillDirection.Horizontal
featuredLayout.Padding = UDim.new(0, 10)

local featuredEmpty = Instance.new("TextLabel")
featuredEmpty.BackgroundTransparency = 1
featuredEmpty.Size = UDim2.new(1, 0, 1, 0)
featuredEmpty.Font = Enum.Font.Gotham
featuredEmpty.TextSize = 12
featuredEmpty.TextWrapped = true
featuredEmpty.TextColor3 = Color3.fromRGB(150, 155, 170)
featuredEmpty.Text = "No featured weapons configured."
featuredEmpty.Parent = featuredStrip

local rollOverlay = gui:WaitForChild("RollOverlay")
rollOverlay.Name = "RollOverlay"
rollOverlay.Visible = false
rollOverlay.Size = UDim2.fromScale(1, 1)
rollOverlay.BackgroundColor3 = Color3.fromRGB(4, 6, 10)
rollOverlay.BackgroundTransparency = 0.15
rollOverlay.BorderSizePixel = 0
rollOverlay.Parent = gui

local rollPanel = rollOverlay:WaitForChild("RollPanel")
rollPanel.Name = "RollPanel"
rollPanel.AnchorPoint = Vector2.new(0.5, 0.5)
rollPanel.Position = UDim2.fromScale(0.5, 0.5)
rollPanel.Size = UDim2.fromScale(0.84, 0.84)
rollPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
rollPanel.BorderSizePixel = 0
rollPanel.Parent = rollOverlay
Instance.new("UICorner", rollPanel).CornerRadius = UDim.new(0, 22)
local rollPanelSizeConstraint = Instance.new("UISizeConstraint", rollPanel)
rollPanelSizeConstraint.MaxSize = Vector2.new(980, 560)
local rollPanelAspect = Instance.new("UIAspectRatioConstraint", rollPanel)
rollPanelAspect.AspectRatio = 980 / 560
rollPanelAspect.DominantAxis = Enum.DominantAxis.Height
local rollPanelStroke = Instance.new("UIStroke", rollPanel)
rollPanelStroke.Color = Color3.fromRGB(68, 86, 120)
rollPanelStroke.Thickness = 1
UiResponsive.attachCenteredPanel(rollPanel, Vector2.new(980, 560))

local rollTitle = Instance.new("TextLabel")
rollTitle.BackgroundTransparency = 1
rollTitle.Position = UDim2.fromOffset(24, 20)
rollTitle.Size = UDim2.new(1, -48, 0, 28)
rollTitle.Font = Enum.Font.GothamBlack
rollTitle.TextSize = 24
rollTitle.TextXAlignment = Enum.TextXAlignment.Left
rollTitle.TextColor3 = Color3.fromRGB(247, 245, 239)
rollTitle.Text = "Reveal"
rollTitle.Parent = rollPanel

local rollSubtitle = Instance.new("TextLabel")
rollSubtitle.BackgroundTransparency = 1
rollSubtitle.Position = UDim2.fromOffset(24, 52)
rollSubtitle.Size = UDim2.new(1, -48, 0, 18)
rollSubtitle.Font = Enum.Font.Gotham
rollSubtitle.TextSize = 12
rollSubtitle.TextXAlignment = Enum.TextXAlignment.Left
rollSubtitle.TextColor3 = Color3.fromRGB(170, 176, 190)
rollSubtitle.Text = "-"
rollSubtitle.Parent = rollPanel

local rollStage = Instance.new("TextLabel")
rollStage.BackgroundTransparency = 1
rollStage.Position = UDim2.fromOffset(24, 74)
rollStage.Size = UDim2.new(1, -180, 0, 18)
rollStage.Font = Enum.Font.GothamBold
rollStage.TextSize = 12
rollStage.TextXAlignment = Enum.TextXAlignment.Left
rollStage.TextColor3 = Color3.fromRGB(210, 214, 224)
rollStage.Text = "Preparing cards..."
rollStage.Parent = rollPanel

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.AnchorPoint = Vector2.new(1, 0)
skipButton.Position = UDim2.new(1, -24, 0, 24)
skipButton.Size = UDim2.fromOffset(112, 34)
skipButton.BackgroundColor3 = Color3.fromRGB(45, 52, 72)
skipButton.BorderSizePixel = 0
skipButton.Font = Enum.Font.GothamBold
skipButton.TextSize = 12
skipButton.TextColor3 = Color3.fromRGB(244, 244, 247)
skipButton.Text = "Skip Reveal"
skipButton.Parent = rollPanel
Instance.new("UICorner", skipButton).CornerRadius = UDim.new(0, 12)

local rollGrid = Instance.new("Frame")
rollGrid.Name = "RollGrid"
rollGrid.Position = UDim2.fromOffset(24, 110)
rollGrid.Size = UDim2.new(1, -48, 0, 360)
rollGrid.BackgroundTransparency = 1
rollGrid.Parent = rollPanel

local rollGridLayout = Instance.new("UIGridLayout", rollGrid)
rollGridLayout.CellPadding = UDim2.fromOffset(14, 14)
rollGridLayout.CellSize = UDim2.fromOffset(156, 216)
rollGridLayout.FillDirectionMaxCells = 5
rollGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rollGridLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local rollSummary = Instance.new("TextLabel")
rollSummary.BackgroundTransparency = 1
rollSummary.Position = UDim2.fromOffset(24, 480)
rollSummary.Size = UDim2.new(1, -48, 0, 20)
rollSummary.Font = Enum.Font.Gotham
rollSummary.TextSize = 12
rollSummary.TextXAlignment = Enum.TextXAlignment.Left
rollSummary.TextColor3 = Color3.fromRGB(188, 193, 206)
rollSummary.Text = ""
rollSummary.Parent = rollPanel

local continueButton = Instance.new("TextButton")
continueButton.Name = "ContinueButton"
continueButton.Visible = false
continueButton.AnchorPoint = Vector2.new(1, 1)
continueButton.Position = UDim2.new(1, -24, 1, -24)
continueButton.Size = UDim2.fromOffset(156, 42)
continueButton.BackgroundColor3 = Color3.fromRGB(76, 126, 218)
continueButton.BorderSizePixel = 0
continueButton.Font = Enum.Font.GothamBold
continueButton.TextSize = 14
continueButton.TextColor3 = Color3.fromRGB(245, 245, 245)
continueButton.Text = "Continue"
continueButton.Parent = rollPanel
Instance.new("UICorner", continueButton).CornerRadius = UDim.new(0, 14)

local function setStatus(text, isGood)
	statusText.Text = tostring(text or "")
	statusText.TextColor3 = isGood == false and Color3.fromRGB(255, 140, 140) or Color3.fromRGB(164, 201, 174)
end

local function setButtonEnabled(button, enabled, activeColor)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.Selectable = enabled
	button.BackgroundColor3 = enabled and activeColor or Color3.fromRGB(58, 62, 72)
end

local function renderViewport(viewport, fallback, weaponId)
	clearContainer(viewport)
	local weaponIdString = tostring(weaponId or "")
	if weaponIdString == "" then
		fallback.Visible = true
		fallback.Text = "?"
		return
	end
	local source = weaponIcons and weaponIcons:FindFirstChild(weaponIdString)
	if not source or not source:IsA("Model") then
		local def = getWeaponDef(weaponIdString)
		fallback.Visible = true
		fallback.Text = def and tostring(def.weaponType or "?"):sub(1, 1) or "?"
		return
	end
	fallback.Visible = false
	local clone = source:Clone()
	clone.Parent = viewport
	clone:PivotTo(CFrame.Angles(math.rad(-12), math.rad(32), 0))

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local _, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	local distance = math.max(4, maxDim * 2.5)
	camera.CFrame = CFrame.new(Vector3.new(distance, distance * 0.35, distance), Vector3.zero)
end

local function createWeaponCard(parent, width, height)
	local root = Instance.new("Frame")
	root.Size = UDim2.fromOffset(width, height)
	root.BackgroundColor3 = baseCardColor
	root.BorderSizePixel = 0
	root.Parent = parent
	Instance.new("UICorner", root).CornerRadius = UDim.new(0, 16)

	local stroke = Instance.new("UIStroke", root)
	stroke.Color = Color3.fromRGB(58, 68, 90)
	stroke.Thickness = 1

	local scale = Instance.new("UIScale", root)

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, 0, 0, 6)
	accent.BackgroundColor3 = Color3.fromRGB(130, 166, 255)
	accent.BorderSizePixel = 0
	accent.Parent = root
	Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 10)

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = root
	Instance.new("UICorner", flash).CornerRadius = UDim.new(0, 16)

	local iconWrap = Instance.new("Frame")
	iconWrap.Position = UDim2.fromOffset(12, 18)
	iconWrap.Size = UDim2.new(1, -24, 0, math.max(88, height - 88))
	iconWrap.BackgroundColor3 = Color3.fromRGB(16, 19, 28)
	iconWrap.BorderSizePixel = 0
	iconWrap.Parent = root
	Instance.new("UICorner", iconWrap).CornerRadius = UDim.new(0, 14)

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(220, 220, 235)
	viewport.LightColor = Color3.fromRGB(255, 245, 220)
	viewport.LightDirection = Vector3.new(-1, -1, -0.5)
	viewport.Parent = iconWrap

	local fallback = Instance.new("TextLabel")
	fallback.BackgroundTransparency = 1
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.Font = Enum.Font.GothamBlack
	fallback.TextSize = 42
	fallback.TextColor3 = Color3.fromRGB(238, 240, 246)
	fallback.Text = "?"
	fallback.Parent = iconWrap

	local featuredChip = Instance.new("TextLabel")
	featuredChip.Visible = false
	featuredChip.AnchorPoint = Vector2.new(1, 0)
	featuredChip.Position = UDim2.new(1, -8, 0, 8)
	featuredChip.Size = UDim2.fromOffset(78, 22)
	featuredChip.BackgroundColor3 = Color3.fromRGB(255, 205, 112)
	featuredChip.BorderSizePixel = 0
	featuredChip.Font = Enum.Font.GothamBold
	featuredChip.TextSize = 10
	featuredChip.TextColor3 = Color3.fromRGB(38, 30, 16)
	featuredChip.Text = "FEATURED"
	featuredChip.Parent = root
	Instance.new("UICorner", featuredChip).CornerRadius = UDim.new(0, 11)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(12, height - 58)
	nameLabel.Size = UDim2.new(1, -24, 0, 22)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextWrapped = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Top
	nameLabel.TextColor3 = Color3.fromRGB(240, 240, 243)
	nameLabel.Text = "Unknown"
	nameLabel.Parent = root

	local metaLabel = Instance.new("TextLabel")
	metaLabel.BackgroundTransparency = 1
	metaLabel.Position = UDim2.fromOffset(12, height - 34)
	metaLabel.Size = UDim2.new(1, -24, 0, 18)
	metaLabel.Font = Enum.Font.Gotham
	metaLabel.TextSize = 11
	metaLabel.TextXAlignment = Enum.TextXAlignment.Left
	metaLabel.TextColor3 = Color3.fromRGB(174, 180, 194)
	metaLabel.Text = "Weapon"
	metaLabel.Parent = root

	return {
		root = root,
		scale = scale,
		stroke = stroke,
		accent = accent,
		flash = flash,
		viewport = viewport,
		fallback = fallback,
		nameLabel = nameLabel,
		metaLabel = metaLabel,
		featuredChip = featuredChip,
	}
end

local function setCardBack(card, labelText)
	card.accent.BackgroundColor3 = Color3.fromRGB(110, 120, 145)
	card.root.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
	card.stroke.Color = Color3.fromRGB(64, 74, 96)
	card.featuredChip.Visible = false
	card.nameLabel.Text = labelText or "Unknown Pull"
	card.metaLabel.Text = "?"
	card.fallback.Visible = true
	card.fallback.Text = "?"
	clearContainer(card.viewport)
	card.flash.BackgroundTransparency = 1
	card.scale.Scale = 1
end

local function setCardResult(card, result)
	local weaponId = tostring(result.WeaponId or "Unknown")
	local rarity = tostring(result.Rarity or "Common")
	local color = getRarityColor(rarity)
	local def = getWeaponDef(weaponId)
	card.accent.BackgroundColor3 = color
	card.root.BackgroundColor3 = blendColor(baseCardColor, color, 0.18)
	card.stroke.Color = blendColor(color, Color3.fromRGB(255, 255, 255), 0.15)
	card.nameLabel.Text = weaponId
	card.metaLabel.Text = string.format("%s | %s", rarity, def and tostring(def.weaponType or "Weapon") or "Weapon")
	card.featuredChip.Visible = result.Featured == true
	renderViewport(card.viewport, card.fallback, weaponId)
	card.flash.BackgroundTransparency = 1
end

local function playCardReveal(card, bannerId, finalResult)
	local cycles = skipRequested and 1 or Random.new():NextInteger(6, 9)
	for index = 1, cycles do
		local decoy = pickDecoyResult(bannerId)
		setCardResult(card, decoy)
		card.scale.Scale = 0.96
		card.root.Rotation = Random.new():NextNumber(-2, 2)
		tween(card.scale, TweenInfo.new(skipRequested and 0.02 or 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.02,
		})
		task.wait(skipRequested and 0.01 or (0.04 + index * 0.01))
	end

	card.root.Rotation = 0
	setCardResult(card, finalResult)
	card.flash.BackgroundColor3 = getRarityColor(finalResult.Rarity)
	card.flash.BackgroundTransparency = 1
	card.scale.Scale = 0.92
	tween(card.flash, TweenInfo.new(skipRequested and 0.02 or 0.12), {
		BackgroundTransparency = 0.48,
	})
	tweenAndWait(card.scale, TweenInfo.new(skipRequested and 0.03 or 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.12,
	})
	tweenAndWait(card.scale, TweenInfo.new(skipRequested and 0.03 or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	tween(card.flash, TweenInfo.new(skipRequested and 0.03 or 0.18), {
		BackgroundTransparency = 1,
	})
end

local function buildRollSummary(results)
	local featuredCount = 0
	local rarityCounts = {}
	for _, result in ipairs(results or {}) do
		local rarity = tostring(result.Rarity or "Common")
		rarityCounts[rarity] = (rarityCounts[rarity] or 0) + 1
		if result.Featured then
			featuredCount += 1
		end
	end
	local parts = {}
	for rarity, amount in pairs(rarityCounts) do
		table.insert(parts, string.format("%d %s", amount, rarity))
	end
	table.sort(parts)
	if featuredCount > 0 then
		table.insert(parts, string.format("%d Featured", featuredCount))
	end
	return table.concat(parts, " | ")
end

local function createPill(parent, text, color)
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(96, 28)
	pill.BackgroundColor3 = blendColor(Color3.fromRGB(30, 36, 50), color, 0.24)
	pill.BorderSizePixel = 0
	pill.Parent = parent
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 999)

	local stroke = Instance.new("UIStroke", pill)
	stroke.Color = blendColor(color, Color3.fromRGB(255, 255, 255), 0.1)
	stroke.Thickness = 1

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = Color3.fromRGB(244, 244, 246)
	label.Text = text
	label.Parent = pill
end

local refreshSelectedBanner

local function renderFeaturedCards(featuredWeaponIds)
	clearContainer(featuredStrip, {
		[featuredLayout] = true,
		[featuredEmpty] = true,
	})
	featuredEmpty.Visible = not featuredWeaponIds or #featuredWeaponIds == 0
	if featuredEmpty.Visible then
		return
	end
	for _, weaponId in ipairs(featuredWeaponIds or {}) do
		local card = createWeaponCard(featuredStrip, 150, 188)
		setCardResult(card, {
			WeaponId = weaponId,
			Rarity = (getWeaponDef(weaponId) and getWeaponDef(weaponId).rarity) or "Common",
			Featured = true,
		})
	end
end

local function renderRates(rates)
	clearContainer(ratesWrap, {
		[ratesLayout] = true,
	})
	local order = {}
	for rarity in pairs(rates or {}) do
		table.insert(order, rarity)
	end
	table.sort(order, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, rarity in ipairs(order) do
		local rate = tonumber(rates[rarity]) or 0
		createPill(ratesWrap, string.format("%s %.1f%%", rarity, rate * 100), getRarityColor(rarity))
	end
end

local function renderRecentResults()
end

local function updateWallet()
	local currencies = state.Currencies or {}
	currencyText.Text = string.format(
		"Tickets: %d | WeaponPoints: %d | 100 W.P = 1 Ticket",
		clampInt(currencies.Tickets),
		clampInt(currencies.WeaponPoints)
	)
end

local function updateActionButtons()
	local banner = banners[selectedBannerId]
	local tickets = clampInt((state.Currencies or {}).Tickets)
	local costAmount = clampInt(banner and banner.Cost and banner.Cost.Amount)
	local canRoll = banner and banner.Active ~= false and not isRolling
	setButtonEnabled(rollOne, canRoll and tickets >= costAmount and costAmount > 0, Color3.fromRGB(58, 109, 190))
	setButtonEnabled(rollTen, canRoll and tickets >= costAmount * 10 and costAmount > 0, Color3.fromRGB(88, 80, 200))
	setButtonEnabled(convertButton, not isRolling and clampInt((state.Currencies or {}).WeaponPoints) >= 100, Color3.fromRGB(72, 90, 136))
end

local function renderBannerList()
	clearContainer(bannerList, {
		[bannerListLayout] = true,
	})
	local order = {}
	for id in pairs(banners) do
		table.insert(order, id)
	end
	table.sort(order, function(a, b)
		local bannerA = banners[a]
		local bannerB = banners[b]
		local activeA = bannerA and bannerA.Active ~= false
		local activeB = bannerB and bannerB.Active ~= false
		if activeA ~= activeB then
			return activeA
		end
		return tostring((bannerA and bannerA.DisplayName) or a) < tostring((bannerB and bannerB.DisplayName) or b)
	end)

	for _, id in ipairs(order) do
		local banner = banners[id]
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 76)
		button.BackgroundColor3 = surfaceColor
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = bannerList
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 14)

		local stroke = Instance.new("UIStroke", button)
		stroke.Color = Color3.fromRGB(42, 52, 72)
		stroke.Thickness = 1

		local accent = Instance.new("Frame")
		accent.Size = UDim2.new(0, 4, 1, 0)
		accent.BackgroundColor3 = banner.Active and Color3.fromRGB(96, 158, 255) or Color3.fromRGB(139, 88, 88)
		accent.BorderSizePixel = 0
		accent.Parent = button
		Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 8)

		local titleLabel = Instance.new("TextLabel")
		titleLabel.BackgroundTransparency = 1
		titleLabel.Position = UDim2.fromOffset(16, 10)
		titleLabel.Size = UDim2.new(1, -28, 0, 20)
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 13
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextColor3 = Color3.fromRGB(239, 239, 242)
		titleLabel.Text = banner.DisplayName or id
		titleLabel.Parent = button

		local cost = banner.Cost or {}
		local detailLabel = Instance.new("TextLabel")
		detailLabel.BackgroundTransparency = 1
		detailLabel.Position = UDim2.fromOffset(16, 32)
		detailLabel.Size = UDim2.new(1, -28, 0, 32)
		detailLabel.Font = Enum.Font.Gotham
		detailLabel.TextSize = 11
		detailLabel.TextWrapped = true
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailLabel.TextYAlignment = Enum.TextYAlignment.Top
		detailLabel.TextColor3 = Color3.fromRGB(168, 174, 188)
		detailLabel.Text = string.format(
			"%s\nCost %d %s",
			banner.Active and "Active now" or "Unavailable",
			clampInt(cost.Amount),
			tostring(cost.Currency or "")
		)
		detailLabel.Parent = button

		if selectedBannerId == id then
			button.BackgroundColor3 = blendColor(surfaceColor, Color3.fromRGB(87, 118, 184), 0.22)
			stroke.Color = Color3.fromRGB(108, 144, 216)
		end

		button.MouseButton1Click:Connect(function()
			if isRolling then
				return
			end
			selectedBannerId = id
			renderBannerList()
			refreshSelectedBanner()
		end)
	end
end

function refreshSelectedBanner()
	local banner = banners[selectedBannerId]
	if not banner then
		bannerName.Text = "-"
		bannerDesc.Text = "No banner selected."
		costBadge.Text = "Cost: -"
		pityTitle.Text = "Pity"
		pityText.Text = "-"
		pityBarFill.Size = UDim2.new(0, 0, 1, 0)
		renderRates(nil)
		renderFeaturedCards(nil)
		updateActionButtons()
		return
	end

	bannerName.Text = banner.DisplayName or selectedBannerId
	bannerDesc.Text = banner.Description or "-"
	local cost = banner.Cost or {}
	costBadge.Text = string.format("Cost: %d %s", clampInt(cost.Amount), tostring(cost.Currency or ""))

	local pityConfig = banner.Pity or {}
	local pityState = (state.Pity or {})[selectedBannerId] or {}
	local hardPity = clampInt(pityConfig.HardPity)
	local pityCount = clampInt(pityState.Count)
	local progress = 0
	if hardPity > 0 then
		progress = math.clamp(pityCount / hardPity, 0, 1)
	end
	pityTitle.Text = string.format("Pity target: %s", tostring(pityConfig.TargetRarity or "-"))
	pityText.Text = string.format(
		"%d / %d pulls | Featured fail flag: %s",
		pityCount,
		hardPity,
		tostring(pityState.FeaturedFail == true)
	)
	pityBarFill.BackgroundColor3 = getRarityColor(pityConfig.TargetRarity)
	pityBarFill.Size = UDim2.new(progress, 0, 1, 0)

	renderRates(banner.RarityRates)
	renderFeaturedCards(banner.FeaturedWeaponIds)
	updateActionButtons()
end

local function fetchState()
	local ok, result = pcall(function()
		return GetGachaState:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		state = result
	else
		state = {}
	end
	updateWallet()
	refreshSelectedBanner()
end

local function fetchBanners()
	local ok, result = pcall(function()
		return GetActiveBanners:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		banners = result
	else
		banners = {}
	end
	if not selectedBannerId or not banners[selectedBannerId] then
		selectedBannerId = nil
		local order = {}
		for id in pairs(banners) do
			table.insert(order, id)
		end
		table.sort(order)
		selectedBannerId = order[1]
	end
	renderBannerList()
	refreshSelectedBanner()
end

local function openUI()
	gui.Enabled = true
	setStatus("Choose a banner and start pulling.", true)
	fetchBanners()
	fetchState()
	renderRecentResults()
end

local function closeUI()
	if isRolling or overlayWaitingForContinue then
		return
	end
	gui.Enabled = false
	rollOverlay.Visible = false
end

local function formatConvertError(code)
	if code == "Min100" then
		return "You need at least 100 Weapon Points to convert."
	end
	if code == "NotEnoughWP" then
		return "Not enough Weapon Points."
	end
	return "Conversion failed."
end

local function formatRollError(code)
	if code == "InvalidBanner" then
		return "That banner is no longer valid."
	end
	if code == "BannerInactive" then
		return "That banner is currently inactive."
	end
	if code == "NotEnoughTickets" then
		return "Not enough tickets for that pull."
	end
	return "Pull failed."
end

local function prepareRollOverlay(bannerId, results)
	rollOverlay.Visible = true
	continueButton.Visible = false
	skipButton.Visible = true
	skipButton.Text = "Skip Reveal"
	overlayWaitingForContinue = false
	clearContainer(rollGrid, {
		[rollGridLayout] = true,
	})
	overlayCards = {}

	local count = #results
	if count <= 1 then
		rollGridLayout.CellSize = UDim2.fromOffset(220, 288)
		rollGridLayout.FillDirectionMaxCells = 1
	elseif count <= 5 then
		rollGridLayout.CellSize = UDim2.fromOffset(156, 216)
		rollGridLayout.FillDirectionMaxCells = count
	else
		rollGridLayout.CellSize = UDim2.fromOffset(146, 204)
		rollGridLayout.FillDirectionMaxCells = 5
	end

	local banner = banners[bannerId]
	rollTitle.Text = count > 1 and string.format("Reveal x%d", count) or "Reveal x1"
	rollSubtitle.Text = banner and (banner.DisplayName or bannerId) or tostring(bannerId)
	rollStage.Text = "Preparing cards..."
	rollSummary.Text = ""

	for index = 1, count do
		local card = createWeaponCard(rollGrid, rollGridLayout.CellSize.X.Offset, rollGridLayout.CellSize.Y.Offset)
		setCardBack(card, string.format("Card %d", index))
		table.insert(overlayCards, card)
	end
end

local function playRollReveal(bannerId, results)
	prepareRollOverlay(bannerId, results)
	for index, result in ipairs(results) do
		rollStage.Text = string.format("Revealing %d / %d", index, #results)
		playCardReveal(overlayCards[index], bannerId, result)
		task.wait(skipRequested and 0.01 or 0.07)
	end

	rollStage.Text = "Reveal complete"
	rollSummary.Text = buildRollSummary(results)
	skipButton.Visible = false
	continueButton.Visible = true
	overlayWaitingForContinue = true
	while overlayWaitingForContinue do
		task.wait()
	end
	rollOverlay.Visible = false
end

closeButton.MouseButton1Click:Connect(closeUI)
continueButton.MouseButton1Click:Connect(function()
	if overlayWaitingForContinue then
		overlayWaitingForContinue = false
	end
end)
skipButton.MouseButton1Click:Connect(function()
	if isRolling then
		skipRequested = true
	end
end)

OpenBannerUI.OnClientEvent:Connect(openUI)

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
		setStatus("Conversion failed.", false)
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

local function doRoll(amount)
	if isRolling or not selectedBannerId then
		return
	end
	local banner = banners[selectedBannerId]
	if not banner then
		setStatus("No banner selected.", false)
		return
	end

	isRolling = true
	skipRequested = false
	updateActionButtons()
	setStatus(string.format("Rolling x%d...", amount), true)

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
	refreshSelectedBanner()

	playRollReveal(selectedBannerId, recentResults)

	isRolling = false
	updateActionButtons()
	renderRecentResults()
	setStatus("Pull complete.", true)
end

rollOne.MouseButton1Click:Connect(function()
	doRoll(1)
end)

rollTen.MouseButton1Click:Connect(function()
	doRoll(10)
end)

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

renderRecentResults()
updateWallet()
refreshSelectedBanner()
