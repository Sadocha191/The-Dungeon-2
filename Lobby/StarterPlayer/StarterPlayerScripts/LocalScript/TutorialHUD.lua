-- SCRIPT: TutorialHUD.lua
-- GDZIE: StarterPlayerScripts/TutorialHUD.lua
-- CO: wizualne prowadzenie do celu tutorialu (beam + tekst + przycisk Show Path)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local TutorialTargetEvent = remotesFolder:WaitForChild("TutorialTargetEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 90)
frame.Position = UDim2.new(0, 20, 1, -110)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.2
frame.Parent = gui

local objectiveLabel = Instance.new("TextLabel")
objectiveLabel.Size = UDim2.new(1, -20, 0, 40)
objectiveLabel.Position = UDim2.new(0, 10, 0, 8)
objectiveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left
objectiveLabel.TextYAlignment = Enum.TextYAlignment.Center
objectiveLabel.Text = ""
objectiveLabel.Font = Enum.Font.GothamBold
objectiveLabel.TextSize = 16
objectiveLabel.BackgroundTransparency = 1
objectiveLabel.Parent = frame

local showPathButton = Instance.new("TextButton")
showPathButton.Size = UDim2.new(0, 120, 0, 28)
showPathButton.Position = UDim2.new(0, 10, 1, -36)
showPathButton.Text = "Show Path"
showPathButton.Font = Enum.Font.GothamSemibold
showPathButton.TextSize = 14
showPathButton.TextColor3 = Color3.fromRGB(255, 255, 255)
showPathButton.BackgroundColor3 = Color3.fromRGB(60, 110, 180)
showPathButton.Parent = frame

local guideState = {
	targetPos = nil :: Vector3?,
	objective = "",
	targetPart = nil :: BasePart?,
	beam = nil :: Beam?,
	originAttachment = nil :: Attachment?,
	targetAttachment = nil :: Attachment?,
}

local function clearGuide()
	if guideState.beam then
		guideState.beam:Destroy()
		guideState.beam = nil
	end
	if guideState.originAttachment then
		guideState.originAttachment:Destroy()
		guideState.originAttachment = nil
	end
	if guideState.targetAttachment then
		guideState.targetAttachment:Destroy()
		guideState.targetAttachment = nil
	end
	if guideState.targetPart then
		guideState.targetPart:Destroy()
		guideState.targetPart = nil
	end
end

local function ensureCharacterRoot(): BasePart?
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("HumanoidRootPart", 5)
end

local function renderGuide()
	clearGuide()

	if not guideState.targetPos then
		return
	end

	local root = ensureCharacterRoot()
	if not root then
		return
	end

	local targetPart = Instance.new("Part")
	targetPart.Name = "TutorialTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.new(1, 1, 1)
	targetPart.CFrame = CFrame.new(guideState.targetPos)
	targetPart.Parent = workspace

	local originAttachment = Instance.new("Attachment")
	originAttachment.Name = "TutorialOriginAttachment"
	originAttachment.Parent = root

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TutorialTargetAttachment"
	targetAttachment.Parent = targetPart

	local beam = Instance.new("Beam")
	beam.Attachment0 = originAttachment
	beam.Attachment1 = targetAttachment
	beam.FaceCamera = true
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	beam.LightEmission = 0.6
	beam.Parent = root

	guideState.targetPart = targetPart
	guideState.originAttachment = originAttachment
	guideState.targetAttachment = targetAttachment
	guideState.beam = beam
end

showPathButton.MouseButton1Click:Connect(function()
	renderGuide()
end)

TutorialTargetEvent.OnClientEvent:Connect(function(targetPos: Vector3?, objectiveText: string?)
	if typeof(targetPos) == "Vector3" then
		guideState.targetPos = targetPos
	else
		guideState.targetPos = nil
	end
	guideState.objective = objectiveText or ""
	objectiveLabel.Text = guideState.objective
	frame.Visible = guideState.objective ~= ""
	renderGuide()
end)

player.CharacterAdded:Connect(function()
	if guideState.targetPos then
		task.defer(renderGuide)
	end
end)
