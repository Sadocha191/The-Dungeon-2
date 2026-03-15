local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local moduleRoot = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local UiResponsive = require(moduleRoot:WaitForChild("UiResponsive"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenMineUI = remoteEvents:WaitForChild("OpenMineUI")
local MineSync = remoteEvents:WaitForChild("MineSync")
local MineAction = remoteEvents:WaitForChild("MineAction")

local gui = playerGui:WaitForChild("MineGui")
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)

local overlay = gui:WaitForChild("overlay")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.48
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = overlay:WaitForChild("panel")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.86, 0.86)
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)
local panelSizeConstraint = Instance.new("UISizeConstraint", panel)
panelSizeConstraint.MaxSize = Vector2.new(860, 560)
local panelAspect = Instance.new("UIAspectRatioConstraint", panel)
panelAspect.AspectRatio = 860 / 560
panelAspect.DominantAxis = Enum.DominantAxis.Height
UiResponsive.attachCenteredPanel(panel, Vector2.new(860, 560))

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(20, 18)
title.Size = UDim2.fromOffset(300, 24)
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(244, 244, 244)
title.Text = "Lobby Mine"
title.Parent = panel

local subTitle = Instance.new("TextLabel")
subTitle.BackgroundTransparency = 1
subTitle.Position = UDim2.fromOffset(20, 46)
subTitle.Size = UDim2.new(1, -40, 0, 18)
subTitle.Font = Enum.Font.Gotham
subTitle.TextSize = 12
subTitle.TextXAlignment = Enum.TextXAlignment.Left
subTitle.TextColor3 = Color3.fromRGB(186, 186, 186)
subTitle.Text = "Set a duration, order your priority list, and let the mine run online or offline."
subTitle.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -16, 0, 16)
closeBtn.Size = UDim2.fromOffset(32, 32)
closeBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 46)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
closeBtn.Text = "X"
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)

local summary = Instance.new("TextLabel")
summary.BackgroundTransparency = 1
summary.Position = UDim2.fromOffset(20, 78)
summary.Size = UDim2.new(1, -40, 0, 68)
summary.Font = Enum.Font.Gotham
summary.TextSize = 12
summary.TextWrapped = true
summary.TextXAlignment = Enum.TextXAlignment.Left
summary.TextYAlignment = Enum.TextYAlignment.Top
summary.TextColor3 = Color3.fromRGB(220, 220, 220)
summary.Text = "Silver: 0\nMine Resources:\n-"
summary.Parent = panel

local durationTitle = Instance.new("TextLabel")
durationTitle.BackgroundTransparency = 1
durationTitle.Position = UDim2.fromOffset(20, 158)
durationTitle.Size = UDim2.fromOffset(240, 20)
durationTitle.Font = Enum.Font.GothamBold
durationTitle.TextSize = 14
durationTitle.TextXAlignment = Enum.TextXAlignment.Left
durationTitle.TextColor3 = Color3.fromRGB(238, 238, 238)
durationTitle.Text = "Mining Duration"
durationTitle.Parent = panel

local durationBar = Instance.new("Frame")
durationBar.Position = UDim2.fromOffset(20, 186)
durationBar.Size = UDim2.fromOffset(820, 46)
durationBar.BackgroundTransparency = 1
durationBar.Parent = panel

local durationLayout = Instance.new("UIListLayout")
durationLayout.FillDirection = Enum.FillDirection.Horizontal
durationLayout.Padding = UDim.new(0, 8)
durationLayout.Parent = durationBar

local priorityTitle = Instance.new("TextLabel")
priorityTitle.BackgroundTransparency = 1
priorityTitle.Position = UDim2.fromOffset(20, 246)
priorityTitle.Size = UDim2.fromOffset(240, 20)
priorityTitle.Font = Enum.Font.GothamBold
priorityTitle.TextSize = 14
priorityTitle.TextXAlignment = Enum.TextXAlignment.Left
priorityTitle.TextColor3 = Color3.fromRGB(238, 238, 238)
priorityTitle.Text = "Priority Order"
priorityTitle.Parent = panel

local priorityListFrame = Instance.new("ScrollingFrame")
priorityListFrame.Position = UDim2.fromOffset(20, 274)
priorityListFrame.Size = UDim2.fromOffset(420, 220)
priorityListFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
priorityListFrame.BorderSizePixel = 0
priorityListFrame.ScrollBarThickness = 6
priorityListFrame.Parent = panel
Instance.new("UICorner", priorityListFrame).CornerRadius = UDim.new(0, 14)

local priorityLayout = Instance.new("UIListLayout")
priorityLayout.Padding = UDim.new(0, 8)
priorityLayout.Parent = priorityListFrame

local sessionTitle = Instance.new("TextLabel")
sessionTitle.BackgroundTransparency = 1
sessionTitle.Position = UDim2.fromOffset(460, 246)
sessionTitle.Size = UDim2.fromOffset(240, 20)
sessionTitle.Font = Enum.Font.GothamBold
sessionTitle.TextSize = 14
sessionTitle.TextXAlignment = Enum.TextXAlignment.Left
sessionTitle.TextColor3 = Color3.fromRGB(238, 238, 238)
sessionTitle.Text = "Current Session"
sessionTitle.Parent = panel

local sessionBody = Instance.new("TextLabel")
sessionBody.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
sessionBody.Position = UDim2.fromOffset(460, 274)
sessionBody.Size = UDim2.fromOffset(380, 220)
sessionBody.BorderSizePixel = 0
sessionBody.Font = Enum.Font.Gotham
sessionBody.TextSize = 12
sessionBody.TextWrapped = true
sessionBody.TextXAlignment = Enum.TextXAlignment.Left
sessionBody.TextYAlignment = Enum.TextYAlignment.Top
sessionBody.TextColor3 = Color3.fromRGB(220, 220, 220)
sessionBody.Text = "No active mining session."
sessionBody.Parent = panel
Instance.new("UICorner", sessionBody).CornerRadius = UDim.new(0, 14)

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(20, 506)
statusLabel.Size = UDim2.new(1, -40, 0, 18)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
statusLabel.Text = ""
statusLabel.Parent = panel

local startBtn = Instance.new("TextButton")
startBtn.Position = UDim2.fromOffset(460, 506)
startBtn.Size = UDim2.fromOffset(180, 36)
startBtn.BackgroundColor3 = Color3.fromRGB(66, 92, 148)
startBtn.BorderSizePixel = 0
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Text = "Start Mining"
startBtn.Parent = panel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 12)

local stopBtn = Instance.new("TextButton")
stopBtn.Position = UDim2.fromOffset(660, 506)
stopBtn.Size = UDim2.fromOffset(180, 36)
stopBtn.BackgroundColor3 = Color3.fromRGB(42, 44, 54)
stopBtn.BorderSizePixel = 0
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 13
stopBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
stopBtn.Text = "Stop and Claim"
stopBtn.Parent = panel
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 12)

local snapshot = nil
local durationButtons = {}
local selectedDuration = 600
local priorityList = {}

local function setButtonState(button, enabled, text)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = enabled and Color3.fromRGB(66, 92, 148) or Color3.fromRGB(42, 44, 54)
	button.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
	button.Text = text
end

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds >= 3600 then
		local hours = seconds / 3600
		if hours == math.floor(hours) then
			return string.format("%dh", hours)
		end
		return string.format("%.1fh", hours)
	end
	return string.format("%dm", math.floor(seconds / 60))
end

local function buildDurationButtons(options)
	for _, button in pairs(durationButtons) do
		button:Destroy()
	end
	durationButtons = {}

	for _, durationSec in ipairs(options or {}) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(90, 42)
		button.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.TextColor3 = Color3.fromRGB(228, 228, 228)
		button.Text = formatDuration(durationSec)
		button.Parent = durationBar
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)

		button.MouseButton1Click:Connect(function()
			selectedDuration = durationSec
			for otherDuration, otherButton in pairs(durationButtons) do
				local active = otherDuration == selectedDuration
				otherButton.BackgroundColor3 = active and Color3.fromRGB(66, 92, 148) or Color3.fromRGB(32, 34, 42)
				otherButton.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(228, 228, 228)
			end
		end)
		durationButtons[durationSec] = button
	end

	if not durationButtons[selectedDuration] then
		for _, durationSec in ipairs(options or {}) do
			selectedDuration = durationSec
			break
		end
	end
	for durationSec, button in pairs(durationButtons) do
		local active = durationSec == selectedDuration
		button.BackgroundColor3 = active and Color3.fromRGB(66, 92, 148) or Color3.fromRGB(32, 34, 42)
		button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(228, 228, 228)
	end
end

local function formatResourceList(list)
	if typeof(list) ~= "table" or #list == 0 then
		return "-"
	end
	local parts = {}
	for index, entry in ipairs(list) do
		parts[index] = string.format("%s x%d", tostring(entry.id), tonumber(entry.amount) or 0)
	end
	return table.concat(parts, ", ")
end

local function rebuildPriorityList()
	for _, child in ipairs(priorityListFrame:GetChildren()) do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	for index, resourceId in ipairs(priorityList) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -16, 0, 46)
		row.Position = UDim2.fromOffset(8, 0)
		row.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
		row.BorderSizePixel = 0
		row.Parent = priorityListFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(12, 12)
		label.Size = UDim2.new(1, -120, 0, 22)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(236, 236, 236)
		label.Text = string.format("%d. %s", index, resourceId)
		label.Parent = row

		local upBtn = Instance.new("TextButton")
		upBtn.Position = UDim2.new(1, -88, 0, 8)
		upBtn.Size = UDim2.fromOffset(34, 30)
		upBtn.BackgroundColor3 = Color3.fromRGB(48, 50, 58)
		upBtn.BorderSizePixel = 0
		upBtn.Font = Enum.Font.GothamBold
		upBtn.TextSize = 12
		upBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
		upBtn.Text = "Up"
		upBtn.Parent = row
		Instance.new("UICorner", upBtn).CornerRadius = UDim.new(0, 10)

		local downBtn = Instance.new("TextButton")
		downBtn.Position = UDim2.new(1, -46, 0, 8)
		downBtn.Size = UDim2.fromOffset(34, 30)
		downBtn.BackgroundColor3 = Color3.fromRGB(48, 50, 58)
		downBtn.BorderSizePixel = 0
		downBtn.Font = Enum.Font.GothamBold
		downBtn.TextSize = 12
		downBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
		downBtn.Text = "Dn"
		downBtn.Parent = row
		Instance.new("UICorner", downBtn).CornerRadius = UDim.new(0, 10)

		upBtn.MouseButton1Click:Connect(function()
			if index <= 1 then
				return
			end
			priorityList[index], priorityList[index - 1] = priorityList[index - 1], priorityList[index]
			rebuildPriorityList()
		end)

		downBtn.MouseButton1Click:Connect(function()
			if index >= #priorityList then
				return
			end
			priorityList[index], priorityList[index + 1] = priorityList[index + 1], priorityList[index]
			rebuildPriorityList()
		end)
	end

	task.defer(function()
		priorityListFrame.CanvasSize = UDim2.fromOffset(0, priorityLayout.AbsoluteContentSize.Y + 16)
	end)
end

local function refresh()
	if not snapshot then
		summary.Text = "Silver: 0\nMine Resources:\n-"
		sessionBody.Text = "No active mining session."
		setButtonState(startBtn, false, "Start Mining")
		setButtonState(stopBtn, false, "Stop and Claim")
		return
	end

	summary.Text = string.format(
		"Silver: %d\nMine Resources:\n%s",
		tonumber(snapshot.silver) or 0,
		formatResourceList(snapshot.mineResources)
	)

	local session = snapshot.session or {}
	if session.active then
		sessionBody.Text = table.concat({
			string.format("Status: Active"),
			string.format("Duration: %s", formatDuration(session.durationSec)),
			string.format("Elapsed: %s", formatDuration(session.elapsedSec)),
			string.format("Remaining: %s", formatDuration(session.remainingSec)),
			string.format("Ends At: %s", os.date("%Y-%m-%d %H:%M:%S", tonumber(session.endsAt) or os.time())),
			"",
			"Priority:",
			table.concat(session.priority or {}, ", "),
		}, "\n")
	else
		sessionBody.Text = "No active mining session."
		if session.recentClaim and #session.recentClaim > 0 then
			sessionBody.Text = sessionBody.Text .. "\n\nLast Claim:\n" .. formatResourceList(session.recentClaim)
		end
	end

	setButtonState(startBtn, session.active ~= true, "Start Mining")
	setButtonState(stopBtn, session.active == true, "Stop and Claim")
end

local function openUI()
	gui.Enabled = true
	MineAction:FireServer({ type = "request" })
end

local function closeUI()
	gui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(closeUI)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)

startBtn.MouseButton1Click:Connect(function()
	if not snapshot then
		return
	end
	MineAction:FireServer({
		type = "start",
		durationSec = selectedDuration,
		priority = priorityList,
	})
end)

stopBtn.MouseButton1Click:Connect(function()
	MineAction:FireServer({ type = "stop" })
end)

local function isMinePrompt(prompt)
	local current = prompt and prompt.Parent
	while current do
		if current.Name == "LobbyMine" then
			return true
		end
		current = current.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, localPlayer)
	if localPlayer ~= player or gui.Enabled then
		return
	end
	if isMinePrompt(prompt) then
		openUI()
	end
end)

OpenMineUI.OnClientEvent:Connect(function()
	if not gui.Enabled then
		openUI()
	end
end)

MineSync.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	snapshot = data
	if data.durationOptions then
		selectedDuration = tonumber(selectedDuration) or 600
		if data.session and data.session.active then
			selectedDuration = tonumber(data.session.durationSec) or selectedDuration
		end
		buildDurationButtons(data.durationOptions)
	end
	if data.session and data.session.active then
		priorityList = data.session.priority or priorityList
	else
		priorityList = data.defaultPriority or priorityList
	end
	rebuildPriorityList()
	if data.lastResult then
		if data.lastResult.ok == true then
			statusLabel.Text = "Action completed."
			statusLabel.TextColor3 = Color3.fromRGB(156, 220, 170)
		else
			statusLabel.Text = "Action failed: " .. tostring(data.lastResult.reason or "Unknown")
			statusLabel.TextColor3 = Color3.fromRGB(232, 144, 144)
		end
	else
		statusLabel.Text = ""
		statusLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
	end
	refresh()
end)
