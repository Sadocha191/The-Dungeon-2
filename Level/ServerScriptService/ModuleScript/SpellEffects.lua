local SpellEffects = {}

local callbacks = nil

local REQUIRED_CALLBACKS = {
	"addImpulse",
	"applyFreeze",
	"applySlow",
	"getDurationMult",
	"getEnemyPosition",
	"isEnemyAlive",
	"safeDamage",
	"spellClock",
}

local function validateCallbacks(newCallbacks)
	assert(typeof(newCallbacks) == "table", "[SpellEffects] callbacks table is required")
	for _, callbackName in ipairs(REQUIRED_CALLBACKS) do
		assert(
			typeof(newCallbacks[callbackName]) == "function",
			string.format("[SpellEffects] missing callback: %s", callbackName)
		)
	end
end

local function isBossEnemy(model)
	return model and (model:GetAttribute("IsBoss") == true or string.sub(model.Name, 1, 5) == "Boss_")
end

local function isEliteEnemy(model)
	return model and (model:GetAttribute("IsElite") == true or isBossEnemy(model))
end

local function applyTimedDot(plr, enemy, dps, duration)
	local endAt = callbacks.spellClock() + duration
	task.spawn(function()
		while callbacks.spellClock() < endAt and callbacks.isEnemyAlive(enemy) do
			callbacks.safeDamage(enemy, dps * 0.5, { player = plr, showFloating = false })
			task.wait(0.5)
		end
	end)
end

function SpellEffects.Configure(newCallbacks)
	validateCallbacks(newCallbacks)
	callbacks = newCallbacks
end

function SpellEffects.GetTargetDamageMultiplier(enemy, stats)
	if isBossEnemy(enemy) then
		return tonumber(stats and stats.bossDamageMultiplier) or 1
	end
	if isEliteEnemy(enemy) then
		return tonumber(stats and stats.eliteDamageMultiplier) or 1
	end
	return 1
end

function SpellEffects.GetEffectResistance(enemy)
	if isBossEnemy(enemy) then
		return {
			dot = 0.70,
			vulnerability = 0.55,
			duration = 0.45,
		}
	end
	if isEliteEnemy(enemy) then
		return {
			dot = 0.85,
			vulnerability = 0.75,
			duration = 0.72,
		}
	end
	return {
		dot = 1,
		vulnerability = 1,
		duration = 1,
	}
end

function SpellEffects.GetVulnerabilityDamageMultiplier(enemy, now)
	local vulnUntil = tonumber(enemy:GetAttribute("VulnerableUntil")) or 0
	local vulnPct = tonumber(enemy:GetAttribute("VulnerablePct")) or 0
	if vulnUntil > now and vulnPct > 0 then
		return 1 + vulnPct
	end
	return 1
end

function SpellEffects.Apply(plr, enemy, stats, sourcePos)
	assert(callbacks, "[SpellEffects] Configure must be called before Apply")

	local effects = stats.effects or {}
	local effectPower = stats.effectPower or 1
	local durationMult = callbacks.getDurationMult(plr)
	local enemyPos = callbacks.getEnemyPosition(enemy)
	local resist = SpellEffects.GetEffectResistance(enemy)

	if effects.dot then
		applyTimedDot(
			plr,
			enemy,
			(effects.dot.dps or 0) * effectPower * resist.dot,
			(effects.dot.duration or 0) * durationMult * resist.duration
		)
	end
	if effects.slow then
		callbacks.applySlow(enemy, math.clamp((effects.slow.pct or 0) * (0.9 + (effectPower * 0.1)), 0, 0.7), (effects.slow.duration or 0) * durationMult)
	end
	if effects.stun then
		callbacks.applyFreeze(enemy, (effects.stun.duration or 0) * durationMult * (0.9 + (effectPower * 0.1)))
	end
	if effects.vulnerability then
		enemy:SetAttribute("VulnerableUntil", callbacks.spellClock() + ((effects.vulnerability.duration or 0) * durationMult * resist.duration))
		enemy:SetAttribute("VulnerablePct", (effects.vulnerability.pct or 0) * (0.9 + (effectPower * 0.1)) * resist.vulnerability)
	end
	if enemyPos and sourcePos and effects.knockback then
		local direction = enemyPos - sourcePos
		if direction.Magnitude > 0.01 then
			callbacks.addImpulse(enemy, direction.Unit * (effects.knockback.force or 0) * (0.8 + (effectPower * 0.2)))
		end
	end
	if enemyPos and sourcePos and effects.pull then
		local direction = sourcePos - enemyPos
		if direction.Magnitude > 0.01 then
			callbacks.addImpulse(enemy, direction.Unit * (effects.pull.force or 0) * (0.8 + (effectPower * 0.2)))
		end
	end
	if enemyPos and sourcePos and tonumber(stats.pullStrength) and tonumber(stats.pullStrength) > 0 then
		local direction = sourcePos - enemyPos
		if direction.Magnitude > 0.01 then
			callbacks.addImpulse(enemy, direction.Unit * 10 * tonumber(stats.pullStrength) * (0.8 + (effectPower * 0.2)))
		end
	end
end

return SpellEffects
