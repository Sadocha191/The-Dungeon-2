-- BlacksmithUI.client.lua (StarterPlayerScripts)
-- Minimalny, działający UI: lista broni, forge, equip, upgrade x1/x10.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenBlacksmithUI = remoteEvents:WaitForChild("OpenBlacksmithUI")
local BlacksmithSync = remoteEvents:WaitForChild("BlacksmithSync")
local BlacksmithAction = remoteEvents:WaitForChild("BlacksmithAction")

local PauseState = ReplicatedStorage:WaitForChild("PauseState")

-- ===== UI build =====
local gui = Instance.new("ScreenGui")
gui.Name = "BlacksmithGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1,1)
overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5,0.5)
panel.Position = UDim2.fromScale(0.5,0.5)
panel.Size = UDim2.fromOffset(860, 480)
panel.BackgroundColor3 = Color3.fromRGB(14,14,16)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 14)
title.Size = UDim2.new(1,-36,0,26)
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Text = "Blacksmith"
title.Parent = panel

local coinsLabel = Instance.new("TextLabel")
coinsLabel.BackgroundTransparency = 1
coinsLabel.Position = UDim2.fromOffset(18, 42)
coinsLabel.Size = UDim2.new(1,-36,0,18)
coinsLabel.Font = Enum.Font.Gotham
coinsLabel.TextSize = 12
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.TextColor3 = Color3.fromRGB(210,210,210)
coinsLabel.Text = "Coins: 0"
coinsLabel.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(18, 70)
list.Size = UDim2.fromOffset(380, 340)
list.BackgroundColor3 = Color3.fromRGB(20,20,24)
list.BackgroundTransparency = 0.10
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.Parent = panel
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 14)

local listLay = Instance.new("UIListLayout")
listLay.Padding = UDim.new(0, 8)
listLay.Parent = list

local right = Instance.new("Frame")
right.Position = UDim2.fromOffset(416, 70)
right.Size = UDim2.fromOffset(426, 340)
right.BackgroundColor3 = Color3.fromRGB(20,20,24)
right.BackgroundTransparency = 0.10
right.BorderSizePixel = 0
right.Parent = panel
Instance.new("UICorner", right).CornerRadius = UDim.new(0, 14)

local rName = Instance.new("TextLabel")
rName.BackgroundTransparency = 1
rName.Position = UDim2.fromOffset(16, 14)
rName.Size = UDim2.new(1,-32,0,22)
rName.Font = Enum.Font.GothamBold
rName.TextSize = 16
rName.TextXAlignment = Enum.TextXAlignment.Left
rName.TextColor3 = Color3.fromRGB(245,245,245)
rName.Text = "Select a weapon"
rName.Parent = right

local rInfo = Instance.new("TextLabel")
rInfo.BackgroundTransparency = 1
rInfo.Position = UDim2.fromOffset(16, 44)
rInfo.Size = UDim2.new(1,-32,1,-160)
rInfo.Font = Enum.Font.Gotham
rInfo.TextSize = 12
rInfo.TextXAlignment = Enum.TextXAlignment.Left
rInfo.TextYAlignment = Enum.TextYAlignment.Top
rInfo.TextColor3 = Color3.fromRGB(220,220,220)
rInfo.TextWrapped = true
rInfo.Text = ""
rInfo.Parent = right

local function mkBtn(text, x, y, w)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, 38)
	b.BackgroundColor3 = Color3.fromRGB(30,30,34)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(245,245,245)
	b.Text = text
	b.Parent = right
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	return b
end

local forgeBtn  = mkBtn("Forge",     16, 260, 190)
local equipBtn  = mkBtn("Equip",    220, 260, 190)
local up1Btn    = mkBtn("Upgrade x1",16, 304, 190)
local up10Btn   = mkBtn("Upgrade x10",220,304, 190)

local closeBtn = Instance.new("TextButton")
closeBtn.Position = UDim2.fromOffset(18, 420)
closeBtn.Size = UDim2.fromOffset(180, 38)
closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,34)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(245,245,245)
closeBtn.Text = "Close"
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 14)

-- ===== Data + helpers =====
local snapshot = nil
local selected = nil

local function refreshCanvas()
	list.CanvasSize = UDim2.fromOffset(0, listLay.AbsoluteContentSize.Y + 16)
end

local function clearList()
	for _,c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") and not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function setRight(row)
	selected = row
	if not row then
		rName.Text = "Select a weapon"
		rInfo.Text = ""
		return
	end

	rName.Text = string.format("%s (Lv %d/%d) [%s]", row.weaponId, row.level, row.maxLevel, row.rarity)
	local s = row.stats or {}
	rInfo.Text = string.format(
		"Type: %s\nRarity: %s\nPrefix: %s\n\nATK: %s\nHP: %s\nDEF: %s\nSPD: %s%%\nCRIT: %s%%\nCRIT DMG: %s%%\nLIFESTEAL: %s%%",
		tostring(row.weaponType),
		tostring(row.rarity),
		tostring(row.prefix or "-"),
		tostring(s.ATK), tostring(s.HP), tostring(s.DEF),
		tostring(s.SPD), tostring(s.CRIT_RATE), tostring(s.CRIT_DMG), tostring(s.LIFESTEAL)
	)
end

local function addRow(row)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -16, 0, 46)
	b.Position = UDim2.fromOffset(8, 0)
	b.BackgroundColor3 = Color3.fromRGB(26,26,30)
	b.BackgroundTransparency = 0.10
	b.BorderSizePixel = 0
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(230,230,230)
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Text = string.format("  %s  [%s]  Lv %d/%d", row.weaponId, row.rarity, row.level, row.maxLevel)
	b.Parent = list
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)

	b.MouseButton1Click:Connect(function()
		setRight(row)
	end)
end

local function openUI()
	gui.Enabled = true
	PauseState.Value = true
	BlacksmithAction:FireServer({ type = "request" })
end

local function closeUI()
	gui.Enabled = false
	PauseState.Value = false
end

closeBtn.MouseButton1Click:Connect(closeUI)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)

forgeBtn.MouseButton1Click:Connect(function()
	if not snapshot then return end
	BlacksmithAction:FireServer({ type = "forge" })
end)

equipBtn.MouseButton1Click:Connect(function()
	if not selected then return end
	BlacksmithAction:FireServer({ type = "equip", instanceId = selected.instanceId })
end)

up1Btn.MouseButton1Click:Connect(function()
	if not selected then return end
	BlacksmithAction:FireServer({ type = "upgrade", instanceId = selected.instanceId, steps = 1 })
end)

up10Btn.MouseButton1Click:Connect(function()
	if not selected then return end
	BlacksmithAction:FireServer({ type = "upgrade", instanceId = selected.instanceId, steps = 10 })
end)

-- Open when prompt used OR when server explicitly tells
local function isPromptInsideBlacksmith(prompt: ProximityPrompt): boolean
	local npcs = workspace:FindFirstChild("NPCs")
	local smith = npcs and (npcs:FindFirstChild("Blacksmith") or npcs:FindFirstChild("BlacksmithNPC"))
	if not smith then return false end

	local p = prompt and prompt.Parent
	while p do
		if p == smith then return true end
		p = p.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if gui.Enabled then return end
	if isPromptInsideBlacksmith(prompt) then
		openUI()
	end
end)

OpenBlacksmithUI.OnClientEvent:Connect(function()
	if not gui.Enabled then
		openUI()
	end
end)

BlacksmithSync.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	snapshot = data

	coinsLabel.Text = string.format("Coins: %d | Forge cost: %d", tonumber(data.coins) or 0, tonumber(data.craftCost) or 0)

	clearList()
	for _, row in ipairs(data.instances or {}) do
		addRow(row)
	end
	refreshCanvas()

	-- jeżeli wybrany item dalej istnieje, odśwież prawy panel
	if selected then
		for _, row in ipairs(data.instances or {}) do
			if row.instanceId == selected.instanceId then
				setRight(row)
				break
			end
		end
	end
end)
