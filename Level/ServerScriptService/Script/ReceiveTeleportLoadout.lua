-- ReceiveTeleportLoadout.server.lua (Level1)
-- Applies weapon/run metadata from TeleportData.
-- Works for single and multi, including per-player weapon map.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = modFolder and require(modFolder:WaitForChild("SpellDefinitions"))

local BASE_WALKSPEED = 21
local BASE_MAX_HP = 47
local BASE_JUMPPOWER = 50
local TELEPORT_DATA_RETRIES = 120
local TELEPORT_DATA_RETRY_DELAY = 0.05

local function findModule(name: string): ModuleScript?
	local roots = { ServerScriptService, ReplicatedStorage }
	for _, root in ipairs(roots) do
		local found = root:FindFirstChild(name, true)
		if found and found:IsA("ModuleScript") then
			return found
		end
	end
	return nil
end

local PlayerData = require(findModule("PlayerData") or error("Missing PlayerData"))
local WeaponService = require(findModule("WeaponService") or error("Missing WeaponService"))

local function safeCSV(list: any): string
	if typeof(list) ~= "table" then
		return ""
	end
	local out = {}
	for _, id in ipairs(list) do
		if typeof(id) == "string" and id ~= "" then
			table.insert(out, id)
		end
	end
	return table.concat(out, ",")
end

local function normalizeWeaponEntry(weaponEntry: any, weaponName: string?): {[string]: any}?
	if typeof(weaponEntry) ~= "table" then
		return nil
	end

	local id = weaponEntry.id or weaponEntry.weaponId or weaponEntry.weaponName or weaponName
	if typeof(id) ~= "string" or id == "" then
		return nil
	end

	local out: {[string]: any} = {}
	for k, v in pairs(weaponEntry) do
		if typeof(k) == "string" then
			local vt = typeof(v)
			if vt == "string" or vt == "number" or vt == "boolean" or vt == "table" then
				out[k] = v
			end
		end
	end
	out.id = id
	if typeof(out.weaponId) ~= "string" or out.weaponId == "" then
		out.weaponId = id
	end
	return out
end

local function getStoredWeaponFromProfile(data: any): (string?, any)
	if typeof(data) ~= "table" then
		return nil, nil
	end

	local loadout = data.Loadout
	if typeof(loadout) ~= "table" then
		return nil, nil
	end

	local first = loadout[1]
	if typeof(first) == "table" then
		local id = first.id or first.weaponId or first.weaponName
		if typeof(id) == "string" and id ~= "" then
			return id, first
		end
	elseif typeof(first) == "string" and first ~= "" then
		return first, { id = first }
	end

	return nil, nil
end

local function applyWeapon(plr: Player, weaponName: string?, weaponEntry: any)
	local data = PlayerData.Get(plr)
	local normalizedEntry = normalizeWeaponEntry(weaponEntry, weaponName)

	if normalizedEntry then
		local id = normalizedEntry.id
		plr:SetAttribute("StarterWeaponName", id)
		data.Loadout = { normalizedEntry }
		if PlayerData.MarkDirty then
			PlayerData.MarkDirty(plr)
		end
		return
	end

	if typeof(weaponName) ~= "string" or weaponName == "" then
		local storedName = nil
		storedName, _ = getStoredWeaponFromProfile(data)
		if typeof(storedName) == "string" and storedName ~= "" then
			plr:SetAttribute("StarterWeaponName", storedName)
			return
		end
		weaponName = "Knight's Oath"
	end

	plr:SetAttribute("StarterWeaponName", weaponName)
	if WeaponService.SyncLoadoutFromStarter then
		WeaponService.SyncLoadoutFromStarter(plr)
	else
		data.Loadout = { { id = weaponName } }
		if PlayerData.MarkDirty then
			PlayerData.MarkDirty(plr)
		end
	end
end

local function getTeleportData(plr: Player): any
	for _ = 1, TELEPORT_DATA_RETRIES do
		local joinData = plr:GetJoinData()
		local tdata = joinData and joinData.TeleportData
		if typeof(tdata) == "table" then
			return tdata
		end
		task.wait(TELEPORT_DATA_RETRY_DELAY)
	end
	return nil
end

local function getPerPlayerWeaponMap(tdata: any): any
	if typeof(tdata) ~= "table" then
		return nil
	end
	if typeof(tdata.WeaponByUserId) == "table" then
		return tdata.WeaponByUserId
	end
	if typeof(tdata.WeaponsByUserId) == "table" then
		return tdata.WeaponsByUserId
	end
	if typeof(tdata.LoadoutByUserId) == "table" then
		return tdata.LoadoutByUserId
	end
	if typeof(tdata.WeaponNameByUserId) == "table" then
		return tdata.WeaponNameByUserId
	end
	return nil
end

local function mapValueByUserId(map: any, userId: number): any
	if typeof(map) ~= "table" then
		return nil
	end
	local key = tostring(userId)
	if map[key] ~= nil then
		return map[key]
	end
	if map[userId] ~= nil then
		return map[userId]
	end
	for k, v in pairs(map) do
		if tonumber(k) == userId then
			return v
		end
	end
	return nil
end

local function findPerPlayerPayload(tdata: any, userId: number): any
	local map = getPerPlayerWeaponMap(tdata)
	return mapValueByUserId(map, userId)
end

local function resolveTeleportWeapon(tdata: any, userId: number): (string?, any)
	if typeof(tdata) ~= "table" then
		return nil, nil
	end

	local weaponName = tdata.StarterWeaponName
	local weaponEntry = tdata.StarterWeaponEntry

	local me = findPerPlayerPayload(tdata, userId)
	if typeof(me) == "string" and me ~= "" then
		weaponName = me
	elseif typeof(me) == "table" then
		local candidateName = me.StarterWeaponName or me.weaponName or me.weaponId or me.id or me.StarterWeapon
		if typeof(candidateName) == "string" and candidateName ~= "" then
			weaponName = candidateName
		end
		local candidateEntry = me.StarterWeaponEntry or me.weaponEntry or me.entry or me.LoadoutEntry
		if candidateEntry ~= nil then
			weaponEntry = candidateEntry
		elseif me.id or me.weaponId or me.weaponName then
			weaponEntry = me
		end
	end

	return weaponName, weaponEntry
end

local function applyUnlockedSpells(plr: Player, unlocked: any)
	local merged = {}
	local seen = {}

	if SpellDefs and SpellDefs.BASE_STARTER then
		for _, id in ipairs(SpellDefs.BASE_STARTER) do
			if typeof(id) == "string" and id ~= "" and not seen[id] then
				seen[id] = true
				table.insert(merged, id)
			end
		end
	end

	if typeof(unlocked) == "table" then
		for _, id in ipairs(unlocked) do
			if typeof(id) == "string" and id ~= "" and not seen[id] then
				seen[id] = true
				table.insert(merged, id)
			end
		end
	end

	plr:SetAttribute("UnlockedSpellsCSV", safeCSV(merged))
end

local processed: {[Player]: boolean} = {}

local function processPlayer(plr: Player)
	if processed[plr] then
		return
	end
	processed[plr] = true

	local tdata = getTeleportData(plr)
	local weaponName, weaponEntry, unlocked = nil, nil, nil
	local runMode, partyId, partyLeader, levelKey = nil, nil, nil, nil

	if typeof(tdata) == "table" then
		weaponName, weaponEntry = resolveTeleportWeapon(tdata, plr.UserId)
		unlocked = tdata.UnlockedSpells
		runMode = tdata.RunMode
		partyId = tdata.PartyId
		partyLeader = tdata.PartyLeaderUserId
		levelKey = tdata.LevelKey or tdata.levelKey
	else
		print("[ReceiveTeleportLoadout] Missing TeleportData for", plr.Name, "- using saved/default loadout")
	end

	applyUnlockedSpells(plr, unlocked)

	if runMode == "Multi" or runMode == "Single" then
		plr:SetAttribute("RunMode", runMode)
	else
		plr:SetAttribute("RunMode", "Single")
	end
	if typeof(partyId) == "string" and partyId ~= "" then
		plr:SetAttribute("PartyId", partyId)
	end
	if typeof(partyLeader) == "number" then
		plr:SetAttribute("PartyLeaderUserId", partyLeader)
	end
	if typeof(levelKey) == "string" and levelKey ~= "" then
		plr:SetAttribute("LevelKey", levelKey)
	else
		plr:SetAttribute("LevelKey", "AshenWastes")
	end

	applyWeapon(plr, weaponName, weaponEntry)

	local function equipNow()
		if WeaponService.EquipLoadout then
			pcall(function()
				WeaponService.EquipLoadout(plr)
			end)
		end
	end

	plr.CharacterAdded:Connect(function(char)
		task.wait(0.15)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			plr:SetAttribute("BaseWalkSpeed", BASE_WALKSPEED)
			plr:SetAttribute("BaseMaxHP", BASE_MAX_HP)
			plr:SetAttribute("BaseJumpPower", BASE_JUMPPOWER)
			plr:SetAttribute("RunBonusHP", 0)
			plr:SetAttribute("RunBonusSpeed", 0)
			plr:SetAttribute("RunAtkMult", 1)
			plr:SetAttribute("MoveSprintLevel", 0)
			plr:SetAttribute("MoveExtraJumpBonus", 0)
			plr:SetAttribute("MoveSlideLevel", 0)
			plr:SetAttribute("MoveDashLevel", 0)
			hum.UseJumpPower = true
			hum.WalkSpeed = BASE_WALKSPEED
			hum.JumpPower = BASE_JUMPPOWER
			hum.MaxHealth = BASE_MAX_HP
			hum.Health = BASE_MAX_HP
		end
		equipNow()
	end)

	task.defer(function()
		if plr.Character then
			equipNow()
		end
	end)
end

Players.PlayerAdded:Connect(processPlayer)

for _, plr in ipairs(Players:GetPlayers()) do
	task.defer(processPlayer, plr)
end

Players.PlayerRemoving:Connect(function(plr: Player)
	processed[plr] = nil
	if PlayerData.Save then
		pcall(function()
			PlayerData.Save(plr)
		end)
	end
end)

print("[ReceiveTeleportLoadout] Ready (spells)")
