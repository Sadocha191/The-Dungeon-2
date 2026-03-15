local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local moduleFolder = (
	ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
)

if not moduleFolder then
	warn("[PortalUIClient] ModuleScripts folder not found in ReplicatedStorage.")
	return
end

print("[PortalUIClient] Boot")

local player = Players.LocalPlayer
local screenGui = script:FindFirstAncestorOfClass("ScreenGui")

local function showScreenGuiLocally()
	if not screenGui then
		warn("[PortalUIClient] ScreenGui ancestor not found.")
		return
	end

	screenGui.Enabled = true
	screenGui:SetAttribute("Modal", true)

	local root = screenGui:FindFirstChild("UI")
	if root and root:IsA("GuiObject") then
		root.Visible = true
		if root:IsA("CanvasGroup") then
			root.GroupTransparency = 0
		end

		local background = root:FindFirstChild("Background")
		if background and background:IsA("GuiObject") then
			background.Visible = true
			if background:IsA("CanvasGroup") then
				background.GroupTransparency = 0
			end
		end

		print(string.format(
			"[PortalUIClient] Local show gui=%s root=%s root.Visible=%s root.AbsPos=(%d,%d) root.AbsSize=(%d,%d)",
			screenGui:GetFullName(),
			root:GetFullName(),
			tostring(root.Visible),
			root.AbsolutePosition.X,
			root.AbsolutePosition.Y,
			root.AbsoluteSize.X,
			root.AbsoluteSize.Y
		))
	else
		warn("[PortalUIClient] UI root not found under ScreenGui.")
	end
end

local ok, PortalUIController = pcall(function()
	return require(moduleFolder:WaitForChild("PortalUIController"))
end)

if not ok then
	warn("[PortalUIClient] Failed to load PortalUIController:", PortalUIController)
	return
end

PortalUIController.Start({
	gui = screenGui,
})

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
	if not PortalUIController.MatchesPortalPrompt(prompt, triggeredPlayer) then
		return
	end

	if typeof(triggeredPlayer) == "Instance" and triggeredPlayer:IsA("Player") and triggeredPlayer ~= player then
		return
	end

	print("[PortalUIClient] Opening from local portal prompt:", prompt:GetFullName())
	showScreenGuiLocally()
	PortalUIController.Open()
end)
