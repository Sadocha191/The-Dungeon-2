local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local function findServerModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end

	local folder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end

	return nil
end

local NpcService = require(findServerModule("NpcService") or error("[DamageIndicatorService] Missing NpcService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local damageIndicatorEvent = remotes:WaitForChild("DamageIndicatorEvent")
assert(damageIndicatorEvent:IsA("RemoteEvent"), "[DamageIndicatorService] DamageIndicatorEvent must be a RemoteEvent")

local BATCH_HZ = 20
local BATCH_WINDOW = 1 / BATCH_HZ
local MAX_PENDING_BATCHES_PER_PLAYER = 128
local MAX_EMITTED_BATCHES_PER_PLAYER_PER_FLUSH = 36

local ELEMENT_ALIASES = {
	Electric = "Electricity",
	Lightning = "Electricity",
	Wind = "Air",
	Nature = "Earth",
	Holy = "Light",
	Dark = "Void",
	Shadow = "Void",
}

local VALID_ELEMENTS = {
	Physical = true,
	Fire = true,
	Electricity = true,
	Air = true,
	Water = true,
	Earth = true,
	Void = true,
	Light = true,
}

local DamageIndicatorService = {}
local pendingByPlayer = {}
local pendingCountByPlayer = {}
local flushAccumulator = 0

local function isActivePlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player") and value.Parent == Players
end

local function normalizeElement(value: any): string
	local element = tostring(value or "")
	element = ELEMENT_ALIASES[element] or element
	if VALID_ELEMENTS[element] then
		return element
	end
	return "Physical"
end

local function cloneMeta(meta: {[string]: any}?): {[string]: any}
	local result = {}
	for key, value in pairs(meta or {}) do
		result[key] = value
	end
	return result
end

local function resolveTargetId(target: any): string?
	if typeof(target) == "Instance" then
		local attribute = target:GetAttribute("NpcId")
		if typeof(attribute) == "string" and attribute ~= "" then
			return attribute
		end
		return nil
	end
	if typeof(target) == "string" and target ~= "" then
		return target
	end
	return nil
end

local function fallbackTargetKey(position: Vector3): string
	return string.format(
		"%d:%d:%d",
		math.floor(position.X * 0.5 + 0.5),
		math.floor(position.Y * 0.5 + 0.5),
		math.floor(position.Z * 0.5 + 0.5)
	)
end

local function buildBatchKey(payload): string
	return table.concat({
		payload.targetId or fallbackTargetKey(payload.pos),
		payload.element,
		payload.secondaryElement or "",
		payload.crit and "crit" or "normal",
		payload.kind or "hit",
	}, "|")
end

local function clearPendingForPlayer(player: Player)
	pendingByPlayer[player] = nil
	pendingCountByPlayer[player] = nil
end

local function emitBucket(sourcePlayer: Player, bucket)
	damageIndicatorEvent:FireClient(sourcePlayer, {
		pos = bucket.pos,
		amount = math.max(1, math.floor(bucket.amount + 0.5)),
		hits = bucket.hits,
		crit = bucket.crit,
		element = bucket.element,
		secondaryElement = bucket.secondaryElement,
		targetId = bucket.targetId,
		kind = bucket.kind,
		sourceId = bucket.sourceId,
		batched = true,
	})
end

local function flushPending(now: number)
	for sourcePlayer, playerBuckets in pairs(pendingByPlayer) do
		if not isActivePlayer(sourcePlayer) or sourcePlayer:GetAttribute("RunEnded") == true then
			clearPendingForPlayer(sourcePlayer)
			continue
		end

		local emitted = 0
		local remaining = pendingCountByPlayer[sourcePlayer] or 0
		for key, bucket in pairs(playerBuckets) do
			if bucket.flushAt <= now then
				playerBuckets[key] = nil
				remaining = math.max(0, remaining - 1)
				if emitted < MAX_EMITTED_BATCHES_PER_PLAYER_PER_FLUSH then
					emitted += 1
					emitBucket(sourcePlayer, bucket)
				end
			end
		end

		if remaining <= 0 or next(playerBuckets) == nil then
			clearPendingForPlayer(sourcePlayer)
		else
			pendingCountByPlayer[sourcePlayer] = remaining
		end
	end
end

local function queueIndicator(sourcePlayer: Player, payload)
	local playerBuckets = pendingByPlayer[sourcePlayer]
	if not playerBuckets then
		playerBuckets = {}
		pendingByPlayer[sourcePlayer] = playerBuckets
	end

	local key = buildBatchKey(payload)
	local bucket = playerBuckets[key]
	if bucket then
		bucket.amount += payload.amount
		bucket.hits += 1
		bucket.pos = bucket.pos:Lerp(payload.pos, 0.35)
		return
	end
	if (pendingCountByPlayer[sourcePlayer] or 0) >= MAX_PENDING_BATCHES_PER_PLAYER then
		return
	end

	bucket = {
		amount = payload.amount,
		hits = 1,
		pos = payload.pos,
		crit = payload.crit,
		element = payload.element,
		secondaryElement = payload.secondaryElement,
		targetId = payload.targetId,
		kind = payload.kind,
		sourceId = payload.sourceId,
		flushAt = os.clock() + BATCH_WINDOW,
	}
	playerBuckets[key] = bucket
	pendingCountByPlayer[sourcePlayer] = (pendingCountByPlayer[sourcePlayer] or 0) + 1
end

function DamageIndicatorService.ApplyDamage(target: any, amount: number, meta: {[string]: any}?): number
	local sourcePlayer = meta and meta.player
	local showFloating = not (meta and meta.showFloating == false)
	local position = showFloating and NpcService.GetPosition(target) or nil
	local targetId = showFloating and resolveTargetId(target) or nil

	local damageMeta = cloneMeta(meta)
	if showFloating then
		damageMeta.showFloating = false
	end

	local applied = NpcService.ApplyDamage(target, amount, damageMeta)
	if applied <= 0 or not showFloating or typeof(position) ~= "Vector3" then
		return applied
	end
	if not isActivePlayer(sourcePlayer) then
		return applied
	end
	if sourcePlayer:GetAttribute("RunEnded") == true then
		return applied
	end

	local element = normalizeElement(meta and meta.element)
	local secondaryElement = nil
	if meta and meta.secondaryElement ~= nil then
		local normalizedSecondary = normalizeElement(meta.secondaryElement)
		if normalizedSecondary ~= element then
			secondaryElement = normalizedSecondary
		end
	end

	queueIndicator(sourcePlayer, {
		pos = position + Vector3.new(0, 2, 0),
		amount = applied,
		crit = meta and meta.crit == true or false,
		element = element,
		secondaryElement = secondaryElement,
		targetId = targetId,
		kind = meta and typeof(meta.kind) == "string" and meta.kind ~= "" and meta.kind or nil,
		sourceId = meta and typeof(meta.sourceId) == "string" and meta.sourceId ~= "" and meta.sourceId or nil,
	})

	return applied
end

RunService.Heartbeat:Connect(function(dt)
	flushAccumulator += dt
	if flushAccumulator < BATCH_WINDOW then
		return
	end
	flushAccumulator %= BATCH_WINDOW
	flushPending(os.clock())
end)

Players.PlayerRemoving:Connect(function(player)
	clearPendingForPlayer(player)
end)

return DamageIndicatorService
