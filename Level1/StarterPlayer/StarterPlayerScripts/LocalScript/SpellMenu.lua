-- SpellMenu.client.lua (Level1/StarterPlayerScripts)
-- UI wyboru spella (3 opcje). Uruchamiane przez Remotes/SpellEvent payload {type="offer", token, choices}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts")
local SpellDefs = require(moduleFolder:WaitForChild("SpellDefinitions"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpellEvent = remotes:WaitForChild("SpellEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "SpellMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui:SetAttribute("Modal", true)
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
card.Size = UDim2.fromOffset(620, 320)
card.BackgroundColor3 = Color3.fromRGB(14,14,16)
card.BackgroundTransparency = 0.06
card.BorderSizePixel = 0
card.Parent = dim
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 16)
title.Size = UDim2.new(1, -44, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(245,245,245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Choose a spell"
title.Parent = card

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(22, 58)
list.Size = UDim2.new(1, -44, 1, -76)
list.Parent = card

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Padding = UDim.new(0, 14)
layout.Parent = list

local currentToken = nil

local function makeOption()
	local opt = Instance.new("Frame")
	opt.Size = UDim2.fromOffset(180, 230)
	opt.BackgroundColor3 = Color3.fromRGB(20,20,24)
	opt.BackgroundTransparency = 0.06
	opt.BorderSizePixel = 0
	Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 16)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(14, 14)
	name.Size = UDim2.new(1, -28, 0, 22)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 16
	name.TextColor3 = Color3.fromRGB(245,245,245)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = opt

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(14, 44)
	desc.Size = UDim2.new(1, -28, 0, 118)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextColor3 = Color3.fromRGB(210,210,210)
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = opt

	local btn = Instance.new("TextButton")
	btn.Position = UDim2.new(0, 14, 1, -50)
	btn.Size = UDim2.new(1, -28, 0, 36)
	btn.BackgroundColor3 = Color3.fromRGB(120,190,255)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(10,10,10)
	btn.Text = "Select"
	btn.Parent = opt
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

	return opt, name, desc, btn
end

local optionFrames = {}

local function clearOptions()
	for _, f in ipairs(optionFrames) do
		f:Destroy()
	end
	table.clear(optionFrames)
end

local function showOffer(token: string, choices: {string})
	currentToken = token
	clearOptions()

	for _, id in ipairs(choices) do
		local def = SpellDefs.SPELLS[id]
		if def then
			local opt, name, desc, btn = makeOption()
			name.Text = def.name or id
			local lv = plr:GetAttribute(("Spell_%s_Level"):format(id)) or 0
			local nextText = def.nextDesc and def.nextDesc(lv) or ""
			desc.Text = nextText

			btn.MouseButton1Click:Connect(function()
				if not currentToken then return end
				SpellEvent:FireServer({ type="pick", token=currentToken, spellId=id })
				gui.Enabled = false
				currentToken = nil
			end)

			opt.Parent = list
			table.insert(optionFrames, opt)
		end
	end

	gui.Enabled = true
end

SpellEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type == "offer" and typeof(payload.token) == "string" and typeof(payload.choices) == "table" then
		showOffer(payload.token, payload.choices)
	end
end)
