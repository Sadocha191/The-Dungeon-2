-- UpgradeMenu.client.lua (StarterPlayerScripts) - 3 wybory + CONFIRM, Modal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpgradeEvent = remotes:WaitForChild("UpgradeEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "UpgradeMenu"
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")
gui.Enabled = false
gui:SetAttribute("Modal", true)

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1,1)
overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.45
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5,0.5)
panel.Position = UDim2.fromScale(0.5,0.5)
panel.Size = UDim2.fromOffset(980, 520)
panel.BackgroundColor3 = Color3.fromRGB(14,14,16)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 24)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 16)
title.Size = UDim2.new(1,-48,0,30)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Text = "LEVEL UP — wybierz upgrade"
title.Parent = panel

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Position = UDim2.fromOffset(24, 48)
hint.Size = UDim2.new(1,-48,0,20)
hint.Font = Enum.Font.Gotham
hint.TextSize = 14
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextColor3 = Color3.fromRGB(210,210,210)
hint.Text = "Kliknij opcję, potem Potwierdź."
hint.Parent = panel

local choicesFrame = Instance.new("Frame")
choicesFrame.BackgroundTransparency = 1
choicesFrame.Position = UDim2.fromOffset(24, 86)
choicesFrame.Size = UDim2.new(1,-48,1,-150)
choicesFrame.Parent = panel

local grid = Instance.new("UIGridLayout", choicesFrame)
grid.CellPadding = UDim2.fromOffset(18,18)
grid.CellSize = UDim2.fromOffset(300, 240)

local confirm = Instance.new("TextButton")
confirm.AnchorPoint = Vector2.new(1,1)
confirm.Position = UDim2.new(1,-24,1,-24)
confirm.Size = UDim2.fromOffset(220, 46)
confirm.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
confirm.BorderSizePixel = 0
confirm.Font = Enum.Font.GothamBold
confirm.TextSize = 16
confirm.TextColor3 = Color3.fromRGB(255,255,255)
confirm.Text = "POTWIERDŹ"
confirm.Parent = panel
Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 14)

local token: string? = nil
local selectedId: string? = nil
local locked = false

local buttons = {}

local function clearButtons()
	for _,b in ipairs(buttons) do
		b:Destroy()
	end
	table.clear(buttons)
	selectedId = nil
	locked = false
end

local function makeChoiceButton(choice)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = choice.color
	b.BackgroundTransparency = 0.85
	b.BorderSizePixel = 0
	b.Text = ""
	b.Parent = choicesFrame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 18)

	local rarity = Instance.new("TextLabel")
	rarity.BackgroundTransparency = 1
	rarity.Position = UDim2.fromOffset(16, 12)
	rarity.Size = UDim2.new(1,-32,0,18)
	rarity.Font = Enum.Font.GothamBold
	rarity.TextSize = 14
	rarity.TextXAlignment = Enum.TextXAlignment.Left
	rarity.TextColor3 = choice.color
	rarity.Text = choice.rarity
	rarity.Parent = b

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(16, 34)
	name.Size = UDim2.new(1,-32,0,24)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 18
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.fromRGB(245,245,245)
	name.Text = choice.name
	name.Parent = b

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(16, 62)
	desc.Size = UDim2.new(1,-32,1,-90)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 14
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextColor3 = Color3.fromRGB(210,210,210)
	desc.TextWrapped = true
	desc.Text = ("+%s %s"):format(tostring(choice.value), tostring(choice.stat))
	desc.Parent = b

	local pick = Instance.new("TextLabel")
	pick.BackgroundTransparency = 1
	pick.AnchorPoint = Vector2.new(0,1)
	pick.Position = UDim2.new(0,16,1,-16)
	pick.Size = UDim2.new(1,-32,0,20)
	pick.Font = Enum.Font.GothamBold
	pick.TextSize = 14
	pick.TextXAlignment = Enum.TextXAlignment.Left
	pick.TextColor3 = Color3.fromRGB(140,200,255)
	pick.Text = "Kliknij, aby zaznaczyć"
	pick.Parent = b

	b.MouseButton1Click:Connect(function()
		if locked then return end
		selectedId = choice.id
		for _,bb in ipairs(buttons) do
			bb.BorderSizePixel = 0
		end
		b.BorderSizePixel = 3
		b.BorderColor3 = Color3.fromRGB(255,255,255)
	end)

	table.insert(buttons, b)
end

confirm.MouseButton1Click:Connect(function()
	if locked then return end
	if not token or not selectedId then return end
	locked = true
	UpgradeEvent:FireServer({ type="PICK", token=token, id=selectedId })
	gui.Enabled = false
	clearButtons()
end)

UpgradeEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type ~= "SHOW" then return end
	if typeof(payload.token) ~= "string" then return end
	if typeof(payload.choices) ~= "table" then return end

	token = payload.token
	clearButtons()
	for _,c in ipairs(payload.choices) do
		makeChoiceButton(c)
	end
	gui.Enabled = true
end)
