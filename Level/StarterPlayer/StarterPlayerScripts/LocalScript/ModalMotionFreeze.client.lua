local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local pauseState = ReplicatedStorage:WaitForChild("PauseState")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local ModalUiState = require(moduleFolder:WaitForChild("ModalUiState"))

local HORIZONTAL_RESUME_HOLD_SECONDS = 0.14
local MIN_RESUME_SPEED = 1

local frozenState = nil
local resumeState = nil
local stateSerial = 0

local function getCharacterParts()
	local character = player.Character
	if not character or not character.Parent then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return character, nil, nil
	end

	return character, humanoid, root
end

local function isBlocked(): boolean
	return pauseState.Value == true or ModalUiState.IsBlockingUiOpen(playerGui)
end

local function beginFreeze()
	if frozenState then
		return
	end

	local character, humanoid, root = getCharacterParts()
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	stateSerial += 1
	resumeState = nil
	frozenState = {
		serial = stateSerial,
		character = character,
		humanoid = humanoid,
		root = root,
		cframe = root.CFrame,
		linearVelocity = root.AssemblyLinearVelocity,
		angularVelocity = root.AssemblyAngularVelocity,
		wasAnchored = root.Anchored,
		autoRotate = humanoid.AutoRotate,
	}

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	humanoid.AutoRotate = false
end

local function finishFreeze()
	local state = frozenState
	frozenState = nil
	if not state then
		return
	end

	stateSerial += 1
	local serial = stateSerial
	local character, humanoid, root = getCharacterParts()
	if character ~= state.character or humanoid ~= state.humanoid or root ~= state.root or humanoid.Health <= 0 then
		if state.root and state.root.Parent and not state.wasAnchored then
			state.root.Anchored = false
		end
		return
	end

	root.CFrame = state.cframe
	root.Anchored = state.wasAnchored
	humanoid.AutoRotate = state.autoRotate

	if state.wasAnchored then
		return
	end

	root.AssemblyLinearVelocity = state.linearVelocity
	root.AssemblyAngularVelocity = state.angularVelocity

	local horizontal = Vector3.new(state.linearVelocity.X, 0, state.linearVelocity.Z)
	if horizontal.Magnitude >= MIN_RESUME_SPEED then
		resumeState = {
			serial = serial,
			character = character,
			root = root,
			horizontalVelocity = horizontal,
			angularVelocity = state.angularVelocity,
			untilTime = os.clock() + HORIZONTAL_RESUME_HOLD_SECONDS,
		}
	else
		resumeState = nil
	end
end

local function maintainFreeze()
	local state = frozenState
	if not state then
		return
	end

	local character, humanoid, root = getCharacterParts()
	if character ~= state.character or humanoid ~= state.humanoid or root ~= state.root or humanoid.Health <= 0 then
		frozenState = nil
		resumeState = nil
		if state.root and state.root.Parent and not state.wasAnchored then
			state.root.Anchored = false
		end
		return
	end

	root.CFrame = state.cframe
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	humanoid.AutoRotate = false
end

local function maintainResumeMomentum()
	local state = resumeState
	if not state then
		return
	end
	if state.serial ~= stateSerial or isBlocked() or os.clock() >= state.untilTime then
		resumeState = nil
		return
	end

	local character, humanoid, root = getCharacterParts()
	if character ~= state.character or root ~= state.root or not humanoid or humanoid.Health <= 0 or root.Anchored then
		resumeState = nil
		return
	end

	local currentVelocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(
		state.horizontalVelocity.X,
		currentVelocity.Y,
		state.horizontalVelocity.Z
	)
	root.AssemblyAngularVelocity = state.angularVelocity
end

RunService.PreSimulation:Connect(function()
	local blocked = isBlocked()
	if blocked then
		beginFreeze()
		maintainFreeze()
	elseif frozenState then
		finishFreeze()
	else
		maintainResumeMomentum()
	end
end)

player.CharacterAdded:Connect(function()
	stateSerial += 1
	frozenState = nil
	resumeState = nil
end)

script.Destroying:Connect(function()
	stateSerial += 1
	resumeState = nil
	local state = frozenState
	frozenState = nil
	if state and state.root and state.root.Parent and not state.wasAnchored then
		state.root.Anchored = false
	end
end)
