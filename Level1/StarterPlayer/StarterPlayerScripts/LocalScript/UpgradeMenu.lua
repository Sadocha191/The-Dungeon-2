-- UpgradeMenu.client.lua (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpgradeEvent = remotes:WaitForChild("UpgradeEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "UpgradeMenu"
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true) -- dla auto-hide HUD
gui.Parent = pg

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1,1)
dim.BackgroundColor3 = Color3.fromRGB(0,0,0)
dim.BackgroundTransparency = 0.35
dim.BorderSizePixel = 0
dim.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5,0.5)
card.Position = UDim2.fromScale(0.5,0.5)
card.Size = UDim2.fromOffset(640, 340)
card.BackgroundColor3 = Color3.fromRGB(14,14,16)
card.BackgroundTransparency = 0.05
card.BorderSizePixel = 0
card.Parent = dim
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 18)
title.Size = UDim2.new(1, -44, 0, 28)
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Text = "Wybierz upgrade"
title.Parent = card

local container = Instance.new("Frame")
container.BackgroundTransparency = 1
container.Position = UDim2.fromOffset(22, 64)
container.Size = UDim2.new(1, -44, 1, -132)
container.Parent = card

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.Padding = UDim.new(0, 14)
list.Parent = container

local footer = Instance.new("TextLabel")
footer.BackgroundTransparency = 1
footer.AnchorPoint = Vector2.new(0.5,1)
footer.Position = UDim2.new(0.5,0,1,-18)
footer.Size = UDim2.new(1, -44, 0, 18)
footer.Font = Enum.Font.Gotham
footer.TextSize = 12
footer.TextColor3 = Color3.fromRGB(210,210,210)
footer.Text = "Kliknij kartę, potem Potwierdź."
footer.Parent = card

local selectedId = nil
local currentToken = nil
local confirmBtn

local function makeOption(opt)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 190, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(20,20,24)
	btn.BackgroundTransparency = 0.08
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = container
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 16)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(14, 14)
	name.Size = UDim2.new(1, -28, 0, 20)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.fromRGB(245,245,245)
	name.Text = opt.name
	name.Parent = btn

	local rar = Instance.new("TextLabel")
	rar.BackgroundTransparency = 1
	rar.Position = UDim2.fromOffset(14, 38)
	rar.Size = UDim2.new(1, -28, 0, 16)
	rar.Font = Enum.Font.Gotham
	rar.TextSize = 12
	rar.TextXAlignment = Enum.TextXAlignment.Left
	rar.TextColor3 = opt.color or Color3.fromRGB(210,210,210)
	rar.Text = tostring(opt.rarity or "Common")
	rar.Parent = btn

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(14, 62)
	desc.Size = UDim2.new(1, -28, 1, -120)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextColor3 = Color3.fromRGB(220,220,220)
	desc.TextWrapped = true

	local fmt = opt.desc or "%s"
	local val = opt.value
	local text
	if typeof(val) == "number" then
		if tostring(val):find("%.") then
			text = string.format(fmt, val)
		else
			text = string.format(fmt, val)
		end
	else
		text = tostring(fmt)
	end
	desc.Text = text
	desc.Parent = btn

	btn.MouseButton1Click:Connect(function()
		selectedId = opt.id
		confirmBtn.Text = ("Potwierdź: %s"):format(opt.name)
		confirmBtn.BackgroundTransparency = 0
	end)

	return btn
end

confirmBtn = Instance.new("TextButton")
confirmBtn.AnchorPoint = Vector2.new(0.5,1)
confirmBtn.Position = UDim2.new(0.5,0,1,-44)
confirmBtn.Size = UDim2.fromOffset(340, 42)
confirmBtn.BackgroundColor3 = Color3.fromRGB(96,165,250)
confirmBtn.BackgroundTransparency = 0.35
confirmBtn.BorderSizePixel = 0
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.TextSize = 14
confirmBtn.TextColor3 = Color3.fromRGB(10,10,12)
confirmBtn.Text = "Wybierz kartę"
confirmBtn.Parent = card
Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 14)

confirmBtn.MouseButton1Click:Connect(function()
	if not currentToken or not selectedId then return end
	UpgradeEvent:FireServer({ type="PICK", token=currentToken, id=selectedId })
	gui.Enabled = false
end)

UpgradeEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "SHOW" then return end
	currentToken = payload.token
	selectedId = nil

	for _,c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") and c ~= list then c:Destroy() end
	end

	for _,opt in ipairs(payload.choices or {}) do
		makeOption(opt)
	end

	confirmBtn.Text = "Wybierz kartę"
	confirmBtn.BackgroundTransparency = 0.35

	gui.Enabled = true
end)
