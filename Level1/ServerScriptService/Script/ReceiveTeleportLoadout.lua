-- ReceiveTeleportLoadout.server.lua (Level1)
-- Fix:
-- - Aplikuje broń z TeleportData (Tool equip dopiero po CharacterAdded)
-- - Ustawia UnlockedSpellsCSV z TeleportData.UnlockedSpells (kupione u wiedźmy)

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = modFolder and require(modFolder:WaitForChild("SpellDefinitions"))

local BASE_WALKSPEED = 18
local BASE_MAX_HP = 120

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
	if typeof(list) ~= "table" then return "" end
	local out = {}
	for _, id in ipairs(list) do
		if typeof(id) == "string" and id ~= "" then table.insert(out, id) end
	end
	return table.concat(out, ",")
end

local function applyWeapon(plr: Player, weaponName: string?, weaponEntry: any)
	local data = PlayerData.Get(plr)

	if typeof(weaponEntry) == "table" then
		local id = weaponEntry.id or weaponEntry.weaponId or weaponEntry.weaponName or weaponName
		if typeof(id) == "string" and id ~= "" then
			weaponEntry.id = id
			plr:SetAttribute("StarterWeaponName", id)
			data.Loadout = { weaponEntry }
			if PlayerData.MarkDirty then PlayerData.MarkDirty(plr) end
			return
		end
	end

	if typeof(weaponName) ~= "string" or weaponName == "" then
		weaponName = "Knight's Oath"
	end
	plr:SetAttribute("StarterWeaponName", weaponName)
	if WeaponService.SyncLoadoutFromStarter then
		WeaponService.SyncLoadoutFromStarter(plr)
	else
		data.Loadout = { { id = weaponName } }
		if PlayerData.MarkDirty then PlayerData.MarkDirty(plr) end
	end
end

Players.PlayerAdded:Connect(function(plr: Player)
	local joinData = plr:GetJoinData()
	local tdata = joinData and joinData.TeleportData

	local weaponName, weaponEntry, unlocked = nil, nil, nil
	local runMode, partyId, partyLeader = nil, nil, nil
	if typeof(tdata) == "table" then
		weaponName = tdata.StarterWeaponName
		weaponEntry = tdata.StarterWeaponEntry
		unlocked = tdata.UnlockedSpells
		runMode = tdata.RunModee
		partyId = tdata.PartyId
		partyLeader = tdata.PartyLeaderUserId
	-- Jeśli teleport wysłał mapę broni per-player (party), to bierzemy broń dla tego userId.
	if typeof(tdata) == "table" and typeof(tdata.WeaponByUserId) == "table" then
		local me = tdata.WeaponByUserId[tostring(plr.UserId)]
		if typeof(me) == "table" then
			if me.StarterWeaponName ~= nil then weaponName = me.StarterWeaponName end
			if me.StarterWeaponEntry ~= nil then weaponEntry = me.StarterWeaponEntry end
		end
	end

	end

	do
	local merged = {}
	local seen = {}
	-- base starters always available in run
	if SpellDefs and SpellDefs.BASE_STARTER then
		for _, id in ipairs(SpellDefs.BASE_STARTER) do
			if not seen[id] then
				seen[id] = true
				table.insert(merged, id)
			end
		end
	end
	-- unlocked from lobby (witch purchases)
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

	-- run mode attrs for other systems (pause/death logic)
	if runMode == "Multi" or runMode == "Single" then
		plr:SetAttribute("RunMode", runMode)
	else
		plr:SetAttribute("RunMode", "Single")
	end
	if typeof(partyId) == "string" then
		plr:SetAttribute("PartyId", partyId)
	end
	if typeof(partyLeader) == "number" then
		plr:SetAttribute("PartyLeaderUserId", partyLeader)
	end

	applyWeapon(plr, weaponName, weaponEntry)

	local function equipNow()
		if WeaponService.EquipLoadout then
			pcall(function() WeaponService.EquipLoadout(plr) end)
		end
	end

	plr.CharacterAdded:Connect(function(char)
		task.wait(0.15)
		-- base movement + hp for run (also used by level stat gains)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			plr:SetAttribute("BaseWalkSpeed", BASE_WALKSPEED)
			plr:SetAttribute("BaseMaxHP", BASE_MAX_HP)
			plr:SetAttribute("RunBonusHP", 0)
			plr:SetAttribute("RunBonusSpeed", 0)
			plr:SetAttribute("RunAtkMult", 1)
			hum.WalkSpeed = BASE_WALKSPEED
			hum.MaxHealth = BASE_MAX_HP
			hum.Health = BASE_MAX_HP
		end
		equipNow()
	end)

	task.defer(function()
		if plr.Character then equipNow() end
	end)
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	if PlayerData.Save then
		pcall(function() PlayerData.Save(plr) end)
	end
end)

print("[ReceiveTeleportLoadout] Ready (spells)")
