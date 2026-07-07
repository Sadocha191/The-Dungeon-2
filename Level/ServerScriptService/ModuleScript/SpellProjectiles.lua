local RunService = game:GetService("RunService")

local SpellProjectiles = {}

local callbacks = nil
local activeProjectiles = {}
local heartbeatConnection = nil

local REQUIRED_CALLBACKS = {
	"broadcastProjectile",
	"extractVisualStats",
	"getEnemyPosition",
	"getNearestEnemy",
	"hitEnemy",
	"isPaused",
	"isPlayerRunActive",
}

local function validateCallbacks(newCallbacks)
	assert(typeof(newCallbacks) == "table", "[SpellProjectiles] callbacks table is required")
	for _, callbackName in ipairs(REQUIRED_CALLBACKS) do
		assert(
			typeof(newCallbacks[callbackName]) == "function",
			string.format("[SpellProjectiles] missing callback: %s", callbackName)
		)
	end
end

local function stopLoopIfIdle()
	if #activeProjectiles > 0 or not heartbeatConnection then
		return
	end

	heartbeatConnection:Disconnect()
	heartbeatConnection = nil
end

local function removeProjectile(index)
	table.remove(activeProjectiles, index)
end

local function stepProjectile(projectile, dt)
	if not callbacks.isPlayerRunActive(projectile.player) then
		return false
	end
	if callbacks.isPaused() then
		return true
	end

	local step = projectile.speed * dt
	projectile.traveled += step
	projectile.pos += projectile.dir * step

	local enemy = callbacks.getNearestEnemy(projectile.pos, projectile.collisionRadius)
	local enemyPos = enemy and callbacks.getEnemyPosition(enemy)
	if enemy and enemyPos and (enemyPos - projectile.pos).Magnitude <= projectile.collisionRadius and not projectile.hit[enemy] then
		projectile.hit[enemy] = true
		callbacks.hitEnemy(projectile.player, enemy, projectile.damage, projectile.stats, projectile.pos, projectile.pos)
		if projectile.remainingPierce <= 0 then
			return false
		end
		projectile.remainingPierce -= 1
	end

	return projectile.traveled < projectile.range
end

local function stepProjectiles(dt)
	for index = #activeProjectiles, 1, -1 do
		if not stepProjectile(activeProjectiles[index], dt) then
			removeProjectile(index)
		end
	end

	stopLoopIfIdle()
end

local function ensureLoop()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(stepProjectiles)
end

function SpellProjectiles.Configure(newCallbacks)
	validateCallbacks(newCallbacks)
	callbacks = newCallbacks
end

function SpellProjectiles.Fire(config)
	assert(callbacks, "[SpellProjectiles] Configure must be called before Fire")
	assert(typeof(config) == "table", "[SpellProjectiles] projectile config is required")

	local stats = config.stats or {}
	callbacks.broadcastProjectile({
		origin = config.origin,
		dir = config.dir,
		speed = config.speed,
		range = config.range,
		startTime = workspace:GetServerTimeNow(),
		stats = callbacks.extractVisualStats(stats),
	})

	table.insert(activeProjectiles, {
		player = config.player,
		pos = config.origin,
		dir = config.dir,
		speed = config.speed,
		range = config.range,
		damage = config.damage,
		stats = stats,
		traveled = 0,
		remainingPierce = math.max(0, math.floor(config.pierce or 0)),
		hit = {},
		collisionRadius = stats.element == "Physical" and 3.6 or 3.3,
	})
	ensureLoop()
end

function SpellProjectiles.GetActiveCount()
	return #activeProjectiles
end

return SpellProjectiles
