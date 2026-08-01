local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NpcExternalPositioning = {}

local MIN_PROBE_HEIGHT = 16
local MIN_PROBE_DISTANCE = 96

local function buildRaycastParams(npc: any): RaycastParams
	local ignore = { npc.model }
	local enemies = Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("Mobs")
	if enemies then
		table.insert(ignore, enemies)
	end
	local drops = Workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignore, drops)
	end
	local spellVfx = Workspace:FindFirstChild("SpellVFX")
	if spellVfx then
		table.insert(ignore, spellVfx)
	end
	local abilityVfx = Workspace:FindFirstChild("EnemyAbilityVFX")
	if abilityVfx then
		table.insert(ignore, abilityVfx)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	params.RespectCanCollide = true
	return params
end

function NpcExternalPositioning.GroundPosition(npc: any, candidate: Vector3): Vector3
	if npc.movementMode ~= "Ground" then
		return candidate
	end

	local groundOffset = math.max(0, tonumber(npc.groundOffset) or 0)
	local probeHeight = math.max(MIN_PROBE_HEIGHT, groundOffset + 6)
	local probeDistance = math.max(MIN_PROBE_DISTANCE, probeHeight + 48)
	local origin = candidate + Vector3.new(0, probeHeight, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -probeDistance, 0), buildRaycastParams(npc))
	if not hit then
		return candidate
	end

	local grounded = Vector3.new(candidate.X, hit.Position.Y + groundOffset, candidate.Z)
	local navigation = npc.navigation
	if navigation and navigation.mode == "Ground" then
		navigation.lastSafePosition = grounded
		navigation.lastSafeSurfaceY = hit.Position.Y
		navigation.lastProgressPosition = grounded
		navigation.lastProgressAt = os.clock()
	end
	return grounded
end

return NpcExternalPositioning
