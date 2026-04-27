local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local runStarted = ReplicatedStorage:WaitForChild("RunStarted")
local pauseState = ReplicatedStorage:WaitForChild("PauseState")

local BASE_SPRINT_BONUS = 0.18
local SPRINT_BONUS_PER_LEVEL = 0.12
local BASE_EXTRA_JUMPS = 1

local BASE_DASH_DISTANCE = 18
local DASH_DISTANCE_PER_LEVEL = 3
local BASE_DASH_DURATION = 0.16
local BASE_DASH_COOLDOWN = 1.2
local DASH_COOLDOWN_REDUCTION = 0.08

local BASE_SLIDE_SPEED_MULT = 1.55
local SLIDE_SPEED_PER_LEVEL = 0.18
local BASE_SLIDE_DURATION = 0.45
local SLIDE_DURATION_PER_LEVEL = 0.03
local BASE_SLIDE_COOLDOWN = 1.35
local SLIDE_COOLDOWN_REDUCTION = 0.10
local SLIDE_CAMERA_DROP = 1.15

local MIN_MOVE_MAGNITUDE = 0.08

local sprintHeld = false
local airJumpsRemaining = BASE_EXTRA_JUMPS
local dashReadyAt = 0
local slideReadyAt = 0
local activeMotion = nil

local function getCharacter(): Model?
	local character = player.Character
	if character and character.Parent then
		return character
	end
	return nil
end

local function getHumanoid(): Humanoid?
	local character = getCharacter()
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid
	end

	return nil
end

local function getRootPart(): BasePart?
	local character = getCharacter()
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function getNumAttr(name: string, fallback: number): number
	local value = player:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function isPauseMenuOpen(): boolean
	local pauseGui = playerGui:FindFirstChild("Pause")
	if not pauseGui or not pauseGui:IsA("ScreenGui") then
		return false
	end

	local overlay = pauseGui:FindFirstChild("MenuOverlay")
	local menuOpen = pauseGui:GetAttribute("MenuOpen") == true
	return menuOpen or (overlay and overlay:IsA("GuiObject") and overlay.Visible) == true
end

local function isDailyMissionsOpen(): boolean
	local dailyMissionsGui = playerGui:FindFirstChild("DailyMissions")
	if not dailyMissionsGui or not dailyMissionsGui:IsA("ScreenGui") then
		return false
	end

	return dailyMissionsGui:GetAttribute("BoardShown") == true
end

local function isRewardRevealOpen(): boolean
	local rewardRevealGui = playerGui:FindFirstChild("RewardRevealGui")
	return rewardRevealGui ~= nil and rewardRevealGui:IsA("ScreenGui") and rewardRevealGui.Enabled
end

local function isBlockingUIOpen(): boolean
	local upgradesGui = playerGui:FindFirstChild("UpgradesGUI")
	local upgradesMain = upgradesGui and upgradesGui:FindFirstChild("Main")
	if upgradesGui and upgradesGui:IsA("ScreenGui") and upgradesGui.Enabled and upgradesMain and upgradesMain:IsA("GuiObject") and upgradesMain.Visible then
		return true
	end

	if isDailyMissionsOpen() then
		return true
	end

	local missionSummary = playerGui:FindFirstChild("MissionSummary")
	if missionSummary and missionSummary:IsA("ScreenGui") and missionSummary.Enabled then
		return true
	end

	local ekeyMenu = playerGui:FindFirstChild("EKeyMenu")
	if ekeyMenu and ekeyMenu:IsA("ScreenGui") and ekeyMenu.Enabled then
		return true
	end

	if isRewardRevealOpen() then
		return true
	end

	return isPauseMenuOpen()
end

local function isRunActive(): boolean
	return runStarted.Value == true
		and pauseState.Value ~= true
		and player:GetAttribute("RunEnded") ~= true
end

local function isMovementSuppressed(): boolean
	return not isRunActive()
		or isBlockingUIOpen()
		or UserInputService:GetFocusedTextBox() ~= nil
end

local function getBaseWalkSpeed(): number
	return getNumAttr("BaseWalkSpeed", 21) + getNumAttr("RunBonusSpeed", 0)
end

local function getSprintMultiplier(): number
	return 1 + BASE_SPRINT_BONUS + (getNumAttr("MoveSprintLevel", 0) * SPRINT_BONUS_PER_LEVEL)
end

local function getTotalExtraJumps(): number
	return BASE_EXTRA_JUMPS + math.max(0, math.floor(getNumAttr("MoveExtraJumpBonus", 0)))
end

local function getDashDistance(): number
	return BASE_DASH_DISTANCE + (getNumAttr("MoveDashLevel", 0) * DASH_DISTANCE_PER_LEVEL)
end

local function getDashCooldown(): number
	return math.max(0.35, BASE_DASH_COOLDOWN - (getNumAttr("MoveDashLevel", 0) * DASH_COOLDOWN_REDUCTION))
end

local function getSlideSpeedMultiplier(): number
	return BASE_SLIDE_SPEED_MULT + (getNumAttr("MoveSlideLevel", 0) * SLIDE_SPEED_PER_LEVEL)
end

local function getSlideDuration(): number
	return BASE_SLIDE_DURATION + math.min(0.18, getNumAttr("MoveSlideLevel", 0) * SLIDE_DURATION_PER_LEVEL)
end

local function getSlideCooldown(): number
	return math.max(0.45, BASE_SLIDE_COOLDOWN - (getNumAttr("MoveSlideLevel", 0) * SLIDE_COOLDOWN_REDUCTION))
end

local function isGrounded(humanoid: Humanoid?): boolean
	if not humanoid then
		return false
	end

	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return true
	end

	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.RunningNoPhysics
		or state == Enum.HumanoidStateType.Landed
		or state == Enum.HumanoidStateType.Climbing
		or state == Enum.HumanoidStateType.Swimming
end

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getMotionDirection(humanoid: Humanoid, root: BasePart): Vector3
	local moveDirection = flatten(humanoid.MoveDirection)
	if moveDirection.Magnitude >= MIN_MOVE_MAGNITUDE then
		return moveDirection.Unit
	end

	local planarVelocity = flatten(root.AssemblyLinearVelocity)
	if planarVelocity.Magnitude >= 2 then
		return planarVelocity.Unit
	end

	local look = flatten(root.CFrame.LookVector)
	if look.Magnitude >= 0.001 then
		return look.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function clearMotion()
	activeMotion = nil

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
	end
end

local function startDash()
	local humanoid = getHumanoid()
	local root = getRootPart()
	if not humanoid or not root or isMovementSuppressed() then
		return
	end

	local now = os.clock()
	if now < dashReadyAt or humanoid.Health <= 0 then
		return
	end

	dashReadyAt = now + getDashCooldown()
	activeMotion = {
		kind = "dash",
		dir = getMotionDirection(humanoid, root),
		duration = BASE_DASH_DURATION,
		elapsed = 0,
		speed = getDashDistance() / BASE_DASH_DURATION,
	}
end

local function startSlide()
	local humanoid = getHumanoid()
	local root = getRootPart()
	if not humanoid or not root or isMovementSuppressed() then
		return
	end

	if not isGrounded(humanoid) or humanoid.MoveDirection.Magnitude < MIN_MOVE_MAGNITUDE or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	if now < slideReadyAt then
		return
	end

	slideReadyAt = now + getSlideCooldown()
	activeMotion = {
		kind = "slide",
		dir = getMotionDirection(humanoid, root),
		duration = getSlideDuration(),
		elapsed = 0,
		speed = getBaseWalkSpeed() * getSlideSpeedMultiplier(),
	}
end

local function getJumpVelocity(humanoid: Humanoid): number
	if humanoid.UseJumpPower then
		return math.max(36, humanoid.JumpPower)
	end

	local jumpHeight = humanoid.JumpHeight
	if jumpHeight <= 0 then
		jumpHeight = 7.2
	end
	return math.sqrt(2 * workspace.Gravity * jumpHeight)
end

local function doExtraJump()
	local humanoid = getHumanoid()
	local root = getRootPart()
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local currentVelocity = root.AssemblyLinearVelocity
	local jumpVelocity = getJumpVelocity(humanoid)
	root.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, math.max(currentVelocity.Y, jumpVelocity), currentVelocity.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function updateHumanoid(dt: number)
	local humanoid = getHumanoid()
	local root = getRootPart()
	if not humanoid or not root then
		clearMotion()
		return
	end

	if humanoid.Health <= 0 then
		clearMotion()
		return
	end

	local grounded = isGrounded(humanoid)
	if grounded then
		airJumpsRemaining = getTotalExtraJumps()
	end

	if isMovementSuppressed() then
		clearMotion()
		return
	end

	if activeMotion then
		activeMotion.elapsed += dt
		humanoid.AutoRotate = false

		if activeMotion.kind == "slide" then
			humanoid.CameraOffset = Vector3.new(0, -SLIDE_CAMERA_DROP, 0)
		else
			humanoid.CameraOffset = Vector3.zero
		end

		local alpha = math.clamp(activeMotion.elapsed / activeMotion.duration, 0, 1)
		local motionSpeed = activeMotion.speed
		if activeMotion.kind == "slide" then
			motionSpeed *= 1 - (alpha * 0.45)
		end

		local currentVelocity = root.AssemblyLinearVelocity
		local horizontalVelocity = activeMotion.dir * motionSpeed
		root.AssemblyLinearVelocity = Vector3.new(horizontalVelocity.X, currentVelocity.Y, horizontalVelocity.Z)
		humanoid.WalkSpeed = 0

		if activeMotion.elapsed >= activeMotion.duration then
			clearMotion()
		end
		return
	end

	humanoid.AutoRotate = true
	humanoid.CameraOffset = Vector3.zero

	local walkSpeed = getBaseWalkSpeed()
	if sprintHeld and grounded and humanoid.MoveDirection.Magnitude >= MIN_MOVE_MAGNITUDE then
		walkSpeed *= getSprintMultiplier()
	end
	humanoid.WalkSpeed = walkSpeed
end

player.CharacterAdded:Connect(function(character)
	clearMotion()
	sprintHeld = false
	airJumpsRemaining = getTotalExtraJumps()
	dashReadyAt = 0
	slideReadyAt = 0

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.CameraOffset = Vector3.zero
	end
end)

if player.Character then
	task.defer(function()
		airJumpsRemaining = getTotalExtraJumps()
	end)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.LeftShift or keyCode == Enum.KeyCode.RightShift or keyCode == Enum.KeyCode.ButtonL3 then
		sprintHeld = true
		return
	end

	if keyCode == Enum.KeyCode.Q or keyCode == Enum.KeyCode.ButtonB then
		startDash()
		return
	end

	if keyCode == Enum.KeyCode.LeftControl or keyCode == Enum.KeyCode.C or keyCode == Enum.KeyCode.ButtonX then
		startSlide()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.LeftShift or keyCode == Enum.KeyCode.RightShift or keyCode == Enum.KeyCode.ButtonL3 then
		sprintHeld = false
	end
end)

UserInputService.JumpRequest:Connect(function()
	if isMovementSuppressed() then
		return
	end

	local humanoid = getHumanoid()
	if not humanoid or isGrounded(humanoid) then
		return
	end

	if airJumpsRemaining <= 0 then
		return
	end

	airJumpsRemaining -= 1
	clearMotion()
	doExtraJump()
end)

script.Destroying:Connect(function()
	clearMotion()
	sprintHeld = false
end)

RunService.Heartbeat:Connect(updateHumanoid)
