-- LOCALSCRIPT: LevelSelectUI.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/LevelSelectUI (LocalScript)
-- CO: Okienko wyboru poziomu przy portalu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenLevelSelect = remoteEvents:WaitForChild("OpenLevelSelect")
local RequestLevelTeleport = remoteEvents:WaitForChild("RequestLevelTeleport")

local Levels = require(ReplicatedStorage:WaitForChild("Levels"))

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

local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(360, 280)
root.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
root.BackgroundTransparency = 0.12
root.BorderSizePixel = 0
root.Parent = gui
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -24, 0, 32)
title.Position = UDim2.fromOffset(12, 10)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Text = "Wybierz poziom"
title.Parent = root

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(90, 32)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -12, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
closeBtn.Text = "Zamknij"
closeBtn.Parent = root
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)

local listFrame = Instance.new("Frame")
listFrame.BackgroundTransparency = 1
listFrame.Position = UDim2.fromOffset(12, 52)
listFrame.Size = UDim2.new(1, -24, 1, -72)
listFrame.Parent = root

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = listFrame

local function clearList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function makeLevelButton(entry)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 44)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 18
	btn.TextColor3 = Color3.fromRGB(245, 245, 245)
	btn.Text = tostring(entry.name or entry.key or "Poziom")
	btn.Parent = listFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

	btn.MouseButton1Click:Connect(function()
		if typeof(entry.key) == "string" then
			RequestLevelTeleport:FireServer(entry.key)
		end
		gui.Enabled = false
	end)
end

local function rebuildList()
	clearList()
	local entries = Levels.GetAll()
	if #entries == 0 then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 24)
		label.Font = Enum.Font.Gotham
		label.TextSize = 18
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(220, 220, 220)
		label.Text = "Brak dostępnych poziomów."
		label.Parent = listFrame
		return
	end

	for _, entry in ipairs(entries) do
		makeLevelButton(entry)
	end
end

local function openUI()
	rebuildList()
	gui.Enabled = true
end

closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

OpenLevelSelect.OnClientEvent:Connect(openUI)

print("[LevelSelectUI] Ready")
