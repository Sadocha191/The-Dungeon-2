-- LevelSelectClient.client.lua (Lobby)
-- Minimal level select UI for portal teleport.
-- Works with PortalToDungeon.server.lua and supports Single/Multi mode.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenLevelSelect = remotes:WaitForChild("OpenLevelSelect")
local RequestLevelTeleport = remotes:WaitForChild("RequestLevelTeleport")
local TeleportStatus = remotes:FindFirstChild("TeleportStatus")

local modFolder = ReplicatedStorage:WaitForChild("ModuleScripts")
local Levels = require(modFolder:WaitForChild("Levels"))

local gui = Instance.new("ScreenGui")
gui.Name = "LevelSelectGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = plr:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 420, 0, 260)
frame.Position = UDim2.new(0.5, -210, 0.5, -130)
frame.BackgroundTransparency = 0.12
frame.Visible = false
frame.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.new(0, 8, 0, 8)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Select level"
title.Parent = frame

local info = Instance.new("TextLabel")
info.BackgroundTransparency = 1
info.Size = UDim2.new(1, -16, 0, 20)
info.Position = UDim2.new(0, 8, 0, 38)
info.Font = Enum.Font.Gotham
info.TextSize = 14
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextColor3 = Color3.fromRGB(220,220,220)
info.Text = ""
info.Parent = frame

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Size = UDim2.new(1, -16, 0, 120)
list.Position = UDim2.new(0, 8, 0, 68)
list.Parent = frame

local single = Instance.new("TextButton")
single.Text = "Single"
single.Size = UDim2.new(0.5, -12, 0, 36)
single.Position = UDim2.new(0, 8, 1, -44)
single.AnchorPoint = Vector2.new(0, 1)
single.Font = Enum.Font.GothamBold
single.TextSize = 16
single.BackgroundTransparency = 0.2
single.Parent = frame

local multi = Instance.new("TextButton")
multi.Text = "Multiplayer"
multi.Size = UDim2.new(0.5, -12, 0, 36)
multi.Position = UDim2.new(0.5, 4, 1, -44)
multi.AnchorPoint = Vector2.new(0, 1)
multi.Font = Enum.Font.GothamBold
multi.TextSize = 16
multi.BackgroundTransparency = 0.2
multi.Parent = frame

local close = Instance.new("TextButton")
close.Text = "X"
close.Size = UDim2.new(0, 28, 0, 28)
close.Position = UDim2.new(1, -36, 0, 6)
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.BackgroundTransparency = 0.2
close.Parent = frame

local selectedKey: string? = nil

local function clearList()
	for _, c in ipairs(list:GetChildren()) do
		c:Destroy()
	end
end

local function renderLevels()
	clearList()
	local y = 0
	for _, entry in ipairs(Levels.GetAll()) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 32)
		b.Position = UDim2.new(0, 0, 0, y)
		b.Font = Enum.Font.Gotham
		b.TextSize = 14
		b.BackgroundTransparency = 0.25
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Text = "  " .. tostring(entry.name or entry.key)
		b.Parent = list
		b.MouseButton1Click:Connect(function()
			selectedKey = entry.key
			info.Text = "Selected: " .. tostring(entry.name or entry.key)
		end)
		y += 34
	end
end

local function request(mode: string)
	if not selectedKey then
		info.Text = "Select a level first."
		return
	end
	RequestLevelTeleport:FireServer(selectedKey, mode)
end

OpenLevelSelect.OnClientEvent:Connect(function()
	selectedKey = nil
	info.Text = ""
	renderLevels()
	frame.Visible = true
end)

single.MouseButton1Click:Connect(function() request("Single") end)
multi.MouseButton1Click:Connect(function() request("Multi") end)
close.MouseButton1Click:Connect(function() frame.Visible = false end)

if TeleportStatus then
	TeleportStatus.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		if payload.type == "failed" then
			frame.Visible = true
			local reason = payload.reason and tostring(payload.reason) or ""
			info.Text = "Teleport failed" .. (reason ~= "" and (": " .. reason) or "")
		end
	end)
end
