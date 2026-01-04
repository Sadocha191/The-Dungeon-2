-- UpgradeViews.client.lua (StarterPlayerScripts) - I: owned, O: admin list

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
local upDefsModule = moduleFolder and moduleFolder:FindFirstChild("UpgradeDefinitions")
if not upDefsModule then
	local waitFolder = ReplicatedStorage:WaitForChild("ModuleScripts", 5)
		or ReplicatedStorage:WaitForChild("ModuleScript", 5)
	upDefsModule = waitFolder and waitFolder:FindFirstChild("UpgradeDefinitions")
end
local UpDefs = upDefsModule and upDefsModule:IsA("ModuleScript") and require(upDefsModule) or { POOL = {} }
if not upDefsModule then
	warn("[UpgradeViews] Missing ReplicatedStorage.UpgradeDefinitions; admin list disabled.")
end

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "UpgradeViews"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = pg

local function makeWindow(name, posX)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Visible = false
	frame.Position = UDim2.new(posX, 18, 0, 110)
	frame.Size = UDim2.fromOffset(360, 420)
	frame.BackgroundColor3 = Color3.fromRGB(14,14,16)
	frame.BackgroundTransparency = 0.10
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 12)
	title.Size = UDim2.new(1, -28, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(245,245,245)
	title.Text = name
	title.Parent = frame

	local box = Instance.new("ScrollingFrame")
	box.Position = UDim2.fromOffset(14, 42)
	box.Size = UDim2.new(1, -28, 1, -56)
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.ScrollBarThickness = 6
	box.Parent = frame

	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.Parent = box

	return frame, box, lay
end

local ownedWin, ownedBox = makeWindow("Moje upgrady (I)", 0)
local adminWin, adminBox = makeWindow("Admin: wszystkie upgrady (O)", 1)

local function addLine(parent, text, color)
	local t = Instance.new("TextLabel")
	t.BackgroundColor3 = Color3.fromRGB(20,20,24)
	t.BackgroundTransparency = 0.08
	t.BorderSizePixel = 0
	t.Size = UDim2.new(1, 0, 0, 46)
	t.Font = Enum.Font.Gotham
	t.TextSize = 12
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextColor3 = color or Color3.fromRGB(220,220,220)
	t.Text = "  " .. text
	t.Parent = parent
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 12)
	return t
end

local function refreshAdmin()
	for _,c in ipairs(adminBox:GetChildren()) do if c:IsA("GuiObject") and not c:IsA("UIListLayout") then c:Destroy() end end
	for _,u in ipairs(UpDefs.POOL) do
		addLine(adminBox, ("%s (%s)  base=%s"):format(u.name, u.id, tostring(u.base)), Color3.fromRGB(245,245,245))
	end
	adminBox.CanvasSize = UDim2.fromOffset(0, adminBox.UIListLayout.AbsoluteContentSize.Y + 12)
end
refreshAdmin()

-- owned: czytamy z atrybutu (na teraz), jeśli masz inny system, podmień źródło
local function refreshOwned()
	for _,c in ipairs(ownedBox:GetChildren()) do if c:IsA("GuiObject") and not c:IsA("UIListLayout") then c:Destroy() end end
	addLine(ownedBox, "Owned upgrades zapisujemy w PlayerData jako d._owned (serwer).", Color3.fromRGB(200,200,200))
	ownedBox.CanvasSize = UDim2.fromOffset(0, ownedBox.UIListLayout.AbsoluteContentSize.Y + 12)
end
refreshOwned()

UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.I then
		ownedWin.Visible = not ownedWin.Visible
		if ownedWin.Visible then refreshOwned() end
	elseif inp.KeyCode == Enum.KeyCode.O then
		adminWin.Visible = not adminWin.Visible
		if adminWin.Visible then refreshAdmin() end
	end
end)
