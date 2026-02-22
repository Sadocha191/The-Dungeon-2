-- LoadingClient.client.lua (Level1)
-- Shows loading screen, preloads critical assets, then notifies server (ClientReady).
-- Run starts only after server receives ClientReady from all players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")

local plr = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClientReady = remotes:WaitForChild("ClientReady")

-- Simple loading GUI (no external assets)
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = true
gui.Parent = plr:WaitForChild("PlayerGui")

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1,1)
dim.BackgroundColor3 = Color3.new(0,0,0)
dim.BackgroundTransparency = 0.25
dim.Parent = gui

local box = Instance.new("Frame")
box.Size = UDim2.new(0, 560, 0, 150)
box.Position = UDim2.new(0.5, -280, 0.5, -75)
box.BackgroundTransparency = 0.2
box.BackgroundColor3 = Color3.new(0.1,0.1,0.1)
box.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true
title.Text = "Loading..."
title.Parent = box

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -60, 0, 20)
barBg.Position = UDim2.new(0, 30, 0, 85)
barBg.BackgroundColor3 = Color3.new(0.2,0.2,0.2)
barBg.BorderSizePixel = 0
barBg.Parent = box

local bar = Instance.new("Frame")
bar.Size = UDim2.new(0, 0, 1, 0)
bar.Position = UDim2.new(0,0,0,0)
bar.BackgroundColor3 = Color3.new(0.5,0.8,1)
bar.BorderSizePixel = 0
bar.Parent = barBg

local pct = Instance.new("TextLabel")
pct.Size = UDim2.new(1, 0, 0, 30)
pct.Position = UDim2.new(0,0,0,110)
pct.BackgroundTransparency = 1
pct.Font = Enum.Font.Gotham
pct.TextColor3 = Color3.new(1,1,1)
pct.TextScaled = true
pct.Text = "0%"
pct.Parent = box

local function sinkAll()
	return Enum.ContextActionResult.Sink
end

local function lockInput()
	ContextActionService:BindActionAtPriority(
		"__LoadingLockAll",
		sinkAll,
		false,
		1000000,
		Enum.UserInputType.Keyboard,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.MouseButton2,
		Enum.UserInputType.MouseMovement,
		Enum.UserInputType.Touch,
		Enum.UserInputType.Gamepad1
	)
end

local function unlockInput()
	ContextActionService:UnbindAction("__LoadingLockAll")
end

local function collectPreloadTargets()
	-- Keep this tight to avoid huge load times. Add more folders if you see stutter from specific content.
	local targets = {}

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then table.insert(targets, assets) end

	local enemies = ReplicatedStorage:FindFirstChild("Enemies")
	if enemies then table.insert(targets, enemies) end

	-- Optional: if you keep weapon models / UI icon atlases elsewhere, add them here.
	return targets
end

lockInput()

local targets = collectPreloadTargets()
local instances = {}
for _, root in ipairs(targets) do
	for _, d in ipairs(root:GetDescendants()) do
		table.insert(instances, d)
	end
end

-- Preload in chunks so we can show progress (approximate)
local total = math.max(#instances, 1)
local chunkSize = 200
local loaded = 0

local function setProgress(n)
	local p = math.clamp(n / total, 0, 1)
	bar.Size = UDim2.new(p, 0, 1, 0)
	pct.Text = tostring(math.floor(p * 100)) .. "%"
end

local function preloadChunk(chunk)
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(chunk)
	end)
	if not ok then
		warn("[LoadingClient] PreloadAsync error:", err)
	end
end

for i = 1, #instances, chunkSize do
	local chunk = {}
	for j = i, math.min(i + chunkSize - 1, #instances) do
		table.insert(chunk, instances[j])
	end
	preloadChunk(chunk)
	loaded = math.min(loaded + #chunk, total)
	setProgress(loaded)
end

-- Final small delay to let UI settle
task.wait(0.05)

ClientReady:FireServer()

gui:Destroy()
unlockInput()
