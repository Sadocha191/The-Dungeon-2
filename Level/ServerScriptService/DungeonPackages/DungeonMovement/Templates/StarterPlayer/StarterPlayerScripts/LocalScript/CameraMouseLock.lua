local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local ModalUiState = require(moduleFolder:WaitForChild("ModalUiState"))

local USE_DEFAULT_TOUCH_CAMERA = UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled

local DISTANCE = 20
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
local movementLocked = false
local ignoreLookDeltaUntil = 0
local lookInputBlockedLastFrame = false

local function getHRP(): BasePart?
	local char = player.Character
	if not char then
		return nil
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	return nil
end

local function getHumanoid(): Humanoid?
	local char = player.Character
	if not char then
		return nil
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid
	end

	return nil
end

local function isBlockingUIOpen(): boolean
	return ModalUiState.IsBlockingUiOpen(playerGui)
end

local function shouldReleaseCursor(): boolean
	return isBlockingUIOpen()
		or UIS:GetFocusedTextBox() ~= nil
		or UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
		or UIS:IsKeyDown(Enum.KeyCode.RightAlt)
end

local function setGameplayInput()
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	UIS.MouseIconEnabled = false
end

local function setUiInput()
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	UIS.MouseIconEnabled = true
end

local function cancelCharacterMotion()
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end

	humanoid:Move(Vector3.zero, true)
	humanoid.Jump = false
end

local function setMovementLocked(locked: boolean)
	if locked then
		if movementLocked then
			return
		end

		movementLocked = true
		ContextActionService:BindActionAtPriority(
			"LevelModalMovementLock",
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
		return
	end

	if not movementLocked then
		return
	end

	movementLocked = false
	ContextActionService:UnbindAction("LevelModalMovementLock")
end

UIS.TouchPan:Connect(function(touchPositions, totalTranslation, _velocity, state, gameProcessedEvent)
	if USE_DEFAULT_TOUCH_CAMERA then
		touchLookDelta = Vector2.zero
		lastTouchPanTranslation = Vector2.zero
		return
	end

	if gameProcessedEvent or shouldReleaseCursor() then
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

	local blockingUiOpen = isBlockingUIOpen()
	local releaseCursor = shouldReleaseCursor()
	local now = os.clock()
	local lookInputBlocked = blockingUiOpen or releaseCursor
	setMovementLocked(blockingUiOpen)

	if USE_DEFAULT_TOUCH_CAMERA then
		if blockingUiOpen then
			cancelCharacterMotion()
		end
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		frozenCFrame = nil
		touchLookDelta = Vector2.zero
		lastTouchPanTranslation = Vector2.zero
		return
	end

	if lookInputBlocked ~= lookInputBlockedLastFrame then
		touchLookDelta = Vector2.zero
		lastTouchPanTranslation = Vector2.zero
		if not lookInputBlocked then
			ignoreLookDeltaUntil = now + 0.12
		end
		lookInputBlockedLastFrame = lookInputBlocked
	end

	camera.CameraType = Enum.CameraType.Scriptable

	if blockingUiOpen then
		cancelCharacterMotion()
		if not frozenCFrame then
			frozenCFrame = camera.CFrame
		end
		camera.CFrame = frozenCFrame
		setUiInput()
		return
	end

	frozenCFrame = nil
	if releaseCursor then
		setUiInput()
	else
		setGameplayInput()
	end

	local hrp = getHRP()
	if not hrp then
		return
	end

	rayParams.FilterDescendantsInstances = { player.Character }

	local suppressLookDelta = releaseCursor or now < ignoreLookDeltaUntil
	local mouseDelta = suppressLookDelta and Vector2.zero or UIS:GetMouseDelta()
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
	local rotation = CFrame.new(focusPos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local desiredPos = (rotation * CFrame.new(0, 0, -DISTANCE)).Position

	local direction = desiredPos - focusPos
	local distance = direction.Magnitude
	if distance > 0.001 then
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

RunService:UnbindFromRenderStep("OrbitCam")
RunService:BindToRenderStep("OrbitCam", Enum.RenderPriority.Camera.Value + 1, orbitStep)
