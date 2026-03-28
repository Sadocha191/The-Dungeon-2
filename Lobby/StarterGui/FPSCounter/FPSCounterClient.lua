local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent
local frame = gui:WaitForChild("Frame")
local fpsLabel = frame:WaitForChild("FPS")

if playerGui:GetAttribute("ShowFPSCounter") == nil then
	playerGui:SetAttribute("ShowFPSCounter", false)
end

gui.Enabled = playerGui:GetAttribute("ShowFPSCounter") == true

local function applyVisibility()
	gui.Enabled = playerGui:GetAttribute("ShowFPSCounter") == true
end

local function setVisible(enabled: boolean)
	playerGui:SetAttribute("ShowFPSCounter", enabled)
end

local lastScreenButtonsNonce = nil
local function handleScreenButtonsRequest()
	local nonce = gui:GetAttribute("ScreenButtonsNonce")
	if nonce == nil or nonce == lastScreenButtonsNonce then
		return
	end

	lastScreenButtonsNonce = nonce
	local action = gui:GetAttribute("ScreenButtonsAction")
	if action == "open" then
		setVisible(true)
	elseif action == "close" then
		setVisible(false)
	elseif action == "toggle" then
		setVisible(not (playerGui:GetAttribute("ShowFPSCounter") == true))
	end
end

playerGui:GetAttributeChangedSignal("ShowFPSCounter"):Connect(applyVisibility)
gui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(handleScreenButtonsRequest)
handleScreenButtonsRequest()
applyVisibility()

local sampleTime = 0
local sampleFrames = 0

RunService.RenderStepped:Connect(function(dt)
	sampleTime += dt
	sampleFrames += 1

	if sampleTime < 0.35 then
		return
	end

	local fps = math.max(1, math.floor((sampleFrames / sampleTime) + 0.5))
	sampleTime = 0
	sampleFrames = 0

	fpsLabel.Text = tostring(fps)
end)
