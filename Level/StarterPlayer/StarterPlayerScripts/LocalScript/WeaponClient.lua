-- WeaponClient.lua (StarterPlayerScripts)
-- Local floating weapon presentation. Damage and target selection remain server-authoritative.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local WeaponSwingVFX = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponSwingVFX")

local Profiles = {
	Sword = { offset = Vector3.new(2.4, 1.5, -0.3), width = 2.5, height = 1.2 },
	Scythe = { offset = Vector3.new(2.8, 1.7, -0.2), width = 3.4, height = 1.4 },
	Halberd = { offset = Vector3.new(2.9, 1.8, -0.2), width = 3.5, height = 1.5 },
	Claymore = { offset = Vector3.new(2.6, 1.6, -0.3), width = 3.0, height = 1.35 },
	Greataxe = { offset = Vector3.new(2.7, 1.6, -0.2), width = 3.2, height = 1.35 },
}
local DefaultProfile = Profiles.Sword

local visualModel: Model? = nil
local sourceTool: Tool? = nil
local renderConnection: RBXScriptConnection? = nil
local trail: Trail? = nil
local attack = nil
local animationClock = 0
local slashSide = -1

local function smoothstep(value: number): number
	value = math.clamp(value, 0, 1)
	return value * value * (3 - (2 * value))
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	local u = 1 - t
	return (u * u * a) + (2 * u * t * b) + (t * t * c)
end

local function isWeaponTool(instance: Instance): boolean
	return instance:IsA("Tool") and typeof(instance:GetAttribute("WeaponType")) == "string"
end

local function getActiveWeaponTool(): Tool?
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if isWeaponTool(child) then
				return child
			end
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if isWeaponTool(child) then
				return child
			end
		end
	end
	return nil
end

local function cleanupVisual()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if visualModel then
		visualModel:Destroy()
		visualModel = nil
	end
	sourceTool = nil
	trail = nil
	attack = nil
end

local function prepareParts(instance: Instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function setPrimaryPart(model: Model): BasePart?
	local handle = model:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then
		model.PrimaryPart = handle
		return handle
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			model.PrimaryPart = descendant
			return descendant
		end
	end
	return nil
end

local function addTrail(part: BasePart): Trail
	local axis = part.Size.Y >= part.Size.X and part.Size.Y >= part.Size.Z and "Y"
		or (part.Size.X >= part.Size.Z and "X" or "Z")
	local extent = axis == "Y" and part.Size.Y or (axis == "X" and part.Size.X or part.Size.Z)
	local direction = axis == "Y" and Vector3.yAxis or (axis == "X" and Vector3.xAxis or Vector3.zAxis)

	local attachment0 = Instance.new("Attachment")
	attachment0.Position = direction * extent * 0.45
	attachment0.Parent = part

	local attachment1 = Instance.new("Attachment")
	attachment1.Position = direction * extent * -0.45
	attachment1.Parent = part

	local createdTrail = Instance.new("Trail")
	createdTrail.Attachment0 = attachment0
	createdTrail.Attachment1 = attachment1
	createdTrail.Color = ColorSequence.new(Color3.fromRGB(235, 240, 255))
	createdTrail.Transparency = NumberSequence.new(0.1, 1)
	createdTrail.WidthScale = NumberSequence.new(1, 0)
	createdTrail.Lifetime = 0.14
	createdTrail.MinLength = 0.04
	createdTrail.FaceCamera = true
	createdTrail.LightEmission = 1
	createdTrail.Enabled = false
	createdTrail.Parent = part
	return createdTrail
end

local function buildVisual(tool: Tool): Model?
	local clone = tool:Clone()
	prepareParts(clone)

	local model = Instance.new("Model")
	model.Name = "WeaponVisualModel"
	for _, child in ipairs(clone:GetChildren()) do
		child.Parent = model
	end
	clone:Destroy()

	local primary = setPrimaryPart(model)
	if not primary then
		model:Destroy()
		return nil
	end

	trail = addTrail(primary)
	model.Parent = workspace
	return model
end

local function getIdleCFrame(root: BasePart, profile, weaponType: string): CFrame
	local bob = math.sin(animationClock * 2.8) * 0.17
	local rotation = weaponType == "Scythe" and -42 or -28
	return root.CFrame
		* CFrame.new(profile.offset + Vector3.new(0, bob, 0))
		* CFrame.Angles(math.rad(8), math.rad(90), math.rad(rotation))
end

local function getAttackCFrame(root: BasePart, profile, idle: CFrame, progress: number): (CFrame, boolean)
	local direction = attack.target - root.Position
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	direction = direction.Unit

	local up = Vector3.yAxis
	local side = Vector3.new(-direction.Z, 0, direction.X) * attack.side
	local target = attack.target + (up * profile.height)
	local windup = root.Position + (up * (profile.height + 0.4)) - (direction * 0.7) + (side * 2.5)
	local slashStart = target + (side * profile.width)
	local slashEnd = target - (side * profile.width)
	local control = target + (up * 1.7) - (direction * 0.4)

	if progress < 0.2 then
		local t = smoothstep(progress / 0.2)
		local windupCFrame = CFrame.lookAt(windup, target, up) * CFrame.Angles(0, math.rad(90), math.rad(-35 * attack.side))
		return (attack.startCFrame or idle):Lerp(windupCFrame, t), false
	elseif progress < 0.78 then
		local t = smoothstep((progress - 0.2) / 0.58)
		local position = bezier(slashStart, control, slashEnd, t)
		local nextPosition = bezier(slashStart, control, slashEnd, math.min(1, t + 0.03))
		local slashCFrame = CFrame.lookAt(position, nextPosition, up)
			* CFrame.Angles(0, math.rad(90), math.rad(-48 * attack.side))
		return slashCFrame, true
	end

	local t = smoothstep((progress - 0.78) / 0.22)
	local endCFrame = CFrame.lookAt(slashEnd, target, up) * CFrame.Angles(0, math.rad(90), math.rad(-35 * attack.side))
	return endCFrame:Lerp(idle, t), false
end

local function startRenderLoop(tool: Tool, model: Model)
	local weaponType = tool:GetAttribute("WeaponType")
	weaponType = typeof(weaponType) == "string" and weaponType or "Sword"
	local profile = Profiles[weaponType] or DefaultProfile
	local currentCFrame: CFrame? = nil

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") or not model.Parent then
			return
		end

		if not PauseState.Value then
			animationClock += math.min(deltaTime, 0.1)
		end

		local idle = getIdleCFrame(root, profile, weaponType)
		local targetCFrame = idle
		local trailEnabled = false
		if attack then
			local progress = (animationClock - attack.startedAt) / attack.duration
			if progress >= 1 then
				attack = nil
			else
				targetCFrame, trailEnabled = getAttackCFrame(root, profile, idle, progress)
			end
		end

		if trail then
			trail.Enabled = trailEnabled and not PauseState.Value
		end

		if not currentCFrame then
			currentCFrame = targetCFrame
		elseif attack then
			currentCFrame = targetCFrame
		else
			local alpha = 1 - math.exp(-12 * math.min(deltaTime, 0.1))
			currentCFrame = currentCFrame:Lerp(targetCFrame, alpha)
		end
		model:PivotTo(currentCFrame)
	end)
end

local function refresh()
	local tool = getActiveWeaponTool()
	if tool == sourceTool and visualModel then
		return
	end
	cleanupVisual()
	if not tool then
		return
	end

	sourceTool = tool
	visualModel = buildVisual(tool)
	if visualModel then
		startRenderLoop(tool, visualModel)
	else
		sourceTool = nil
	end
end

WeaponSwingVFX.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.pos) ~= "Vector3" or typeof(payload.lookAt) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or (root.Position - payload.lookAt).Magnitude > 6 then
		return
	end

	slashSide *= -1
	attack = {
		startedAt = animationClock,
		duration = 0.28,
		target = payload.pos,
		side = slashSide,
		startCFrame = visualModel and visualModel:GetPivot() or nil,
	}
end)

local function bindBackpack()
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	backpack.ChildAdded:Connect(function() task.defer(refresh) end)
	backpack.ChildRemoved:Connect(function() task.defer(refresh) end)
end

bindBackpack()
player.CharacterAdded:Connect(function(character)
	character.ChildAdded:Connect(function() task.defer(refresh) end)
	character.ChildRemoved:Connect(function() task.defer(refresh) end)
	task.delay(0.2, refresh)
end)
if player.Character then
	task.defer(refresh)
end
