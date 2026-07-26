local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local runStarted = ReplicatedStorage:WaitForChild("RunStarted")
local pauseState = ReplicatedStorage:WaitForChild("PauseState")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local MovementConfig = require(moduleFolder:WaitForChild("MovementConfig"))

local RECOVERY_WINDOW = 1
local ZERO_SPEED_THRESHOLD = 0.1
local DEFAULT_BASE_WALK_SPEED = 21

local characterConnections = {}
local currentHumanoid = nil
local recoveryUntil = -math.huge
local lastSlideActiveAt = -math.huge
local destroyed = false
local characterAddedConnection = nil
local heartbeatConnection = nil

local function disconnectCharacterConnections()
	for index = #characterConnections, 1, -1 do
		characterConnections[index]:Disconnect()
		characterConnections[index] = nil
	end
end

local function getBaseWalkSpeed()
	local baseWalkSpeed = player:GetAttribute("BaseWalkSpeed")
	if typeof(baseWalkSpeed) ~= "number" then
		baseWalkSpeed = DEFAULT_BASE_WALK_SPEED
	end

	local movementMultiplier = player:GetAttribute("RunStat_MovementSpeed")
	if typeof(movementMultiplier) ~= "number" then
		movementMultiplier = 1
	end

	return baseWalkSpeed * math.max(0.25, movementMultiplier)
end

local function isRunActive()
	return runStarted.Value == true
		and pauseState.Value ~= true
		and player:GetAttribute("RunEnded") ~= true
end

local function recoverSwimmingMovement()
	local humanoid = currentHumanoid
	if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
		return
	end
	if os.clock() > recoveryUntil or not isRunActive() then
		return
	end
	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		return
	end
	if humanoid.WalkSpeed > ZERO_SPEED_THRESHOLD then
		return
	end

	humanoid.AutoRotate = true
	humanoid.CameraOffset = Vector3.zero
	humanoid.WalkSpeed = getBaseWalkSpeed()

	local slideAttribute = MovementConfig.SlideActiveAttribute
	if type(slideAttribute) == "string" and slideAttribute ~= "" then
		humanoid:SetAttribute(slideAttribute, false)
	end
end

local function bindCharacter(character)
	if destroyed then
		return
	end
	disconnectCharacterConnections()
	currentHumanoid = nil
	recoveryUntil = -math.huge
	lastSlideActiveAt = -math.huge

	local humanoid = character:WaitForChild("Humanoid", 5)
	if destroyed or not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	currentHumanoid = humanoid

	local slideAttribute = MovementConfig.SlideActiveAttribute
	if type(slideAttribute) == "string" and slideAttribute ~= "" then
		table.insert(characterConnections, humanoid:GetAttributeChangedSignal(slideAttribute):Connect(function()
			if humanoid:GetAttribute(slideAttribute) == true then
				lastSlideActiveAt = os.clock()
			end
		end))
		if humanoid:GetAttribute(slideAttribute) == true then
			lastSlideActiveAt = os.clock()
		end
	end

	table.insert(characterConnections, humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Swimming then
			local now = os.clock()
			local slideWasRecent = (now - lastSlideActiveAt) <= RECOVERY_WINDOW
			local slideIsActive = type(slideAttribute) == "string"
				and slideAttribute ~= ""
				and humanoid:GetAttribute(slideAttribute) == true
			if slideWasRecent or slideIsActive then
				recoveryUntil = now + RECOVERY_WINDOW
				task.defer(recoverSwimmingMovement)
			end
		else
			recoveryUntil = -math.huge
		end
	end))

	table.insert(characterConnections, humanoid.Died:Connect(function()
		recoveryUntil = -math.huge
	end))
end

characterAddedConnection = player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end

heartbeatConnection = RunService.Heartbeat:Connect(function()
	recoverSwimmingMovement()
end)

script.Destroying:Connect(function()
	destroyed = true
	if characterAddedConnection then
		characterAddedConnection:Disconnect()
		characterAddedConnection = nil
	end
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	disconnectCharacterConnections()
	currentHumanoid = nil
end)
