-- SCRIPT: ReceiveTeleportLoadout.server.lua
-- DUNGEON: odbiera TeleportData (Profile + StarterWeaponName + StarterWeaponEntry)
-- ustawia atrybuty gracza + loadout

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

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

Players.PlayerAdded:Connect(function(player: Player)
	local joinData = player:GetJoinData()
	local tdata = joinData and joinData.TeleportData

	if typeof(tdata) ~= "table" then
		warn("[Dungeon] No TeleportData for", player.Name, "- using fallback loadout")
		local data = PlayerData.Get(player)
		local fallbackProfile = {
			Id = "Local",
			Class = player:GetAttribute("Class") or "Default",
			Race = player:GetAttribute("Race") or "Human",
			Stats = { Level = data.level or 1 },
		}
		applyProfileAttributes(player, fallbackProfile)

		local fallbackWeapon = player:GetAttribute("StarterWeaponName")
		if typeof(fallbackWeapon) ~= "string" or fallbackWeapon == "" then
			fallbackWeapon = "Knight's Oath"
			player:SetAttribute("StarterWeaponName", fallbackWeapon)
		end

		WeaponService.SyncLoadoutFromStarter(player)
		WeaponService.EquipLoadout(player)
		return
	end

	local profile = tdata.Profile
	local weaponName = tdata.StarterWeaponName
	local weaponEntry = tdata.StarterWeaponEntry

	if typeof(profile) ~= "table" then
		warn("[Dungeon] Bad TeleportData profile for", player.Name)
		return
	end

	applyProfileAttributes(player, profile)

	local data = PlayerData.Get(player)

	-- ✅ instancja jeśli jest
	if typeof(weaponEntry) == "table" then
		local id = weaponEntry.id or weaponEntry.weaponId or weaponEntry.weaponName or weaponName
		if typeof(id) == "string" and id ~= "" then
			weaponEntry.id = id
			player:SetAttribute("StarterWeaponName", id)
			data.Loadout = { weaponEntry }
			PlayerData.MarkDirty(player)
			WeaponService.EquipLoadout(player)
		else
			warn("[Dungeon] StarterWeaponEntry missing id for", player.Name)
		end
	else
		-- fallback
		if typeof(weaponName) ~= "string" or weaponName == "" then
			weaponName = "Knight's Oath"
		end
		player:SetAttribute("StarterWeaponName", weaponName)
		WeaponService.SyncLoadoutFromStarter(player)
		WeaponService.EquipLoadout(player)
	end

	-- progres (jak było)
	local profLevel = 1
	if typeof(profile.Stats) == "table" and typeof(profile.Stats.Level) == "number" then
		profLevel = math.max(1, math.floor(profile.Stats.Level))
	end
	local profCoins = tonumber(profile.Coins) or 0

	if data.level < profLevel then
		data.level = profLevel
		data.nextXp = PlayerData.RollNextXp(data.level)
		PlayerData.MarkDirty(player)
	end
	if data.coins < profCoins then
		data.coins = profCoins
		PlayerData.MarkDirty(player)
	end

	print("[Dungeon] Loaded:", player.Name, profile.Class, profile.Race, "Weapon=", player:GetAttribute("StarterWeaponName"))
end)

Players.PlayerRemoving:Connect(function(player: Player)
	PlayerData.Save(player)
end)

print("[ReceiveTeleportLoadout] Ready")
