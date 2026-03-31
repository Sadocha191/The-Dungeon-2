local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent
local frame = gui:WaitForChild("Frame")
local fpsLabel = frame:WaitForChild("FPS")
local FPS_TELEPORT_SETTING = "ShowFPSCounter"
local debugSettings = ReplicatedStorage:FindFirstChild("DebugSettings")
local perfHudDefault = debugSettings and debugSettings:FindFirstChild("PerfHudEnabled")

local function getPersistedVisibility(): boolean
	local ok, value = pcall(function()
		return TeleportService:GetTeleportSetting(FPS_TELEPORT_SETTING)
	end)

	if ok and type(value) == "boolean" then
		return value
	end

	if perfHudDefault and perfHudDefault:IsA("BoolValue") then
		return perfHudDefault.Value == true
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

local function applyVisibility()
	local enabled = playerGui:GetAttribute("ShowFPSCounter") == true
	gui.Enabled = enabled
	persistVisibility(enabled)
end

playerGui:GetAttributeChangedSignal("ShowFPSCounter"):Connect(applyVisibility)
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
