-- LOCALSCRIPT: PlayerHudLobby.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/PlayerHudLobby (LocalScript)
-- CO: HUD (monety + nick/lvl/rasa + HP/EXP) + auto-hide gdy istnieje ScreenGui z atrybutem Modal=true i Enabled=true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlayerProgressEvent = remoteEvents:WaitForChild("PlayerProgressEvent")

-- Race updates (opcjonalnie)
local RaceUpdated = remoteEvents:FindFirstChild("RaceUpdated")

local gui = Instance.new("ScreenGui")
gui.Name = "PlayerHudGui_Lobby"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
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
coinsText.TextYAlignment = Enum.TextYAlignment.Center
coinsText.TextColor3 = Color3.fromRGB(245, 245, 245)
coinsText.Text = "Monety: 0"
coinsText.Parent = coinsBox

-- Name + level + race (right) - autosize width
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
nameText.TextYAlignment = Enum.TextYAlignment.Center
nameText.TextColor3 = Color3.fromRGB(245, 245, 245)
nameText.Text = plr.Name .. " • Lv. 1 • Rasa: -"
nameText.Parent = nameBox

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
		hpLabel.Text = ("HP: %d/%d"):format(math.floor(cur + 0.5), math.floor(maxHp + 0.5))
		tweenFill(hpFill, cur / maxHp)
	end
	refresh()
	hum.HealthChanged:Connect(refresh)
end
if plr.Character then bindCharacter(plr.Character) end
plr.CharacterAdded:Connect(bindCharacter)

local level, xp, nextXp, coins = 1, 0, 120, 0
local race = tostring(plr:GetAttribute("Race") or "-")

local function autoSizeNameBox()
	local bounds = TextService:GetTextSize(nameText.Text, nameText.TextSize, nameText.Font, Vector2.new(2000, 2000))
	local targetW = math.clamp(bounds.X + 28, 200, 520)
	nameBox.Size = UDim2.fromOffset(targetW, 38)
end

local function render()
	race = tostring(plr:GetAttribute("Race") or race or "-")
	nameText.Text = ("%s • Lv. %d • Rasa: %s"):format(plr.Name, level, race)
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

if RaceUpdated and RaceUpdated:IsA("RemoteEvent") then
	RaceUpdated.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.race) == "string" then
			plr:SetAttribute("Race", payload.race)
		end
	end)
end

plr:GetAttributeChangedSignal("Race"):Connect(render)

-- INVENTORY (Lobby only)
-- AUTO-HIDE: jeśli jakikolwiek ScreenGui ma Modal=true i Enabled=true, chowamy HUD
local function anyModalOpen(): boolean
	for _, inst in ipairs(pg:GetChildren()) do
		if inst:IsA("ScreenGui") and inst.Enabled then
			if inst:GetAttribute("Modal") == true then
				return true
			end
		end
	end
	return false
end

local lastHidden = false
RunService.RenderStepped:Connect(function()
	local hide = anyModalOpen()
	if hide ~= lastHidden then
		gui.Enabled = not hide
		lastHidden = hide
	end
end)

render()
print("[PlayerHudLobby] Ready (auto-hide on Modal)")
