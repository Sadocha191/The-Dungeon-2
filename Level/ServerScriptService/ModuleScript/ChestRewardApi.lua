--!strict

local Players = game:GetService("Players")

local ChestRewardApi = {}
local spawnCallback: ((Vector3, {[string]: any}) -> any)? = nil

function ChestRewardApi.Configure(callback: (Vector3, {[string]: any}) -> any)
	assert(typeof(callback) == "function", "[ChestRewardApi] spawn callback is required")
	spawnCallback = callback
end

local function spawn(pos: Vector3, config: {[string]: any})
	if not spawnCallback then
		warn("[ChestRewardApi] ChestService is not configured yet")
		return nil
	end
	return spawnCallback(pos, config)
end

function ChestRewardApi.SpawnForPlayer(player: Player, pos: Vector3, config: {[string]: any}?)
	if player.Parent ~= Players then
		return nil
	end
	local resolved = typeof(config) == "table" and table.clone(config) or {}
	resolved.ownerUserId = player.UserId
	resolved.forceFree = true
	resolved.countsForScaling = false
	return spawn(pos, resolved)
end

function ChestRewardApi.SpawnShared(players: {Player}, pos: Vector3, config: {[string]: any}?)
	local eligible = {}
	for _, player in ipairs(players) do
		if player.Parent == Players and player:GetAttribute("RunEnded") ~= true then
			eligible[player.UserId] = true
		end
	end
	if next(eligible) == nil then
		return nil
	end
	local resolved = typeof(config) == "table" and table.clone(config) or {}
	resolved.eligibleUserIds = eligible
	resolved.forceFree = true
	resolved.countsForScaling = false
	resolved.expiresAfter = math.max(5, tonumber(resolved.expiresAfter) or 60)
	return spawn(pos, resolved)
end

return ChestRewardApi
