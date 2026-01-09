-- SCRIPT: DialogueUI.lua
-- GDZIE: StarterPlayerScripts/DialogueUI.lua
-- CO: UI dialogów tutorialu (klient), wysyła DialogueFinishedEvent po zakończeniu

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local OpenDialogueEvent = remotesFolder:WaitForChild("OpenDialogueEvent")
local DialogueFinishedEvent = remotesFolder:WaitForChild("DialogueFinishedEvent")

-- TODO: Podłącz tu źródło dialogów (np. ReplicatedStorage/ModuleScripts/DialogueData)
local function getDialogueLines(dialogueKey: string): {string}
	local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	local sourceModule = moduleFolder and moduleFolder:FindFirstChild("DialogueData")
	if sourceModule and sourceModule:IsA("ModuleScript") then
		local ok, data = pcall(require, sourceModule)
		if ok and typeof(data) == "table" then
			local lines = data[dialogueKey]
			if typeof(lines) == "table" then
				return lines
			end
		end
	end
	return { ("[Dialogue missing: %s]"):format(dialogueKey) }
end

local gui = Instance.new("ScreenGui")
gui.Name = "DialogueUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0.6, 0, 0.3, 0)
frame.Position = UDim2.new(0.2, 0, 0.6, 0)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
frame.BackgroundTransparency = 0.2
frame.Parent = gui

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(1, -24, 1, -70)
textLabel.Position = UDim2.new(0, 12, 0, 12)
textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
textLabel.TextWrapped = true
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextYAlignment = Enum.TextYAlignment.Top
textLabel.Font = Enum.Font.Gotham
textLabel.TextSize = 18
textLabel.BackgroundTransparency = 1
textLabel.Parent = frame

local nextButton = Instance.new("TextButton")
nextButton.Size = UDim2.new(0, 140, 0, 36)
nextButton.Position = UDim2.new(1, -160, 1, -48)
nextButton.Text = "Next"
nextButton.Font = Enum.Font.GothamBold
nextButton.TextSize = 16
nextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
nextButton.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
nextButton.Parent = frame

local currentKey = ""
local lines: {string} = {}
local lineIndex = 1

local function showLine()
	local line = lines[lineIndex] or ""
	textLabel.Text = line
	if lineIndex >= #lines then
		nextButton.Text = "Finish"
	else
		nextButton.Text = "Next"
	end
end

local function openDialogue(dialogueKey: string)
	currentKey = dialogueKey
	lines = getDialogueLines(dialogueKey)
	lineIndex = 1
	showLine()
	gui.Enabled = true
end

local function finishDialogue()
	gui.Enabled = false
	if currentKey ~= "" then
		DialogueFinishedEvent:FireServer(currentKey)
	end
	currentKey = ""
	lines = {}
	lineIndex = 1
end

nextButton.MouseButton1Click:Connect(function()
	if lineIndex < #lines then
		lineIndex += 1
		showLine()
	else
		finishDialogue()
	end
end)

OpenDialogueEvent.OnClientEvent:Connect(function(dialogueKey: string)
	if typeof(dialogueKey) ~= "string" or dialogueKey == "" then return end
	openDialogue(dialogueKey)
end)
