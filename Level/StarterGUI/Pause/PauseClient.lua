local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = script.Parent
local frame = screenGui:WaitForChild("Frame")
local pauseIcon = frame:WaitForChild("PauseIcon")
local hotKey = pauseIcon:FindFirstChild("HotKey")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pauseMenuEvent = remotes:WaitForChild("PauseMenuEvent")
local pauseState = ReplicatedStorage:WaitForChild("PauseState")
local returnToLobby = ReplicatedStorage:WaitForChild("ReturnToLobby")

screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 70
screenGui:SetAttribute("MenuOpen", false)

if hotKey and hotKey:IsA("TextLabel") then
	hotKey.Text = "P"
end

local toggleRequested = screenGui:FindFirstChild("ToggleRequested")
if not toggleRequested then
	toggleRequested = Instance.new("BindableEvent")
	toggleRequested.Name = "ToggleRequested"
	toggleRequested.Parent = screenGui
end

local clickTarget = pauseIcon:FindFirstChild("ClickTarget")
if not clickTarget then
	clickTarget = Instance.new("TextButton")
	clickTarget.Name = "ClickTarget"
	clickTarget.BackgroundTransparency = 1
	clickTarget.BorderSizePixel = 0
	clickTarget.Text = ""
	clickTarget.AutoButtonColor = false
	clickTarget.Size = UDim2.fromScale(1, 1)
	clickTarget.ZIndex = pauseIcon.ZIndex + 1
	clickTarget.Parent = pauseIcon
end

local overlay = screenGui:FindFirstChild("MenuOverlay")
if not overlay then
	overlay = Instance.new("Frame")
	overlay.Name = "MenuOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(5, 7, 12)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 20
	overlay.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(430, 250)
	panel.BackgroundColor3 = Color3.fromRGB(17, 22, 32)
	panel.BorderSizePixel = 0
	panel.ZIndex = 21
	panel.Parent = overlay

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 22)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(88, 126, 186)
	panelStroke.Transparency = 0.2
	panelStroke.Thickness = 1
	panelStroke.Parent = panel

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(360, 220)
	sizeConstraint.MaxSize = Vector2.new(460, 280)
	sizeConstraint.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(22, 20)
	title.Size = UDim2.new(1, -90, 0, 30)
	title.Font = Enum.Font.GothamBold
	title.Text = "Run Paused"
	title.TextColor3 = Color3.fromRGB(244, 247, 252)
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 22
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(22, 58)
	body.Size = UDim2.new(1, -44, 0, 68)
	body.Font = Enum.Font.Gotham
	body.Text = "You can resume the run or end it now. Ending the run will bank your current progress as a failed run, then let you return to the lobby."
	body.TextColor3 = Color3.fromRGB(191, 201, 216)
	body.TextSize = 15
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 22
	body.Parent = panel

	local resumeButton = Instance.new("TextButton")
	resumeButton.Name = "ResumeButton"
	resumeButton.Position = UDim2.fromOffset(22, 152)
	resumeButton.Size = UDim2.new(1, -44, 0, 42)
	resumeButton.BackgroundColor3 = Color3.fromRGB(97, 194, 138)
	resumeButton.BorderSizePixel = 0
	resumeButton.Font = Enum.Font.GothamBold
	resumeButton.Text = "Resume"
	resumeButton.TextColor3 = Color3.fromRGB(10, 14, 22)
	resumeButton.TextSize = 16
	resumeButton.ZIndex = 22
	resumeButton.Parent = panel

	local resumeCorner = Instance.new("UICorner")
	resumeCorner.CornerRadius = UDim.new(0, 14)
	resumeCorner.Parent = resumeButton

	local leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.Position = UDim2.fromOffset(22, 202)
	leaveButton.Size = UDim2.new(1, -44, 0, 42)
	leaveButton.BackgroundColor3 = Color3.fromRGB(205, 93, 93)
	leaveButton.BorderSizePixel = 0
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.Text = "End Run"
	leaveButton.TextColor3 = Color3.fromRGB(255, 248, 248)
	leaveButton.TextSize = 16
	leaveButton.ZIndex = 22
	leaveButton.Parent = panel

	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 14)
	leaveCorner.Parent = leaveButton

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -18, 0, 18)
	closeButton.Size = UDim2.fromOffset(34, 34)
	closeButton.BackgroundColor3 = Color3.fromRGB(30, 36, 48)
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(244, 247, 252)
	closeButton.TextSize = 14
	closeButton.ZIndex = 22
	closeButton.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 12)
	closeCorner.Parent = closeButton
end

local panel = overlay:WaitForChild("Panel")
local resumeButton = panel:WaitForChild("ResumeButton")
local leaveButton = panel:WaitForChild("LeaveButton")
local closeButton = panel:WaitForChild("CloseButton")

local leavePending = false
local defaultLeaveText = leaveButton.Text

local function isMenuOpen(): boolean
	return screenGui:GetAttribute("MenuOpen") == true
end

local function isBlockedByOtherUi(): boolean
	local upgradesGui = playerGui:FindFirstChild("UpgradesGUI")
	local upgradesMain = upgradesGui and upgradesGui:FindFirstChild("Main")
	if upgradesGui and upgradesGui:IsA("ScreenGui") and upgradesGui.Enabled and upgradesMain and upgradesMain:IsA("GuiObject") and upgradesMain.Visible then
		return true
	end

	local missionSummary = playerGui:FindFirstChild("MissionSummary")
	if missionSummary and missionSummary:IsA("ScreenGui") and missionSummary.Enabled then
		return true
	end

	if player:GetAttribute("RunEnded") == true then
		return true
	end

	if pauseState.Value and not isMenuOpen() then
		return true
	end

	return false
end

local function setMenuOpen(open: boolean, notifyServer: boolean)
	if isMenuOpen() == open then
		return
	end

	screenGui:SetAttribute("MenuOpen", open)
	overlay.Visible = open

	if notifyServer then
		pauseMenuEvent:FireServer(open and "pause" or "resume")
	end
end

local function toggleMenu()
	if isMenuOpen() then
		setMenuOpen(false, true)
		return
	end

	if leavePending or isBlockedByOtherUi() then
		return
	end

	setMenuOpen(true, true)
end

clickTarget.MouseButton1Click:Connect(toggleMenu)
toggleRequested.Event:Connect(toggleMenu)
resumeButton.MouseButton1Click:Connect(function()
	setMenuOpen(false, true)
end)
closeButton.MouseButton1Click:Connect(function()
	setMenuOpen(false, true)
end)
leaveButton.MouseButton1Click:Connect(function()
	if leavePending then
		return
	end
	leavePending = true
	leaveButton.Text = "Ending Run..."
	setMenuOpen(false, false)
	returnToLobby:FireServer()
	task.delay(4, function()
		leavePending = false
		if leaveButton.Parent then
			leaveButton.Text = defaultLeaveText
		end
	end)
end)

player:GetAttributeChangedSignal("RunEnded"):Connect(function()
	if player:GetAttribute("RunEnded") == true then
		leavePending = false
		leaveButton.Text = defaultLeaveText
		setMenuOpen(false, false)
	end
end)
