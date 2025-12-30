-- PlayerHudUnified.client.lua (StarterPlayerScripts) - HUD gracza (bez fal, bez armora)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayerProgressEvent = remotes:WaitForChild("PlayerProgressEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "PlayerHudUnified"
gui.ResetOnSpawn = false
gui.Parent = pg

-- Coins (left)
local coinsBox = Instance.new("Frame")
coinsBox.Position = UDim2.fromOffset(18, 150)
coinsBox.Size = UDim2.fromOffset(200, 36)
coinsBox.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
coinsBox.BackgroundTransparency = 0.12
coinsBox.BorderSizePixel = 0
coinsBox.Parent = gui
Instance.new("UICorner", coinsBox).CornerRadius = UDim.new(0, 14)
local padL = Instance.new("UIPadding", coinsBox)
padL.PaddingLeft = UDim.new(0, 12)

local coinsText = Instance.new("TextLabel")
coinsText.BackgroundTransparency = 1
coinsText.Size = UDim2.new(1, 0, 1, 0)
coinsText.Font = Enum.Font.GothamBold
coinsText.TextSize = 14
coinsText.TextXAlignment = Enum.TextXAlignment.Left
coinsText.TextColor3 = Color3.fromRGB(245, 245, 245)
coinsText.Text = "Monety: 0"
coinsText.Parent = coinsBox

-- Name (right)
local nameBox = Instance.new("Frame")
nameBox.AnchorPoint = Vector2.new(1, 0)
nameBox.Position = UDim2.new(1, -18, 0, 18)
nameBox.Size = UDim2.fromOffset(260, 38)
nameBox.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
nameBox.BackgroundTransparency = 0.12
nameBox.BorderSizePixel = 0
nameBox.Parent = gui
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 14)
local padR = Instance.new("UIPadding", nameBox)
padR.PaddingLeft = UDim.new(0, 14)
padR.PaddingRight = UDim.new(0, 14)

local nameText = Instance.new("TextLabel")
nameText.BackgroundTransparency = 1
nameText.Size = UDim2.new(1, 0, 1, 0)
nameText.Font = Enum.Font.GothamBold
nameText.TextSize = 14
nameText.TextXAlignment = Enum.TextXAlignment.Right
nameText.TextColor3 = Color3.fromRGB(245, 245, 245)
nameText.Text = plr.Name .. " • Lv. 1"
nameText.Parent = nameBox

local function autoSizeNameBox()
	local bounds = TextService:GetTextSize(nameText.Text, nameText.TextSize, nameText.Font, Vector2.new(2000, 2000))
	local w = math.clamp(bounds.X + 28, 200, 520)
	nameBox.Size = UDim2.fromOffset(w, 38)
end

-- Bottom bars
local bottom = Instance.new("Frame")
bottom.AnchorPoint = Vector2.new(0.5, 1)
bottom.Position = UDim2.new(0.5, 0, 1, -18)
bottom.Size = UDim2.fromOffset(520, 66)
bottom.BackgroundTransparency = 1
bottom.Parent = gui

local bl = Instance.new("UIListLayout", bottom)
bl.FillDirection = Enum.FillDirection.Vertical
bl.Padding = UDim.new(0, 10)

local function makeBar(labelText, fillColor)
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 28)
	wrap.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	wrap.BackgroundTransparency = 0.12
	wrap.BorderSizePixel = 0
	wrap.Parent = bottom
	Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, 14)

	local p = Instance.new("UIPadding", wrap)
	p.PaddingLeft = UDim.new(0, 12); p.PaddingRight = UDim.new(0, 12)
	p.PaddingTop = UDim.new(0, 6); p.PaddingBottom = UDim.new(0, 6)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 14)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.Parent = wrap

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, 16)
	back.Size = UDim2.new(1, 0, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
	back.BorderSizePixel = 0
	back.Parent = wrap
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 999)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 999)

	return label, fill
end

local hpLabel, hpFill = makeBar("HP: 0/0", Color3.fromRGB(34, 197, 94))
local xpLabel, xpFill = makeBar("EXP: 0/0", Color3.fromRGB(96, 165, 250))

local function tweenFill(fill, pct)
	pct = math.clamp(pct, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(pct, 0, 1, 0)
	}):Play()
end

local function bindCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then return end

	local function refresh()
		local maxHp = math.max(1, hum.MaxHealth)
		local cur = math.clamp(hum.Health, 0, maxHp)
		hpLabel.Text = ("HP: %d/%d"):format(math.floor(cur+0.5), math.floor(maxHp+0.5))
		tweenFill(hpFill, cur / maxHp)
	end
	refresh()
	hum.HealthChanged:Connect(refresh)
end

if plr.Character then bindCharacter(plr.Character) end
plr.CharacterAdded:Connect(bindCharacter)

local level, xp, nextXp, coins = 1, 0, 120, 0

local function render()
	nameText.Text = ("%s • Lv. %d"):format(plr.Name, level)
	coinsText.Text = ("Monety: %d"):format(coins)
	local n = math.max(1, nextXp)
	xpLabel.Text = ("EXP: %d/%d"):format(xp, n)
	tweenFill(xpFill, xp / n)
	autoSizeNameBox()
end

PlayerProgressEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "progress" then return end
	level = tonumber(payload.level) or level
	xp = tonumber(payload.xp) or xp
	nextXp = tonumber(payload.nextXp) or nextXp
	coins = tonumber(payload.coins) or coins
	render()
end)

render()
