local NpcExternalPositioning = require(script.Parent:WaitForChild("NpcExternalPositioning"))
local NpcGroundNavigation = require(script.Parent:WaitForChild("NpcGroundNavigation"))
local NpcFlightNavigation = require(script.Parent:WaitForChild("NpcFlightNavigation"))
local NpcSurfaceNavigation = require(script.Parent:WaitForChild("NpcSurfaceNavigation"))

local NpcMovementSystemController = {}

local function isMovementV2(npc: any): boolean
	return npc.movementSystem == "MovementV2"
		or (npc.navigationProfile and npc.navigationProfile.MovementSystem == "MovementV2")
end

local function isSurfaceCrawler(npc: any): boolean
	return isMovementV2(npc) and npc.movementBehavior == "SurfaceCrawler"
end

function NpcMovementSystemController.Uses3DTargeting(npc: any): boolean
	return npc.movementMode == "Flying" or isSurfaceCrawler(npc)
end

function NpcMovementSystemController.Step(
	npc: any,
	targetPosition: Vector3,
	desiredPosition: Vector3,
	speed: number,
	dt: number,
	now: number,
	spatialGrid: {[string]: {any}}
): (Vector3, string)
	if isSurfaceCrawler(npc) then
		return NpcSurfaceNavigation.Step(npc, targetPosition, speed, dt, now)
	end
	if npc.movementMode == "Flying" then
		return NpcFlightNavigation.Step(npc, targetPosition, speed, dt, now)
	end

	local separation = NpcGroundNavigation.GetSeparation(npc, spatialGrid)
	return NpcGroundNavigation.Step(
		npc,
		targetPosition,
		desiredPosition,
		speed,
		dt,
		now,
		separation
	)
end

function NpcMovementSystemController.ConstrainPosition(
	npc: any,
	nextPosition: Vector3,
	now: number,
	impulseMove: Vector3?
): Vector3
	if isSurfaceCrawler(npc) then
		return NpcSurfaceNavigation.ConstrainPosition(npc, nextPosition, now)
	end
	if npc.movementMode == "Flying" then
		if typeof(impulseMove) == "Vector3" and impulseMove.Magnitude > 0.01 then
			return NpcFlightNavigation.ClampPosition(npc, nextPosition)
		end
		return nextPosition
	end
	return NpcGroundNavigation.ConstrainPosition(npc, nextPosition, now)
end

function NpcMovementSystemController.ProjectImpulse(npc: any, impulse: Vector3): Vector3
	if isSurfaceCrawler(npc) then
		return NpcSurfaceNavigation.ProjectImpulse(npc, impulse)
	end
	if npc.movementMode == "Flying" then
		return impulse
	end
	return Vector3.new(impulse.X, 0, impulse.Z)
end

function NpcMovementSystemController.Cleanup(npc: any)
	if isSurfaceCrawler(npc) then
		NpcSurfaceNavigation.Cleanup(npc)
	elseif npc.movementMode == "Flying" then
		NpcFlightNavigation.Cleanup(npc)
	else
		NpcGroundNavigation.Cleanup(npc)
	end
end

function NpcMovementSystemController.Invalidate(npc: any, reason: string?)
	if reason == "external_set_position" and npc.movementMode == "Ground" then
		npc.position = NpcExternalPositioning.GroundPosition(npc, npc.position)
	end

	if isSurfaceCrawler(npc) then
		NpcSurfaceNavigation.Invalidate(npc, reason)
	elseif npc.movementMode == "Flying" then
		NpcFlightNavigation.Invalidate(npc, reason)
	else
		NpcGroundNavigation.Invalidate(npc, reason)
	end
end

function NpcMovementSystemController.BeginTick(alivePlayers: {any})
	NpcGroundNavigation.BeginTick(alivePlayers)
	NpcFlightNavigation.BeginTick(alivePlayers)
	NpcSurfaceNavigation.BeginTick(alivePlayers)
end

function NpcMovementSystemController.StepScheduler(now: number)
	NpcGroundNavigation.StepScheduler(now)
end

function NpcMovementSystemController.BuildSpatialGrid(npcPairs: () -> ()): {[string]: {any}}
	return NpcGroundNavigation.BuildSpatialGrid(npcPairs)
end

function NpcMovementSystemController.GetDebug(npc: any): {[string]: any}?
	if isSurfaceCrawler(npc) then
		return NpcSurfaceNavigation.GetDebug(npc)
	end
	if npc.movementMode == "Flying" then
		return NpcFlightNavigation.GetDebug(npc)
	end
	return NpcGroundNavigation.GetDebug(npc)
end

function NpcMovementSystemController.GetMetrics(): {[string]: any}
	return {
		ground = NpcGroundNavigation.GetMetrics(),
		flight = NpcFlightNavigation.GetMetrics(),
		surface = NpcSurfaceNavigation.GetMetrics(),
	}
end

return NpcMovementSystemController
