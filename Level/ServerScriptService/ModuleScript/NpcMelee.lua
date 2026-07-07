local ServerScriptService = game:GetService("ServerScriptService")

local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(serverModuleFolder, "[NpcMelee] Server ModuleScript folder is required")
local damageServiceModule = serverModuleFolder:FindFirstChild("DamageService")
assert(damageServiceModule and damageServiceModule:IsA("ModuleScript"), "[NpcMelee] DamageService ModuleScript is required for player damage")
local DamageService = require(damageServiceModule)

local NpcMelee = {}

local ENEMY_MELEE_MAX_VERTICAL_DELTA = 5
local ENEMY_MELEE_MAX_HIT_HEIGHT_ABOVE_ENEMY = 4.5
local ENEMY_MELEE_USE_3D_DISTANCE = true
local ENEMY_MELEE_DEBUG = false

local function getNpcBooleanAttribute(model: Model, attributeName: string, fallback: boolean): boolean
	local value = model:GetAttribute(attributeName)
	if typeof(value) == "boolean" then
		return value
	end
	return fallback
end

local function getNpcNumberAttribute(model: Model, attributeName: string, fallback: number): number
	local value = model:GetAttribute(attributeName)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function debugMeleeSkip(npc: any, targetInfo: any, reason: string, detail: string)
	if ENEMY_MELEE_DEBUG ~= true then
		return
	end

	print(string.format(
		"[NpcService] Skip melee hit %s -> %s: %s (%s)",
		npc.model.Name,
		targetInfo.player.Name,
		reason,
		detail
		))
end

function NpcMelee.ApplyPlayerDamage(player: Player, amount: number, sourceModel: Model?)
	if amount <= 0 then
		return
	end

	DamageService.Apply(player, amount, {
		source = sourceModel,
		sourceType = "npc",
		damageType = "contact",
		attacker = sourceModel,
	})
end

function NpcMelee.CanApplyDamage(npc: any, targetInfo: any): boolean
	if npc.isRanged then
		return true
	end

	local targetRoot = targetInfo.hrp
	local npcRoot = npc.root
	if not targetRoot.Parent then
		debugMeleeSkip(npc, targetInfo, "missing_target_root", "HumanoidRootPart is no longer parented")
		return false
	end
	if not npcRoot.Parent then
		debugMeleeSkip(npc, targetInfo, "missing_npc_root", "NPC root is no longer parented")
		return false
	end

	local targetPos = targetRoot.Position
	local npcPos = npc.position
	local verticalDelta = targetPos.Y - npcPos.Y
	local verticalDeltaAbs = math.abs(verticalDelta)
	local maxVerticalDelta = math.max(0, getNpcNumberAttribute(npc.model, "EnemyMeleeMaxVerticalDelta", ENEMY_MELEE_MAX_VERTICAL_DELTA))
	local maxHitHeightAboveEnemy = math.max(0, getNpcNumberAttribute(npc.model, "EnemyMeleeMaxHitHeightAboveEnemy", ENEMY_MELEE_MAX_HIT_HEIGHT_ABOVE_ENEMY))
	local ignoreVerticalValidation = getNpcBooleanAttribute(npc.model, "EnemyMeleeIgnoreVerticalValidation", false)

	if not ignoreVerticalValidation and verticalDelta > maxHitHeightAboveEnemy then
		debugMeleeSkip(npc, targetInfo, "target_above_enemy", string.format("verticalDelta=%.2f limit=%.2f", verticalDelta, maxHitHeightAboveEnemy))
		return false
	end

	if not ignoreVerticalValidation and verticalDeltaAbs > maxVerticalDelta then
		debugMeleeSkip(npc, targetInfo, "vertical_delta", string.format("absDelta=%.2f limit=%.2f", verticalDeltaAbs, maxVerticalDelta))
		return false
	end

	if getNpcBooleanAttribute(npc.model, "EnemyMeleeUse3DDistance", ENEMY_MELEE_USE_3D_DISTANCE) then
		local max3DDistance = math.sqrt((npc.attackRange * npc.attackRange) + (maxVerticalDelta * maxVerticalDelta))
		local fullDistance = (targetPos - npcPos).Magnitude
		if fullDistance > max3DDistance then
			debugMeleeSkip(npc, targetInfo, "3d_distance", string.format("distance=%.2f limit=%.2f", fullDistance, max3DDistance))
			return false
		end
	end

	return true
end

return NpcMelee
