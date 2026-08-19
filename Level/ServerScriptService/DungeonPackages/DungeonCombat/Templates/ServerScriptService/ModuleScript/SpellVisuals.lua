local SpellVisuals = {}

local spellVfxEvent = nil
local getServerTimeNow = nil

local function ensureConfigured()
	assert(spellVfxEvent, "[SpellVisuals] Configure must be called before use")
end

function SpellVisuals.Configure(options)
	assert(typeof(options) == "table", "[SpellVisuals] options table is required")
	assert(typeof(options.spellVfxEvent) == "Instance", "[SpellVisuals] spellVfxEvent is required")

	spellVfxEvent = options.spellVfxEvent
	getServerTimeNow = options.getServerTimeNow or function()
		return workspace:GetServerTimeNow()
	end
end

function SpellVisuals.ExtractStats(stats)
	if typeof(stats) ~= "table" then
		return {}
	end

	return {
		spellId = stats.spellId,
		level = tonumber(stats.level) or 1,
		basePower = tonumber(stats.basePower) or 0,
		upgradePower = tonumber(stats.upgradePower) or 0,
		element = stats.element,
		secondaryElement = stats.secondaryElement,
		attackType = stats.attackType,
		spellType = stats.spellType,
		isCombo = stats.isCombo == true,
		iconGlyph = stats.iconGlyph,
		artMotif = stats.artMotif,
		visualDirection = stats.visualDirection,
		visualProfile = typeof(stats.visualProfile) == "table" and stats.visualProfile or nil,
		radius = tonumber(stats.radius),
		width = tonumber(stats.width),
		visualColor = typeof(stats.visualColor) == "Color3" and stats.visualColor or nil,
		visualSecondaryColor = typeof(stats.visualSecondaryColor) == "Color3" and stats.visualSecondaryColor or nil,
	}
end

function SpellVisuals.Broadcast(action, payload)
	ensureConfigured()

	payload = payload or {}
	payload.action = action
	payload.serverTime = getServerTimeNow()
	spellVfxEvent:FireAllClients(payload)
end

function SpellVisuals.SyncOrbit(vfxState, plr, spellId, enabled, params)
	ensureConfigured()

	vfxState[spellId] = vfxState[spellId] or {}
	local last = vfxState[spellId]

	if not enabled then
		if last.enabled ~= false then
			last.enabled = false
			spellVfxEvent:FireClient(plr, spellId, false)
		end
		return
	end

	params = params or {}
	local changed = last.enabled ~= true
	for key, value in pairs(params) do
		if last[key] ~= value then
			changed = true
			break
		end
	end
	if changed then
		last.enabled = true
		for key, value in pairs(params) do
			last[key] = value
		end
		spellVfxEvent:FireClient(plr, spellId, true, params)
	end
end

function SpellVisuals.StopAllOrbits(vfxState, plr)
	for spellId, info in pairs(vfxState) do
		if info and info.enabled == true then
			SpellVisuals.SyncOrbit(vfxState, plr, spellId, false)
		end
	end
end

return SpellVisuals
