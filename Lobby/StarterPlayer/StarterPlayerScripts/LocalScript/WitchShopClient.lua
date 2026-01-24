-- WitchShopClient.client.lua (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local WitchShopEvent = remotes:WaitForChild("WitchShopEvent")

local PauseState = ReplicatedStorage:WaitForChild("PauseState")

local gui = Instance.new("ScreenGui")
gui.Name = "WitchShopGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = pg

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1,1)
overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5,0.5)
panel.Position = UDim2.fromScale(0.5,0.5)
panel.Size = UDim2.fromOffset(820, 460)
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
title.Text = "Witch Shop"
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

local left = Instance.new("ScrollingFrame")
left.Position = UDim2.fromOffset(18, 70)
left.Size = UDim2.fromOffset(360, 330)
left.BackgroundColor3 = Color3.fromRGB(20,20,24)
left.BackgroundTransparency = 0.10
left.BorderSizePixel = 0
left.ScrollBarThickness = 6
left.Parent = panel
Instance.new("UICorner", left).CornerRadius = UDim.new(0, 14)

local leftLay = Instance.new("UIListLayout")
leftLay.Padding = UDim.new(0, 8)
leftLay.Parent = left

local right = Instance.new("Frame")
right.Position = UDim2.fromOffset(396, 70)
right.Size = UDim2.fromOffset(406, 330)
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
rName.Text = "Select a spell"
rName.Parent = right

local rInfo = Instance.new("TextLabel")
rInfo.BackgroundTransparency = 1
rInfo.Position = UDim2.fromOffset(16, 44)
rInfo.Size = UDim2.new(1,-32,1,-110)
rInfo.Font = Enum.Font.Gotham
rInfo.TextSize = 12
rInfo.TextXAlignment = Enum.TextXAlignment.Left
rInfo.TextYAlignment = Enum.TextYAlignment.Top
rInfo.TextColor3 = Color3.fromRGB(220,220,220)
rInfo.TextWrapped = true
rInfo.Text = ""
rInfo.Parent = right

local buyBtn = Instance.new("TextButton")
buyBtn.AnchorPoint = Vector2.new(0.5,1)
buyBtn.Position = UDim2.new(0.5,0,1,-18)
buyBtn.Size = UDim2.fromOffset(320, 44)
buyBtn.BackgroundColor3 = Color3.fromRGB(180,120,255)
buyBtn.BackgroundTransparency = 0.15
buyBtn.BorderSizePixel = 0
buyBtn.Font = Enum.Font.GothamBold
buyBtn.TextSize = 14
buyBtn.TextColor3 = Color3.fromRGB(10,10,12)
buyBtn.Text = "Buy"
buyBtn.Parent = right
Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 14)

local closeBtn = Instance.new("TextButton")
closeBtn.Position = UDim2.fromOffset(18, 410)
closeBtn.Size = UDim2.fromOffset(180, 38)
closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,34)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(245,245,245)
closeBtn.Text = "Close"
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 14)

local selected = nil
local currentCoins = 0
local currentSpells = {}

local function refreshCanvas()
	left.CanvasSize = UDim2.fromOffset(0, leftLay.AbsoluteContentSize.Y + 16)
end

local function clearList()
	for _,c in ipairs(left:GetChildren()) do
		if c:IsA("GuiObject") and not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function setRight(spell)
	selected = spell
	if not spell then
		rName.Text = "Select a spell"
		rInfo.Text = ""
		buyBtn.Text = "Buy"
		buyBtn.BackgroundTransparency = 0.5
		buyBtn.Active = false
		return
	end

	rName.Text = spell.name
	rInfo.Text = ("Category: %s\nCost: %d coins\nStatus: %s\n\nUnlocks the spell so it can appear during level up."):format(
		tostring(spell.category),
		tonumber(spell.costCoins) or 0,
		spell.owned and "Owned" or "Locked"
	)

	if spell.owned then
		buyBtn.Text = "Owned"
		buyBtn.BackgroundTransparency = 0.5
		buyBtn.Active = false
	else
		buyBtn.Text = ("Buy (%d)"):format(tonumber(spell.costCoins) or 0)
		buyBtn.BackgroundTransparency = 0.15
		buyBtn.Active = true
	end
end

local function addRow(spell)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -16, 0, 46)
	row.Position = UDim2.fromOffset(8, 0)
	row.BackgroundColor3 = Color3.fromRGB(26,26,30)
	row.BackgroundTransparency = 0.10
	row.BorderSizePixel = 0
	row.Font = Enum.Font.Gotham
	row.TextSize = 12
	row.TextColor3 = Color3.fromRGB(230,230,230)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = ("  %s  [%s]  %s"):format(
		spell.name,
		spell.category,
		spell.owned and "Owned" or ("Cost: "..tostring(spell.costCoins))
	)
	row.Parent = left
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

	row.MouseButton1Click:Connect(function()
		setRight(spell)
	end)
end

local function openShop(payload)
	currentCoins = tonumber(payload.coins) or 0
	currentSpells = payload.spells or {}
	coinsLabel.Text = ("Coins: %d"):format(currentCoins)

	clearList()
	for _, spell in ipairs(currentSpells) do
		addRow(spell)
	end
	refreshCanvas()
	setRight(nil)

	gui.Enabled = true
	PauseState.Value = true
end

local function closeShop()
	gui.Enabled = false
	PauseState.Value = false
end

closeBtn.MouseButton1Click:Connect(closeShop)

buyBtn.MouseButton1Click:Connect(function()
	if not selected or selected.owned then return end
	WitchShopEvent:FireServer({ type = "BUY", id = selected.id })
end)

-- (opcjonalnie) ESC zamyka
UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeShop()
	end
end)

WitchShopEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.type == "OPEN" then
		openShop(payload)
	elseif payload.type == "BOUGHT" then
		-- odśwież stan
		if payload.coins then coinsLabel.Text = ("Coins: %d"):format(tonumber(payload.coins) or 0) end
		if payload.spells then
			currentSpells = payload.spells
			clearList()
			for _, spell in ipairs(currentSpells) do
				addRow(spell)
			end
			refreshCanvas()
		end
		-- ponownie ustaw prawy panel na ten sam spell (jeśli istnieje)
		if selected then
			for _, s in ipairs(currentSpells) do
				if s.id == selected.id then
					setRight(s)
					break
				end
			end
		end
	elseif payload.type == "ERROR" or payload.type == "INFO" then
		-- minimalnie: pokaż w panelu
		rInfo.Text = tostring(payload.message or "...")
	end
end)
