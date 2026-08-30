local RunService = game:GetService("RunService")

local SpellTargeting = require(script.Parent:WaitForChild("SpellTargeting"))

local SpellProjectiles = {}

local callbacks = nil
local activeProjectiles = {}
local heartbeatConnection = nil

local REQUIRED_CALLBACKS = {
	"broadcastProjectile",
	"extractVisualStats",
	"getEnemiesInRadius",
	"getEnemyPosition",
	"getNearestEnemy",
	"hitEnemy",
	"isPaused",
	"isPlayerRunActive",
}

local function validateCallbacks(newCallbacks)
	assert(typeof(newCallbacks) == "table", "[SpellProjectiles] callbacks table is required")
	for _, callbackName in ipairs(REQUIRED_CALLBACKS) do
		assert(typeof(newCallbacks[callbackName]) == "function", string.format("[SpellProjectiles] missing callback: %s", callbackName))
	end
end

local function stopLoopIfIdle()
	if #activeProjectiles > 0 or not heartbeatConnection then return end
	heartbeatConnection:Disconnect()
	heartbeatConnection = nil
end

local function updateHomingDirection(projectile, dt)
	if not projectile.homing or not projectile.target then return end
	local targetPos = callbacks.getEnemyPosition(projectile.target)
	if not targetPos then return end
	local desired = targetPos - projectile.pos
	if desired.Magnitude <= 0.01 then return end
	desired = desired.Unit
	local turnRate = math.max(0.1, projectile.homingTurnRate or 8)
	local alpha = math.clamp(1 - math.exp(-turnRate * dt), 0, 1)
	local blended = projectile.dir:Lerp(desired, alpha)
	if blended.Magnitude > 0.01 then projectile.dir = blended.Unit end
end

local function applyProjectileHit(projectile, enemy)
	if projectile.hit[enemy] then return end
	projectile.hit[enemy] = true
	callbacks.hitEnemy(projectile.player, enemy, projectile.damage, projectile.stats, projectile.pos, projectile.pos)

	local impactRadius = math.max(0, tonumber(projectile.stats and projectile.stats.impactRadius) or 0)
	if impactRadius > 0 then
		local multiplier = math.clamp(tonumber(projectile.stats.impactDamageMultiplier) or 0.72, 0, 1)
		for _, splashEnemy in ipairs(callbacks.getEnemiesInRadius(projectile.pos, impactRadius)) do
			if splashEnemy ~= enemy and not projectile.hit[splashEnemy] then
				projectile.hit[splashEnemy] = true
				callbacks.hitEnemy(projectile.player, splashEnemy, projectile.damage * multiplier, projectile.stats, projectile.pos, projectile.pos)
			end
		end
	end
end

local function stepProjectile(projectile, dt)
	if not callbacks.isPlayerRunActive(projectile.player) then return false end
	if callbacks.isPaused() then return true end

	local remainingDistance = projectile.range - projectile.traveled
	if remainingDistance <= 1e-4 then return false end

	updateHomingDirection(projectile, dt)
	local step = math.min(projectile.speed * dt, remainingDistance)
	projectile.traveled += step
	projectile.pos += projectile.dir * step

	local enemy = callbacks.getNearestEnemy(projectile.pos, projectile.collisionRadius)
	local enemyPos = enemy and callbacks.getEnemyPosition(enemy)
	if enemy and enemyPos and (enemyPos - projectile.pos).Magnitude <= projectile.collisionRadius and not projectile.hit[enemy] then
		applyProjectileHit(projectile, enemy)
		if projectile.remainingPierce <= 0 then return false end
		projectile.remainingPierce -= 1
	end

	return projectile.traveled + 1e-4 < projectile.range
end

local function stepProjectiles(dt)
	for index = #activeProjectiles, 1, -1 do
		if not stepProjectile(activeProjectiles[index], dt) then table.remove(activeProjectiles, index) end
	end
	stopLoopIfIdle()
end

local function ensureLoop()
	if heartbeatConnection then return end
	heartbeatConnection = RunService.Heartbeat:Connect(stepProjectiles)
end

function SpellProjectiles.Configure(newCallbacks)
	validateCallbacks(newCallbacks)
	callbacks = newCallbacks
end

function SpellProjectiles.Fire(config)
	assert(callbacks, "[SpellProjectiles] Configure must be called before Fire")
	assert(typeof(config) == "table", "[SpellProjectiles] projectile config is required")

	local origin = config.origin
	local direction = config.dir
	local speed = math.max(0, tonumber(config.speed) or 0)
	local maxRange = math.max(0, tonumber(config.range) or 0)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude <= 0.01 or speed <= 0 or maxRange <= 0 then return end

	direction = direction.Unit
	local unobstructedRange = SpellTargeting.GetUnobstructedDistance(origin, direction, maxRange)
	if unobstructedRange <= 0.05 then return end

	local stats = config.stats or {}
	callbacks.broadcastProjectile({
		origin = origin,
		dir = direction,
		speed = speed,
		range = unobstructedRange,
		startTime = workspace:GetServerTimeNow(),
		target = config.target,
		homing = config.homing == true,
		homingTurnRate = tonumber(config.homingTurnRate) or 8,
		stats = callbacks.extractVisualStats(stats),
	})

	table.insert(activeProjectiles, {
		player = config.player,
		pos = origin,
		dir = direction,
		speed = speed,
		range = unobstructedRange,
		damage = config.damage,
		stats = stats,
		traveled = 0,
		remainingPierce = math.max(0, math.floor(config.pierce or 0)),
		hit = {},
		collisionRadius = tonumber(stats.collisionRadius) or 3.3,
		target = config.target,
		homing = config.homing == true,
		homingTurnRate = tonumber(config.homingTurnRate) or 8,
	})
	ensureLoop()
end

function SpellProjectiles.GetActiveCount()
	return #activeProjectiles
end

return SpellProjectiles
