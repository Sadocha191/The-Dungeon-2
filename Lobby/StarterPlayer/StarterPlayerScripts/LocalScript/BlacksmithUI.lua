-- BlacksmithUI.lua (LocalScript)
-- Otwiera UI kowala tylko po ukończeniu tutoriala.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local RF_GetTutorialState = remoteFunctions:WaitForChild("RF_GetTutorialState")

-- Zakładam, że już masz swój ScreenGui od kowala w PlayerGui albo tworzysz go w tym pliku.
-- Jeśli masz inną nazwę GUI, zmień tutaj:
local gui = playerGui:WaitForChild("BlacksmithGui")

local function tutorialComplete(): boolean
	local ok, t = pcall(function()
		return RF_GetTutorialState:InvokeServer()
	end)
	if not ok or typeof(t) ~= "table" then
		return false
	end
	return t.Complete == true
end

local function openUI()
	if not tutorialComplete() then
		return
	end
	gui.Enabled = true
end

local function closeUI()
	gui.Enabled = false
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)

local function isPromptInsideBlacksmith(prompt: ProximityPrompt): boolean
	local npcs = workspace:FindFirstChild("NPCs")
	local smith = npcs and (npcs:FindFirstChild("Blacksmith") or npcs:FindFirstChild("BlacksmithNPC"))
	if not smith then return false end

	local p = prompt and prompt.Parent
	while p do
		if p == smith then return true end
		p = p.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if isPromptInsideBlacksmith(prompt) then
		openUI()
	end
end)
