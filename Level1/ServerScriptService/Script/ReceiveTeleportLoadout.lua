-- ReceiveTeleportLoadout.server.lua (Level1)
-- FIX PACK 11:
-- 1) NIE przerywaj jeśli TeleportData.Profile jest nil (broń ma się załadować i tak)
-- 2) EquipLoadout dopiero po CharacterAdded (Tool wymaga postaci)
-- 3) Logi w output: co przyszło z TeleportData

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local function findModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then return direct end
	local folder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then return nested end
	end
	-- deep find fallback
	local found = ServerScriptService:FindFirstChild(name, true)
	if found and found:IsA("ModuleScript") then return found end
	return nil
end

local PlayerData = require(findModule("PlayerData") or error("Missing PlayerData"))
local WeaponService = require(findModule("WeaponService") or error("Missing WeaponService"))

local function applyWeapon(plr: Player, weaponName: string?, weaponEntry: any)
	local d = PlayerData.Get(plr)

	if typeof(weaponEntry) == "table" then
		local id = weaponEntry.id or weaponEntry.weaponId or weaponEntry.weaponName or weaponName
		if typeof(id) == "string" and id ~= "" then
			weaponEntry.id = id
			plr:SetAttribute("StarterWeaponName", id)
			d.Loadout = { weaponEntry }
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
		d.Loadout = { { id = weaponName } }
		if PlayerData.MarkDirty then PlayerData.MarkDirty(plr) end
	end
end

local function equipAfterSpawn(plr: Player)
	if WeaponService.EquipLoadout then
		pcall(function() WeaponService.EquipLoadout(plr) end)
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	local joinData = player:GetJoinData()
	local tdata = joinData and joinData.TeleportData

	local weaponName, weaponEntry, equippedId = nil, nil, nil
	if typeof(tdata) == "table" then
		weaponName = tdata.StarterWeaponName
		weaponEntry = tdata.StarterWeaponEntry
		equippedId = tdata.EquippedWeaponInstanceId
	end

	print("[ReceiveTeleportLoadout] ", player.Name, "TeleportData.weaponName=", tostring(weaponName),
		"weaponEntry.weaponId=", tostring(typeof(weaponEntry)=="table" and weaponEntry.weaponId or nil),
		"equippedId=", tostring(equippedId))

	if typeof(equippedId) == "string" and equippedId ~= "" then
		player:SetAttribute("EquippedWeaponInstanceId", equippedId)
	end

	applyWeapon(player, weaponName, weaponEntry)

	player.CharacterAdded:Connect(function()
		task.wait(0.15)
		equipAfterSpawn(player)
	end)

	task.defer(function()
		if player.Character then
			equipAfterSpawn(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	if PlayerData.Save then pcall(function() PlayerData.Save(player) end) end
end)

print("[ReceiveTeleportLoadout] Ready (fix_pack11)")
