-- LOCALSCRIPT: LevelSelectUI.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/LevelSelectUI (LocalScript)
-- CO: UI wyboru poziomu po użyciu portalu

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local openLevelSelect = remoteFolder:WaitForChild("OpenLevelSelect")
local levelSelectRequest = remoteFolder:WaitForChild("LevelSelectRequest")

local gui = Instance.new("ScreenGui")
gui.Name = "LevelSelectUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = pg

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.45
dim.BorderSizePixel = 0
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(520, 360)
panel.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = dim
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -24, 0, 34)
title.Position = UDim2.fromOffset(12, 10)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Text = "Wybierz poziom"
title.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(110, 34)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -12, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
closeBtn.Text = "Zamknij"
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 12)

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(12, 58)
list.Size = UDim2.new(1, -24, 1, -70)
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = list

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function closeUI()
	gui.Enabled = false
	clearList()
end

closeBtn.MouseButton1Click:Connect(closeUI)

local function addLevelButton(level)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 44)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 18
	btn.TextColor3 = Color3.fromRGB(245, 245, 245)
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = ("  %s"):format(level.name or "Poziom")
	btn.Parent = list
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

	btn.MouseButton1Click:Connect(function()
		if typeof(level.id) == "number" then
			levelSelectRequest:FireServer(level.id)
			closeUI()
		end
	end)
end

openLevelSelect.OnClientEvent:Connect(function(levels)
	if typeof(levels) ~= "table" then return end
	clearList()

	for _, level in ipairs(levels) do
		if typeof(level) == "table" then
			addLevelButton(level)
		end
	end

	gui.Enabled = true
end)

print("[LevelSelectUI] Ready")
