-- LOCALSCRIPT: BannerUI.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/BannerUI (LocalScript)
-- CO: UI bannerów + roll/convert

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")

local OpenBannerUI = remoteEvents:WaitForChild("OpenWeaponBannerUI")
local GetActiveBanners = remoteFunctions:WaitForChild("GetActiveBanners")
local GetGachaState = remoteFunctions:WaitForChild("GetGachaState")
local RollBanner = remoteFunctions:WaitForChild("RollBanner")
local ConvertWeaponPoints = remoteFunctions:WaitForChild("ConvertWeaponPoints")

local gui = Instance.new("ScreenGui")
gui.Name = "BannerUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
overlay.BackgroundTransparency = 0.25
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(820, 460)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.Position = UDim2.fromOffset(776, 12)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
closeButton.TextColor3 = Color3.fromRGB(230, 230, 230)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Parent = panel
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.fromOffset(360, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Bannery broni"
title.Parent = panel

local currencyText = Instance.new("TextLabel")
currencyText.BackgroundTransparency = 1
currencyText.Position = UDim2.fromOffset(18, 44)
currencyText.Size = UDim2.fromOffset(440, 20)
currencyText.Font = Enum.Font.Gotham
currencyText.TextSize = 14
currencyText.TextColor3 = Color3.fromRGB(210, 210, 210)
currencyText.TextXAlignment = Enum.TextXAlignment.Left
currencyText.Text = "Tickets: 0 | WeaponPoints: 0 (100 W.P = 1 Ticket)"
currencyText.Parent = panel

local convertButton = Instance.new("TextButton")
convertButton.Size = UDim2.fromOffset(160, 28)
convertButton.Position = UDim2.fromOffset(460, 40)
convertButton.BackgroundColor3 = Color3.fromRGB(58, 70, 100)
convertButton.TextColor3 = Color3.fromRGB(240, 240, 240)
convertButton.Text = "Konwertuj W.P"
convertButton.Font = Enum.Font.GothamBold
convertButton.TextSize = 12
convertButton.Parent = panel
Instance.new("UICorner", convertButton).CornerRadius = UDim.new(0, 8)

local listFrame = Instance.new("ScrollingFrame")
listFrame.Position = UDim2.fromOffset(18, 80)
listFrame.Size = UDim2.fromOffset(240, 350)
listFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
listFrame.BorderSizePixel = 0
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 6
listFrame.Parent = panel
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 10)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = listFrame

local detailsFrame = Instance.new("Frame")
detailsFrame.Position = UDim2.fromOffset(270, 80)
detailsFrame.Size = UDim2.fromOffset(532, 350)
detailsFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
detailsFrame.BorderSizePixel = 0
detailsFrame.Parent = panel
Instance.new("UICorner", detailsFrame).CornerRadius = UDim.new(0, 10)

local detailsPadding = Instance.new("UIPadding")
detailsPadding.PaddingTop = UDim.new(0, 12)
detailsPadding.PaddingLeft = UDim.new(0, 12)
detailsPadding.PaddingRight = UDim.new(0, 12)
detailsPadding.PaddingBottom = UDim.new(0, 12)
detailsPadding.Parent = detailsFrame

local bannerName = Instance.new("TextLabel")
bannerName.BackgroundTransparency = 1
bannerName.Size = UDim2.new(1, 0, 0, 24)
bannerName.Font = Enum.Font.GothamBold
bannerName.TextSize = 16
bannerName.TextColor3 = Color3.fromRGB(240, 240, 240)
bannerName.TextXAlignment = Enum.TextXAlignment.Left
bannerName.Text = "-"
bannerName.Parent = detailsFrame

local bannerDesc = Instance.new("TextLabel")
bannerDesc.BackgroundTransparency = 1
bannerDesc.Position = UDim2.fromOffset(0, 26)
bannerDesc.Size = UDim2.new(1, 0, 0, 40)
bannerDesc.Font = Enum.Font.Gotham
bannerDesc.TextSize = 13
bannerDesc.TextColor3 = Color3.fromRGB(210, 210, 210)
bannerDesc.TextXAlignment = Enum.TextXAlignment.Left
bannerDesc.TextYAlignment = Enum.TextYAlignment.Top
bannerDesc.TextWrapped = true
bannerDesc.Text = "-"
bannerDesc.Parent = detailsFrame

local featuredText = Instance.new("TextLabel")
featuredText.BackgroundTransparency = 1
featuredText.Position = UDim2.fromOffset(0, 70)
featuredText.Size = UDim2.new(1, 0, 0, 18)
featuredText.Font = Enum.Font.GothamSemibold
featuredText.TextSize = 12
featuredText.TextColor3 = Color3.fromRGB(200, 200, 220)
featuredText.TextXAlignment = Enum.TextXAlignment.Left
featuredText.RichText = true
featuredText.Text = "Featured: -"
featuredText.Parent = detailsFrame

local ratesText = Instance.new("TextLabel")
ratesText.BackgroundTransparency = 1
ratesText.Position = UDim2.fromOffset(0, 92)
ratesText.Size = UDim2.new(1, 0, 0, 60)
ratesText.Font = Enum.Font.Gotham
ratesText.TextSize = 12
ratesText.TextColor3 = Color3.fromRGB(200, 200, 200)
ratesText.TextXAlignment = Enum.TextXAlignment.Left
ratesText.TextYAlignment = Enum.TextYAlignment.Top
ratesText.TextWrapped = true
ratesText.Text = "Rates: -"
ratesText.Parent = detailsFrame

local pityText = Instance.new("TextLabel")
pityText.BackgroundTransparency = 1
pityText.Position = UDim2.fromOffset(0, 156)
pityText.Size = UDim2.new(1, 0, 0, 20)
pityText.Font = Enum.Font.GothamSemibold
pityText.TextSize = 12
pityText.TextColor3 = Color3.fromRGB(200, 200, 200)
pityText.TextXAlignment = Enum.TextXAlignment.Left
pityText.Text = "Pity: -"
pityText.Parent = detailsFrame

local costText = Instance.new("TextLabel")
costText.BackgroundTransparency = 1
costText.Position = UDim2.fromOffset(0, 178)
costText.Size = UDim2.new(1, 0, 0, 18)
costText.Font = Enum.Font.Gotham
costText.TextSize = 12
costText.TextColor3 = Color3.fromRGB(200, 200, 200)
costText.TextXAlignment = Enum.TextXAlignment.Left
costText.Text = "Koszt: -"
costText.Parent = detailsFrame

local rollOne = Instance.new("TextButton")
rollOne.Size = UDim2.fromOffset(120, 32)
rollOne.Position = UDim2.fromOffset(0, 210)
rollOne.BackgroundColor3 = Color3.fromRGB(62, 90, 120)
rollOne.TextColor3 = Color3.fromRGB(240, 240, 240)
rollOne.Text = "Roll x1"
rollOne.Font = Enum.Font.GothamBold
rollOne.TextSize = 12
rollOne.Parent = detailsFrame
Instance.new("UICorner", rollOne).CornerRadius = UDim.new(0, 8)

local rollTen = Instance.new("TextButton")
rollTen.Size = UDim2.fromOffset(120, 32)
rollTen.Position = UDim2.fromOffset(132, 210)
rollTen.BackgroundColor3 = Color3.fromRGB(62, 90, 120)
rollTen.TextColor3 = Color3.fromRGB(240, 240, 240)
rollTen.Text = "Roll x10"
rollTen.Font = Enum.Font.GothamBold
rollTen.TextSize = 12
rollTen.Parent = detailsFrame
Instance.new("UICorner", rollTen).CornerRadius = UDim.new(0, 8)

local resultsBox = Instance.new("TextLabel")
resultsBox.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
resultsBox.Position = UDim2.fromOffset(0, 252)
resultsBox.Size = UDim2.new(1, 0, 0, 86)
resultsBox.BorderSizePixel = 0
resultsBox.Font = Enum.Font.Gotham
resultsBox.TextSize = 12
resultsBox.TextColor3 = Color3.fromRGB(220, 220, 220)
resultsBox.TextXAlignment = Enum.TextXAlignment.Left
resultsBox.TextYAlignment = Enum.TextYAlignment.Top
resultsBox.TextWrapped = true
resultsBox.RichText = true
resultsBox.Text = "Wyniki: -"
resultsBox.Parent = detailsFrame
Instance.new("UICorner", resultsBox).CornerRadius = UDim.new(0, 8)
local resultsPadding = Instance.new("UIPadding")
resultsPadding.PaddingLeft = UDim.new(0, 8)
resultsPadding.PaddingTop = UDim.new(0, 6)
resultsPadding.Parent = resultsBox

local banners = {}
local state = {}
local selectedBannerId

local rarityColors = WeaponConfigs.RarityColors or {}

local function colorToHex(color: Color3): string
	return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
end

local function colorizeWeaponName(weaponId: string, rarity: string?): string
	local def = WeaponConfigs.Get and WeaponConfigs.Get(weaponId) or nil
	local finalRarity = (def and def.rarity) or rarity
	local color = finalRarity and rarityColors[finalRarity] or nil
	if color then
		return string.format("<font color=\"%s\">%s</font>", colorToHex(color), weaponId)
	end
	return tostring(weaponId)
end

local function formatRates(rates: any)
	if typeof(rates) ~= "table" then
		return "-"
	end
	local parts = {}
	for rarity, rate in pairs(rates) do
		table.insert(parts, string.format("%s: %.1f%%", tostring(rarity), (tonumber(rate) or 0) * 100))
	end
	table.sort(parts)
	return table.concat(parts, " | ")
end

local function refreshCurrency()
	local currencies = state.Currencies or {}
	currencyText.Text = ("Tickets: %d | WeaponPoints: %d (100 W.P = 1 Ticket)"):format(
		tonumber(currencies.Tickets) or 0,
		tonumber(currencies.WeaponPoints) or 0
	)
end

local function updateDetails()
	local banner = banners[selectedBannerId]
	if not banner then
		bannerName.Text = "-"
		bannerDesc.Text = "-"
		featuredText.Text = "Featured: -"
		ratesText.Text = "Rates: -"
		pityText.Text = "Pity: -"
		costText.Text = "Koszt: -"
		return
	end

	bannerName.Text = banner.DisplayName or selectedBannerId
	bannerDesc.Text = banner.Description or "-"
	local featuredNames = {}
	for _, weaponId in ipairs(banner.FeaturedWeaponIds or {}) do
		table.insert(featuredNames, colorizeWeaponName(weaponId))
	end
	featuredText.Text = "Featured: " .. table.concat(featuredNames, ", ")
	ratesText.Text = "Rates: " .. formatRates(banner.RarityRates)
	local pityConfig = banner.Pity or {}
	local pityState = (state.Pity or {})[selectedBannerId] or { Count = 0, FeaturedFail = false }
	local hard = tonumber(pityConfig.HardPity) or 0
	local target = pityConfig.TargetRarity or "-"
	local pityLine = string.format("Pity: %d/%d (Target: %s, 50/50 fail: %s)", pityState.Count or 0, hard, target, tostring(pityState.FeaturedFail == true))
	pityText.Text = pityLine
	local cost = banner.Cost or {}
	costText.Text = string.format("Koszt: %d %s", tonumber(cost.Amount) or 0, tostring(cost.Currency or ""))
end

local function clearList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function rebuildList()
	clearList()
	local order = {}
	for id in pairs(banners) do
		table.insert(order, id)
	end
	table.sort(order)
	for _, id in ipairs(order) do
		local banner = banners[id]
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(220, 36)
		button.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		button.TextColor3 = Color3.fromRGB(235, 235, 235)
		button.Font = Enum.Font.GothamSemibold
		button.TextSize = 12
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = "  " .. (banner.DisplayName or id)
		button.Parent = listFrame
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

		if not banner.Active then
			button.Text = "  " .. (banner.DisplayName or id) .. " (Niedostępny)"
			button.BackgroundColor3 = Color3.fromRGB(36, 26, 26)
		end

		button.MouseButton1Click:Connect(function()
			selectedBannerId = id
			updateDetails()
		end)
	end
	listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
end

local function refreshState()
	local ok, result = pcall(function()
		return GetGachaState:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		state = result
	else
		state = {}
	end
	refreshCurrency()
	updateDetails()
end

local function refreshBanners()
	local ok, result = pcall(function()
		return GetActiveBanners:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		banners = result
		if not selectedBannerId then
			for id in pairs(banners) do
				selectedBannerId = id
				break
			end
		end
	else
		banners = {}
	end
	rebuildList()
	updateDetails()
end

local function openUI()
	gui.Enabled = true
	refreshBanners()
	refreshState()
end

local function closeUI()
	gui.Enabled = false
end

closeButton.MouseButton1Click:Connect(closeUI)
OpenBannerUI.OnClientEvent:Connect(openUI)

convertButton.MouseButton1Click:Connect(function()
	local currencies = state.Currencies or {}
	local available = tonumber(currencies.WeaponPoints) or 0
	local amount = math.floor(available / 100) * 100
	if amount <= 0 then
		return
	end
	local ok, success, info, newBalances = pcall(function()
		return ConvertWeaponPoints:InvokeServer(amount)
	end)
	if ok and success then
		state.Currencies = newBalances or state.Currencies
		refreshCurrency()
	end
end)

local function doRoll(amount: number)
	if not selectedBannerId then return end
	local ok, success, payload = pcall(function()
		return RollBanner:InvokeServer(selectedBannerId, amount)
	end)
	if not ok or not success then
		resultsBox.Text = "Wyniki: Błąd rolla."
		return
	end
	state.Pity = payload.Pity or state.Pity
	state.Currencies = payload.Currencies or state.Currencies
	refreshCurrency()
	updateDetails()
	local lines = {}
	for _, result in ipairs(payload.Results or {}) do
		local featured = result.Featured and " [Featured]" or ""
		local weaponId = tostring(result.WeaponId or "-")
		local rarity = tostring(result.Rarity or "-")
		table.insert(lines, string.format("%s (%s)%s", colorizeWeaponName(weaponId, rarity), rarity, featured))
	end
	resultsBox.Text = "Wyniki: " .. table.concat(lines, ", ")
end

rollOne.MouseButton1Click:Connect(function()
	doRoll(1)
end)

rollTen.MouseButton1Click:Connect(function()
	doRoll(10)
end)
