-- ReceiveTeleportLoadout.server.lua
-- Level1/ServerScriptService/Script/ReceiveTeleportLoadout.lua
-- FIX:
-- 1) Nie przerywaj, gdy TeleportData.Profile jest nil (teleport może nieść tylko loadout)
-- 2) Ustaw UnlockedSpellsCSV na graczu (pod Spell roll)
-- 3) StarterWeaponEntry z Lobby ma format instancji z PlayerStateStore (weaponId/rarity/level/prefix/rollStats)

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local function findModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	local folder = ServerScriptService:FindFirstChild("ModuleScript")
		or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end
	return nil
end

local playerDataModule = findModule("PlayerData")
local weaponServiceModule = findModule("WeaponService")
if not playerDataModule or not weaponServiceModule then
	warn("[ReceiveTeleportLoadout] Missing PlayerData/WeaponService module; loadout disabled.")
	return
end

local PlayerData = require(playerDataModule)
local WeaponService = require(weaponServiceModule)

local function applyProfileAttributes(player: Player, profile: any)
	player:SetAttribute("ProfileId", profile.Id)
	player:SetAttribute("Class", profile.Class)
	player:SetAttribute("Race", profile.Race)

	if typeof(profile.Stats) == "table" then
		for k, v in pairs(profile.Stats) do
			if typeof(v) == "number" then
				player:SetAttribute("Stat_" .. tostring(k), v)
			end
		end
	end
end

local function safeCSV(list: any): string
	if typeof(list) ~= "table" then return "" end
	local out = {}
	for _, id in ipairs(list) do
		if typeof(id) == "string" and id ~= "" then
			table.insert(out, id)
		end
	end
	return table.concat(out, ",")
end

Players.PlayerAdded:Connect(function(player: Player)
	local joinData = player:GetJoinData()
	local tdata = joinData and joinData.TeleportData

	local profile = nil
	local weaponName = nil
	local weaponEntry = nil
	local equippedId = nil
	local unlockedSpells = nil

	if typeof(tdata) == "table" then
		profile = tdata.Profile
		weaponName = tdata.StarterWeaponName
		weaponEntry = tdata.StarterWeaponEntry
		equippedId = tdata.EquippedWeaponInstanceId
		unlockedSpells = tdata.UnlockedSpells
	end

	-- Profile: jeśli brak, nie blokuj loadoutu.
	if typeof(profile) ~= "table" then
		local d = PlayerData.Get(player)
		local fallbackProfile = {
			Id = "Local",
			Class = player:GetAttribute("Class") or "Default",
			Race = player:GetAttribute("Race") or "Human",
			Stats = { Level = d.level or 1 },
		}
		applyProfileAttributes(player, fallbackProfile)
	else
		applyProfileAttributes(player, profile)
	end

	-- Spells unlocked (do losowania w runie)
	player:SetAttribute("UnlockedSpellsCSV", safeCSV(unlockedSpells))

	if typeof(equippedId) == "string" and equippedId ~= "" then
		player:SetAttribute("EquippedWeaponInstanceId", equippedId)
	end

	local data = PlayerData.Get(player)

	-- Weapon loadout
	if typeof(weaponEntry) == "table" then
		-- normalize -> WeaponService rozumie id/weaponId/weaponName
		local id = weaponEntry.id or weaponEntry.weaponId or weaponEntry.weaponName or weaponName
		if typeof(id) == "string" and id ~= "" then
			weaponEntry.id = id
			player:SetAttribute("StarterWeaponName", id)
			data.Loadout = { weaponEntry }
			PlayerData.MarkDirty(player)
			WeaponService.EquipLoadout(player)
		else
			warn("[Dungeon] StarterWeaponEntry missing id for", player.Name)
			-- fallback
			if typeof(weaponName) ~= "string" or weaponName == "" then
				weaponName = "Knight's Oath"
			end
			player:SetAttribute("StarterWeaponName", weaponName)
			WeaponService.SyncLoadoutFromStarter(player)
			WeaponService.EquipLoadout(player)
		end
	else
		if typeof(weaponName) ~= "string" or weaponName == "" then
			weaponName = player:GetAttribute("StarterWeaponName")
		end
		if typeof(weaponName) ~= "string" or weaponName == "" then
			weaponName = "Knight's Oath"
		end
		player:SetAttribute("StarterWeaponName", weaponName)
		WeaponService.SyncLoadoutFromStarter(player)
		WeaponService.EquipLoadout(player)
	end

	print("[Dungeon] Loaded:", player.Name, "Weapon=", player:GetAttribute("StarterWeaponName"))
end)

Players.PlayerRemoving:Connect(function(player: Player)
	PlayerData.Save(player)
end)

print("[ReceiveTeleportLoadout] Ready")
