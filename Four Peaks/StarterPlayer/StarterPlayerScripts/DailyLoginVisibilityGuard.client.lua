-- DailyLoginVisibilityGuard.client.lua
-- Replaces the visible Daily Login CanvasGroup with a regular Frame at runtime.
-- CanvasGroup can render as a solid black texture on some devices even when its
-- GroupTransparency and GroupColor3 values are correct. The original CanvasGroup
-- is kept invisible so DailyLoginClient's existing open/close tween can finish and
-- disable the ScreenGui without changing reward or button logic.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local processedGuis = setmetatable({}, { __mode = "k" })
local connectedGuis = setmetatable({}, { __mode = "k" })

local function copyPanelProperties(source, target)
	target.AnchorPoint = source.AnchorPoint
	target.Position = source.Position
	target.Size = source.Size
	target.AutomaticSize = source.AutomaticSize
	target.BackgroundColor3 = source.BackgroundColor3
	target.BackgroundTransparency = source.BackgroundTransparency
	target.BorderColor3 = source.BorderColor3
	target.BorderMode = source.BorderMode
	target.BorderSizePixel = source.BorderSizePixel
	target.ClipsDescendants = source.ClipsDescendants
	target.LayoutOrder = source.LayoutOrder
	target.Rotation = source.Rotation
	target.Visible = source.Visible
	target.ZIndex = source.ZIndex
	target.Active = source.Active
	target.Selectable = source.Selectable
	target.SelectionOrder = source.SelectionOrder
end

local function tryReplaceCanvasGroup(gui)
	if processedGuis[gui] or gui.Parent ~= playerGui then
		return
	end

	local overlay = gui:FindFirstChild("Overlay")
	local panel = overlay and overlay:FindFirstChild("Panel")
	if not panel then
		return
	end

	if panel:IsA("Frame") then
		processedGuis[gui] = true
		return
	end
	if not panel:IsA("CanvasGroup") then
		return
	end

	-- Wait until the generated UI is complete enough that DailyLoginClient will no
	-- longer add direct children to the panel. References and event connections on
	-- moved descendants remain valid after reparenting.
	local footer = panel:FindFirstChild("Footer")
	local claimButton = footer and footer:FindFirstChild("Claim")
	if not claimButton then
		return
	end

	local replacement = Instance.new("Frame")
	replacement.Name = "Panel"
	copyPanelProperties(panel, replacement)
	replacement:SetAttribute("CanvasGroupWorkaround", true)

	-- Move styling objects, UIScale, cards, labels, and buttons before parenting the
	-- replacement into PlayerGui. This also prevents the responsive policy from
	-- briefly creating a duplicate UIScale.
	for _, child in ipairs(panel:GetChildren()) do
		child.Parent = replacement
	end

	panel.Name = "LegacyPanelCanvasGroup"
	panel.Visible = false
	panel.Active = false
	panel.BackgroundTransparency = 1

	replacement.Parent = overlay
	processedGuis[gui] = true
end

local function scheduleReplacement(gui)
	task.defer(function()
		tryReplaceCanvasGroup(gui)
	end)
end

local function connectDailyLoginGui(gui)
	if not gui:IsA("ScreenGui") or gui.Name ~= "DailyLoginGui" or connectedGuis[gui] then
		return
	end

	connectedGuis[gui] = true

	gui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Panel" or descendant.Name == "Footer" or descendant.Name == "Claim" then
			scheduleReplacement(gui)
		end
	end)

	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			scheduleReplacement(gui)
		end
	end)

	scheduleReplacement(gui)
end

for _, child in ipairs(playerGui:GetChildren()) do
	connectDailyLoginGui(child)
end

playerGui.ChildAdded:Connect(connectDailyLoginGui)
