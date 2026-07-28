-- DailyLoginVisibilityGuard.client.lua
-- Keeps the daily login CanvasGroup fully visible while its opening tween settles.
-- Some clients can leave the group close to fully transparent or dark-tinted when
-- the CanvasGroup tween is throttled/interrupted.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OPEN_GUARD_DURATION_SECONDS = 1
local WHITE = Color3.new(1, 1, 1)

local connectedGuis = setmetatable({}, { __mode = "k" })
local guardGenerations = setmetatable({}, { __mode = "k" })

local function findPanel(gui)
	local overlay = gui:FindFirstChild("Overlay")
	local panel = overlay and overlay:FindFirstChild("Panel")
	if panel and panel:IsA("CanvasGroup") then
		return panel
	end
	return nil
end

local function restorePanelVisibility(gui)
	if not gui.Enabled then
		return
	end

	local panel = findPanel(gui)
	if not panel then
		return
	end

	-- GroupTransparency affects every descendant. GroupColor3 also multiplies every
	-- descendant color, so a stale dark value makes the whole panel appear black.
	panel.GroupTransparency = 0
	panel.GroupColor3 = WHITE
end

local function cancelOpeningGuard(gui)
	guardGenerations[gui] = (guardGenerations[gui] or 0) + 1
end

local function guardOpening(gui)
	cancelOpeningGuard(gui)
	local generation = guardGenerations[gui]

	task.spawn(function()
		local deadline = os.clock() + OPEN_GUARD_DURATION_SECONDS
		repeat
			if guardGenerations[gui] ~= generation then
				return
			end
			if gui.Parent ~= playerGui or not gui.Enabled then
				return
			end

			restorePanelVisibility(gui)
			RunService.RenderStepped:Wait()
		until os.clock() >= deadline

		if guardGenerations[gui] == generation and gui.Parent == playerGui and gui.Enabled then
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
			guardOpening(gui)
		else
			cancelOpeningGuard(gui)
		end
	end)

	gui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Panel" and descendant:IsA("CanvasGroup") and gui.Enabled then
			guardOpening(gui)
		end
	end)

	gui.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			cancelOpeningGuard(gui)
		end
	end)

	if gui.Enabled then
		guardOpening(gui)
	end
end

for _, child in ipairs(playerGui:GetChildren()) do
	connectDailyLoginGui(child)
end

playerGui.ChildAdded:Connect(connectDailyLoginGui)
