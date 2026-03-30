local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent
local frame = gui:WaitForChild("Frame")
local fpsLabel = frame:WaitForChild("FPS")
local FPS_TELEPORT_SETTING = "ShowFPSCounter"

local function getPersistedVisibility(): boolean
	local ok, value = pcall(function()
		return TeleportService:GetTeleportSetting(FPS_TELEPORT_SETTING)
	end)

	if ok and type(value) == "boolean" then
		return value
	end

	return false
end

local function persistVisibility(enabled: boolean)
	pcall(function()
		TeleportService:SetTeleportSetting(FPS_TELEPORT_SETTING, enabled)
	end)
end

if playerGui:GetAttribute("ShowFPSCounter") == nil then
	playerGui:SetAttribute("ShowFPSCounter", getPersistedVisibility())
end

gui.Enabled = playerGui:GetAttribute("ShowFPSCounter") == true

local function applyVisibility()
	local enabled = playerGui:GetAttribute("ShowFPSCounter") == true
	gui.Enabled = enabled
	persistVisibility(enabled)
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
