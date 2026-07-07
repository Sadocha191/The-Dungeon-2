local SpellSustained = {}

local callbacks = nil

local REQUIRED_CALLBACKS = {
	"broadcastBeam",
	"broadcastRing",
	"distancePointToSegment",
	"extractVisualStats",
	"getAllEnemies",
	"getDurationMult",
	"getEnemiesInRadius",
	"getEnemyPosition",
	"hitEnemy",
	"isPlayerRunActive",
	"pickPriorityEnemy",
	"spellClock",
}

local function validateCallbacks(newCallbacks)
	assert(typeof(newCallbacks) == "table", "[SpellSustained] callbacks table is required")
	for _, callbackName in ipairs(REQUIRED_CALLBACKS) do
		assert(
			typeof(newCallbacks[callbackName]) == "function",
			string.format("[SpellSustained] missing callback: %s", callbackName)
		)
	end
end

local function getBeamImpactPosition(enemyPos, origin, beamEnd)
	local impactPos = enemyPos
	if enemyPos then
		local ab = beamEnd - origin
		local denom = ab:Dot(ab)
		if denom > 1e-4 then
			local t = math.clamp(((enemyPos - origin):Dot(ab)) / denom, 0, 1)
			impactPos = origin + (ab * t)
		end
	end
	return impactPos
end

function SpellSustained.Configure(newCallbacks)
	validateCallbacks(newCallbacks)
	callbacks = newCallbacks
end

function SpellSustained.RunZone(config)
	assert(callbacks, "[SpellSustained] Configure must be called before RunZone")
	assert(typeof(config) == "table", "[SpellSustained] zone config is required")

	local plr = config.player
	local stats = config.stats or {}
	local origin = config.origin
	local center = origin
	if stats.spawnAtEnemy then
		local target = callbacks.pickPriorityEnemy(origin, math.max(70, stats.range or 0))
		local targetPos = target and callbacks.getEnemyPosition(target)
		if targetPos then
			center = targetPos
		end
	end

	local radius = stats.radius or 6
	local duration = (stats.duration or 3) * callbacks.getDurationMult(plr)
	local tickRate = stats.tickRate or 0.45
	local tickDamage = stats.damage * math.max(0.3, tickRate)
	callbacks.broadcastRing({
		pos = center,
		radius = radius,
		duration = duration,
		stats = callbacks.extractVisualStats(stats),
	})

	local endAt = callbacks.spellClock() + duration
	task.spawn(function()
		while callbacks.spellClock() < endAt do
			if not callbacks.isPlayerRunActive(plr) then
				break
			end
			for _, enemy in ipairs(callbacks.getEnemiesInRadius(center, radius)) do
				callbacks.hitEnemy(plr, enemy, tickDamage, stats, center, callbacks.getEnemyPosition(enemy))
			end
			task.wait(tickRate)
		end
	end)
end

function SpellSustained.RunBeam(config)
	assert(callbacks, "[SpellSustained] Configure must be called before RunBeam")
	assert(typeof(config) == "table", "[SpellSustained] beam config is required")

	local plr = config.player
	local stats = config.stats or {}
	local origin = config.origin
	local target = callbacks.pickPriorityEnemy(config.targetSearchPosition, stats.range or 60)
	local targetPos = target and callbacks.getEnemyPosition(target)
	local direction = targetPos and (targetPos - origin) or config.fallbackDirection
	if direction.Magnitude <= 0.01 then
		return
	end
	direction = direction.Unit

	local range = stats.range or 50
	local width = stats.width or 4
	local duration = stats.duration or 1.5
	local tickRate = stats.tickRate or 0.18
	local beamDamage = stats.damage * math.max(0.6, tickRate * 4)
	callbacks.broadcastBeam({
		origin = origin,
		dir = direction,
		range = range,
		width = width,
		duration = duration,
		stats = callbacks.extractVisualStats(stats),
	})

	local endAt = callbacks.spellClock() + duration
	task.spawn(function()
		while callbacks.spellClock() < endAt do
			if not callbacks.isPlayerRunActive(plr) then
				break
			end
			local hitThisTick = {}
			local beamEnd = origin + (direction * range)
			for _, enemy in ipairs(callbacks.getAllEnemies()) do
				local enemyPos = callbacks.getEnemyPosition(enemy)
				if enemyPos and not hitThisTick[enemy] and callbacks.distancePointToSegment(enemyPos, origin, beamEnd) <= (width * 0.5) then
					hitThisTick[enemy] = true
					callbacks.hitEnemy(plr, enemy, beamDamage, stats, origin, getBeamImpactPosition(enemyPos, origin, beamEnd))
				end
			end
			task.wait(tickRate)
		end
	end)
end

return SpellSustained
