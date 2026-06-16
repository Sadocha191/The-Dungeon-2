local MovementConfig = {
	DebugMovement = false,

	SlideKeyCodes = {
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.C,
		Enum.KeyCode.ButtonX,
	},

	SlideDuration = 0.45,
	SlideCooldown = 0.9,
	SlideBoostSpeed = 42,
	MinSlideSpeed = 10,
	SlideFriction = 0.92,
	MaxHorizontalSpeed = 75,

	GroundCheckDistance = 5,
	MaxSlopeAngle = 50,

	MaxJumps = 2,
	AirJumpPower = 52,
	AirJumpCooldown = 1.0,
	CanAirJumpAfterGroundLeaveDelay = 0.12,
	LandingResetDelay = 0.05,

	PreserveHorizontalMomentum = true,
	MaxMomentumChainSpeed = 140,

	AirControlEnabled = true,
	AirControlStrength = 0.025,
	AirDrag = 0.998,
	MinAirSpeedToPreserve = 6,
	MaxAirHorizontalSpeed = 75,
	AirTurnResponsiveness = 0.012,

	LowGravityEnabled = true,
	AirGravityScale = 0.65,
	LowGravityMinYVelocity = -120,

	SlopeSlideEnabled = true,
	SlopeAcceleration = 35,
	UphillDeceleration = 18,
	FlatSlideFriction = 0.999,
	DownhillSpeedGainMultiplier = 1.0,
	UphillSlowdownMultiplier = 0.65,
	MinSlideEndSpeed = 3,
	MaxSlideSlopeSpeed = 85,
	SlideGroundGraceTime = 0.16,
	SlideSurfaceTransitionGrace = 0.2,
	SlideSurfaceTransitionFriction = 0.9995,
	MinSlopeAutoSlideAngle = 8,
	SlopeAutoSlideStartSpeed = 4,
	SlideEdgeLaunchEnabled = true,
	SlideEdgeLaunchSpeedMultiplier = 1.0,
	SlideEdgeLaunchUpVelocity = 6,
	SlidePreserveYVelocity = true,
	SlideJumpEnabled = true,
	SlideJumpHorizontalMultiplier = 1.0,
	SlideJumpExtraUpVelocity = 0,
	SlideJumpMinCarrySpeed = 8,
	SlideJumpMaxCarrySpeed = 140,
	SlideJumpCountsAsJump = true,

	SlideHoldEnabled = true,
	SlideHardMaxDurationEnabled = false,
	MaxSlideHoldDuration = 1.2,

	LandingMomentumCarry = true,
	LandingFrictionDuration = 0.12,
	LandingFriction = 0.9,
	SlideLandingResumeEnabled = true,
	SlideLandingResumeGraceTime = 0.25,
	SlideLandingMinCarrySpeed = 10,
	SlideLandingBypassCooldown = true,
	SlideLandingNoFreshBoost = true,
	SlideLandingFriction = 0.995,

	-- Compatibility tuning for existing Level movement upgrades.
	SlideBaseSpeedMultiplier = 1.55,
	SlideSpeedPerLevel = 0.18,
	SlideDurationPerLevel = 0.03,
	MaxSlideDurationBonus = 0.18,
	SlideCooldownReductionPerLevel = 0.10,
	MinSlideCooldown = 0.45,
	SlideLookFallbackMinSpeed = 2.5,
	SlideCameraDrop = 1.15,
}

return table.freeze(MovementConfig)
