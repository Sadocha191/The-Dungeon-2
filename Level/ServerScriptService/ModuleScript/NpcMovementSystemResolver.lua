local CollectionService = game:GetService("CollectionService")

local NpcMovementSystemResolver = {}

NpcMovementSystemResolver.Systems = {
	Legacy = "Legacy",
	MovementV2 = "MovementV2",
}

NpcMovementSystemResolver.SystemTags = {
	NpcMovementSystem_Legacy = "Legacy",
	NpcMovementSystem_V2 = "MovementV2",
}

NpcMovementSystemResolver.MovementTags = {
	NpcMove_SurfaceCrawler = {
		Behavior = "SurfaceCrawler",
		LegacyProfile = "GroundSmall",
		V2Profile = "SurfaceCrawler",
	},
	NpcMove_GroundWalker = {
		Behavior = "GroundWalker",
		LegacyProfile = "GroundSmall",
		V2Profile = "GroundSmall",
	},
	NpcMove_GroundRunner = {
		Behavior = "GroundRunner",
		LegacyProfile = "GroundSmall",
		V2Profile = "GroundSmall",
	},
	NpcMove_Flying = {
		Behavior = "Flying",
		LegacyProfile = "Flying",
		V2Profile = "Flying",
	},
	NpcMove_HeavyWalker = {
		Behavior = "HeavyWalker",
		LegacyProfile = "GroundLarge",
		V2Profile = "GroundLarge",
	},
}

NpcMovementSystemResolver.CombatTags = {
	NpcCombat_LeapExplode = "LeapExplode",
}

local warnedModels = setmetatable({}, { __mode = "k" })

local function normalized(value: any): string
	return string.lower((tostring(value or ""):gsub("[%s_%-]", "")))
end

local SYSTEM_ALIASES = {
	legacy = "Legacy",
	old = "Legacy",
	v1 = "Legacy",
	movementv2 = "MovementV2",
	v2 = "MovementV2",
	new = "MovementV2",
}

local MOVEMENT_BEHAVIOR_ALIASES = {
	surfacecrawler = "SurfaceCrawler",
	crawler = "SurfaceCrawler",
	groundwalker = "GroundWalker",
	walker = "GroundWalker",
	groundrunner = "GroundRunner",
	runner = "GroundRunner",
	flying = "Flying",
	fly = "Flying",
	heavywalker = "HeavyWalker",
	heavy = "HeavyWalker",
}

local COMBAT_BEHAVIOR_ALIASES = {
	leapexplode = "LeapExplode",
	explodingleap = "LeapExplode",
}

local function warnOnce(model: Model, message: string)
	local previous = warnedModels[model]
	if previous == message then
		return
	end
	warnedModels[model] = message
	warn(string.format("[NpcMovementSystemResolver] %s: %s", model:GetFullName(), message))
end

local function collectKnownTags(model: Model, definitions: {[string]: any}, prefix: string): ({string}, {string})
	local known = {}
	local unknown = {}
	for _, tag in ipairs(CollectionService:GetTags(model)) do
		if definitions[tag] ~= nil then
			table.insert(known, tag)
		elseif string.sub(tag, 1, #prefix) == prefix then
			table.insert(unknown, tag)
		end
	end
	table.sort(known)
	table.sort(unknown)
	return known, unknown
end

local function resolveSystem(model: Model, config: {[string]: any}, defaultSystem: string): (string, boolean)
	local explicit = SYSTEM_ALIASES[normalized(config.movementSystem)]
	if explicit then
		return explicit, true
	end

	local tags, unknown = collectKnownTags(model, NpcMovementSystemResolver.SystemTags, "NpcMovementSystem_")
	if #unknown > 0 then
		warnOnce(model, "unknown movement-system tag(s): " .. table.concat(unknown, ", ") .. "; using Legacy")
		return "Legacy", false
	end
	if #tags > 1 then
		warnOnce(model, "multiple movement-system tags: " .. table.concat(tags, ", ") .. "; using Legacy")
		return "Legacy", false
	end
	if #tags == 1 then
		return NpcMovementSystemResolver.SystemTags[tags[1]], true
	end

	local attributeSystem = SYSTEM_ALIASES[normalized(model:GetAttribute("MovementSystem"))]
	if attributeSystem then
		return attributeSystem, true
	end

	return SYSTEM_ALIASES[normalized(defaultSystem)] or "Legacy", true
end

local function resolveMovement(model: Model, config: {[string]: any}): (string?, {[string]: any}?, boolean)
	local explicitBehavior = MOVEMENT_BEHAVIOR_ALIASES[normalized(config.movementBehavior)]
	local tags, unknown = collectKnownTags(model, NpcMovementSystemResolver.MovementTags, "NpcMove_")
	if #unknown > 0 then
		warnOnce(model, "unknown movement tag(s): " .. table.concat(unknown, ", "))
		return nil, nil, false
	end
	if #tags > 1 then
		warnOnce(model, "multiple movement tags: " .. table.concat(tags, ", "))
		return nil, nil, false
	end
	if #tags == 1 then
		local tag = tags[1]
		return tag, NpcMovementSystemResolver.MovementTags[tag], true
	end

	local behavior = explicitBehavior
		or MOVEMENT_BEHAVIOR_ALIASES[normalized(model:GetAttribute("MovementBehavior"))]
	if behavior then
		for tag, descriptor in pairs(NpcMovementSystemResolver.MovementTags) do
			if descriptor.Behavior == behavior then
				return tag, descriptor, true
			end
		end
	end

	return nil, nil, true
end

local function resolveCombat(model: Model, config: {[string]: any}): (string?, string?, boolean)
	local explicitBehavior = COMBAT_BEHAVIOR_ALIASES[normalized(config.combatBehavior)]
	local tags, unknown = collectKnownTags(model, NpcMovementSystemResolver.CombatTags, "NpcCombat_")
	if #unknown > 0 then
		warnOnce(model, "unknown combat tag(s): " .. table.concat(unknown, ", "))
		return nil, nil, false
	end
	if #tags > 1 then
		warnOnce(model, "multiple combat tags: " .. table.concat(tags, ", "))
		return nil, nil, false
	end
	if #tags == 1 then
		local tag = tags[1]
		return tag, NpcMovementSystemResolver.CombatTags[tag], true
	end

	local behavior = explicitBehavior
		or COMBAT_BEHAVIOR_ALIASES[normalized(model:GetAttribute("CombatBehavior"))]
	return nil, behavior, true
end

function NpcMovementSystemResolver.Resolve(model: Model, config: {[string]: any}?, defaultSystem: string?): {[string]: any}
	config = config or {}
	local system, systemValid = resolveSystem(model, config, defaultSystem or "Legacy")
	local movementTag, movementDescriptor, movementValid = resolveMovement(model, config)
	local combatTag, combatBehavior, combatValid = resolveCombat(model, config)

	return {
		System = system,
		MovementTag = movementTag,
		MovementBehavior = movementDescriptor and movementDescriptor.Behavior or nil,
		MovementDescriptor = movementDescriptor,
		CombatTag = combatTag,
		CombatBehavior = combatBehavior,
		Valid = systemValid and movementValid and combatValid,
	}
end

return NpcMovementSystemResolver
