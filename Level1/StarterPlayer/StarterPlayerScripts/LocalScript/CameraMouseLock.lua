-- StarterPlayerScripts/OrbitCamera_WithLag.client.lua

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local upgradesGui = playerGui:WaitForChild("UpgradesGUI")
local main = upgradesGui:WaitForChild("Main")

-- Any ScreenGui with attribute Modal=true should unlock the mouse (menus, game over, etc.)
local function anyModalGuiOpen(): boolean
	for _, ch in ipairs(playerGui:GetChildren()) do
		if ch:IsA("ScreenGui") and ch.Enabled then
			if ch:GetAttribute("Modal") == true then
				return true
			end
			-- fallback for known modals that may not set the attribute
			local n = ch.Name
			if n == "MissionSummary" or n == "EscMenu" or n == "EKeyMenu" then
				return true
			end
		end
	end
	return false
end

local cam = Workspace.CurrentCamera

-- USTAWIENIA
local DISTANCE = 20
local HEIGHT = 2.5
local SENSITIVITY = 0.0022
local LAG_SPEED = 7

-- ograniczenia patrzenia (to blokuje “pod mapę”)
local MIN_PITCH = math.rad(-35)  -- max w dół (mniej ujemne = mniej w dół)
local MAX_PITCH = math.rad(70)   -- max w górę

-- kolizja kamery
local CAMERA_RADIUS = 0.6
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local targetYaw, targetPitch = 0, 0
local yaw, pitch = 0, 0
local frozenCFrame

local function getHRP()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function setGameplayInput()
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	UIS.MouseIconEnabled = false
end

local function setUiInput()
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	UIS.MouseIconEnabled = true
end

local function orbitStep(dt)
	-- If any modal UI is open (upgrades, game over, esc menu), free the cursor and freeze camera.
	if main.Visible or anyModalGuiOpen() then
		if not frozenCFrame then frozenCFrame = cam.CFrame end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = frozenCFrame
		setUiInput()
		return
	end

	frozenCFrame = nil
	cam.CameraType = Enum.CameraType.Scriptable
	setGameplayInput()

	local hrp = getHRP()
	if not hrp then return end

	-- raycast ignoruje postać
	rayParams.FilterDescendantsInstances = { player.Character }

	local delta = UIS:GetMouseDelta()
	targetYaw -= delta.X * SENSITIVITY

	-- FIX: bez inverta (góra = patrzy w górę)
	targetPitch = math.clamp(targetPitch + delta.Y * SENSITIVITY, MIN_PITCH, MAX_PITCH)

	local a = 1 - math.exp(-LAG_SPEED * dt)
	yaw += (targetYaw - yaw) * a
	pitch += (targetPitch - pitch) * a

	local focusPos = hrp.Position + Vector3.new(0, HEIGHT, 0)

	local rot = CFrame.new(focusPos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local desiredPos = (rot * CFrame.new(0, 0, -DISTANCE)).Position

	-- Kolizja: przytnij dystans jeśli coś jest między graczem a kamerą
	local dir = desiredPos - focusPos
	local dist = dir.Magnitude
	if dist > 0.001 then
		local result = Workspace:Raycast(focusPos, dir, rayParams)
		if result then
			-- cofnij kamerę trochę od przeszkody
			local hitDist = (result.Position - focusPos).Magnitude
			local safeDist = math.max(2, hitDist - CAMERA_RADIUS)
			desiredPos = focusPos + dir.Unit * safeDist
		end
	end

	cam.CFrame = CFrame.new(desiredPos, focusPos)
end

RunService:UnbindFromRenderStep("OrbitCam")
RunService:BindToRenderStep("OrbitCam", Enum.RenderPriority.Camera.Value + 1, orbitStep)