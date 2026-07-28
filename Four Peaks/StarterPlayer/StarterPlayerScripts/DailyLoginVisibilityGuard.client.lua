-- DailyLoginVisibilityGuard.client.lua
-- Prevents the daily login CanvasGroup from remaining partially transparent
-- when its opening tween is interrupted or never reaches its final value.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OPEN_TWEEN_DURATION = 0.2
local VISIBILITY_FALLBACK_DELAY = OPEN_TWEEN_DURATION + 0.05

local connectedGuis = setmetatable({}, { __mode = "k" })

local function restorePanelVisibility(gui)
	if not gui.Enabled then
		return
	end

	local overlay = gui:FindFirstChild("Overlay")
	local panel = overlay and overlay:FindFirstChild("Panel")
	if panel and panel:IsA("CanvasGroup") and panel.GroupTransparency > 0 then
		panel.GroupTransparency = 0
	end
end

local function scheduleVisibilityFallback(gui)
	task.delay(VISIBILITY_FALLBACK_DELAY, function()
		if gui.Parent == playerGui then
			restorePanelVisibility(gui)
		end
	end)
end

local function connectDailyLoginGui(gui)
	if not gui:IsA("ScreenGui") or gui.Name ~= "DailyLoginGui" or connectedGuis[gui] then
		return
	end

	connectedGuis[gui] = true

	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			scheduleVisibilityFallback(gui)
		end
	end)

	gui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Panel" and descendant:IsA("CanvasGroup") and gui.Enabled then
			scheduleVisibilityFallback(gui)
		end
	end)

	if gui.Enabled then
		scheduleVisibilityFallback(gui)
	end
end

for _, child in ipairs(playerGui:GetChildren()) do
	connectDailyLoginGui(child)
end

playerGui.ChildAdded:Connect(connectDailyLoginGui)
