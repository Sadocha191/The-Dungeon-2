-- SCRIPT: DialogueUI.lua
-- GDZIE: StarterPlayerScripts/DialogueUI.lua
-- CO: UI dialogów tutorialu (klient), auto-dopasowanie wysokości do tekstu
--     + wysyła DialogueFinishedEvent po zakończeniu

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local OpenDialogueEvent = remotesFolder:WaitForChild("OpenDialogueEvent")
local DialogueFinishedEvent = remotesFolder:WaitForChild("DialogueFinishedEvent")

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

-- ===== Main frame =====
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 0.93, 0) -- przy dole
frame.Size = UDim2.new(0.62, 0, 0, 220) -- Y liczone dynamicznie
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Color = Color3.fromRGB(60, 60, 70)
stroke.Transparency = 0.2
stroke.Parent = frame

-- ===== Layout constants =====
local PAD = 14
local BTN_H = 36
local BTN_W = 140
local BTN_MARGIN_BOTTOM = 14
local GAP_TEXT_TO_BTN = 14

local MIN_H = 140
local MAX_H = 420

-- ===== Text =====
local textLabel = Instance.new("TextLabel")
textLabel.BackgroundTransparency = 1
textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
textLabel.TextWrapped = true
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextYAlignment = Enum.TextYAlignment.Top
textLabel.Font = Enum.Font.Gotham
textLabel.TextSize = 18
textLabel.RichText = true
textLabel.Parent = frame

-- ===== Button =====
local nextButton = Instance.new("TextButton")
nextButton.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
nextButton.BorderSizePixel = 0
nextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
nextButton.Font = Enum.Font.GothamBold
nextButton.TextSize = 16
nextButton.Text = "Next"
nextButton.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent = nextButton

-- ===== State =====
local currentKey = ""
local lines: {string} = {}
local lineIndex = 1

local function getViewportSize()
	local cam = workspace.CurrentCamera
	if cam then
		return cam.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function layoutForCurrentFrameSize()
	-- Ustaw pozycje elementów na podstawie obecnej wysokości frame
	local frameAbsW = frame.AbsoluteSize.X
	local contentW = math.max(200, frameAbsW - (PAD * 2))

	nextButton.Size = UDim2.new(0, BTN_W, 0, BTN_H)
	nextButton.Position = UDim2.new(1, -(PAD + BTN_W), 1, -(BTN_MARGIN_BOTTOM + BTN_H))

	-- Tekst ma zostawić miejsce na button
	local textTop = PAD
	local textBottomReserve = BTN_MARGIN_BOTTOM + BTN_H + GAP_TEXT_TO_BTN + PAD
	textLabel.Position = UDim2.new(0, PAD, 0, textTop)
	textLabel.Size = UDim2.new(1, -(PAD * 2), 1, -(textTop + textBottomReserve))
end

local function computeTextHeightPx(text: string, widthPx: number): number
	local size = TextService:GetTextSize(
		text,
		textLabel.TextSize,
		textLabel.Font,
		Vector2.new(widthPx, 10_000)
	)
	return math.ceil(size.Y)
end

local function resizeToText(text: string)
	local vp = getViewportSize()

	-- szerokość w px liczona z Size.X scale
	local widthPx = math.floor(vp.X * 0.62) - (PAD * 2)
	if widthPx < 240 then widthPx = 240 end

	local textH = computeTextHeightPx(text, widthPx)

	-- frame height = tekst + padding + miejsce na button
	local desired =
		PAD -- top
		+ textH
		+ GAP_TEXT_TO_BTN
		+ BTN_H
		+ BTN_MARGIN_BOTTOM
		+ PAD -- bottom

	-- clamp + zależność od ekranu (żeby nie zasłaniało)
	local maxByScreen = math.floor(vp.Y * 0.55)
	local maxH = math.min(MAX_H, maxByScreen)

	local h = math.clamp(desired, MIN_H, maxH)
	frame.Size = UDim2.new(0.62, 0, 0, h)

	layoutForCurrentFrameSize()
end

local function showLine()
	local line = lines[lineIndex] or ""
	textLabel.Text = line

	if lineIndex >= #lines then
		nextButton.Text = "Finish"
	else
		nextButton.Text = "Next"
	end

	resizeToText(line)
end

local function openDialogue(dialogueKey: string)
	currentKey = dialogueKey
	lines = getDialogueLines(dialogueKey)
	lineIndex = 1
	gui.Enabled = true
	showLine()
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

-- Przelicz, gdy gracz zmieni rozmiar okna (Studio / różne rozdzielczości)
task.defer(function()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if gui.Enabled and typeof(lines) == "table" then
				local line = lines[lineIndex] or ""
				resizeToText(line)
			end
		end)
	end
end)
