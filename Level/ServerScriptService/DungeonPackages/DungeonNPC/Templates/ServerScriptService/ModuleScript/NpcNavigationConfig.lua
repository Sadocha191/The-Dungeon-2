local NpcMovementSystemResolver = require(script.Parent:WaitForChild("NpcMovementSystemResolver"))

local NpcNavigationConfig = {}

local DIRECT_FAILURE_REPATH_DISABLED = math.huge

-- New NPCs resolve this value when they are registered. Existing spawned NPCs
-- intentionally keep their selected system until they despawn.
NpcNavigationConfig.ActiveSystem = "Legacy"

NpcNavigationConfig.Scheduler = {
	MovementHz = 12,
	TargetingHz = 3,
	FormationHz = 2,
	MaxConcurrentPaths = 2,
	MaxPathStartsPerSecond = 15,
	MaxPendingPaths = 160,
	PathCacheTtl = 5,
	PathSectorSize = 18,
	AirGraphConnectionDistance = 90,
	AirGraphCacheTtl = 10,
	SpatialCellSize = 12,
	SurfaceCacheTtl = 0.08,
	SurfaceCacheResolution = 0.5,
	SurfaceCacheExpectedYResolution = 0.5,
	SurfaceCacheMaxPositionDelta = 0.4,
	SurfaceCacheMaxExpectedYDelta = 0.4,
	MaxGroundProbeHits = 3,
	GroundProbeAdvance = 0.05,
	SurfaceLayerTolerance = 0.35,
	PathLayerResolution = 2,
	UnreachableRetargetSeconds = 2.5,
}

NpcNavigationConfig.Profiles = {
	GroundSmall = {
		Name = "GroundSmall",
		Mode = "Ground",
		AgentRadius = 1.75,
		AgentHeight = 6,
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = 6,
		MaxStepUp = 2.75,
		MaxDrop = 6,
		MaxSlopeDegrees = 42,
		GroundSkin = 0.35,
		DirectSampleSpacing = 2.75,
		-- A failed long-range direct probe must not force a repath by itself.
		-- ValidateStep still queues a path immediately when the next real movement step is blocked.
		DirectFailureThreshold = DIRECT_FAILURE_REPATH_DISABLED,
		StepFailureThreshold = 2,
		FrontProbeScale = 0.65,
		WidthProbeScale = 0.8,
		PathGoalMoveDistance = 12,
		CanJump = true,
		CanClimb = false,
		CanDrop = true,
		DirectCheckInterval = 0.3,
		DirectProbeDistance = 18,
		PathRefreshSeconds = 3,
		StuckSeconds = 1.25,
		StuckDistance = 0.8,
		RepathCooldown = 0.5,
		TraversalKind = "Hop",
		TraversalArcHeight = 3.25,
		TraversalDuration = 0.42,
		TraversalMaxDistance = 8.5,
		TraversalMaxRise = 2.75,
		TraversalMaxDrop = 6,
		TraversalMaxObstacleTop = 3.75,
		TraversalCooldown = 0.55,
		Costs = {
			Bridge = 1,
			NarrowBridge = 4,
			Water = 1000,
			Mud = 6,
			Lava = 1000,
			Jump = 2,
			Climb = 1000,
			Drop = 5,
		},
	},
	GroundLarge = {
		Name = "GroundLarge",
		Mode = "Ground",
		AgentRadius = 5.5,
		AgentHeight = 18,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 8,
		MaxStepUp = 4.5,
		MaxDrop = 8,
		MaxSlopeDegrees = 38,
		GroundSkin = 0.5,
		DirectSampleSpacing = 4.5,
		-- Large NPCs use the same rule: only a blocked local step should trigger repathing.
		DirectFailureThreshold = DIRECT_FAILURE_REPATH_DISABLED,
		StepFailureThreshold = 2,
		FrontProbeScale = 0.65,
		WidthProbeScale = 0.8,
		PathGoalMoveDistance = 16,
		CanJump = false,
		CanClimb = false,
		CanDrop = true,
		DirectCheckInterval = 0.35,
		DirectProbeDistance = 24,
		PathRefreshSeconds = 4,
		StuckSeconds = 1.5,
		StuckDistance = 0.7,
		RepathCooldown = 0.7,
		TraversalKind = "Stride",
		TraversalArcHeight = 4,
		TraversalDuration = 0.55,
		TraversalMaxDistance = 12,
		TraversalMaxRise = 6,
		TraversalMaxDrop = 8,
		TraversalMaxObstacleTop = 6.5,
		TraversalCooldown = 0.5,
		Costs = {
			Bridge = 1.5,
			NarrowBridge = 25,
			Water = 1000,
			Mud = 9,
			Lava = 1000,
			Jump = 1000,
			Climb = 1000,
			Drop = 8,
		},
	},
	Flying = {
		Name = "Flying",
		Mode = "Flying",
		CollisionRadius = 2.5,
		PreferredAltitude = 14,
		MinimumGroundClearance = 7,
		MinimumAltitude = -64,
		MaximumAltitude = 320,
		ObstacleProbeDistance = 14,
		TurnSpeed = 5.5,
		AscendSpeed = 12,
		DescendSpeed = 10,
		UseAirNodes = true,
		DirectCheckInterval = 0.2,
		RetryCooldown = 0.6,
		ForbiddenZones = { Lava = true },
	},
	SurfaceCrawler = {
		Name = "SurfaceCrawler",
		Mode = "Surface",
		SurfaceOffset = 1.25,
		AcquireDistance = 10,
		AdhesionProbeLift = 0.75,
		AdhesionDistance = 4.5,
		ForwardTransitionProbe = 1.75,
		EdgeTransitionProbe = 2.5,
		AllowUntaggedCrawlable = false,
		TerrainFloorNormalMinDot = 0.65,
	},
}

local function normalized(value: any): string
	return string.lower((tostring(value or ""):gsub("[%s_%-]", "")))
end

local PROFILE_ALIASES = {
	ground = "GroundSmall",
	groundsmall = "GroundSmall",
	small = "GroundSmall",
	groundlarge = "GroundLarge",
	large = "GroundLarge",
	fly = "Flying",
	flying = "Flying",
	air = "Flying",
	surface = "SurfaceCrawler",
	surfacecrawler = "SurfaceCrawler",
	crawler = "SurfaceCrawler",
}

local BEHAVIOR_BY_PROFILE = {
	GroundSmall = "GroundWalker",
	GroundLarge = "HeavyWalker",
	Flying = "Flying",
	SurfaceCrawler = "SurfaceCrawler",
}

local function setAttributeIfChanged(model: Model, name: string, value: any)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

function NpcNavigationConfig.Resolve(model: Model, config: {[string]: any}?): (string, {[string]: any})
	config = config or {}
	local descriptor = NpcMovementSystemResolver.Resolve(model, config, NpcNavigationConfig.ActiveSystem)
	local canFly = config.canFly == true or model:GetAttribute("CanFly") == true
	local requested = config.movementProfile
		or config.movementMode
		or model:GetAttribute("MovementProfile")
		or model:GetAttribute("movementProfile")
		or model:GetAttribute("MovementMode")
		or model:GetAttribute("movementMode")

	local profileName = PROFILE_ALIASES[normalized(requested)]
	local movementDescriptor = descriptor.MovementDescriptor
	if movementDescriptor then
		if descriptor.System == "MovementV2" then
			profileName = movementDescriptor.V2Profile
		else
			profileName = movementDescriptor.LegacyProfile
		end
	end
	if canFly or normalized(config.movementMode) == "flying" then
		profileName = "Flying"
	end
	profileName = profileName or "GroundSmall"

	-- Invalid tag combinations fail closed to the proven Legacy backend.
	local movementSystem = descriptor.Valid and descriptor.System or "Legacy"
	if movementSystem == "Legacy" and profileName == "SurfaceCrawler" then
		profileName = "GroundSmall"
	end

	local source = NpcNavigationConfig.Profiles[profileName] or NpcNavigationConfig.Profiles.GroundSmall
	local profile = table.clone(source)
	profile.MovementSystem = movementSystem
	profile.MovementTag = descriptor.MovementTag
	profile.MovementBehavior = descriptor.MovementBehavior or BEHAVIOR_BY_PROFILE[profileName]
	profile.CombatTag = descriptor.CombatTag
	profile.CombatBehavior = descriptor.CombatBehavior

	setAttributeIfChanged(model, "MovementSystem", profile.MovementSystem)
	setAttributeIfChanged(model, "MovementBehavior", profile.MovementBehavior)
	setAttributeIfChanged(model, "CombatBehavior", profile.CombatBehavior)

	return profileName, profile
end

function NpcNavigationConfig.GetProfile(name: string): {[string]: any}
	return table.clone(NpcNavigationConfig.Profiles[name] or NpcNavigationConfig.Profiles.GroundSmall)
end

function NpcNavigationConfig.SetActiveSystem(systemName: string): boolean
	local normalizedName = normalized(systemName)
	if normalizedName == "legacy" or normalizedName == "v1" then
		NpcNavigationConfig.ActiveSystem = "Legacy"
		return true
	end
	if normalizedName == "movementv2" or normalizedName == "v2" then
		NpcNavigationConfig.ActiveSystem = "MovementV2"
		return true
	end
	return false
end

return NpcNavigationConfig
