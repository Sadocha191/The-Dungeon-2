local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local runStarted = ReplicatedStorage:WaitForChild("RunStarted")
local pauseState = ReplicatedStorage:WaitForChild("PauseState")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local MovementConfig = require(moduleFolder:WaitForChild("MovementConfig"))
local ModalUiState = require(moduleFolder:WaitForChild("ModalUiState"))

local BASE_SPRINT_BONUS = 0.18
local SPRINT_BONUS_PER_LEVEL = 0.12

local BASE_DASH_DISTANCE = 18
local DASH_DISTANCE_PER_LEVEL = 3
local BASE_DASH_DURATION = 0.16
local BASE_DASH_COOLDOWN = 1.2
local DASH_COOLDOWN_REDUCTION = 0.08

local MIN_MOVE_MAGNITUDE = 0.05
local MIN_VECTOR_MAGNITUDE = 1e-4
local UP_VECTOR = Vector3.new(0, 1, 0)
local DOWN_VECTOR = Vector3.new(0, -1, 0)
local LOW_GRAVITY_ATTACHMENT_NAME = "MovementLowGravityAttachment"
local LOW_GRAVITY_FORCE_NAME = "LowGravityForce"
local SLIDE_MIN_END_GRACE = 0.12
local KEYBOARD_MOVE_VECTORS = {
	[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
	[Enum.KeyCode.Up] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.Down] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.Left] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.Right] = Vector3.new(1, 0, 0),
}

local BLOCKED_SLIDE_STATES = {
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
}

local BLOCKED_AIR_STATES = {
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
}

type GroundInfo = {
	isGrounded: boolean,
	normal: Vector3,
	hitPart: BasePart?,
	slopeAngle: number,
	hitPosition: Vector3?,
	humanoidState: Enum.HumanoidStateType?,
}

type MotionState = {
	kind: string,
	character: Model?,
	root: BasePart?,
	direction: Vector3,
	speed: number,
	startedAt: number,
	endsAt: number,
	minEndsAt: number?,
	holdEnabled: boolean?,
	lastSlideVelocity: Vector3?,
	lastGroundNormal: Vector3?,
	lastSlopeAngle: number?,
	lastWasOnSlope: boolean?,
	surfaceTransitionUntil: number?,
	edgeLaunched: boolean?,
	groundLostAt: number?,
	chainMomentum: boolean?,
}

type LandingMomentumState = {
	velocity: Vector3,
	endsAt: number,
}

type ChainMomentumState = {
	velocity: Vector3,
	startedAt: number,
	lastAirborneAt: number,
	canResumeSlide: boolean,
}

type SlideStartOptions = {
	bypassCooldown: boolean?,
	noFreshBoost: boolean?,
	initialHorizontalVelocity: Vector3?,
	sourceReason: string?,
	chainMomentum: boolean?,
}

local slideKeyCodeLookup = {}
for _, keyCode in ipairs(MovementConfig.SlideKeyCodes or {}) do
	slideKeyCodeLookup[keyCode] = true
end

local connections = {}
local characterConnections = {}

local currentCharacter: Model? = nil
local currentHumanoid: Humanoid? = nil
local currentRoot: BasePart? = nil

local sprintHeld = false
local slideHeldKeyCodes = {}
local jumpsUsed = 0
local lastJumpTime = -math.huge
local lastAirJumpTime = -math.huge
local leftGroundTime = -math.huge
local landedAt = -math.huge
local dashReadyAt = 0
local slideReadyAt = 0
local wasGrounded = false
local lastGroundInfo: GroundInfo? = nil
local activeMotion: MotionState? = nil
local landingMomentum: LandingMomentumState? = nil
local chainMomentum: ChainMomentumState? = nil
local landingSlideResumeUntil = -math.huge
local slideJumpLowGravityUntil = -math.huge
local lowGravityAttachment: Attachment? = nil
local lowGravityForce: VectorForce? = nil
local lastDebugPrintAt = {}

local function connect(connectionList, signal, handler)
	local connection = signal:Connect(handler)
	table.insert(connectionList, connection)
	return connection
end

local function disconnectAll(connectionList)
	for i = #connectionList, 1, -1 do
		local connection = connectionList[i]
		if connection then
			connection:Disconnect()
		end
		connectionList[i] = nil
	end
end

local function debugLog(key: string, message: string)
	if MovementConfig.DebugMovement ~= true then
		return
	end

	local now = os.clock()
	local lastPrintAt = lastDebugPrintAt[key]
	if lastPrintAt and (now - lastPrintAt) < 0.2 then
		return
	end

	lastDebugPrintAt[key] = now
	print("[Movement]", message)
end

local function debugSlideEnd(reason: string, detail: string?)
	local message = "Slide ended: reason=" .. reason
	if detail and detail ~= "" then
		message ..= " " .. detail
	end
	debugLog("slide_end_" .. reason, message)
end

local function setSlideKeyHeld(keyCode: Enum.KeyCode, isHeld: boolean)
	if not slideKeyCodeLookup[keyCode] then
		return
	end

	if isHeld then
		slideHeldKeyCodes[keyCode] = true
	else
		slideHeldKeyCodes[keyCode] = nil
	end
end

local function isSlideInputHeld(): boolean
	for _, isHeld in pairs(slideHeldKeyCodes) do
		if isHeld == true then
			return true
		end
	end
	return false
end

local function resetJumpTracking()
	jumpsUsed = 0
	lastJumpTime = -math.huge
	lastAirJumpTime = -math.huge
	leftGroundTime = -math.huge
	landedAt = -math.huge
end

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function clampHorizontal(vector: Vector3, maxSpeed: number): Vector3
	if maxSpeed <= 0 then
		return Vector3.zero
	end

	local magnitude = vector.Magnitude
	if magnitude <= maxSpeed or magnitude <= MIN_VECTOR_MAGNITUDE then
		return vector
	end

	return vector.Unit * maxSpeed
end

local function getStrongerHorizontal(first: Vector3?, second: Vector3?): Vector3
	local firstHorizontal = first and flatten(first) or Vector3.zero
	local secondHorizontal = second and flatten(second) or Vector3.zero
	if secondHorizontal.Magnitude > firstHorizontal.Magnitude then
		return secondHorizontal
	end
	return firstHorizontal
end

local function clampVelocityByHorizontal(velocity: Vector3, maxHorizontalSpeed: number): Vector3
	if maxHorizontalSpeed <= 0 then
		return Vector3.zero
	end

	local horizontal = flatten(velocity)
	local magnitude = horizontal.Magnitude
	if magnitude <= maxHorizontalSpeed or magnitude <= MIN_VECTOR_MAGNITUDE then
		return velocity
	end

	local scale = maxHorizontalSpeed / magnitude
	return velocity * scale
end

local function faceMovementDirection(root: BasePart, horizontalVelocity: Vector3, dt: number, turnSpeed: number?, state: string)
	if MovementConfig.FaceMovementDirectionEnabled ~= true then
		return
	end

	local flatVelocity = flatten(horizontalVelocity)
	local speed = flatVelocity.Magnitude
	if speed < 1 then
		return
	end

	local currentPosition = root.Position
	local targetCFrame = CFrame.lookAt(currentPosition, currentPosition + flatVelocity.Unit)
	local configuredTurnSpeed = math.max(0, turnSpeed or 12)
	local alpha = math.clamp(configuredTurnSpeed * dt, 0, 1)
	local linearVelocity = root.AssemblyLinearVelocity
	local angularVelocity = root.AssemblyAngularVelocity
	root.CFrame = root.CFrame:Lerp(targetCFrame, alpha)
	root.AssemblyLinearVelocity = linearVelocity
	root.AssemblyAngularVelocity = angularVelocity

	debugLog(
		"face_movement_" .. state,
		string.format("face_movement state=%s speed=%.2f turnSpeed=%.2f", state, speed, configuredTurnSpeed)
	)
end

local function projectOntoPlane(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

local function getNumAttr(name: string, fallback: number): number
	local value = player:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function getRunStat(name: string, fallback: number): number
	local value = player:GetAttribute("RunStat_" .. name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function isBlockingUIOpen(): boolean
	return ModalUiState.IsBlockingUiOpen(playerGui)
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

local function syncHeldSprintState()
	sprintHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL3)
end

local function getHeldMovementIntent(): Vector3
	local moveIntent = Vector3.zero
	for keyCode, direction in pairs(KEYBOARD_MOVE_VECTORS) do
		if UserInputService:IsKeyDown(keyCode) then
			moveIntent += direction
		end
	end

	if moveIntent.Magnitude <= MIN_MOVE_MAGNITUDE then
		return Vector3.zero
	end

	return moveIntent.Unit
end

local function getCurrentMoveIntent(humanoid: Humanoid): Vector3
	local moveDirection = flatten(humanoid.MoveDirection)
	if moveDirection.Magnitude > MIN_MOVE_MAGNITUDE then
		return moveDirection
	end

	return getHeldMovementIntent()
end

local function applyHeldMovementIntent(humanoid: Humanoid, moveIntent: Vector3)
	if moveIntent.Magnitude <= MIN_MOVE_MAGNITUDE then
		return
	end

	if flatten(humanoid.MoveDirection).Magnitude > MIN_MOVE_MAGNITUDE then
		return
	end

	humanoid:Move(Vector3.new(moveIntent.X, 0, moveIntent.Z), true)
end

local function refreshCharacterReferences()
	local character = currentCharacter
	if not character or not character.Parent then
		character = player.Character
	end

	currentCharacter = character
	currentHumanoid = nil
	currentRoot = nil

	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		currentHumanoid = humanoid
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		currentRoot = root
	end

	return currentCharacter, currentHumanoid, currentRoot
end

local function getBaseWalkSpeed(): number
	return getNumAttr("BaseWalkSpeed", 21) * math.max(0.25, getRunStat("MovementSpeed", 1))
end

local function getSprintMultiplier(): number
	return 1 + BASE_SPRINT_BONUS + (getNumAttr("MoveSprintLevel", 0) * SPRINT_BONUS_PER_LEVEL)
end

local function getMaxJumpCount(): number
	local configuredMax = math.max(1, math.floor(tonumber(MovementConfig.MaxJumps) or 1))
	local bonusJumps = math.max(0, math.floor(getRunStat("ExtraJumps", 0)))
	return configuredMax + bonusJumps
end

local function getDashDistance(): number
	return BASE_DASH_DISTANCE + (getNumAttr("MoveDashLevel", 0) * DASH_DISTANCE_PER_LEVEL)
end

local function getDashCooldown(): number
	return math.max(0.35, BASE_DASH_COOLDOWN - (getNumAttr("MoveDashLevel", 0) * DASH_COOLDOWN_REDUCTION))
end

local function getSlideDuration(): number
	local level = math.max(0, math.floor(getNumAttr("MoveSlideLevel", 0)))
	local baseDuration = tonumber(MovementConfig.SlideDuration) or 0.45
	local perLevel = tonumber(MovementConfig.SlideDurationPerLevel) or 0
	local maxBonus = tonumber(MovementConfig.MaxSlideDurationBonus) or 0
	return baseDuration + math.min(maxBonus, level * perLevel)
end

local function getSlideMaxDuration(minDuration: number): number
	if MovementConfig.SlideHoldEnabled ~= true then
		return minDuration
	end

	if MovementConfig.SlideHardMaxDurationEnabled ~= true then
		return math.huge
	end

	return math.max(minDuration, tonumber(MovementConfig.MaxSlideHoldDuration) or minDuration)
end

local function getSlideGroundGraceTime(): number
	return math.max(0, tonumber(MovementConfig.SlideGroundGraceTime) or 0.16)
end

local function getSlideCooldown(): number
	local level = math.max(0, math.floor(getNumAttr("MoveSlideLevel", 0)))
	local baseCooldown = tonumber(MovementConfig.SlideCooldown) or 0.9
	local perLevelReduction = tonumber(MovementConfig.SlideCooldownReductionPerLevel) or 0
	local minCooldown = tonumber(MovementConfig.MinSlideCooldown) or 0.45
	return math.max(minCooldown, baseCooldown - (level * perLevelReduction))
end

local function getSlideBoostSpeed(): number
	local level = math.max(0, math.floor(getNumAttr("MoveSlideLevel", 0)))
	local configuredBoost = tonumber(MovementConfig.SlideBoostSpeed) or 42
	local multiplier = (tonumber(MovementConfig.SlideBaseSpeedMultiplier) or 1.55)
		+ (level * (tonumber(MovementConfig.SlideSpeedPerLevel) or 0))
	return math.max(configuredBoost, getBaseWalkSpeed() * multiplier)
end

local function getMaxHorizontalSpeed(): number
	return math.max(1, tonumber(MovementConfig.MaxHorizontalSpeed) or 75)
end

local function getMaxAirHorizontalSpeed(): number
	return math.max(1, tonumber(MovementConfig.MaxAirHorizontalSpeed) or getMaxHorizontalSpeed())
end

local function getMaxMomentumChainSpeed(): number
	return math.max(getMaxAirHorizontalSpeed(), tonumber(MovementConfig.MaxMomentumChainSpeed) or 160)
end

local function getMomentumChainMinSpeed(): number
	return math.max(0, tonumber(MovementConfig.MomentumChainMinSpeed) or 3)
end

local function getMomentumChainAirDrag(): number
	return math.clamp(tonumber(MovementConfig.MomentumChainAirDrag) or 1, 0, 1)
end

local function getMomentumChainAirControlStrength(): number
	return math.max(0, tonumber(MovementConfig.MomentumChainAirControlStrength) or 0.018)
end

local function getMomentumChainAirTurnResponsiveness(): number
	return math.max(0, tonumber(MovementConfig.MomentumChainAirTurnResponsiveness) or 0.012)
end

local function getMaxSlideSlopeSpeed(): number
	return math.max(getMaxHorizontalSpeed(), tonumber(MovementConfig.MaxSlideSlopeSpeed) or 150)
end

local function getSlideSpeedLimit(useChainLimit: boolean?): number
	local slideLimit = getMaxSlideSlopeSpeed()
	if useChainLimit == true or chainMomentum ~= nil then
		return math.max(slideLimit, getMaxMomentumChainSpeed())
	end
	return slideLimit
end

local function getCurrentHorizontalVelocity(root: BasePart): Vector3
	return flatten(root.AssemblyLinearVelocity)
end

local function getMotionDirection(humanoid: Humanoid, root: BasePart): Vector3
	local moveDirection = flatten(humanoid.MoveDirection)
	if moveDirection.Magnitude >= MIN_MOVE_MAGNITUDE then
		return moveDirection.Unit
	end

	local planarVelocity = getCurrentHorizontalVelocity(root)
	if planarVelocity.Magnitude >= 2 then
		return planarVelocity.Unit
	end

	local look = flatten(root.CFrame.LookVector)
	if look.Magnitude >= MIN_VECTOR_MAGNITUDE then
		return look.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function isSlideStateBlocked(humanoid: Humanoid?): boolean
	if not humanoid then
		return true
	end

	if humanoid.Sit or humanoid.SeatPart ~= nil then
		return true
	end

	return BLOCKED_SLIDE_STATES[humanoid:GetState()] == true
end

local function isAirStateBlocked(humanoid: Humanoid?): boolean
	if not humanoid then
		return true
	end

	if humanoid.Sit or humanoid.SeatPart ~= nil then
		return true
	end

	return BLOCKED_AIR_STATES[humanoid:GetState()] == true
end

local function getGroundInfo(allowFreefallGround: boolean?): GroundInfo
	local _, humanoid, root = refreshCharacterReferences()
	if not currentCharacter or not humanoid or not root then
		return {
			isGrounded = false,
			normal = UP_VECTOR,
			hitPart = nil,
			slopeAngle = 90,
			hitPosition = nil,
			humanoidState = humanoid and humanoid:GetState() or nil,
		}
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { currentCharacter }
	params.RespectCanCollide = true
	params.IgnoreWater = false

	local distance = math.max(0.5, tonumber(MovementConfig.GroundCheckDistance) or 5)
	local origin = root.Position + (UP_VECTOR * 0.25)
	local result = workspace:Raycast(origin, -UP_VECTOR * (distance + 0.25), params)
	if not result then
		return {
			isGrounded = false,
			normal = UP_VECTOR,
			hitPart = nil,
			slopeAngle = 90,
			hitPosition = nil,
			humanoidState = humanoid:GetState(),
		}
	end

	local hitPart = result.Instance
	local normal = result.Normal
	local slopeDot = math.clamp(normal:Dot(UP_VECTOR), -1, 1)
	local slopeAngle = math.deg(math.acos(slopeDot))
	local humanoidState = humanoid:GetState()
	local blocksGroundByState = humanoidState == Enum.HumanoidStateType.Jumping
		or humanoidState == Enum.HumanoidStateType.FallingDown
		or (humanoidState == Enum.HumanoidStateType.Freefall and allowFreefallGround ~= true)
	local isGrounded = hitPart ~= nil
		and result.Material ~= Enum.Material.Water
		and slopeDot > 0.05
		and not blocksGroundByState
		and slopeAngle <= math.max(0, tonumber(MovementConfig.MaxSlopeAngle) or 50)

	return {
		isGrounded = isGrounded,
		normal = normal,
		hitPart = (hitPart and hitPart:IsA("BasePart")) and hitPart or nil,
		slopeAngle = slopeAngle,
		hitPosition = result.Position,
		humanoidState = humanoidState,
	}
end

local function clearMotion()
	activeMotion = nil

	local _, humanoid = refreshCharacterReferences()
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
		if type(MovementConfig.SlideActiveAttribute) == "string" and MovementConfig.SlideActiveAttribute ~= "" then
			humanoid:SetAttribute(MovementConfig.SlideActiveAttribute, false)
		end
	end
end

local function clearLandingMomentum()
	landingMomentum = nil
end

local function clearChainMomentum(reason: string?)
	if chainMomentum then
		debugLog(
			"chain_clear",
			string.format("chain_clear reason=%s speed=%.2f", tostring(reason or "unspecified"), chainMomentum.velocity.Magnitude)
		)
	end
	chainMomentum = nil
	landingSlideResumeUntil = -math.huge
end

local function setChainMomentum(horizontalVelocity: Vector3, now: number)
	local clampedVelocity = clampHorizontal(flatten(horizontalVelocity), getMaxMomentumChainSpeed())
	if clampedVelocity.Magnitude < getMomentumChainMinSpeed() then
		clearChainMomentum("speed_low")
		return
	end

	chainMomentum = {
		velocity = clampedVelocity,
		startedAt = now,
		lastAirborneAt = now,
		canResumeSlide = true,
	}
end

local function clearLowGravity()
	if lowGravityForce then
		lowGravityForce.Enabled = false
		lowGravityForce:Destroy()
		lowGravityForce = nil
	end

	if lowGravityAttachment then
		lowGravityAttachment:Destroy()
		lowGravityAttachment = nil
	end
end

local function setLowGravityEnabled(root: BasePart?, enabled: boolean, scale: number?)
	if not root or MovementConfig.LowGravityEnabled ~= true then
		clearLowGravity()
		return
	end

	if not enabled then
		if lowGravityForce then
			lowGravityForce.Enabled = false
			lowGravityForce.Force = Vector3.zero
		end
		return
	end

	if lowGravityForce and lowGravityForce.Parent ~= root then
		clearLowGravity()
	end

	if not lowGravityAttachment or lowGravityAttachment.Parent ~= root then
		clearLowGravity()

		local attachment = root:FindFirstChild(LOW_GRAVITY_ATTACHMENT_NAME)
		if not attachment or not attachment:IsA("Attachment") then
			attachment = Instance.new("Attachment")
			attachment.Name = LOW_GRAVITY_ATTACHMENT_NAME
			attachment.Parent = root
		end
		lowGravityAttachment = attachment
	end

	if not lowGravityForce or lowGravityForce.Parent ~= root then
		local force = root:FindFirstChild(LOW_GRAVITY_FORCE_NAME)
		if not force or not force:IsA("VectorForce") then
			force = Instance.new("VectorForce")
			force.Name = LOW_GRAVITY_FORCE_NAME
			force.Parent = root
		end

		force.Attachment0 = lowGravityAttachment
		force.ApplyAtCenterOfMass = true
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		lowGravityForce = force
	end

	local gravityScale = math.clamp(scale or tonumber(MovementConfig.AirGravityScale) or 0.52, 0, 1)
	local forceAmount = root.AssemblyMass * workspace.Gravity * (1 - gravityScale)
	lowGravityForce.Attachment0 = lowGravityAttachment
	lowGravityForce.Force = Vector3.new(0, forceAmount, 0)
	lowGravityForce.Enabled = forceAmount > 0
end

local function updateLowGravity(humanoid: Humanoid, root: BasePart, groundInfo: GroundInfo)
	if MovementConfig.LowGravityEnabled ~= true then
		clearLowGravity()
		return
	end

	local now = os.clock()
	local baseGravityScale = tonumber(MovementConfig.AirGravityScale) or 0.52
	local gravityScale = baseGravityScale
	local gravityReason = "normal_air"
	if now <= slideJumpLowGravityUntil then
		gravityScale = tonumber(MovementConfig.SlideJumpGravityScale) or 0.48
		gravityReason = "slide_jump_window"
	elseif slideJumpLowGravityUntil ~= -math.huge then
		debugLog("slide_jump_low_gravity_end", string.format("slideJumpLowGravityUntil ended at %.2f", now))
		slideJumpLowGravityUntil = -math.huge
		if chainMomentum then
			gravityScale = tonumber(MovementConfig.MomentumChainGravityScale) or 0.55
			gravityReason = "chain_momentum"
		end
	elseif chainMomentum then
		gravityScale = tonumber(MovementConfig.MomentumChainGravityScale) or 0.55
		gravityReason = "chain_momentum"
	end

	local minYVelocity = tonumber(MovementConfig.LowGravityMinYVelocity) or -140
	local shouldEnable = not groundInfo.isGrounded
		and humanoid.Health > 0
		and not isAirStateBlocked(humanoid)
		and root.AssemblyLinearVelocity.Y > minYVelocity

	setLowGravityEnabled(root, shouldEnable, gravityScale)

	if shouldEnable then
		debugLog(
			"low_gravity",
			string.format(
				"low_gravity gravityScale=%.2f reason=%s yVelocity=%.2f",
				gravityScale,
				gravityReason,
				root.AssemblyLinearVelocity.Y
			)
		)
	end
end

local function setPlanarVelocity(root: BasePart, horizontalVelocity: Vector3, maxSpeed: number)
	local currentVelocity = root.AssemblyLinearVelocity
	local clampedHorizontal = clampHorizontal(horizontalVelocity, maxSpeed)
	root.AssemblyLinearVelocity = Vector3.new(clampedHorizontal.X, currentVelocity.Y, clampedHorizontal.Z)
end

local function getSlopeDownhillDirection(groundNormal: Vector3): Vector3?
	local downhillDirection = projectOntoPlane(DOWN_VECTOR, groundNormal)
	if downhillDirection.Magnitude <= MIN_VECTOR_MAGNITUDE then
		return nil
	end

	return downhillDirection.Unit
end

local function isAutoSlideSlope(groundInfo: GroundInfo): boolean
	if MovementConfig.SlopeSlideEnabled ~= true then
		return false
	end

	local minSlopeAngle = math.max(0, tonumber(MovementConfig.MinSlopeAutoSlideAngle) or 8)
	return groundInfo.isGrounded and groundInfo.slopeAngle >= minSlopeAngle
end

local function resolveSlideDirection(humanoid: Humanoid, root: BasePart, groundInfo: GroundInfo): (Vector3?, string)
	local moveDirection = getCurrentMoveIntent(humanoid)
	local direction = moveDirection
	local reason = "move_direction"

	if moveDirection.Magnitude < MIN_MOVE_MAGNITUDE then
		local downhillDirection = isAutoSlideSlope(groundInfo) and getSlopeDownhillDirection(groundInfo.normal) or nil
		if downhillDirection then
			return downhillDirection, "slope_auto"
		end

		local lookDirection = root.CFrame.LookVector
		local flatLookDirection = flatten(lookDirection)
		if flatLookDirection.Magnitude <= MIN_VECTOR_MAGNITUDE then
			return nil, "no_look_direction"
		end

		local forwardSpeed = getCurrentHorizontalVelocity(root):Dot(flatLookDirection.Unit)
		if forwardSpeed < (tonumber(MovementConfig.SlideLookFallbackMinSpeed) or 2.5) then
			return nil, "standing_still"
		end

		direction = lookDirection
		reason = "look_direction"
	end

	local projectedDirection = projectOntoPlane(direction, groundInfo.normal)
	if projectedDirection.Magnitude <= MIN_MOVE_MAGNITUDE then
		return nil, "projected_direction_too_small"
	end

	return projectedDirection.Unit, reason
end

local function startDash()
	local character, humanoid, root = refreshCharacterReferences()
	if not character or not humanoid or not root or isMovementSuppressed() or activeMotion then
		return
	end

	local now = os.clock()
	if now < dashReadyAt or humanoid.Health <= 0 then
		return
	end

	dashReadyAt = now + getDashCooldown()
	activeMotion = {
		kind = "dash",
		character = character,
		root = root,
		direction = getMotionDirection(humanoid, root),
		speed = getDashDistance() / BASE_DASH_DURATION,
		startedAt = now,
		endsAt = now + BASE_DASH_DURATION,
	}
	clearLandingMomentum()
end

local function startSlide(groundInfo: GroundInfo, options: SlideStartOptions?): boolean
	local character, humanoid, root = refreshCharacterReferences()
	if not character or not humanoid or not root or isMovementSuppressed() or activeMotion then
		return false
	end

	if humanoid.Health <= 0 then
		debugLog("slide_dead", "Slide blocked: humanoid is dead.")
		return false
	end
	if isSlideStateBlocked(humanoid) then
		debugLog("slide_state", "Slide blocked: humanoid state does not allow sliding.")
		return false
	end
	if not groundInfo.isGrounded then
		debugLog("slide_grounded", "Slide blocked: raycast ground check failed or slope is too steep.")
		return false
	end
	if groundInfo.slopeAngle > (tonumber(MovementConfig.MaxSlopeAngle) or 50) then
		debugLog("slide_slope", string.format("Slide blocked: slope angle %.2f exceeds max.", groundInfo.slopeAngle))
		return false
	end

	local slideDirection: Vector3? = nil
	local sourceReason = options and options.sourceReason or nil
	local initialHorizontalVelocity = options and options.initialHorizontalVelocity or nil
	if initialHorizontalVelocity and initialHorizontalVelocity.Magnitude > MIN_MOVE_MAGNITUDE then
		local projectedCarry = projectOntoPlane(initialHorizontalVelocity, groundInfo.normal)
		if projectedCarry.Magnitude > MIN_MOVE_MAGNITUDE then
			slideDirection = projectedCarry.Unit
			sourceReason = sourceReason or "carry_velocity"
		end
	end

	if not slideDirection then
		local resolvedDirection, resolvedReason = resolveSlideDirection(humanoid, root, groundInfo)
		slideDirection = resolvedDirection
		sourceReason = sourceReason or resolvedReason
	end

	if not slideDirection then
		debugLog("slide_direction", "Slide blocked: no valid slide direction (" .. tostring(sourceReason) .. ").")
		return false
	end

	local now = os.clock()
	if not (options and options.bypassCooldown == true) and now < slideReadyAt then
		debugLog("slide_cooldown", "Slide blocked: cooldown active.")
		return false
	end

	local currentVelocity = root.AssemblyLinearVelocity
	local carriedHorizontal = flatten(initialHorizontalVelocity or Vector3.zero)
	local currentHorizontalSpeed = math.max(flatten(currentVelocity).Magnitude, carriedHorizontal.Magnitude)
	local currentSlopeVelocity = projectOntoPlane(
		(initialHorizontalVelocity and initialHorizontalVelocity.Magnitude > MIN_MOVE_MAGNITUDE) and initialHorizontalVelocity or currentVelocity,
		groundInfo.normal
	)
	local currentSlopeSpeed = currentSlopeVelocity.Magnitude
	local slideLimit = getSlideSpeedLimit(options and options.chainMomentum == true)
	local slideSpeed
	if options and options.noFreshBoost == true then
		slideSpeed = math.max(
			tonumber(MovementConfig.SlideLandingMinCarrySpeed) or 10,
			currentHorizontalSpeed,
			currentSlopeSpeed
		)
	elseif sourceReason == "slope_auto" then
		slideSpeed = math.max(
			tonumber(MovementConfig.SlopeAutoSlideStartSpeed) or 4,
			currentHorizontalSpeed,
			currentSlopeSpeed
		)
	else
		slideSpeed = math.max(
			tonumber(MovementConfig.MinSlideSpeed) or 10,
			getSlideBoostSpeed(),
			currentHorizontalSpeed,
			currentSlopeSpeed
		)
	end
	slideSpeed = math.min(slideSpeed, slideLimit)

	local slideDuration = getSlideDuration()
	local slideMaxDuration = getSlideMaxDuration(slideDuration)

	if not (options and options.chainMomentum == true) then
		clearChainMomentum("new_slide")
	end

	slideReadyAt = now + getSlideCooldown()
	activeMotion = {
		kind = "slide",
		character = character,
		root = root,
		direction = slideDirection,
		speed = slideSpeed,
		startedAt = now,
		endsAt = now + slideMaxDuration,
		minEndsAt = now + slideDuration,
		holdEnabled = MovementConfig.SlideHoldEnabled == true,
		lastSlideVelocity = slideDirection * slideSpeed,
		lastGroundNormal = groundInfo.normal,
		lastSlopeAngle = groundInfo.slopeAngle,
		lastWasOnSlope = isAutoSlideSlope(groundInfo),
		surfaceTransitionUntil = nil,
		edgeLaunched = false,
		groundLostAt = nil,
		chainMomentum = options and options.chainMomentum == true,
	}
	if type(MovementConfig.SlideActiveAttribute) == "string" and MovementConfig.SlideActiveAttribute ~= "" then
		humanoid:SetAttribute(MovementConfig.SlideActiveAttribute, true)
	end
	clearLandingMomentum()

	debugLog(
		"slide_start",
		string.format(
			"Slide started: source=%s slope=%.2f speed=%.2f hold=%s chain=%s state=%s hit=%s",
			tostring(sourceReason),
			groundInfo.slopeAngle,
			slideSpeed,
			tostring(activeMotion.holdEnabled),
			tostring(activeMotion.chainMomentum == true),
			tostring(groundInfo.humanoidState or humanoid:GetState()),
			groundInfo.hitPart and groundInfo.hitPart:GetFullName() or "nil"
		)
	)

	return true
end

local function getAirJumpPower(humanoid: Humanoid): number
	local jumpScale = math.max(0.10, getRunStat("JumpHeight", 1))
	local configuredPower = (tonumber(MovementConfig.AirJumpPower) or 52) * jumpScale
	if humanoid.UseJumpPower then
		return configuredPower
	end

	local jumpHeight = humanoid.JumpHeight
	if jumpHeight <= 0 then
		jumpHeight = 7.2
	end
	return math.max(configuredPower, math.sqrt(2 * workspace.Gravity * jumpHeight))
end

local function doSlideJump(humanoid: Humanoid, root: BasePart, motion: MotionState, groundInfo: GroundInfo, now: number): boolean
	if MovementConfig.SlideJumpEnabled ~= true then
		return false
	end
	if not humanoid or humanoid.Health <= 0 or not root or not motion then
		return false
	end

	local slideHorizontal = flatten((motion and motion.lastSlideVelocity) or root.AssemblyLinearVelocity)
	local currentHorizontal = flatten(root.AssemblyLinearVelocity)
	local carriedHorizontal = getStrongerHorizontal(slideHorizontal, currentHorizontal)

	local speedBefore = math.max(slideHorizontal.Magnitude, currentHorizontal.Magnitude)
	local minCarrySpeed = math.max(0, tonumber(MovementConfig.SlideJumpMinCarrySpeed) or 3)
	if carriedHorizontal.Magnitude < minCarrySpeed then
		debugLog(
			"slide_jump_blocked",
			string.format("slide_jump_blocked carrySpeed=%.2f min=%.2f", carriedHorizontal.Magnitude, minCarrySpeed)
		)
		return false
	end

	local multiplier = math.max(0, tonumber(MovementConfig.SlideJumpHorizontalMultiplier) or 1)
	local maxCarrySpeed = math.min(
		math.max(1, tonumber(MovementConfig.SlideJumpMaxCarrySpeed) or 160),
		getMaxMomentumChainSpeed()
	)

	carriedHorizontal = clampHorizontal(flatten(carriedHorizontal) * multiplier, maxCarrySpeed)

	local yVelocity = getAirJumpPower(humanoid) + (tonumber(MovementConfig.SlideJumpExtraUpVelocity) or 0)
	root.AssemblyLinearVelocity = Vector3.new(carriedHorizontal.X, yVelocity, carriedHorizontal.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	if MovementConfig.SlideJumpCountsAsJump ~= false then
		jumpsUsed = 1
	end
	lastJumpTime = now
	leftGroundTime = now
	landedAt = -math.huge
	setChainMomentum(carriedHorizontal, now)
	slideJumpLowGravityUntil = now + math.max(0, tonumber(MovementConfig.SlideJumpLowGravityDuration) or 0.45)
	clearLandingMomentum()

	debugLog(
		"slide_jump",
		string.format(
			"slide_jump speedBefore=%.2f speedAfter=%.2f yVelocity=%.2f lowGravityUntil=%.2f slope=%.2f state=%s",
			speedBefore,
			carriedHorizontal.Magnitude,
			yVelocity,
			slideJumpLowGravityUntil,
			groundInfo.slopeAngle,
			tostring(groundInfo.humanoidState or humanoid:GetState())
		)
	)
	debugSlideEnd("slide_jump", string.format("speed=%.2f y=%.2f", carriedHorizontal.Magnitude, yVelocity))
	clearMotion()
	return true
end

local function doAirJump(humanoid: Humanoid, root: BasePart)
	local currentHorizontal = getCurrentHorizontalVelocity(root)
	local horizontalVelocity = currentHorizontal
	if chainMomentum then
		horizontalVelocity = getStrongerHorizontal(currentHorizontal, chainMomentum.velocity)
	end
	if MovementConfig.PreserveHorizontalMomentum ~= true and not chainMomentum then
		horizontalVelocity = Vector3.zero
	end

	local speedBefore = horizontalVelocity.Magnitude
	local maxCarrySpeed = chainMomentum and getMaxMomentumChainSpeed() or getMaxAirHorizontalSpeed()
	horizontalVelocity = clampHorizontal(horizontalVelocity, maxCarrySpeed)
	if chainMomentum then
		chainMomentum.velocity = horizontalVelocity
		chainMomentum.lastAirborneAt = os.clock()
	end
	root.AssemblyLinearVelocity = Vector3.new(horizontalVelocity.X, getAirJumpPower(humanoid), horizontalVelocity.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	debugLog(
		"air_jump_carry",
		string.format(
			"air_jump_carry speedBefore=%.2f speedAfter=%.2f limitUsed=%.2f chainMomentum=%s",
			speedBefore,
			horizontalVelocity.Magnitude,
			maxCarrySpeed,
			tostring(chainMomentum ~= nil)
		)
	)
end

local function applyLandingMomentum(root: BasePart, dt: number, now: number)
	if not landingMomentum then
		return
	end

	if now >= landingMomentum.endsAt then
		landingMomentum = nil
		return
	end

	local friction = math.clamp(tonumber(MovementConfig.LandingFriction) or 0.9, 0.01, 1)
	landingMomentum.velocity *= friction ^ (dt * 60)
	if landingMomentum.velocity.Magnitude <= 0.5 then
		landingMomentum = nil
		return
	end

	local currentVelocity = root.AssemblyLinearVelocity
	local currentHorizontal = flatten(currentVelocity)
	if currentHorizontal.Magnitude + 0.1 < landingMomentum.velocity.Magnitude then
		local landingLimit = chainMomentum and getMaxMomentumChainSpeed() or getMaxHorizontalSpeed()
		setPlanarVelocity(root, landingMomentum.velocity, landingLimit)
	end
end

local function applyAirMomentum(humanoid: Humanoid, root: BasePart, dt: number)
	local chainState = chainMomentum
	if isAirStateBlocked(humanoid) then
		return
	end
	if MovementConfig.AirControlEnabled ~= true and not chainState then
		return
	end

	local currentVelocity = root.AssemblyLinearVelocity
	local currentHorizontal = flatten(currentVelocity)
	local horizontal = currentHorizontal
	local desiredInput = getCurrentMoveIntent(humanoid)
	local speedBefore = currentHorizontal.Magnitude
	local dragUsed = math.clamp(tonumber(MovementConfig.AirDrag) or 0.999, 0, 1)
	local limitUsed = getMaxAirHorizontalSpeed()

	if chainState then
		if chainState.velocity.Magnitude > currentHorizontal.Magnitude then
			horizontal = chainState.velocity
		end

		local chainSpeed = horizontal.Magnitude
		if MovementConfig.MomentumChainAllowAirControl ~= false
			and desiredInput.Magnitude > MIN_MOVE_MAGNITUDE
			and chainSpeed > MIN_VECTOR_MAGNITUDE
		then
			desiredInput = desiredInput.Unit
			local desiredVelocity = desiredInput * chainSpeed
			local turnAlpha = math.clamp(getMomentumChainAirTurnResponsiveness() * dt * 60, 0, 1)
			local steeredHorizontal = horizontal:Lerp(desiredVelocity, turnAlpha)
			local controlStrength = getMomentumChainAirControlStrength()
			if controlStrength > 0 then
				steeredHorizontal += desiredInput * (getBaseWalkSpeed() * controlStrength * dt * 60)
			end
			if steeredHorizontal.Magnitude > MIN_VECTOR_MAGNITUDE then
				horizontal = steeredHorizontal.Unit * chainSpeed
			end
		end

		dragUsed = getMomentumChainAirDrag()
		horizontal *= dragUsed ^ (dt * 60)
		limitUsed = getMaxMomentumChainSpeed()
		horizontal = clampHorizontal(horizontal, limitUsed)

		if horizontal.Magnitude < getMomentumChainMinSpeed() then
			clearChainMomentum("speed_low")
		elseif chainMomentum then
			chainMomentum.velocity = horizontal
			chainMomentum.lastAirborneAt = os.clock()
		end
	else
		if desiredInput.Magnitude > MIN_MOVE_MAGNITUDE then
			desiredInput = desiredInput.Unit
			local currentSpeed = horizontal.Magnitude
			if currentSpeed >= (tonumber(MovementConfig.MinAirSpeedToPreserve) or 8) then
				local desiredVelocity = desiredInput * currentSpeed
				local turnAlpha = math.clamp((tonumber(MovementConfig.AirTurnResponsiveness) or 0.025) * dt * 60, 0, 1)
				horizontal = horizontal:Lerp(desiredVelocity, turnAlpha)
			end

			local airControlStrength = math.max(0, tonumber(MovementConfig.AirControlStrength) or 0.04)
			horizontal += desiredInput * (getBaseWalkSpeed() * airControlStrength * dt * 60)
		end

		horizontal *= dragUsed ^ (dt * 60)
		horizontal = clampHorizontal(horizontal, limitUsed)
	end

	root.AssemblyLinearVelocity = Vector3.new(horizontal.X, currentVelocity.Y, horizontal.Z)
	faceMovementDirection(root, horizontal, dt, tonumber(MovementConfig.AirFaceTurnSpeed) or 10, "air")

	debugLog(
		"air_momentum",
		string.format(
			"air_momentum speedBefore=%.2f speedAfter=%.2f dragUsed=%.4f limitUsed=%.2f chainMomentum=%s",
			speedBefore,
			horizontal.Magnitude,
			dragUsed,
			limitUsed,
			tostring(chainState ~= nil)
		)
	)
	debugLog(
		"air_steer",
		string.format(
			"air_steer speedBefore=%.2f speedAfter=%.2f chainMomentum=%s",
			speedBefore,
			horizontal.Magnitude,
			tostring(chainState ~= nil)
		)
	)
end

local function updateGroundState(groundInfo: GroundInfo, now: number): boolean
	local justLanded = groundInfo.isGrounded and not wasGrounded
	if groundInfo.isGrounded ~= wasGrounded then
		debugLog(
			"ground_state",
			string.format(
				"Grounded=%s slope=%.2f hit=%s",
				tostring(groundInfo.isGrounded),
				groundInfo.slopeAngle,
				groundInfo.hitPart and groundInfo.hitPart:GetFullName() or "nil"
			)
		)
	end

	if groundInfo.isGrounded and not wasGrounded then
		landedAt = now
		if chainMomentum and isSlideInputHeld() then
			landingSlideResumeUntil = now + math.max(0, tonumber(MovementConfig.SlideLandingResumeGraceTime) or 0.25)
		else
			landingSlideResumeUntil = -math.huge
		end

		if MovementConfig.LandingMomentumCarry == true and currentRoot then
			local landingLimit = chainMomentum and getMaxMomentumChainSpeed() or getMaxAirHorizontalSpeed()
			local landingVelocity = clampHorizontal(
				getCurrentHorizontalVelocity(currentRoot),
				landingLimit
			)
			if landingVelocity.Magnitude >= (tonumber(MovementConfig.MinAirSpeedToPreserve) or 8) then
				landingMomentum = {
					velocity = landingVelocity,
					endsAt = now + math.max(0, tonumber(MovementConfig.LandingFrictionDuration) or 0.12),
				}
			else
				landingMomentum = nil
			end
		else
			landingMomentum = nil
		end
	elseif not groundInfo.isGrounded and wasGrounded then
		leftGroundTime = now
		landedAt = -math.huge
		if chainMomentum then
			chainMomentum.lastAirborneAt = now
		end
		if jumpsUsed <= 0 then
			jumpsUsed = 1
		end
	elseif not groundInfo.isGrounded and leftGroundTime == -math.huge then
		leftGroundTime = now
		if jumpsUsed <= 0 then
			jumpsUsed = 1
		end
	elseif groundInfo.isGrounded and landedAt == -math.huge then
		landedAt = now
	end

	if groundInfo.isGrounded then
		local landingResetDelay = math.max(0, tonumber(MovementConfig.LandingResetDelay) or 0.05)
		if now - landedAt >= landingResetDelay and now - lastJumpTime >= landingResetDelay then
			if jumpsUsed ~= 0 then
				debugLog("jump_reset", string.format("Jump count reset after landing: used=%d", jumpsUsed))
			end
			jumpsUsed = 0
			lastAirJumpTime = -math.huge
		end
	end

	wasGrounded = groundInfo.isGrounded
	lastGroundInfo = groundInfo
	return justLanded
end

local function tryStartLandingSlide(humanoid: Humanoid, root: BasePart, groundInfo: GroundInfo, now: number): boolean
	if MovementConfig.SlideLandingResumeEnabled ~= true then
		return false
	end
	if activeMotion or not chainMomentum or chainMomentum.canResumeSlide ~= true then
		return false
	end
	if not isSlideInputHeld() or now > landingSlideResumeUntil then
		return false
	end
	if not groundInfo.isGrounded or isSlideStateBlocked(humanoid) then
		return false
	end

	local carriedHorizontal = getStrongerHorizontal(chainMomentum.velocity, getCurrentHorizontalVelocity(root))
	local minCarrySpeed = math.max(0, tonumber(MovementConfig.SlideLandingMinCarrySpeed) or 10)
	if carriedHorizontal.Magnitude < minCarrySpeed then
		debugLog(
			"landing_slide_resume_blocked",
			string.format("Landing slide resume blocked: speed=%.2f min=%.2f", carriedHorizontal.Magnitude, minCarrySpeed)
		)
		clearChainMomentum("landing_slide_resume_speed_low")
		return false
	end

	local projectedCarry = projectOntoPlane(carriedHorizontal, groundInfo.normal)
	if projectedCarry.Magnitude <= MIN_MOVE_MAGNITUDE then
		debugLog("landing_slide_resume_blocked", "Landing slide resume blocked: projected carry too small.")
		clearChainMomentum("landing_slide_resume_projected_low")
		return false
	end

	local friction = math.clamp(tonumber(MovementConfig.SlideLandingFriction) or 0.995, 0.01, 1)
	projectedCarry *= friction
	projectedCarry = clampHorizontal(projectedCarry, getMaxMomentumChainSpeed())

	local downhillDot = 0
	local downhillDirection = getSlopeDownhillDirection(groundInfo.normal)
	if downhillDirection then
		downhillDot = math.clamp(projectedCarry.Unit:Dot(downhillDirection), -1, 1)
	end

	local started = startSlide(groundInfo, {
		bypassCooldown = MovementConfig.SlideLandingBypassCooldown == true,
		noFreshBoost = MovementConfig.SlideLandingNoFreshBoost == true,
		initialHorizontalVelocity = projectedCarry,
		sourceReason = "landing_resume",
		chainMomentum = true,
	})
	if not started then
		return false
	end

	chainMomentum.velocity = flatten(projectedCarry)
	chainMomentum.canResumeSlide = false
	landingSlideResumeUntil = -math.huge
	clearLandingMomentum()
	debugLog(
		"landing_slide_resume",
		string.format(
			"Landing slide resume: speed=%.2f slope=%.2f downhillDot=%.2f state=%s",
			projectedCarry.Magnitude,
			groundInfo.slopeAngle,
			downhillDot,
			tostring(groundInfo.humanoidState or humanoid:GetState())
		)
	)
	return true
end

local function launchSlideFromEdge(root: BasePart, motion: MotionState): boolean
	if MovementConfig.SlideEdgeLaunchEnabled ~= true or motion.edgeLaunched == true then
		return false
	end

	local launchVelocity = motion.lastSlideVelocity or (motion.direction * motion.speed)
	if launchVelocity.Magnitude <= MIN_MOVE_MAGNITUDE then
		return false
	end

	local multiplier = math.max(0, tonumber(MovementConfig.SlideEdgeLaunchSpeedMultiplier) or 1)
	local launchLimit = motion.chainMomentum == true and getMaxMomentumChainSpeed() or getMaxAirHorizontalSpeed()
	local horizontal = clampHorizontal(flatten(launchVelocity) * multiplier, launchLimit)
	local currentVelocity = root.AssemblyLinearVelocity
	if flatten(currentVelocity).Magnitude > horizontal.Magnitude then
		horizontal = clampHorizontal(flatten(currentVelocity), launchLimit)
	end

	local launchUpVelocity = tonumber(MovementConfig.SlideEdgeLaunchUpVelocity) or 6
	local yVelocity = math.max(currentVelocity.Y, launchVelocity.Y, launchUpVelocity)
	root.AssemblyLinearVelocity = Vector3.new(horizontal.X, yVelocity, horizontal.Z)
	motion.edgeLaunched = true
	if motion.chainMomentum == true then
		setChainMomentum(horizontal, os.clock())
	end

	debugLog(
		"slide_edge_launch",
		string.format("Slide edge launch: speed=%.2f y=%.2f", horizontal.Magnitude, yVelocity)
	)

	return true
end

local function bindCharacter(character: Model)
	disconnectAll(characterConnections)
	currentCharacter = character
	currentHumanoid = nil
	currentRoot = nil

	clearMotion()
	clearLandingMomentum()
	clearChainMomentum("character_bound")
	clearLowGravity()
	sprintHeld = false
	table.clear(slideHeldKeyCodes)
	dashReadyAt = 0
	slideReadyAt = 0
	wasGrounded = false
	lastGroundInfo = nil
	resetJumpTracking()

	task.defer(function(boundCharacter)
		if currentCharacter ~= boundCharacter then
			return
		end

		local humanoid = boundCharacter:WaitForChild("Humanoid", 5)
		local root = boundCharacter:WaitForChild("HumanoidRootPart", 5)
		if currentCharacter ~= boundCharacter then
			return
		end

		if humanoid and humanoid:IsA("Humanoid") then
			currentHumanoid = humanoid
			humanoid.CameraOffset = Vector3.zero
			if type(MovementConfig.SlideActiveAttribute) == "string" and MovementConfig.SlideActiveAttribute ~= "" then
				humanoid:SetAttribute(MovementConfig.SlideActiveAttribute, false)
			end
			connect(characterConnections, humanoid.Died, function()
				clearMotion()
				clearLandingMomentum()
				clearChainMomentum("humanoid_died")
				clearLowGravity()
				resetJumpTracking()
			end)
		end

		if root and root:IsA("BasePart") then
			currentRoot = root
		end
	end, character)

	connect(characterConnections, character.AncestryChanged, function(_, parent)
		if parent == nil and currentCharacter == character then
			clearMotion()
			clearLandingMomentum()
			clearChainMomentum("character_removed")
			clearLowGravity()
			resetJumpTracking()
			currentCharacter = nil
			currentHumanoid = nil
			currentRoot = nil
			wasGrounded = false
		end
	end)
end

local function updateMovement(dt: number)
	local character, humanoid, root = refreshCharacterReferences()
	if not character or not humanoid or not root then
		clearMotion()
		clearLandingMomentum()
		clearChainMomentum("missing_character")
		clearLowGravity()
		wasGrounded = false
		return
	end

	if humanoid.Health <= 0 then
		clearMotion()
		clearLandingMomentum()
		clearChainMomentum("humanoid_dead")
		clearLowGravity()
		wasGrounded = false
		return
	end

	local now = os.clock()
	local groundInfo = getGroundInfo(activeMotion ~= nil and activeMotion.kind == "slide")
	local justLanded = updateGroundState(groundInfo, now)

	if isMovementSuppressed() then
		clearMotion()
		clearLandingMomentum()
		clearChainMomentum("movement_suppressed")
		setLowGravityEnabled(root, false)
		return
	end

	syncHeldSprintState()
	updateLowGravity(humanoid, root, groundInfo)
	if justLanded then
		tryStartLandingSlide(humanoid, root, groundInfo, now)
	end

	if activeMotion then
		if activeMotion.character ~= character or activeMotion.root ~= root then
			clearMotion()
		elseif activeMotion.kind == "slide" then
			local slideGroundInfo = groundInfo
			if not slideGroundInfo.isGrounded then
				local graceTime = getSlideGroundGraceTime()
				if not activeMotion.groundLostAt then
					activeMotion.groundLostAt = now
					debugLog(
						"slide_ground_lost",
						string.format(
							"Slide temporarily lost ground: grace=%.2fs speed=%.2f state=%s",
							graceTime,
							activeMotion.speed,
							tostring(groundInfo.humanoidState or humanoid:GetState())
						)
					)
				end

				local timeWithoutGround = now - activeMotion.groundLostAt
				if timeWithoutGround > graceTime then
					if launchSlideFromEdge(root, activeMotion) then
						debugSlideEnd("lost_ground", string.format("duration=%.2f launched_from_edge=true", timeWithoutGround))
					else
						debugSlideEnd("lost_ground", string.format("duration=%.2f", timeWithoutGround))
						if activeMotion.chainMomentum == true then
							if chainMomentum then
								chainMomentum.lastAirborneAt = now
							end
						else
							clearChainMomentum("slide_lost_ground")
						end
					end
					clearMotion()
				else
					slideGroundInfo = {
						isGrounded = true,
						normal = activeMotion.lastGroundNormal or UP_VECTOR,
						hitPart = nil,
						slopeAngle = activeMotion.lastSlopeAngle or 0,
						hitPosition = nil,
						humanoidState = groundInfo.humanoidState,
					}
				end
			elseif activeMotion.groundLostAt then
				debugLog(
					"slide_ground_recovered",
					string.format(
						"Slide recovered ground after %.2fs: slope=%.2f state=%s",
						now - activeMotion.groundLostAt,
						slideGroundInfo.slopeAngle,
						tostring(slideGroundInfo.humanoidState or humanoid:GetState())
					)
				)
				activeMotion.groundLostAt = nil
			end

			if activeMotion and isSlideStateBlocked(humanoid) then
				debugSlideEnd("blocked_state", "humanoid state no longer allows sliding.")
				clearChainMomentum("slide_blocked_state")
				clearMotion()
			elseif activeMotion and activeMotion.holdEnabled == true
				and now >= (activeMotion.minEndsAt or activeMotion.endsAt)
				and not isSlideInputHeld()
			then
				debugSlideEnd("input_released", "slide input released after minimum duration.")
				clearChainMomentum("slide_input_released")
				clearMotion()
			elseif activeMotion then
				local projectedDirection = projectOntoPlane(activeMotion.direction, slideGroundInfo.normal)
				if projectedDirection.Magnitude <= MIN_MOVE_MAGNITUDE then
					debugSlideEnd("blocked_state", "slope projection became invalid.")
					clearChainMomentum("slide_projection_invalid")
					clearMotion()
				else
					activeMotion.direction = projectedDirection.Unit
					local slideInput = getCurrentMoveIntent(humanoid)
					if slideInput.Magnitude > MIN_MOVE_MAGNITUDE then
						local projectedMoveDirection = projectOntoPlane(slideInput, slideGroundInfo.normal)
						if projectedMoveDirection.Magnitude > MIN_MOVE_MAGNITUDE then
							local oldDirection = activeMotion.direction
							local targetDirection = projectedMoveDirection.Unit
							local steerStrength = math.max(0, tonumber(MovementConfig.SlideSteerStrength) or 0.42)
							local steerResponsiveness = math.max(0, tonumber(MovementConfig.SlideSteerResponsiveness) or 0.16)
							local maxTurnRate = math.max(0, tonumber(MovementConfig.SlideMaxTurnRate) or 7.5)
							local alpha = math.clamp(steerResponsiveness * dt * 60, 0, 1) * steerStrength
							alpha = math.min(alpha, math.clamp(maxTurnRate * dt, 0, 1))
							if oldDirection:Dot(targetDirection) < -0.35 then
								alpha *= 0.35
							end

							local steeredDirection = oldDirection:Lerp(targetDirection, alpha)
							if steeredDirection.Magnitude > MIN_VECTOR_MAGNITUDE then
								activeMotion.direction = steeredDirection.Unit
								debugLog(
									"slide_steer",
									string.format(
										"slide_steer inputDir=(%.2f, %.2f, %.2f) oldDir=(%.2f, %.2f, %.2f) newDir=(%.2f, %.2f, %.2f) speed=%.2f",
										targetDirection.X,
										targetDirection.Y,
										targetDirection.Z,
										oldDirection.X,
										oldDirection.Y,
										oldDirection.Z,
										activeMotion.direction.X,
										activeMotion.direction.Y,
										activeMotion.direction.Z,
										activeMotion.speed
									)
								)
							end
						end
					end
					local currentIsSlope = isAutoSlideSlope(slideGroundInfo)
					if activeMotion.lastWasOnSlope == true and not currentIsSlope and not activeMotion.surfaceTransitionUntil then
						activeMotion.surfaceTransitionUntil = now + math.max(0, tonumber(MovementConfig.SlideSurfaceTransitionGrace) or 0.2)
						debugLog(
							"slide_surface_transition",
							string.format("Slide entered flat carry grace: %.2fs", tonumber(MovementConfig.SlideSurfaceTransitionGrace) or 0.2)
						)
					elseif currentIsSlope then
						activeMotion.surfaceTransitionUntil = nil
					end

					local downhillDot = 0
					local slopeAccelerationApplied = 0
					if MovementConfig.SlopeSlideEnabled == true then
						local downhillDirection = getSlopeDownhillDirection(slideGroundInfo.normal)
						if downhillDirection then
							downhillDot = math.clamp(activeMotion.direction:Dot(downhillDirection), -1, 1)
						end
					end

					if downhillDot > 0.05 then
						local acceleration = math.max(0, tonumber(MovementConfig.SlopeAcceleration) or 22)
						local multiplier = math.max(0, tonumber(MovementConfig.DownhillSpeedGainMultiplier) or 0.65)
						slopeAccelerationApplied = acceleration * downhillDot * multiplier * dt
						activeMotion.speed += slopeAccelerationApplied
					elseif downhillDot < -0.05 then
						local deceleration = math.max(0, tonumber(MovementConfig.UphillDeceleration) or 18)
						local multiplier = math.max(0, tonumber(MovementConfig.UphillSlowdownMultiplier) or 1)
						slopeAccelerationApplied = -deceleration * -downhillDot * multiplier * dt
						activeMotion.speed += slopeAccelerationApplied
					else
						local inTransitionGrace = activeMotion.surfaceTransitionUntil ~= nil and now <= activeMotion.surfaceTransitionUntil
						local configuredFriction = tonumber(MovementConfig.FlatSlideFriction)
						if inTransitionGrace then
							configuredFriction = tonumber(MovementConfig.SlideSurfaceTransitionFriction)
						end
						local friction = math.clamp(configuredFriction or tonumber(MovementConfig.SlideFriction) or 0.999, 0.01, 1)
						activeMotion.speed *= friction ^ (dt * 60)
					end
					debugLog(
						"slide_accel",
						string.format(
							"slide_accel downhillDot=%.2f slopeAccelerationApplied=%.3f speed=%.2f",
							downhillDot,
							slopeAccelerationApplied,
							activeMotion.speed
						)
					)

					local slideSpeedLimit = getSlideSpeedLimit(activeMotion.chainMomentum == true)
					activeMotion.speed = math.clamp(activeMotion.speed, 0, slideSpeedLimit)
					local minSlideEndSpeed = math.max(0, tonumber(MovementConfig.MinSlideEndSpeed) or 3)
					if now - activeMotion.startedAt >= SLIDE_MIN_END_GRACE and activeMotion.speed <= minSlideEndSpeed then
						debugSlideEnd("speed_low", string.format("speed=%.2f min=%.2f", activeMotion.speed, minSlideEndSpeed))
						clearChainMomentum("speed_low")
						clearMotion()
					else
						local desiredVelocity = activeMotion.direction * activeMotion.speed
						if desiredVelocity.Magnitude > slideSpeedLimit then
							desiredVelocity = desiredVelocity.Unit * slideSpeedLimit
						end
						desiredVelocity = clampVelocityByHorizontal(desiredVelocity, slideSpeedLimit)

						local currentVelocity = root.AssemblyLinearVelocity
						local appliedVelocity = desiredVelocity
						if MovementConfig.SlidePreserveYVelocity ~= false then
							appliedVelocity = Vector3.new(desiredVelocity.X, currentVelocity.Y, desiredVelocity.Z)
						end

						root.AssemblyLinearVelocity = appliedVelocity
						faceMovementDirection(root, appliedVelocity, dt, tonumber(MovementConfig.SlideFaceTurnSpeed) or 14, "slide")
						activeMotion.lastSlideVelocity = appliedVelocity
						activeMotion.lastGroundNormal = slideGroundInfo.normal
						activeMotion.lastSlopeAngle = slideGroundInfo.slopeAngle
						activeMotion.lastWasOnSlope = currentIsSlope
						if activeMotion.chainMomentum == true and chainMomentum then
							chainMomentum.velocity = flatten(appliedVelocity)
						end
						humanoid.AutoRotate = false
						humanoid.CameraOffset = Vector3.new(0, -(tonumber(MovementConfig.SlideCameraDrop) or 1.15), 0)
						humanoid.WalkSpeed = 0
						debugLog(
							"slide_status",
							string.format(
								"Slide update: speed=%.2f slope=%.2f downhillDot=%.2f state=%s",
								activeMotion.speed,
								slideGroundInfo.slopeAngle,
								downhillDot,
								tostring(slideGroundInfo.humanoidState or humanoid:GetState())
							)
						)
					end
				end
			end
		elseif activeMotion.kind == "dash" then
			local currentVelocity = root.AssemblyLinearVelocity
			local dashVelocity = activeMotion.direction * activeMotion.speed
			root.AssemblyLinearVelocity = Vector3.new(dashVelocity.X, currentVelocity.Y, dashVelocity.Z)
			humanoid.AutoRotate = false
			humanoid.CameraOffset = Vector3.zero
			humanoid.WalkSpeed = 0
		end

		if activeMotion and now >= activeMotion.endsAt then
			if activeMotion.kind == "slide" then
				debugSlideEnd("hard_max", "hard max duration.")
				clearChainMomentum("slide_hard_max")
			end
			clearMotion()
		end

		if activeMotion then
			return
		end
	end

	humanoid.CameraOffset = Vector3.zero

	if groundInfo.isGrounded and chainMomentum and now > landingSlideResumeUntil then
		clearChainMomentum("landed_without_slide")
	end

	if groundInfo.isGrounded then
		humanoid.AutoRotate = true
		local moveIntent = getCurrentMoveIntent(humanoid)
		applyHeldMovementIntent(humanoid, moveIntent)
		local walkSpeed = getBaseWalkSpeed()
		if sprintHeld and moveIntent.Magnitude >= MIN_MOVE_MAGNITUDE then
			walkSpeed *= getSprintMultiplier()
		end
		humanoid.WalkSpeed = walkSpeed
		applyLandingMomentum(root, dt, now)
	else
		humanoid.AutoRotate = isAirStateBlocked(humanoid)
		applyAirMomentum(humanoid, root, dt)
	end
end

connect(connections, player.CharacterAdded, bindCharacter)

if player.Character then
	bindCharacter(player.Character)
end

connect(connections, UserInputService.InputBegan, function(input: InputObject, gameProcessedEvent: boolean)
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

	if slideKeyCodeLookup[keyCode] then
		setSlideKeyHeld(keyCode, true)
		startSlide(getGroundInfo(true))
	end
end)

connect(connections, UserInputService.InputEnded, function(input: InputObject)
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.LeftShift or keyCode == Enum.KeyCode.RightShift or keyCode == Enum.KeyCode.ButtonL3 then
		sprintHeld = false
	end

	if slideKeyCodeLookup[keyCode] then
		setSlideKeyHeld(keyCode, false)
	end
end)

connect(connections, UserInputService.JumpRequest, function()
	if isMovementSuppressed() then
		return
	end

	local _, humanoid, root = refreshCharacterReferences()
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local groundInfo = getGroundInfo(activeMotion ~= nil and activeMotion.kind == "slide")
	if activeMotion and activeMotion.kind == "slide" and groundInfo.isGrounded then
		local slideMotion = activeMotion
		if doSlideJump(humanoid, root, slideMotion, groundInfo, now) then
			return
		end
		clearMotion()
	end

	if groundInfo.isGrounded then
		jumpsUsed = math.max(jumpsUsed, 1)
		lastJumpTime = now
		return
	end
	if isAirStateBlocked(humanoid) then
		return
	end

	if leftGroundTime == -math.huge then
		leftGroundTime = now
	end
	if jumpsUsed <= 0 then
		jumpsUsed = 1
	end

	local maxJumps = getMaxJumpCount()
	local groundLeaveDelay = math.max(0, tonumber(MovementConfig.CanAirJumpAfterGroundLeaveDelay) or 0.12)
	local airJumpCooldown = math.max(0, tonumber(MovementConfig.AirJumpCooldown) or 0.22)
	if now - leftGroundTime < groundLeaveDelay then
		debugLog("air_jump_blocked", "Air jump blocked: waiting for ground leave debounce.")
		return
	end
	if now - lastAirJumpTime < airJumpCooldown then
		debugLog("air_jump_blocked", "Air jump blocked: cooldown active.")
		return
	end
	if jumpsUsed >= maxJumps then
		debugLog("air_jump_blocked", string.format("Air jump blocked: used=%d max=%d.", jumpsUsed, maxJumps))
		return
	end

	jumpsUsed += 1
	lastJumpTime = now
	lastAirJumpTime = now

	clearMotion()
	clearLandingMomentum()
	doAirJump(humanoid, root)
end)

connect(connections, RunService.Heartbeat, updateMovement)

connect(connections, script.Destroying, function()
	clearMotion()
	clearLandingMomentum()
	clearChainMomentum("script_destroying")
	clearLowGravity()
	sprintHeld = false
	table.clear(slideHeldKeyCodes)
	resetJumpTracking()
	currentCharacter = nil
	currentHumanoid = nil
	currentRoot = nil
	wasGrounded = false
	disconnectAll(characterConnections)
	disconnectAll(connections)
end)
