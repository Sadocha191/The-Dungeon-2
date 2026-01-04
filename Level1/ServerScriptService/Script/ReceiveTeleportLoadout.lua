-- SCRIPT: ReceiveTeleportLoadout.server.lua
-- GDZIE: ServerScriptService/ReceiveTeleportLoadout.server.lua (Script)
-- CO: odbiera TeleportData (Profile + StarterWeaponName)
--     ustawia atrybuty gracza + daje broń z ServerStorage/WeaponTemplates
--     synchronizuje level/coins z Twoim PlayerData

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

	-- staty jako atrybuty (opcjonalnie)
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
		local fallback = player:GetAttribute("StarterWeaponName")
		if typeof(fallback) == "string" and fallback ~= "" then
			WeaponService.SyncLoadoutFromStarter(player)
		end
		WeaponService.EquipLoadout(player)
		return
	end

	local profile = tdata.Profile
	local weaponName = tdata.StarterWeaponName

	if typeof(profile) ~= "table" or typeof(weaponName) ~= "string" then
		warn("[Dungeon] Bad TeleportData for", player.Name)
		return
	end

	applyProfileAttributes(player, profile)

	-- ✅ bron
	player:SetAttribute("StarterWeaponName", weaponName)
	WeaponService.SyncLoadoutFromStarter(player)
	WeaponService.EquipLoadout(player)

	-- ✅ podepnij do Twojego globalnego progresu w dungeon
	local data = PlayerData.Get(player)

	-- jeżeli chcesz, żeby level/coins z profilu startowego nadpisywały dungeonowe ONLY gdy większe:
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

	print("[Dungeon] Loaded:", player.Name, profile.Class, profile.Race, "Weapon=", weaponName)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	PlayerData.Save(player)
end)

print("[ReceiveTeleportLoadout] Ready")
