-- SCRIPT: ReceiveTeleportLoadout.server.lua
-- GDZIE: ServerScriptService/ReceiveTeleportLoadout.server.lua (Script)
-- CO: odbiera TeleportData (Profile + StarterWeaponName)
--     ustawia atrybuty gracza + daje broń z ServerStorage/WeaponTemplates
--     synchronizuje level/coins z Twoim PlayerData

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local PlayerData = require(serverModules:WaitForChild("PlayerData"))
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))

local function findWeaponCatalog(): ModuleScript?
	local direct = ServerScriptService:FindFirstChild("WeaponCatalog", true)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	local folder = ServerScriptService:FindFirstChild("ModuleScript")
		or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild("WeaponCatalog")
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end
	return nil
end

local weaponCatalogModule = findWeaponCatalog()
if not weaponCatalogModule then
	warn("[ReceiveTeleportLoadout] Missing WeaponCatalog module; loadout disabled.")
	return
end

local WeaponCatalog = require(weaponCatalogModule)

local function giveTool(player: Player, toolName: string): boolean
	local template = WeaponCatalog.FindTemplate(toolName)
	if not template then
		warn("[Dungeon] Missing weapon template:", toolName)
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false end

	local clone = template:Clone()
	WeaponCatalog.PrepareTool(clone, toolName)
	clone.Parent = backpack
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		local starterClone = template:Clone()
		WeaponCatalog.PrepareTool(starterClone, toolName)
		starterClone.Parent = starterGear
	end
	return true
end

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
		warn("[Dungeon] No TeleportData for", player.Name)
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
	if giveTool(player, weaponName) then
		PlayerStateStore.EnsureOwnedWeapon(player, weaponName)
		PlayerStateStore.SetEquippedWeaponName(player, weaponName)
	end

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
