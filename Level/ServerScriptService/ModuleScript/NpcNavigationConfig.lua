local NpcNavigationConfig = {}

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
		DirectFailureThreshold = 999,
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
		MaxStepUp = 3,
		MaxDrop = 5,
		MaxSlopeDegrees = 34,
		GroundSkin = 0.5,
		DirectSampleSpacing = 4,
		-- Large NPCs use the same rule: only a blocked local step should trigger repathing.
		DirectFailureThreshold = 999,
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
}

function NpcNavigationConfig.Resolve(model: Model, config: {[string]: any}?): (string, {[string]: any})
	config = config or {}
	local canFly = config.canFly == true
		or model:GetAttribute("CanFly") == true
	local requested = config.movementProfile
		or config.movementMode
		or model:GetAttribute("MovementProfile")
		or model:GetAttribute("movementProfile")
		or model:GetAttribute("MovementMode")
		or model:GetAttribute("movementMode")

	local profileName = PROFILE_ALIASES[normalized(requested)]
	if canFly or normalized(config.movementMode) == "flying" then
		profileName = "Flying"
	end
	profileName = profileName or "GroundSmall"

	local source = NpcNavigationConfig.Profiles[profileName] or NpcNavigationConfig.Profiles.GroundSmall
	return profileName, table.clone(source)
end

function NpcNavigationConfig.GetProfile(name: string): {[string]: any}
	return table.clone(NpcNavigationConfig.Profiles[name] or NpcNavigationConfig.Profiles.GroundSmall)
end

return NpcNavigationConfig
