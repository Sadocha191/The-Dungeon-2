-- MODULE: AccountReset.lua
-- GDZIE: ServerScriptService/AccountReset.lua (ModuleScript)
-- CO: reset działa na live, ale tylko dla whitelisty UserId

local DataStoreService = game:GetService("DataStoreService")

-- ✅ wpisz swoje UserId (i ewentualnie testowych kont)
local ALLOWED_USER_IDS = {
	10018945151,
}

local PlayerStateDS = DataStoreService:GetDataStore("PlayerState_v1")
local DungeonDS = DataStoreService:GetDataStore("GlobalPlayerProgress_v1")

local AccountReset = {}

local function isAllowed(userId: number): boolean
	for _, v in ipairs(ALLOWED_USER_IDS) do
		if v == userId then return true end
	end
	return false
end

local function playerStateKey(userId: number): string
	return "u:" .. tostring(userId)
end

function AccountReset.ResetAllForPlayer(player: Player): (boolean, string)
	if not isAllowed(player.UserId) then
		return false, "NotAllowed"
	end

	local uid = player.UserId
	local k1 = playerStateKey(uid)
	local k2 = tostring(uid)

	local ok1, err1 = pcall(function()
		PlayerStateDS:RemoveAsync(k1)
	end)
	local ok2, err2 = pcall(function()
		DungeonDS:RemoveAsync(k2)
	end)

	if not ok1 then
		warn("[AccountReset] PlayerState RemoveAsync FAILED:", err1)
	end
	if not ok2 then
		warn("[AccountReset] Dungeon RemoveAsync FAILED:", err2)
	end

	if ok1 and ok2 then
		print("[AccountReset] OK for", player.Name, "uid=", uid)
		return true, "OK"
	end

	return false, ("PlayerState ok=%s | Dungeon ok=%s"):format(tostring(ok1), tostring(ok2))
end

return AccountReset
