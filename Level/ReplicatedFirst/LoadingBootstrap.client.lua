local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local localPlayer = Players.LocalPlayer
if not localPlayer then
	return
end

local playerGui = localPlayer:WaitForChild("PlayerGui")
local existing = playerGui:FindFirstChild("LoadingGui")
if existing then
	if existing:IsA("ScreenGui") then
		existing.Enabled = true
		return
	end
	existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10000
gui.Enabled = true
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BorderSizePixel = 0
dim.Parent = gui

local box = Instance.new("Frame")
box.Name = "Box"
box.AnchorPoint = Vector2.new(0.5, 0.5)
box.Position = UDim2.fromScale(0.5, 0.5)
box.Size = UDim2.fromOffset(560, 160)
box.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
box.BackgroundTransparency = 0.15
box.BorderSizePixel = 0
box.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = box

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -40, 0, 42)
titleLabel.Position = UDim2.new(0, 20, 0, 18)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextScaled = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "Loading..."
titleLabel.Parent = box

local detailLabel = Instance.new("TextLabel")
detailLabel.Name = "Detail"
detailLabel.Size = UDim2.new(1, -40, 0, 28)
detailLabel.Position = UDim2.new(0, 20, 0, 62)
detailLabel.BackgroundTransparency = 1
detailLabel.Font = Enum.Font.Gotham
detailLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
detailLabel.TextScaled = true
detailLabel.TextXAlignment = Enum.TextXAlignment.Left
detailLabel.Text = "Joining level"
detailLabel.Parent = box

local barBg = Instance.new("Frame")
barBg.Name = "BarBg"
barBg.Size = UDim2.new(1, -40, 0, 18)
barBg.Position = UDim2.new(0, 20, 0, 108)
barBg.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
barBg.BorderSizePixel = 0
barBg.Parent = box

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 9)
barCorner.Parent = barBg

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(102, 178, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 9)
fillCorner.Parent = barFill

local pctLabel = Instance.new("TextLabel")
pctLabel.Name = "Pct"
pctLabel.Size = UDim2.new(1, -40, 0, 20)
pctLabel.Position = UDim2.new(0, 20, 0, 132)
pctLabel.BackgroundTransparency = 1
pctLabel.Font = Enum.Font.Gotham
pctLabel.TextColor3 = Color3.new(1, 1, 1)
pctLabel.TextScaled = true
pctLabel.TextXAlignment = Enum.TextXAlignment.Right
pctLabel.Text = "0%"
pctLabel.Parent = box
