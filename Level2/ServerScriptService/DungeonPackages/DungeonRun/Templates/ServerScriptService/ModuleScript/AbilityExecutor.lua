local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript")
assert(moduleFolder and moduleFolder:IsA("Folder"), "[AbilityExecutor] ServerScriptService.ModuleScript folder is required")

local function requireModule(name: string)
	local module = moduleFolder:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "[AbilityExecutor] " .. name .. " ModuleScript is required")
	return require(module)
end

local AbilityGeometry = requireModule("AbilityGeometry")
local AbilityHazards = requireModule("AbilityHazards")
local DamageService = requireModule("DamageService")
local NpcService = requireModule("NpcService")

local AbilityExecutor = {}
AbilityExecutor.__index = AbilityExecutor

local DEFAULT_COLOR = Color3.fromRGB(255, 132, 82)

local function anyPlayersAlive(): boolean
	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and plr:GetAttribute("RunEnded") ~= true then
			return true
		end
	end
	return false
end

local function getAliveCombatPlayers()
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Parent and plr:GetAttribute("RunEnded") ~= true then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				out[#out + 1] = {
					player = plr,
					humanoid = hum,
					hrp = hrp,
				}
			end
		end
	end
	return out
end

function AbilityExecutor.new(options)
	assert(type(options) == "table", "[AbilityExecutor] options table is required")
	assert(typeof(options.abilityVfxFolder) == "Instance", "[AbilityExecutor] abilityVfxFolder is required")
	assert(typeof(options.runStarted) == "Instance", "[AbilityExecutor] runStarted BoolValue is required")
	assert(typeof(options.pauseState) == "Instance", "[AbilityExecutor] pauseState BoolValue is required")

	return setmetatable({
		abilityVfxFolder = options.abilityVfxFolder,
		raycastGround = options.raycastGround,
		runStarted = options.runStarted,
		pauseState = options.pauseState,
		spawnBurst = options.spawnBurst,
		elapsed = options.elapsed,
		runTimeLimit = tonumber(options.runTimeLimit) or 0,
	}, AbilityExecutor)
end

function AbilityExecutor:FlatVector(v: Vector3): Vector3
	return AbilityGeometry.FlatVector(v)
end

function AbilityExecutor:Groundify(pos: Vector3): Vector3
	return AbilityGeometry.Groundify(pos, self.raycastGround)
end

function AbilityExecutor:ApplyAbilityDamageToPlayer(player: Player, amount: number, context: {[string]: any}?)
	amount = math.max(1, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return
	end

	local damageContext = nil
	if typeof(context) == "table" then
		damageContext = {
			sourceType = context.sourceType,
		}
		if context.abilityId ~= nil then
			damageContext.abilityId = context.abilityId
		end
	end

	DamageService.Apply(player, amount, damageContext)
end

function AbilityExecutor:MakeTelegraphPart(name: string, color: Color3, transparency: number)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.CastShadow = false
	part.Color = color
	part.Transparency = transparency
	part.Parent = self.abilityVfxFolder
	return part
end

function AbilityExecutor:TelegraphCircle(center: Vector3, radius: number, duration: number, color: Color3?)
	local disk = self:MakeTelegraphPart("TelegraphCircle", color or DEFAULT_COLOR, 0.30)
	disk.Shape = Enum.PartType.Cylinder
	disk.Size = Vector3.new(radius * 2, 0.12, radius * 2)
	disk.CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(disk, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Transparency = 0.75,
		Size = Vector3.new(radius * 2.18, 0.12, radius * 2.18),
	}):Play()
	Debris:AddItem(disk, duration + 0.2)
	return disk
end

function AbilityExecutor:TelegraphLine(startPos: Vector3, endPos: Vector3, width: number, duration: number, color: Color3?)
	local dir = endPos - startPos
	local length = math.max(1, dir.Magnitude)
	local beam = self:MakeTelegraphPart("TelegraphLine", color or DEFAULT_COLOR, 0.36)
	beam.Size = Vector3.new(width, 0.18, length)
	beam.CFrame = CFrame.lookAt(startPos:Lerp(endPos, 0.5) + Vector3.new(0, 0.2, 0), endPos + Vector3.new(0, 0.2, 0))
	TweenService:Create(beam, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Transparency = 0.8,
		Size = Vector3.new(width * 1.08, 0.18, length),
	}):Play()
	Debris:AddItem(beam, duration + 0.2)
	return beam
end

function AbilityExecutor:BurstMarker(pos: Vector3, color: Color3?, scale: number?, duration: number?)
	local burst = self:MakeTelegraphPart("AbilityBurst", color or DEFAULT_COLOR, 0.16)
	burst.Shape = Enum.PartType.Ball
	local size = math.max(1, tonumber(scale) or 1)
	burst.Size = Vector3.new(size, size, size)
	burst.CFrame = CFrame.new(pos)
	TweenService:Create(burst, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(size * 2.2, size * 2.2, size * 2.2),
	}):Play()
	Debris:AddItem(burst, (duration or 0.35) + 0.1)
end

function AbilityExecutor:DamagePlayersInRadius(center: Vector3, radius: number, damage: number, context: {[string]: any}?)
	for _, info in ipairs(getAliveCombatPlayers()) do
		if AbilityGeometry.IsPointInRadius(info.hrp.Position, center, radius) then
			self:ApplyAbilityDamageToPlayer(info.player, damage, context)
		end
	end
end

function AbilityExecutor:DamagePlayersAlongLine(startPos: Vector3, endPos: Vector3, width: number, damage: number, context: {[string]: any}?)
	for _, info in ipairs(getAliveCombatPlayers()) do
		if AbilityGeometry.IsPointAlongLine(info.hrp.Position, startPos, endPos, width) then
			self:ApplyAbilityDamageToPlayer(info.player, damage, context)
		end
	end
end

function AbilityExecutor:DamagePlayersInCone(origin: Vector3, forward: Vector3, range: number, halfAngleDeg: number, damage: number, context: {[string]: any}?)
	for _, info in ipairs(getAliveCombatPlayers()) do
		if AbilityGeometry.IsPointInCone(info.hrp.Position, origin, forward, range, halfAngleDeg) then
			self:ApplyAbilityDamageToPlayer(info.player, damage, context)
		end
	end
end

function AbilityExecutor:CreateHazardZone(center: Vector3, radius: number, duration: number, tickRate: number, damage: number, color: Color3?, context: {[string]: any}?)
	return AbilityHazards.CreateZone({
		center = center,
		radius = radius,
		duration = duration,
		tickRate = tickRate,
		damage = damage,
		color = color,
		context = context,
		parent = self.abilityVfxFolder,
		runStarted = self.runStarted,
		pauseState = self.pauseState,
	})
end

function AbilityExecutor:ScheduleGameplayDelay(delaySeconds: number, callback: () -> ())
	task.spawn(function()
		local remaining = math.max(0, tonumber(delaySeconds) or 0)
		while remaining > 0 do
			if not self.runStarted.Value or not anyPlayersAlive() then
				return
			end
			if self.pauseState.Value then
				task.wait(0.1)
			else
				local step = math.min(0.1, remaining)
				task.wait(step)
				remaining -= step
			end
		end
		if self.pauseState.Value or not self.runStarted.Value or not anyPlayersAlive() then
			return
		end
		callback()
	end)
end

function AbilityExecutor:AbilityReady(controller, abilityId: string, now: number)
	return now >= (controller.globalCooldown or 0) and now >= ((controller.cooldowns and controller.cooldowns[abilityId]) or 0)
end

function AbilityExecutor:SetAbilityCooldown(controller, abilityId: string, now: number, cooldown: number, globalCooldown: number?)
	local scale = tonumber(controller.cooldownScale) or 1
	controller.cooldowns = controller.cooldowns or {}
	controller.cooldowns[abilityId] = now + (cooldown * scale)
	controller.globalCooldown = now + ((globalCooldown or 1.25) * scale)
end

function AbilityExecutor:CastTargetImpact(controller, targetInfo, now, cfg)
	local targetPos = targetInfo and self:Groundify(targetInfo.hrp.Position) or nil
	if not targetPos then
		return false
	end
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	self:TelegraphCircle(targetPos, cfg.radius, cfg.telegraph, cfg.color)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			self:BurstMarker(targetPos, cfg.color, cfg.radius * 0.45, 0.4)
			self:DamagePlayersInRadius(targetPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
		end
	end)
	return true
end

function AbilityExecutor:CastGroundSlam(controller, targetInfo, now, cfg)
	local center = NpcService.GetPosition(controller.model)
	if not center then
		return false
	end
	center = self:Groundify(center)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetInfo and targetInfo.hrp.Position or center)
	self:TelegraphCircle(center, cfg.radius, cfg.telegraph, cfg.color)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			local currentPos = NpcService.GetPosition(controller.model) or center
			self:BurstMarker(currentPos, cfg.color, cfg.radius * 0.55, 0.45)
			self:DamagePlayersInRadius(currentPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
		end
	end)
	return true
end

function AbilityExecutor:CastDash(controller, targetInfo, now, cfg)
	local startPos = NpcService.GetPosition(controller.model)
	local targetPos = targetInfo and self:Groundify(targetInfo.hrp.Position) or nil
	if not startPos or not targetPos then
		return false
	end
	local dir = self:FlatVector(targetPos - startPos)
	if dir.Magnitude <= 1e-4 then
		return false
	end
	dir = dir.Unit
	local dashDistance = math.min(cfg.distance, math.max(6, (targetPos - startPos).Magnitude - 2))
	local endPos = startPos + (dir * dashDistance)
	endPos = self:Groundify(endPos)
	self:TelegraphLine(startPos, endPos, cfg.width, cfg.telegraph, cfg.color)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			NpcService.SetPosition(controller.model, endPos, dir)
			self:BurstMarker(endPos, cfg.color, cfg.width * 0.8, 0.35)
			self:DamagePlayersAlongLine(startPos, endPos, cfg.width, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
		end
	end)
	return true
end

function AbilityExecutor:CastLineStrike(controller, targetInfo, now, cfg)
	local startPos = NpcService.GetPosition(controller.model)
	local targetPos = targetInfo and self:Groundify(targetInfo.hrp.Position) or nil
	if not startPos or not targetPos then
		return false
	end
	local dir = self:FlatVector(targetPos - startPos)
	if dir.Magnitude <= 1e-4 then
		return false
	end
	dir = dir.Unit
	local strikeDistance = math.min(cfg.distance, math.max(8, (targetPos - startPos).Magnitude))
	local endPos = self:Groundify(startPos + (dir * strikeDistance))
	self:TelegraphLine(startPos, endPos, cfg.width, cfg.telegraph, cfg.color)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			self:DamagePlayersAlongLine(startPos, endPos, cfg.width, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			self:BurstMarker(endPos, cfg.color, cfg.width * 0.7, 0.35)
		end
	end)
	return true
end

function AbilityExecutor:CastCone(controller, targetInfo, now, cfg)
	local startPos = NpcService.GetPosition(controller.model)
	local targetPos = targetInfo and self:Groundify(targetInfo.hrp.Position) or nil
	if not startPos or not targetPos then
		return false
	end
	local dir = self:FlatVector(targetPos - startPos)
	if dir.Magnitude <= 1e-4 then
		return false
	end
	self:TelegraphCircle(startPos + (dir.Unit * math.min(cfg.range * 0.45, 6)), cfg.range * 0.52, cfg.telegraph, cfg.color)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			self:DamagePlayersInCone(startPos, dir.Unit, cfg.range, cfg.angle, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			self:BurstMarker(startPos + (dir.Unit * math.min(cfg.range * 0.55, 7)), cfg.color, cfg.range * 0.20, 0.32)
		end
	end)
	return true
end

function AbilityExecutor:CastTripleCombo(controller, targetInfo, now, cfg)
	local startPos = NpcService.GetPosition(controller.model)
	local targetPos = targetInfo and self:Groundify(targetInfo.hrp.Position) or nil
	if not startPos or not targetPos then
		return false
	end
	local dir = self:FlatVector(targetPos - startPos)
	if dir.Magnitude <= 1e-4 then
		return false
	end
	NpcService.LockForAbility(controller.model, cfg.totalDuration, targetPos)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for _, hitDelay in ipairs(cfg.hitDelays) do
		self:ScheduleGameplayDelay(hitDelay, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				self:DamagePlayersInCone(startPos, dir.Unit, cfg.range, cfg.angle, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
				self:BurstMarker(startPos + (dir.Unit * math.min(cfg.range * 0.5, 6)), cfg.color, cfg.range * 0.16, 0.20)
			end
		end)
	end
	return true
end

function AbilityExecutor:CastArmorUp(controller, now, cfg)
	NpcService.SetIncomingDamageModifier(controller.model, cfg.damageTakenMult, cfg.duration)
	local pos = NpcService.GetPosition(controller.model)
	if pos then
		self:BurstMarker(pos, cfg.color, 5, 0.45)
	end
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	return true
end

function AbilityExecutor:CastVolley(controller, targetInfo, now, cfg)
	local targetPos = targetInfo and self:Groundify(targetInfo.hrp.Position) or nil
	if not targetPos then
		return false
	end
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for index = 1, cfg.count do
		local angle = ((index - 1) / math.max(1, cfg.count)) * math.pi * 2
		local impactPos = self:Groundify(targetPos + Vector3.new(math.cos(angle) * cfg.spread, 0, math.sin(angle) * cfg.spread))
		self:TelegraphCircle(impactPos, cfg.radius, cfg.telegraph, cfg.color)
		task.delay(cfg.telegraph, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				self:BurstMarker(impactPos, cfg.color, cfg.radius * 0.45, 0.35)
				self:DamagePlayersInRadius(impactPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			end
		end)
	end
	return true
end

function AbilityExecutor:CastTeleportStep(controller, targetInfo, now, cfg)
	local targetPos = targetInfo and self:Groundify(targetInfo.hrp.Position) or nil
	if not targetPos then
		return false
	end
	local offsetBase = self:FlatVector(targetPos - (NpcService.GetPosition(controller.model) or targetPos))
	if offsetBase.Magnitude <= 1e-4 then
		offsetBase = Vector3.new(1, 0, 0)
	end
	local side = Vector3.new(-offsetBase.Z, 0, offsetBase.X).Unit * (math.random() < 0.5 and -cfg.distance or cfg.distance)
	local endPos = self:Groundify(targetPos + side)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			NpcService.SetPosition(controller.model, endPos, self:FlatVector(targetPos - endPos))
			self:BurstMarker(endPos, cfg.color, cfg.radius * 0.55, 0.35)
			self:DamagePlayersInRadius(endPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
		end
	end)
	return true
end

function AbilityExecutor:CastHazard(controller, targetInfo, now, cfg)
	local targetPos = targetInfo and self:Groundify(targetInfo.hrp.Position) or nil
	if not targetPos then
		return false
	end
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	self:TelegraphCircle(targetPos, cfg.radius, cfg.telegraph, cfg.color)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			self:CreateHazardZone(
				targetPos,
				cfg.radius,
				cfg.duration,
				cfg.tickRate,
				math.floor(controller.baseDamage * cfg.damageMultiplier),
				cfg.color,
				{ sourceType = "hazard", abilityId = cfg.id }
			)
		end
	end)
	return true
end

function AbilityExecutor:CastSummon(controller, now, cfg)
	local bossPos = NpcService.GetPosition(controller.model)
	if not bossPos then
		return false
	end
	bossPos = self:Groundify(bossPos)
	NpcService.LockForAbility(controller.model, cfg.telegraph or 0.6, bossPos)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	self:ScheduleGameplayDelay(cfg.telegraph or 0.6, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			local elapsed = type(self.elapsed) == "function" and self.elapsed() or 0
			if type(self.spawnBurst) == "function" then
				self.spawnBurst(cfg.count, bossPos, math.max(elapsed, self.runTimeLimit - 60), "BossSummon")
			end
			self:BurstMarker(bossPos, cfg.color, 6, 0.5)
		end
	end)
	return true
end

function AbilityExecutor:CastShockwaveSequence(controller, targetInfo, now, cfg)
	local center = NpcService.GetPosition(controller.model)
	if not center then
		return false
	end
	center = self:Groundify(center)
	local longestDelay = 0
	for _, pulse in ipairs(cfg.pulses) do
		longestDelay = math.max(longestDelay, pulse.delay)
	end
	NpcService.LockForAbility(controller.model, longestDelay, targetInfo and targetInfo.hrp.Position or center)
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for _, pulse in ipairs(cfg.pulses) do
		self:TelegraphCircle(center, pulse.radius, pulse.delay, cfg.color)
		self:ScheduleGameplayDelay(pulse.delay, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				self:BurstMarker(center, cfg.color, pulse.radius * 0.35, 0.35)
				self:DamagePlayersInRadius(center, pulse.radius, math.floor(controller.baseDamage * pulse.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			end
		end)
	end
	return true
end

function AbilityExecutor:CastMeteorRain(controller, now, cfg)
	local players = getAliveCombatPlayers()
	if #players <= 0 then
		return false
	end
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for index = 1, cfg.count do
		local info = players[((index - 1) % #players) + 1]
		local impactPos = self:Groundify(info.hrp.Position + Vector3.new(math.random(-cfg.spread, cfg.spread), 0, math.random(-cfg.spread, cfg.spread)))
		self:TelegraphCircle(impactPos, cfg.radius, cfg.telegraph, cfg.color)
		task.delay(cfg.telegraph, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				self:BurstMarker(impactPos, cfg.color, cfg.radius * 0.55, 0.45)
				self:DamagePlayersInRadius(impactPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			end
		end)
	end
	return true
end

function AbilityExecutor:CastArenaPressure(controller, now, cfg)
	local players = getAliveCombatPlayers()
	if #players <= 0 then
		return false
	end
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for _, info in ipairs(players) do
		local offset = Vector3.new(math.random(-cfg.spread, cfg.spread), 0, math.random(-cfg.spread, cfg.spread))
		local center = self:Groundify(info.hrp.Position + offset)
		self:TelegraphCircle(center, cfg.radius, cfg.telegraph, cfg.color)
		task.delay(cfg.telegraph, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				self:CreateHazardZone(center, cfg.radius, cfg.duration, cfg.tickRate, math.floor(controller.baseDamage * cfg.damageMultiplier), cfg.color, { sourceType = "hazard", abilityId = cfg.id })
			end
		end)
	end
	return true
end

function AbilityExecutor:CastEnrage(controller, now, cfg)
	if controller.enraged then
		return false
	end
	controller.enraged = true
	controller.cooldownScale = cfg.cooldownScale
	controller.baseDamage *= cfg.damageMultiplier
	local bossPos = NpcService.GetPosition(controller.model)
	if bossPos then
		self:BurstMarker(bossPos, cfg.color, 8, 0.55)
	end
	self:SetAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	return true
end

function AbilityExecutor:TryCast(controller, targetInfo, now, cfg)
	if not self:AbilityReady(controller, cfg.id, now) then
		return false
	end
	if cfg.kind == "TargetImpact" then
		return self:CastTargetImpact(controller, targetInfo, now, cfg)
	elseif cfg.kind == "GroundSlam" then
		return self:CastGroundSlam(controller, targetInfo, now, cfg)
	elseif cfg.kind == "Dash" then
		return self:CastDash(controller, targetInfo, now, cfg)
	elseif cfg.kind == "LineStrike" then
		return self:CastLineStrike(controller, targetInfo, now, cfg)
	elseif cfg.kind == "Cone" then
		return self:CastCone(controller, targetInfo, now, cfg)
	elseif cfg.kind == "TripleCombo" then
		return self:CastTripleCombo(controller, targetInfo, now, cfg)
	elseif cfg.kind == "ArmorUp" then
		return self:CastArmorUp(controller, now, cfg)
	elseif cfg.kind == "Volley" then
		return self:CastVolley(controller, targetInfo, now, cfg)
	elseif cfg.kind == "TeleportStep" then
		return self:CastTeleportStep(controller, targetInfo, now, cfg)
	elseif cfg.kind == "Hazard" then
		return self:CastHazard(controller, targetInfo, now, cfg)
	elseif cfg.kind == "Summon" then
		return self:CastSummon(controller, now, cfg)
	elseif cfg.kind == "ShockwaveSequence" then
		return self:CastShockwaveSequence(controller, targetInfo, now, cfg)
	elseif cfg.kind == "MeteorRain" then
		return self:CastMeteorRain(controller, now, cfg)
	elseif cfg.kind == "ArenaPressure" then
		return self:CastArenaPressure(controller, now, cfg)
	elseif cfg.kind == "Enrage" then
		return self:CastEnrage(controller, now, cfg)
	end
	return false
end

return AbilityExecutor
