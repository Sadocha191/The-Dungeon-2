local AbilityGeometry = {}

local DEFAULT_GROUND_OFFSET = Vector3.new(0, 0.2, 0)

local function flatVector(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function AbilityGeometry.FlatVector(v: Vector3): Vector3
	return flatVector(v)
end

function AbilityGeometry.HorizontalDistance(a: Vector3, b: Vector3): number
	return (flatVector(a) - flatVector(b)).Magnitude
end

function AbilityGeometry.VerticalDelta(a: Vector3, b: Vector3): number
	return math.abs(a.Y - b.Y)
end

function AbilityGeometry.Groundify(pos: Vector3, raycastGround, offset: Vector3?): Vector3
	local hit = type(raycastGround) == "function" and raycastGround(pos) or nil
	if hit and hit.Position then
		return hit.Position + (offset or DEFAULT_GROUND_OFFSET)
	end
	return pos
end

function AbilityGeometry.DistancePointToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom <= 1e-4 then
		return (point - a).Magnitude
	end
	local t = math.clamp(((point - a):Dot(ab)) / denom, 0, 1)
	local projection = a + (ab * t)
	return (point - projection).Magnitude
end

function AbilityGeometry.IsPointInRadius(point: Vector3, center: Vector3, radius: number): boolean
	return (point - center).Magnitude <= radius
end

function AbilityGeometry.IsPointAlongLine(point: Vector3, startPos: Vector3, endPos: Vector3, width: number): boolean
	return (point - startPos).Magnitude <= ((endPos - startPos).Magnitude + width + 2)
		and AbilityGeometry.DistancePointToSegment(point, startPos, endPos) <= width
end

function AbilityGeometry.IsPointInCone(point: Vector3, origin: Vector3, forward: Vector3, range: number, halfAngleDeg: number): boolean
	local flatForward = flatVector(forward)
	if flatForward.Magnitude <= 1e-4 then
		return false
	end
	flatForward = flatForward.Unit
	local dotMin = math.cos(math.rad(halfAngleDeg))
	local toPoint = flatVector(point - origin)
	if toPoint.Magnitude <= range and toPoint.Magnitude > 1e-4 then
		return flatForward:Dot(toPoint.Unit) >= dotMin
	end
	return false
end

return AbilityGeometry
