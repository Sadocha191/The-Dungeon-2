-- SaveScheduler.lua
-- Jeden scheduler zapisów dla całej gry: batch + debounce.
-- Użycie:
--   local SaveScheduler = require(...SaveScheduler)
--   SaveScheduler.Bind(store)  -- store musi mieć :_RawSave(player, reason)
--   SaveScheduler.MarkDirty(player, "reason")
--   SaveScheduler.ForceSave(player, "reason")

local Players = game:GetService("Players")

local SaveScheduler = {}

-- TUNING:
local MIN_INTERVAL = 25       -- minimalnie co ile sekund zapis (anti-spam)
local MAX_INTERVAL = 75       -- maksymalnie co ile sekund wymuś zapis jeśli brudne
local JITTER_MIN = 1
local JITTER_MAX = 4

local boundStore = nil

local stateByUserId: {[number]: {
	dirty: boolean,
	lastSaveAt: number,
	lastDirtyAt: number,
	taskActive: boolean,
	reason: string?
}} = {}

local function now(): number
	return os.clock()
end

local function getState(userId: number)
	local st = stateByUserId[userId]
	if not st then
		st = {
			dirty = false,
			lastSaveAt = 0,
			lastDirtyAt = 0,
			taskActive = false,
			reason = nil,
		}
		stateByUserId[userId] = st
	end
	return st
end

function SaveScheduler.Bind(store)
	boundStore = store
end

local function schedule(userId: number)
	local st = getState(userId)
	if st.taskActive then return end
	st.taskActive = true

	task.spawn(function()
		while true do
			task.wait(0.25)

			local plr = Players:GetPlayerByUserId(userId)
			if not plr then
				-- gracz wyszedł, scheduler kończy
				st.taskActive = false
				return
			end

			if not st.dirty then
				st.taskActive = false
				return
			end

			local t = now()
			local sinceSave = t - st.lastSaveAt
			local sinceDirty = t - st.lastDirtyAt

			local shouldSave =
				(sinceSave >= MIN_INTERVAL) or
				(sinceDirty >= MAX_INTERVAL)

			if shouldSave then
				if boundStore and boundStore._RawSave then
					local reason = st.reason or "dirty"
					st.reason = nil
					st.dirty = false
					st.lastSaveAt = now()

					-- mały jitter żeby nie walić wielu graczy w tym samym ticku
					task.wait(math.random(JITTER_MIN, JITTER_MAX) * 0.1)

					boundStore:_RawSave(plr, reason)
				else
					-- brak store -> nie rób nic, ale wyłącz task żeby nie mielić
					st.taskActive = false
					return
				end
			end
		end
	end)
end

function SaveScheduler.MarkDirty(player: Player, reason: string?)
	local st = getState(player.UserId)
	st.dirty = true
	st.lastDirtyAt = now()
	if reason then st.reason = reason end
	schedule(player.UserId)
end

function SaveScheduler.ForceSave(player: Player, reason: string?)
	local st = getState(player.UserId)
	st.dirty = false
	st.reason = nil
	st.lastSaveAt = now()

	if boundStore and boundStore._RawSave then
		boundStore:_RawSave(player, reason or "force")
	end
end

Players.PlayerRemoving:Connect(function(player)
	-- nic nie zapisujemy tu bezpośrednio (store zrobi własny ForceSave).
	stateByUserId[player.UserId] = nil
end)

return SaveScheduler
