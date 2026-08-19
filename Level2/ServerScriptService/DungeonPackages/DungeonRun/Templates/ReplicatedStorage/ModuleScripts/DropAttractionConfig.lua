-- Shared attraction-speed tuning for authoritative drops and client presentation.

local DropAttractionConfig = {}

DropAttractionConfig.SpeedMultiplier = 1.15
DropAttractionConfig.SpeedBonus = 4
DropAttractionConfig.MinimumSpeed = 22
DropAttractionConfig.CatchupBonus = 40
DropAttractionConfig.GlobalMagnetSpeed = 180

function DropAttractionConfig.GetHorizontalSpeed(assemblyLinearVelocity: Vector3?): number
	if typeof(assemblyLinearVelocity) ~= "Vector3" then
		return 0
	end

	return Vector3.new(assemblyLinearVelocity.X, 0, assemblyLinearVelocity.Z).Magnitude
end

function DropAttractionConfig.GetSpeed(
	walkSpeed: number?,
	assemblyLinearVelocity: Vector3?,
	usingGlobalMagnet: boolean?
): number
	local safeWalkSpeed = math.max(0, tonumber(walkSpeed) or 16)
	local catchupSpeed = DropAttractionConfig.GetHorizontalSpeed(assemblyLinearVelocity)
		+ DropAttractionConfig.CatchupBonus

	if usingGlobalMagnet == true then
		return math.max(
			DropAttractionConfig.GlobalMagnetSpeed,
			safeWalkSpeed * 6,
			catchupSpeed
		)
	end

	return math.max(
		DropAttractionConfig.MinimumSpeed,
		safeWalkSpeed * DropAttractionConfig.SpeedMultiplier + DropAttractionConfig.SpeedBonus,
		catchupSpeed
	)
end

return DropAttractionConfig
