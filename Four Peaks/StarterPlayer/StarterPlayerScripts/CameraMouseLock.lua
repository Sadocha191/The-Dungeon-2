local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CAMERA_DISTANCES = {
	Close = 12,
	Medium = 20,
	Far = 28,
}

local HEIGHT = 2.5
local MOUSE_SENSITIVITY = 0.0022
local TOUCH_SENSITIVITY = 0.0065
local LAG_SPEED = 7
local MIN_PITCH = math.rad(-35)
local MAX_PITCH = math.rad(70)
local CAMERA_RADIUS = 0.6

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local targetYaw = 0
local targetPitch = 0
local yaw = 0
local pitch = 0
local frozenCFrame: CFrame? = nil
local touchLookDelta = Vector2.zero
local lastTouchPanTranslation = Vector2.zero
local anglesInitialized = false
local movementLocked = false
local savedWalkSpeed = nil
local savedJumpPower = nil
local savedJumpHeight = nil

local function getHRP(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	return nil
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid
	end

	return nil
end

local function setGameplayInput()
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	UIS.MouseIconEnabled = false
end

local function setUiInput()
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	UIS.MouseIconEnabled = true
end

local function anyBlockingUiOpen()
	for _, inst in ipairs(playerGui:GetChildren()) do
		if inst:IsA("ScreenGui") and inst.Enabled then
			if inst:GetAttribute("Modal") == true then
				return true
			end

			if inst.Name == "PartyGui" then
				local overlay = inst:FindFirstChild("overlay")
				if overlay and overlay:IsA("GuiObject") and overlay.Visible then
					return true
				end
			end
		end
	end

	return false
end

local function shouldReleaseCursor(): boolean
	return anyBlockingUiOpen()
		or UIS:GetFocusedTextBox() ~= nil
		or UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
		or UIS:IsKeyDown(Enum.KeyCode.RightAlt)
end

local function applyHumanoidLock(humanoid: Humanoid?, locked: boolean)
	if not humanoid then
		return
	end
	if locked then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		if savedWalkSpeed ~= nil then
			humanoid.WalkSpeed = savedWalkSpeed
		end
		if savedJumpPower ~= nil then
			humanoid.JumpPower = savedJumpPower
		end
		if savedJumpHeight ~= nil then
			humanoid.JumpHeight = savedJumpHeight
		end
	end
end

local function setMovementLocked(locked: boolean)
	if locked then
		if movementLocked then
			applyHumanoidLock(getHumanoid(), true)
			return
		end
		movementLocked = true
		ContextActionService:BindActionAtPriority(
			"LobbyModalMovementLock",
			function()
				return Enum.ContextActionResult.Sink
			end,
			false,
			9999,
			Enum.PlayerActions.CharacterForward,
			Enum.PlayerActions.CharacterBackward,
			Enum.PlayerActions.CharacterLeft,
			Enum.PlayerActions.CharacterRight,
			Enum.PlayerActions.CharacterJump
		)

		local humanoid = getHumanoid()
		if humanoid then
			savedWalkSpeed = humanoid.WalkSpeed
			savedJumpPower = humanoid.JumpPower
			savedJumpHeight = humanoid.JumpHeight
			applyHumanoidLock(humanoid, true)
		end
		return
	end

	if not movementLocked then
		return
	end

	movementLocked = false
	ContextActionService:UnbindAction("LobbyModalMovementLock")
	applyHumanoidLock(getHumanoid(), false)
	savedWalkSpeed = nil
	savedJumpPower = nil
	savedJumpHeight = nil
end

local function getCameraDistance(): number
	local presetId = tostring(playerGui:GetAttribute("CameraZoomPreset") or "Medium")
	return CAMERA_DISTANCES[presetId] or CAMERA_DISTANCES.Medium
end

local function initializeAngles(hrp: BasePart)
	if anglesInitialized then
		return
	end

	local look = hrp.CFrame.LookVector
	local horizontalLook = Vector3.new(look.X, 0, look.Z)
	if horizontalLook.Magnitude > 0.001 then
		horizontalLook = horizontalLook.Unit
		targetYaw = math.atan2(horizontalLook.X, horizontalLook.Z)
	else
		targetYaw = 0
	end

	yaw = targetYaw
	targetPitch = 0
	pitch = 0
	anglesInitialized = true
end

UIS.TouchPan:Connect(function(touchPositions, totalTranslation, _velocity, state, gameProcessed)
	if gameProcessed or shouldReleaseCursor() then
		touchLookDelta = Vector2.zero
		lastTouchPanTranslation = Vector2.zero
		return
	end

	local camera = Workspace.CurrentCamera
	local viewportWidth = math.max(1, camera and camera.ViewportSize.X or 1)
	local controlsZone = viewportWidth * 0.35
	local shouldRotate = false

	for _, touchPos in ipairs(touchPositions or {}) do
		if typeof(touchPos) == "Vector2" and touchPos.X >= controlsZone then
			shouldRotate = true
			break
		end
	end

	if not shouldRotate then
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			lastTouchPanTranslation = Vector2.zero
		end
		return
	end

	if state == Enum.UserInputState.Begin then
		lastTouchPanTranslation = totalTranslation
		return
	end

	local delta = totalTranslation - lastTouchPanTranslation
	lastTouchPanTranslation = totalTranslation
	touchLookDelta += delta

	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		lastTouchPanTranslation = Vector2.zero
	end
end)

local function orbitStep(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		setMovementLocked(false)
		return
	end
	setMovementLocked(anyBlockingUiOpen())

	local hrp = getHRP()
	if not hrp then
		frozenCFrame = nil
		setMovementLocked(false)
		setUiInput()
		return
	end

	initializeAngles(hrp)

	camera.CameraType = Enum.CameraType.Scriptable

	if shouldReleaseCursor() then
		if not frozenCFrame then
			frozenCFrame = camera.CFrame
		end
		camera.CFrame = frozenCFrame
		setUiInput()
		return
	end

	frozenCFrame = nil
	setGameplayInput()

	rayParams.FilterDescendantsInstances = { player.Character }

	local mouseDelta = UIS:GetMouseDelta()
	local touchDelta = touchLookDelta
	touchLookDelta = Vector2.zero

	targetYaw -= mouseDelta.X * MOUSE_SENSITIVITY
	targetYaw -= touchDelta.X * TOUCH_SENSITIVITY
	targetPitch = math.clamp(
		targetPitch + (mouseDelta.Y * MOUSE_SENSITIVITY) + (touchDelta.Y * TOUCH_SENSITIVITY),
		MIN_PITCH,
		MAX_PITCH
	)

	local alpha = 1 - math.exp(-LAG_SPEED * dt)
	yaw += (targetYaw - yaw) * alpha
	pitch += (targetPitch - pitch) * alpha

	local focusPos = hrp.Position + Vector3.new(0, HEIGHT, 0)
	local distance = getCameraDistance()
	local rotation = CFrame.new(focusPos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local desiredPos = (rotation * CFrame.new(0, 0, -distance)).Position

	local direction = desiredPos - focusPos
	local directionDistance = direction.Magnitude
	if directionDistance > 0.001 then
		local result = Workspace:Raycast(focusPos, direction, rayParams)
		if result then
			local hitDistance = (result.Position - focusPos).Magnitude
			local safeDistance = math.max(2, hitDistance - CAMERA_RADIUS)
			desiredPos = focusPos + direction.Unit * safeDistance
		end
	end

	camera.CFrame = CFrame.new(desiredPos, focusPos)
end

player.CharacterAdded:Connect(function()
	anglesInitialized = false
	frozenCFrame = nil
	if movementLocked then
		task.defer(function()
			setMovementLocked(true)
		end)
	end
end)

script.Destroying:Connect(function()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
	setMovementLocked(false)
	setUiInput()
end)

RunService:UnbindFromRenderStep("LobbyOrbitCam")
RunService:BindToRenderStep("LobbyOrbitCam", Enum.RenderPriority.Camera.Value + 1, orbitStep)
