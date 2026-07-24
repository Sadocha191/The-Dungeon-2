local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VfxTemplatePlayer = {}

local DEFAULT_EMISSION_DURATION = 0.18
local DEFAULT_CLEANUP_DELAY = 3
local CAMERA_BIND_NAME = "VfxTemplatePlayerCameraImpulse"
local MAX_CAMERA_IMPULSES = 8

local activeCameraImpulses = {}
local cameraStepBound = false
local randomGenerator = Random.new()

local function readNumber(source, names, fallback)
	if source then
		for _, name in ipairs(names) do
			local attribute = source:GetAttribute(name)
			if typeof(attribute) == "number" then
				return attribute
			end

			local child = source:FindFirstChild(name)
			if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
				return child.Value
			end
		end
	end
	return fallback
end

local function ensureVfxFolder()
	local folder = Workspace:FindFirstChild("ClientVFX")
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = "ClientVFX"
	folder.Parent = Workspace
	return folder
end

local function setCollisionDefaults(part)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
end

local function placeClone(clone, worldCFrame, anchorTo)
	if clone:IsA("BasePart") then
		setCollisionDefaults(clone)
		clone.CFrame = worldCFrame

		if anchorTo and anchorTo:IsA("BasePart") then
			clone.Anchored = false
			clone.CFrame = anchorTo.CFrame

			local weld = Instance.new("WeldConstraint")
			weld.Name = "VfxAnchorWeld"
			weld.Part0 = anchorTo
			weld.Part1 = clone
			weld.Parent = clone
		else
			clone.Anchored = true
		end
		return
	end

	if clone:IsA("Model") then
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				setCollisionDefaults(descendant)
				descendant.Anchored = true
			end
		end
		clone:PivotTo(worldCFrame)
	end
end

local function resolveEmitCount(emitter, emissionDuration)
	local configured = readNumber(emitter, {
		"EmitCount",
		"Emit",
		"Amount",
		"BurstCount",
	}, nil)
	if configured and configured > 0 then
		return math.max(1, math.floor(configured + 0.5))
	end

	if emitter.Rate > 0 then
		return math.clamp(math.floor((emitter.Rate * emissionDuration) + 0.5), 1, 120)
	end
	return 1
end

local function startVisualObjects(clone, emissionDuration)
	local longestLifetime = emissionDuration
	local longestSound = 0

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			longestLifetime = math.max(longestLifetime, emissionDuration + descendant.Lifetime.Max)
			if descendant.Enabled then
				task.delay(emissionDuration, function()
					if descendant.Parent then
						descendant.Enabled = false
					end
				end)
			else
				descendant:Emit(resolveEmitCount(descendant, emissionDuration))
			end
		elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = true
			task.delay(emissionDuration, function()
				if descendant.Parent then
					descendant.Enabled = false
				end
			end)
		elseif descendant:IsA("Sound") then
			descendant:Play()
			longestSound = math.max(longestSound, descendant.TimeLength)
		end
	end

	return math.max(longestLifetime + 0.25, longestSound + 0.25)
end

local function bindCameraStep()
	if cameraStepBound or not RunService:IsClient() then
		return
	end
	cameraStepBound = true

	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		if #activeCameraImpulses == 0 then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local now = os.clock()
		local positionOffset = Vector3.zero
		local rotationOffset = Vector3.zero

		for index = #activeCameraImpulses, 1, -1 do
			local impulse = activeCameraImpulses[index]
			local alpha = (now - impulse.startedAt) / impulse.duration
			if alpha >= 1 then
				table.remove(activeCameraImpulses, index)
			else
				alpha = math.clamp(alpha, 0, 1)
				local fade = (1 - alpha) * (1 - alpha)
				local sampleTime = now * impulse.frequency
				local seed = impulse.seed
				local noiseX = math.noise(sampleTime, seed, 0)
				local noiseY = math.noise(sampleTime, seed, 11)
				local noiseZ = math.noise(sampleTime, seed, 23)

				positionOffset += Vector3.new(noiseX, noiseY, noiseZ) * impulse.positionMagnitude * fade
				rotationOffset += Vector3.new(noiseY, noiseZ, noiseX) * math.rad(impulse.rotationDegrees) * fade
			end
		end

		if positionOffset.Magnitude > 0 or rotationOffset.Magnitude > 0 then
			camera.CFrame = camera.CFrame
				* CFrame.new(positionOffset)
				* CFrame.Angles(rotationOffset.X, rotationOffset.Y, rotationOffset.Z)
		end
	end)
end

function VfxTemplatePlayer.PlayCamera(cameraData, fallback)
	if not RunService:IsClient() then
		return
	end

	fallback = fallback or {}
	local duration = math.max(0.05, readNumber(cameraData, {
		"Duration",
		"Time",
		"ShakeDuration",
	}, fallback.duration or 0.2))
	local positionMagnitude = math.max(0, readNumber(cameraData, {
		"PositionMagnitude",
		"TranslationMagnitude",
		"PositionAmplitude",
		"Magnitude",
	}, fallback.positionMagnitude or 0.1))
	local rotationDegrees = math.max(0, readNumber(cameraData, {
		"RotationMagnitude",
		"RotationAmplitude",
		"RotationDegrees",
		"Rotation",
	}, fallback.rotationDegrees or 1.2))
	local frequency = math.max(1, readNumber(cameraData, {
		"Frequency",
		"Roughness",
		"Speed",
	}, fallback.frequency or 26))

	if positionMagnitude <= 0 and rotationDegrees <= 0 then
		return
	end

	while #activeCameraImpulses >= MAX_CAMERA_IMPULSES do
		table.remove(activeCameraImpulses, 1)
	end

	table.insert(activeCameraImpulses, {
		startedAt = os.clock(),
		duration = duration,
		positionMagnitude = positionMagnitude,
		rotationDegrees = rotationDegrees,
		frequency = frequency,
		seed = randomGenerator:NextNumber(-1000, 1000),
	})
	bindCameraStep()
end

function VfxTemplatePlayer.Play(template, worldCFrame, options)
	if not template or typeof(template) ~= "Instance" then
		return nil
	end
	if typeof(worldCFrame) ~= "CFrame" then
		return nil
	end

	options = options or {}
	local clone = template:Clone()
	clone.Name = template.Name .. "Runtime"
	clone.Parent = ensureVfxFolder()
	placeClone(clone, worldCFrame, options.anchorTo)

	local emissionDuration = math.max(0.01, tonumber(options.emissionDuration)
		or readNumber(template, { "EmissionDuration", "Duration" }, DEFAULT_EMISSION_DURATION))
	local visualLifetime = startVisualObjects(clone, emissionDuration)
	local cleanupDelay = math.max(0.1, tonumber(options.cleanupDelay) or visualLifetime or DEFAULT_CLEANUP_DELAY)

	if options.playCamera == true then
		local cameraData = template:FindFirstChild("CameraData", true)
		VfxTemplatePlayer.PlayCamera(cameraData, options.cameraFallback)
	end

	Debris:AddItem(clone, cleanupDelay)
	return clone
end

return VfxTemplatePlayer
