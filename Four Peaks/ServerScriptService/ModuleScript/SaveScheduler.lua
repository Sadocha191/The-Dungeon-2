-- SaveScheduler.lua
-- Debounces PlayerStateStore writes without clearing dirty state before DataStore confirms success.

local Players = game:GetService("Players")

local SaveScheduler = {}

local MIN_INTERVAL = 25
local MAX_INTERVAL = 75
local JITTER_MIN = 1
local JITTER_MAX = 4

local boundStore = nil
local stateByUserId = {}

local function now(): number
	return os.clock()
end

local function getState(userId: number)
	local state = stateByUserId[userId]
	if not state then
		state = {
			dirty = false,
			version = 0,
			lastSaveAt = 0,
			lastDirtyAt = 0,
			taskActive = false,
			saving = false,
			reason = nil,
		}
		stateByUserId[userId] = state
	end
	return state
end

function SaveScheduler.Bind(store)
	boundStore = store
end

local function attemptSave(player: Player, state, reason: string)
	if state.saving then
		return false, "SaveInProgress"
	end
	if not (boundStore and boundStore._RawSave) then
		return false, "StoreNotBound"
	end

	local version = state.version
	state.saving = true
	local ok, err = boundStore:_RawSave(player, reason)
	state.saving = false
	state.lastSaveAt = now()

	if ok then
		if state.version == version then
			state.dirty = false
		end
		return true
	end

	state.dirty = true
	state.reason = "retry:" .. tostring(reason)
	return false, err
end

local function schedule(userId: number)
	local state = getState(userId)
	if state.taskActive then return end
	state.taskActive = true

	task.spawn(function()
		while true do
			task.wait(0.25)
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				state.taskActive = false
				return
			end
			if not state.dirty then
				state.taskActive = false
				return
			end

			local currentTime = now()
			local shouldSave = (currentTime - state.lastSaveAt >= MIN_INTERVAL)
				or (currentTime - state.lastDirtyAt >= MAX_INTERVAL)
			if shouldSave and not state.saving then
				task.wait(math.random(JITTER_MIN, JITTER_MAX) * 0.1)
				if state.dirty and player.Parent == Players then
					local reason = state.reason or "dirty"
					state.reason = nil
					attemptSave(player, state, reason)
				end
			end
		end
	end)
end

function SaveScheduler.MarkDirty(player: Player, reason: string?)
	local state = getState(player.UserId)
	state.dirty = true
	state.version += 1
	state.lastDirtyAt = now()
	if reason then state.reason = reason end
	schedule(player.UserId)
end

function SaveScheduler.ForceSave(player: Player, reason: string?)
	local state = getState(player.UserId)
	return attemptSave(player, state, reason or "force")
end

function SaveScheduler.Flush(player: Player, reason: string?)
	local state = getState(player.UserId)
	if not state.dirty then
		return true
	end
	return attemptSave(player, state, reason or state.reason or "flush")
end

function SaveScheduler.IsDirty(player: Player): boolean
	local state = stateByUserId[player.UserId]
	return state ~= nil and state.dirty == true
end

function SaveScheduler.Release(player: Player, force: boolean?)
	local state = stateByUserId[player.UserId]
	if not state then return true end
	if state.saving then return false, "SaveInProgress" end
	if state.dirty and force ~= true then return false, "DirtyState" end
	stateByUserId[player.UserId] = nil
	return true
end

return SaveScheduler
