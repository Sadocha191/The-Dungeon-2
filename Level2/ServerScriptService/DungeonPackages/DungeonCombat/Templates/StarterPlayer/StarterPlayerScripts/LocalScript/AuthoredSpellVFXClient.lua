local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts")
local VfxTemplatePlayer = require(moduleFolder:WaitForChild("VfxTemplatePlayer"))
local SpellVFXEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SpellVFXEvent")
local PauseState = ReplicatedStorage:FindFirstChild("PauseState") or ReplicatedStorage:WaitForChild("PauseState", 5)

local activeProjectiles = {}
local activeMovingZones = {}
local warnedMissingAssets = {}

local function isPaused()
	return PauseState ~= nil and PauseState.Value == true
end

local function getAnimationFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Animations")
end

local function resolveTemplate(name)
	if typeof(name) ~= "string" or name == "" then return nil end
	local folder = getAnimationFolder()
	local template = folder and folder:FindFirstChild(name)
	if not template and not warnedMissingAssets[name] then
		warnedMissingAssets[name] = true
		warn("[AuthoredSpellVFXClient] Missing ReplicatedStorage.Assets.Animations." .. name)
	end
	return template
end

local function resolveTargetRoot(target)
	if typeof(target) ~= "Instance" or not target.Parent then return nil end
	if target:IsA("BasePart") then return target end
	if target:IsA("Model") then
		local root = target:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then return root end
		if target.PrimaryPart then return target.PrimaryPart end
		return target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getTargetPosition(target)
	local root = resolveTargetRoot(target)
	return root and root.Position or nil
end

local function setWorldCFrame(instance, cframe)
	if not instance or not instance.Parent or typeof(cframe) ~= "CFrame" then return end
	if instance:IsA("BasePart") then
		instance.CFrame = cframe
	elseif instance:IsA("Model") then
		instance:PivotTo(cframe)
	end
end

local function applyScale(instance, scale)
	scale = tonumber(scale) or 1
	if math.abs(scale - 1) < 0.01 or not instance then return end
	if instance:IsA("Model") then
		pcall(function() instance:ScaleTo(scale) end)
	elseif instance:IsA("BasePart") then
		instance.Size *= scale
	end
end

local function playTemplate(name, cframe, duration, anchorTo, scale)
	local template = resolveTemplate(name)
	if not template then return nil end
	local clone = VfxTemplatePlayer.Play(template, cframe, {
		emissionDuration = math.max(0.05, tonumber(duration) or 0.25),
		cleanupDelay = math.max(0.5, (tonumber(duration) or 0.25) + 1.5),
		anchorTo = anchorTo,
	})
	if clone then applyScale(clone, scale) end
	return clone
end

local function spawnAuthoredCast(payload)
	local cframe = payload.cframe
	if typeof(cframe) ~= "CFrame" then return end
	playTemplate(payload.assetName, cframe, payload.duration or 0.45, nil, payload.scale)
end

local function spawnAuthoredImpact(payload)
	if typeof(payload.pos) ~= "Vector3" then return end
	local anchor = resolveTargetRoot(payload.target)
	local cframe = anchor and anchor.CFrame or CFrame.new(payload.pos)
	playTemplate(payload.assetName, cframe, payload.duration or 0.3, anchor, payload.scale)
end

local function spawnAuthoredProjectile(payload)
	local origin = payload.origin
	local direction = payload.dir
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude <= 0.01 then return end

	local speed = math.max(1, tonumber(payload.speed) or 80)
	local range = math.max(0.1, tonumber(payload.range) or 60)
	local startTime = tonumber(payload.startTime) or workspace:GetServerTimeNow()
	local age = math.max(0, workspace:GetServerTimeNow() - startTime)
	local traveled = math.min(range, speed * age)
	if traveled >= range then return end

	direction = direction.Unit
	local position = origin + direction * traveled
	local life = math.max(0.2, (range - traveled) / speed + 0.75)
	local clone = playTemplate(payload.assetName, CFrame.lookAt(position, position + direction), life, nil, payload.scale)
	if not clone then return end

	table.insert(activeProjectiles, {
		instance = clone,
		position = position,
		direction = direction,
		speed = speed,
		range = range,
		traveled = traveled,
		target = payload.target,
		homing = payload.homing == true,
		homingTurnRate = math.max(0.1, tonumber(payload.homingTurnRate) or 8),
	})
end

local function spawnMovingZone(payload)
	local startPos = payload.startPos
	local direction = payload.dir
	if typeof(startPos) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude <= 0.01 then return end

	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude <= 0.01 then direction = Vector3.new(0, 0, -1) else direction = direction.Unit end
	local duration = math.max(0.1, tonumber(payload.duration) or 4)
	local clone = playTemplate(payload.assetName, CFrame.lookAt(startPos, startPos + direction), duration, nil, payload.scale)
	if not clone then return end

	table.insert(activeMovingZones, {
		instance = clone,
		position = startPos,
		direction = direction,
		speed = math.max(0, tonumber(payload.speed) or 4),
		endTime = workspace:GetServerTimeNow() + duration,
		target = payload.target,
		followTarget = payload.followTarget == true,
	})
end

SpellVFXEvent.OnClientEvent:Connect(function(arg1)
	if typeof(arg1) ~= "table" then return end
	local action = arg1.action
	if action == "authoredCast" then
		spawnAuthoredCast(arg1)
	elseif action == "authoredImpact" then
		spawnAuthoredImpact(arg1)
	elseif action == "authoredProjectile" then
		spawnAuthoredProjectile(arg1)
	elseif action == "authoredMovingZone" then
		spawnMovingZone(arg1)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if isPaused() then return end

	for index = #activeProjectiles, 1, -1 do
		local projectile = activeProjectiles[index]
		if not projectile.instance or not projectile.instance.Parent then
			table.remove(activeProjectiles, index)
			continue
		end

		if projectile.homing then
			local targetPos = getTargetPosition(projectile.target)
			if targetPos then
				local desired = targetPos - projectile.position
				if desired.Magnitude > 0.01 then
					desired = desired.Unit
					local alpha = math.clamp(1 - math.exp(-projectile.homingTurnRate * dt), 0, 1)
					local blended = projectile.direction:Lerp(desired, alpha)
					if blended.Magnitude > 0.01 then projectile.direction = blended.Unit end
				end
			end
		end

		local step = projectile.speed * dt
		projectile.traveled += step
		if projectile.traveled >= projectile.range then
			projectile.instance:Destroy()
			table.remove(activeProjectiles, index)
			continue
		end
		projectile.position += projectile.direction * step
		setWorldCFrame(projectile.instance, CFrame.lookAt(projectile.position, projectile.position + projectile.direction))
	end

	local now = workspace:GetServerTimeNow()
	for index = #activeMovingZones, 1, -1 do
		local zone = activeMovingZones[index]
		if not zone.instance or not zone.instance.Parent or now >= zone.endTime then
			if zone.instance and zone.instance.Parent then zone.instance:Destroy() end
			table.remove(activeMovingZones, index)
			continue
		end
		if zone.followTarget then
			local targetPos = getTargetPosition(zone.target)
			if targetPos then
				local desired = Vector3.new(targetPos.X - zone.position.X, 0, targetPos.Z - zone.position.Z)
				if desired.Magnitude > 0.01 then zone.direction = desired.Unit end
			end
		end
		zone.position += zone.direction * zone.speed * dt
		setWorldCFrame(zone.instance, CFrame.lookAt(zone.position, zone.position + zone.direction))
	end
end)
