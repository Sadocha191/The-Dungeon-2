-- BlacksmithUI.lua
-- UI kowala:
-- - rarity kolory jak w inventory
-- - ikony broni (ViewportFrame z ReplicatedStorage.WeaponIcons)
-- - Upgrade x1 i Upgrade +10
-- - selekcja instancji NIE znika po upgrade
-- - panel statystyk (wybrana instancja)
-- - Forge prawy panel: pełne info o wycraftowanej broni

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenBlacksmithUI = remoteEvents:WaitForChild("OpenBlacksmithUI")
local BlacksmithSync = remoteEvents:WaitForChild("BlacksmithSync")
local BlacksmithAction = remoteEvents:WaitForChild("BlacksmithAction")

local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))
local weaponIconsFolder = ReplicatedStorage:FindFirstChild("WeaponIcons")

local function hexToColor3(hex)
	hex = tostring(hex or ""):gsub("#", "")
	if #hex ~= 6 then return Color3.fromRGB(176, 176, 176) end
	local r = tonumber(hex:sub(1,2), 16) or 176
	local g = tonumber(hex:sub(3,4), 16) or 176
	local b = tonumber(hex:sub(5,6), 16) or 176
	return Color3.fromRGB(r,g,b)
end

local function rarityColor3(rarityOrHex)
	local hex = rarityOrHex
	if typeof(hex) ~= "string" or hex == "" then
		hex = (WeaponConfigs.RarityColors and WeaponConfigs.RarityColors[rarityOrHex or ""]) or "#B0B0B0"
	end
	if WeaponConfigs.RarityColors and WeaponConfigs.RarityColors[rarityOrHex or ""] then
		hex = WeaponConfigs.RarityColors[rarityOrHex]
	end
	return hexToColor3(hex)
end

local function addCorner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = inst
	return c
end

local function addStroke(inst, color)
	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Color = color or Color3.fromRGB(45, 45, 55)
	s.Parent = inst
	return s
end

local function tweenBg(obj, c)
	TweenService:Create(obj, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = c
	}):Play()
end

-- ===== Viewport icon helper =====
local function clearViewport(vp: ViewportFrame)
	for _, ch in ipairs(vp:GetChildren()) do
		ch:Destroy()
	end
end

local function setupViewport(vp: ViewportFrame, weaponId: string, stroke: UIStroke?)
	clearViewport(vp)

	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)

	local cam = Instance.new("Camera")
	cam.Parent = vp
	vp.CurrentCamera = cam

	local wm = Instance.new("WorldModel")
	wm.Parent = vp

	if not weaponIconsFolder then
		return
	end

	local iconModel = weaponIconsFolder:FindFirstChild(weaponId)
	if not (iconModel and iconModel:IsA("Model")) then
		return
	end

	local clone = iconModel:Clone()
	clone.Parent = wm

	-- bounding + camera
	local cf, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	maxDim = math.max(maxDim, 1)

	-- kamera trochę z góry/przodu
	local dist = maxDim * 2.2
	cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist, dist*0.6, dist), cf.Position)

	-- rysuj obramowanie według rarity (opcjonalnie)
	if stroke then
		-- zostawiamy to do zewnętrznego ustawienia
	end
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "BlacksmithGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = pg

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(980, 560)
panel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
panel.BorderSizePixel = 0
panel.Parent = overlay
addCorner(panel, 16)
addStroke(panel, Color3.fromRGB(40, 40, 48))

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 16)
title.Size = UDim2.new(1, -220, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Blacksmith"
title.Parent = panel

local coinsLabel = Instance.new("TextLabel")
coinsLabel.BackgroundTransparency = 1
coinsLabel.AnchorPoint = Vector2.new(1, 0)
coinsLabel.Position = UDim2.new(1, -60, 0, 16)
coinsLabel.Size = UDim2.fromOffset(200, 24)
coinsLabel.Font = Enum.Font.Gotham
coinsLabel.TextSize = 14
coinsLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
coinsLabel.Text = "Coins: 0"
coinsLabel.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -16, 0, 16)
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(210, 210, 210)
closeBtn.Text = "X"
closeBtn.Parent = panel
addCorner(closeBtn, 10)

local tabs = Instance.new("Frame")
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(24, 52)
tabs.Size = UDim2.new(1, -48, 0, 36)
tabs.Parent = panel

local function makeTab(text, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(140, 32)
	b.Position = UDim2.fromOffset(x, 2)
	b.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(230, 230, 230)
	b.Text = text
	b.Parent = tabs
	addCorner(b, 10)
	addStroke(b, Color3.fromRGB(45, 45, 55))
	return b
end

local tabForge = makeTab("Forge", 0)
local tabUpgrade = makeTab("Upgrade", 150)

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(24, 96)
body.Size = UDim2.new(1, -48, 1, -120)
body.Parent = panel

local forgePage = Instance.new("Frame")
forgePage.BackgroundTransparency = 1
forgePage.Size = UDim2.fromScale(1, 1)
forgePage.Parent = body

local upgradePage = Instance.new("Frame")
upgradePage.BackgroundTransparency = 1
upgradePage.Size = UDim2.fromScale(1, 1)
upgradePage.Visible = false
upgradePage.Parent = body

local function setTab(which)
	if which == "Forge" then
		forgePage.Visible = true
		upgradePage.Visible = false
		tabForge.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		tabUpgrade.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	else
		forgePage.Visible = false
		upgradePage.Visible = true
		tabForge.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
		tabUpgrade.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	end
end

tabForge.MouseButton1Click:Connect(function() setTab("Forge") end)
tabUpgrade.MouseButton1Click:Connect(function() setTab("Upgrade") end)

-- ===== Forge UI =====
local forgeLeft = Instance.new("Frame")
forgeLeft.Size = UDim2.new(0.46, -8, 1, 0)
forgeLeft.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
forgeLeft.BorderSizePixel = 0
forgeLeft.Parent = forgePage
addCorner(forgeLeft, 14)
addStroke(forgeLeft, Color3.fromRGB(40, 40, 48))

local forgeBtn = Instance.new("TextButton")
forgeBtn.Position = UDim2.fromOffset(16, 16)
forgeBtn.Size = UDim2.new(1, -32, 0, 44)
forgeBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
forgeBtn.BorderSizePixel = 0
forgeBtn.Font = Enum.Font.GothamBold
forgeBtn.TextSize = 14
forgeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
forgeBtn.Text = "Forge Random Weapon"
forgeBtn.Parent = forgeLeft
addCorner(forgeBtn, 12)

local forgeHint = Instance.new("TextLabel")
forgeHint.BackgroundTransparency = 1
forgeHint.Position = UDim2.fromOffset(16, 68)
forgeHint.Size = UDim2.new(1, -32, 1, -84)
forgeHint.Font = Enum.Font.Gotham
forgeHint.TextSize = 14
forgeHint.TextColor3 = Color3.fromRGB(200, 200, 200)
forgeHint.TextXAlignment = Enum.TextXAlignment.Left
forgeHint.TextYAlignment = Enum.TextYAlignment.Top
forgeHint.TextWrapped = true
forgeHint.Text = "Forge creates a random weapon (max Epic).\nEach weapon rolls a quality prefix that changes all stats.\nDuplicates are allowed."
forgeHint.Parent = forgeLeft

local forgeRight = Instance.new("Frame")
forgeRight.AnchorPoint = Vector2.new(1, 0)
forgeRight.Position = UDim2.new(1, 0, 0, 0)
forgeRight.Size = UDim2.new(0.54, -8, 1, 0)
forgeRight.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
forgeRight.BorderSizePixel = 0
forgeRight.Parent = forgePage
addCorner(forgeRight, 14)
addStroke(forgeRight, Color3.fromRGB(40, 40, 48))

local forgedTitle = Instance.new("TextLabel")
forgedTitle.BackgroundTransparency = 1
forgedTitle.Position = UDim2.fromOffset(16, 12)
forgedTitle.Size = UDim2.new(1, -32, 0, 20)
forgedTitle.Font = Enum.Font.GothamBold
forgedTitle.TextSize = 14
forgedTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
forgedTitle.TextXAlignment = Enum.TextXAlignment.Left
forgedTitle.Text = "Last forged"
forgedTitle.Parent = forgeRight

local forgedIconWrap = Instance.new("Frame")
forgedIconWrap.Position = UDim2.fromOffset(16, 40)
forgedIconWrap.Size = UDim2.fromOffset(64, 64)
forgedIconWrap.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
forgedIconWrap.BorderSizePixel = 0
forgedIconWrap.Parent = forgeRight
addCorner(forgedIconWrap, 14)
local forgedIconStroke = addStroke(forgedIconWrap, Color3.fromRGB(50, 50, 64))

local forgedViewport = Instance.new("ViewportFrame")
forgedViewport.Size = UDim2.fromScale(1, 1)
forgedViewport.Parent = forgedIconWrap

local forgedName = Instance.new("TextLabel")
forgedName.BackgroundTransparency = 1
forgedName.Position = UDim2.fromOffset(92, 44)
forgedName.Size = UDim2.new(1, -108, 0, 20)
forgedName.Font = Enum.Font.GothamBold
forgedName.TextSize = 16
forgedName.TextColor3 = Color3.fromRGB(245, 245, 245)
forgedName.TextXAlignment = Enum.TextXAlignment.Left
forgedName.Text = "-"
forgedName.Parent = forgeRight

local forgedMeta = Instance.new("TextLabel")
forgedMeta.BackgroundTransparency = 1
forgedMeta.Position = UDim2.fromOffset(92, 66)
forgedMeta.Size = UDim2.new(1, -108, 0, 18)
forgedMeta.Font = Enum.Font.Gotham
forgedMeta.TextSize = 12
forgedMeta.TextColor3 = Color3.fromRGB(200, 200, 200)
forgedMeta.TextXAlignment = Enum.TextXAlignment.Left
forgedMeta.Text = "-"
forgedMeta.Parent = forgeRight

local forgedStats = Instance.new("TextLabel")
forgedStats.BackgroundTransparency = 1
forgedStats.Position = UDim2.fromOffset(16, 116)
forgedStats.Size = UDim2.new(1, -32, 1, -132)
forgedStats.Font = Enum.Font.Gotham
forgedStats.TextSize = 14
forgedStats.TextColor3 = Color3.fromRGB(220, 220, 220)
forgedStats.TextXAlignment = Enum.TextXAlignment.Left
forgedStats.TextYAlignment = Enum.TextYAlignment.Top
forgedStats.TextWrapped = true
forgedStats.Text = "Forge a weapon to see details here."
forgedStats.Parent = forgeRight

-- ===== Upgrade UI =====
local left = Instance.new("Frame")
left.Size = UDim2.new(0.56, -8, 1, 0)
left.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
left.BorderSizePixel = 0
left.Parent = upgradePage
addCorner(left, 14)
addStroke(left, Color3.fromRGB(40, 40, 48))

local listTitle = Instance.new("TextLabel")
listTitle.BackgroundTransparency = 1
listTitle.Position = UDim2.fromOffset(16, 12)
listTitle.Size = UDim2.new(1, -32, 0, 20)
listTitle.Font = Enum.Font.GothamBold
listTitle.TextSize = 14
listTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
listTitle.TextXAlignment = Enum.TextXAlignment.Left
listTitle.Text = "Your Weapon Instances"
listTitle.Parent = left

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(16, 40)
list.Size = UDim2.new(1, -32, 1, -56)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = left

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = list

local right = Instance.new("Frame")
right.AnchorPoint = Vector2.new(1, 0)
right.Position = UDim2.new(1, 0, 0, 0)
right.Size = UDim2.new(0.44, -8, 1, 0)
right.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
right.BorderSizePixel = 0
right.Parent = upgradePage
addCorner(right, 14)
addStroke(right, Color3.fromRGB(40, 40, 48))

local selIconWrap = Instance.new("Frame")
selIconWrap.Position = UDim2.fromOffset(16, 16)
selIconWrap.Size = UDim2.fromOffset(72, 72)
selIconWrap.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
selIconWrap.BorderSizePixel = 0
selIconWrap.Parent = right
addCorner(selIconWrap, 14)
local selIconStroke = addStroke(selIconWrap, Color3.fromRGB(50, 50, 64))

local selViewport = Instance.new("ViewportFrame")
selViewport.Size = UDim2.fromScale(1, 1)
selViewport.Parent = selIconWrap

local details = Instance.new("TextLabel")
details.BackgroundTransparency = 1
details.Position = UDim2.fromOffset(100, 18)
details.Size = UDim2.new(1, -116, 0, 70)
details.Font = Enum.Font.Gotham
details.TextSize = 14
details.TextColor3 = Color3.fromRGB(220, 220, 220)
details.TextXAlignment = Enum.TextXAlignment.Left
details.TextYAlignment = Enum.TextYAlignment.Top
details.TextWrapped = true
details.Text = "Select a weapon instance."
details.Parent = right

local statsBox = Instance.new("TextLabel")
statsBox.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
statsBox.BackgroundTransparency = 0
statsBox.BorderSizePixel = 0
statsBox.Position = UDim2.fromOffset(16, 96)
statsBox.Size = UDim2.new(1, -32, 1, -208)
statsBox.Font = Enum.Font.Gotham
statsBox.TextSize = 14
statsBox.TextColor3 = Color3.fromRGB(220, 220, 220)
statsBox.TextXAlignment = Enum.TextXAlignment.Left
statsBox.TextYAlignment = Enum.TextYAlignment.Top
statsBox.TextWrapped = true
statsBox.Text = "-"
statsBox.Parent = right
addCorner(statsBox, 12)
addStroke(statsBox, Color3.fromRGB(40, 40, 48))

local equipBtn = Instance.new("TextButton")
equipBtn.Position = UDim2.new(0, 16, 1, -100)
equipBtn.Size = UDim2.new(1, -32, 0, 36)
equipBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 80)
equipBtn.BorderSizePixel = 0
equipBtn.Font = Enum.Font.GothamBold
equipBtn.TextSize = 13
equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
equipBtn.Text = "Equip"
equipBtn.Parent = right
addCorner(equipBtn, 12)

local upBtn = Instance.new("TextButton")
upBtn.Position = UDim2.new(0, 16, 1, -56)
upBtn.Size = UDim2.new(0.5, -20, 0, 36)
upBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
upBtn.BorderSizePixel = 0
upBtn.Font = Enum.Font.GothamBold
upBtn.TextSize = 13
upBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
upBtn.Text = "Upgrade"
upBtn.Parent = right
addCorner(upBtn, 12)

local up10Btn = Instance.new("TextButton")
up10Btn.AnchorPoint = Vector2.new(1, 0)
up10Btn.Position = UDim2.new(1, -16, 1, -56)
up10Btn.Size = UDim2.new(0.5, -20, 0, 36)
up10Btn.BackgroundColor3 = Color3.fromRGB(90, 120, 255)
up10Btn.BorderSizePixel = 0
up10Btn.Font = Enum.Font.GothamBold
up10Btn.TextSize = 13
up10Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
up10Btn.Text = "Upgrade +10"
up10Btn.Parent = right
addCorner(up10Btn, 12)

-- ===== State =====
local snapshot = nil
local selectedInstanceId: string? = nil
local selectedCacheRow = nil -- last selected row data from snapshot.instances

local function requestSnapshot()
	BlacksmithAction:FireServer({ type = "request" })
end

local function formatStats(stats)
	if typeof(stats) ~= "table" then return "-" end
	return table.concat({
		("ATK: %d"):format(tonumber(stats.ATK) or 0),
		("HP: %d"):format(tonumber(stats.HP) or 0),
		("DEF: %d"):format(tonumber(stats.DEF) or 0),
		("SPD: %d%%"):format(tonumber(stats.SPD) or 0),
		("Crit Rate: %d%%"):format(tonumber(stats.CRIT_RATE) or 0),
		("Crit DMG: %d%%"):format(tonumber(stats.CRIT_DMG) or 0),
		("Lifesteal: %d%%"):format(tonumber(stats.LIFESTEAL) or 0),
	}, "\n")
end

local function applyForgePanel(lastForged)
	if typeof(lastForged) ~= "table" then
		forgedName.Text = "-"
		forgedName.TextColor3 = Color3.fromRGB(245, 245, 245)
		forgedMeta.Text = "-"
		forgedStats.Text = "Forge a weapon to see details here."
		forgedIconStroke.Color = Color3.fromRGB(50, 50, 64)
		clearViewport(forgedViewport)
		return
	end

	local color = rarityColor3(lastForged.rarity)
	forgedIconStroke.Color = color
	forgedName.Text = ("%s %s"):format(tostring(lastForged.prefix or "Standard"), tostring(lastForged.weaponId or ""))
	forgedName.TextColor3 = color
	forgedMeta.Text = ("%s | Lv %d/%d"):format(
		tostring(lastForged.rarity or ""),
		tonumber(lastForged.level) or 1,
		tonumber(lastForged.maxLevel) or 1
	)
	forgedMeta.TextColor3 = Color3.fromRGB(200, 200, 200)

	setupViewport(forgedViewport, tostring(lastForged.weaponId), forgedIconStroke)

	local extra = ""
	if (lastForged.passiveName or "") ~= "" then
		extra = extra .. ("\n\nPassive: %s"):format(lastForged.passiveName)
	elseif (lastForged.abilityName or "") ~= "" then
		extra = extra .. ("\n\nAbility: %s"):format(lastForged.abilityName)
	end

	forgedStats.Text = formatStats(lastForged.stats) .. extra
end

local function setSelectedRow(row)
	selectedCacheRow = row
	if not row then
		selectedInstanceId = nil
		details.Text = "Select a weapon instance."
		statsBox.Text = "-"
		selIconStroke.Color = Color3.fromRGB(50, 50, 64)
		clearViewport(selViewport)
		upBtn.Text = "Upgrade"
		up10Btn.Text = "Upgrade +10"
		upBtn.AutoButtonColor = true
		up10Btn.AutoButtonColor = true
		upBtn.BackgroundTransparency = 0
		up10Btn.BackgroundTransparency = 0
		return
	end

	selectedInstanceId = row.instanceId

	local color = rarityColor3(row.rarity)
	selIconStroke.Color = color
	setupViewport(selViewport, tostring(row.weaponId), selIconStroke)

	local equippedTag = (snapshot and snapshot.equippedInstanceId == row.instanceId) and " | Equipped" or ""
	details.Text = ("%s %s\n%s | Lv %d/%d%s"):format(
		tostring(row.prefix or "Standard"),
		tostring(row.weaponId or ""),
		tostring(row.rarity or ""),
		tonumber(row.level) or 1,
		tonumber(row.maxLevel) or 1,
		equippedTag
	)
	details.TextColor3 = Color3.fromRGB(220, 220, 220)

	local extra = ""
	if (row.passiveName or "") ~= "" then
		extra = extra .. ("\n\nPassive: %s"):format(row.passiveName)
	elseif (row.abilityName or "") ~= "" then
		extra = extra .. ("\n\nAbility: %s"):format(row.abilityName)
	end

	statsBox.Text = formatStats(row.stats) .. extra

	if row.canUpgrade then
		upBtn.Text = ("Upgrade (Cost: %d)"):format(tonumber(row.upgradeCost) or 0)
		up10Btn.Text = "Upgrade +10"
		upBtn.AutoButtonColor = true
		up10Btn.AutoButtonColor = true
		upBtn.BackgroundTransparency = 0
		up10Btn.BackgroundTransparency = 0
	else
		upBtn.Text = "Max level"
		up10Btn.Text = "Max level"
		upBtn.AutoButtonColor = false
		up10Btn.AutoButtonColor = false
		upBtn.BackgroundTransparency = 0.5
		up10Btn.BackgroundTransparency = 0.5
	end
end

local function clearList()
	for _, ch in ipairs(list:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
end

local function refreshForge()
	if not snapshot then return end
	coinsLabel.Text = ("Coins: %d"):format(tonumber(snapshot.coins) or 0)
	forgeBtn.Text = ("Forge Random Weapon (Cost: %d)"):format(tonumber(snapshot.craftCost) or 500)

	applyForgePanel(snapshot.lastForged)
end

local function refreshUpgrade()
	if not snapshot then return end
	coinsLabel.Text = ("Coins: %d"):format(tonumber(snapshot.coins) or 0)

	-- zachowujemy selekcję
	local keepId = selectedInstanceId
	clearList()

	local equippedId = snapshot.equippedInstanceId
	local foundSelected = nil

	for _, row in ipairs(snapshot.instances or {}) do
		local rarityCol = rarityColor3(row.rarity)

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 62)
		frame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
		frame.BorderSizePixel = 0
		frame.Parent = list
		addCorner(frame, 12)
		local stroke = addStroke(frame, Color3.fromRGB(40, 40, 48))

		-- ICON
		local iconWrap = Instance.new("Frame")
		iconWrap.Position = UDim2.fromOffset(10, 9)
		iconWrap.Size = UDim2.fromOffset(44, 44)
		iconWrap.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
		iconWrap.BorderSizePixel = 0
		iconWrap.Parent = frame
		addCorner(iconWrap, 12)
		local iconStroke = addStroke(iconWrap, rarityCol)

		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.fromScale(1, 1)
		vp.Parent = iconWrap
		setupViewport(vp, tostring(row.weaponId), iconStroke)

		-- TEXT
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(64, 10)
		name.Size = UDim2.new(1, -160, 0, 18)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 13
		name.TextColor3 = rarityCol
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = ("%s %s"):format(tostring(row.prefix or "Standard"), tostring(row.weaponId or ""))
		name.Parent = frame

		local meta = Instance.new("TextLabel")
		meta.BackgroundTransparency = 1
		meta.Position = UDim2.fromOffset(64, 30)
		meta.Size = UDim2.new(1, -160, 0, 16)
		meta.Font = Enum.Font.Gotham
		meta.TextSize = 12
		meta.TextColor3 = Color3.fromRGB(200, 200, 200)
		meta.TextXAlignment = Enum.TextXAlignment.Left
		meta.Text = ("%s | Lv %d/%d"):format(
			tostring(row.rarity or ""),
			tonumber(row.level) or 1,
			tonumber(row.maxLevel) or 1
		) .. ((row.instanceId == equippedId) and " | Equipped" or "")
		meta.Parent = frame

		local mini = Instance.new("TextLabel")
		mini.BackgroundTransparency = 1
		mini.AnchorPoint = Vector2.new(1, 0.5)
		mini.Position = UDim2.new(1, -12, 0.5, 0)
		mini.Size = UDim2.fromOffset(120, 16)
		mini.Font = Enum.Font.Gotham
		mini.TextSize = 12
		mini.TextColor3 = Color3.fromRGB(200, 200, 200)
		mini.TextXAlignment = Enum.TextXAlignment.Right
		mini.Text = ("ATK %d"):format(tonumber(row.stats and row.stats.ATK) or 0)
		mini.Parent = frame

		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.Size = UDim2.fromScale(1, 1)
		btn.Text = ""
		btn.Parent = frame

		local function setHighlight(on)
			if on then
				stroke.Color = rarityCol
				frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
			else
				stroke.Color = Color3.fromRGB(40, 40, 48)
				frame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
			end
		end

		btn.MouseButton1Click:Connect(function()
			-- odznacz inne
			for _, fr in ipairs(list:GetChildren()) do
				if fr:IsA("Frame") then
					local st = fr:FindFirstChildOfClass("UIStroke")
					if st then st.Color = Color3.fromRGB(40, 40, 48) end
					fr.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
				end
			end
			setHighlight(true)
			setSelectedRow(row)
		end)

		-- auto select po refresh (żeby nie trzeba było wybierać ponownie)
		if keepId and row.instanceId == keepId then
			foundSelected = row
			setHighlight(true)
		end
	end

	if foundSelected then
		setSelectedRow(foundSelected)
	else
		-- jeśli nie ma selekcji, a jest equipped, auto-select equipped
		if not selectedInstanceId and equippedId then
			for _, row in ipairs(snapshot.instances or {}) do
				if row.instanceId == equippedId then
					setSelectedRow(row)
					break
				end
			end
		end
	end
end

local function applySnapshot(payload)
	if typeof(payload) ~= "table" then return end
	snapshot = payload
	refreshForge()
	refreshUpgrade()
end

BlacksmithSync.OnClientEvent:Connect(applySnapshot)

-- ===== Open / Close =====
OpenBlacksmithUI.OnClientEvent:Connect(function()
	gui.Enabled = true
	setTab("Forge")
	requestSnapshot()
end)

closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

overlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local pos = input.Position
		local absPos = panel.AbsolutePosition
		local absSize = panel.AbsoluteSize
		local inside = pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
		if not inside then
			gui.Enabled = false
		end
	end
end)

-- ===== Buttons =====
forgeBtn.MouseButton1Click:Connect(function()
	BlacksmithAction:FireServer({ type = "forge" })
end)

equipBtn.MouseButton1Click:Connect(function()
	if not selectedInstanceId then return end
	BlacksmithAction:FireServer({ type = "equip", instanceId = selectedInstanceId })
end)

upBtn.MouseButton1Click:Connect(function()
	if not selectedInstanceId then return end
	if not selectedCacheRow or not selectedCacheRow.canUpgrade then return end
	BlacksmithAction:FireServer({ type = "upgrade", instanceId = selectedInstanceId, steps = 1 })
end)

up10Btn.MouseButton1Click:Connect(function()
	if not selectedInstanceId then return end
	if not selectedCacheRow or not selectedCacheRow.canUpgrade then return end
	BlacksmithAction:FireServer({ type = "upgrade", instanceId = selectedInstanceId, steps = 10 })
end)
