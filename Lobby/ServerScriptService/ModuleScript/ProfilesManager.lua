-- MODULE: ProfilesManager.lua
-- GDZIE: ServerScriptService/ModuleScript/ProfilesManager.lua
-- CO: Trzyma aktywny profil w pamięci + tworzy profil. Bez Modulescriptu Classes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local replicatedModules = ReplicatedStorage:WaitForChild("ModuleScripts")

local Races = require(replicatedModules:WaitForChild("Races"))
local Items = require(replicatedModules:WaitForChild("Items"))

local PlayerStateStore = require(script.Parent:WaitForChild("PlayerStateStore"))

local ProfilesManager = {}
local mem: {[number]: any} = {} -- userId -> aktywny profil (w pamięci)

local function newProfileId(userId: number): string
	return tostring(userId) .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
end

function ProfilesManager.GetActiveProfile(player: Player)
	return mem[player.UserId]
end

function ProfilesManager.LoadIfAny(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if state.CreatedOnce and typeof(state.Profile) == "table" then
		mem[player.UserId] = state.Profile
	end
end

function ProfilesManager.CreateProfile(player: Player, className: string)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if state.CreatedOnce then
		return false, "AlreadyCreated"
	end

	if typeof(className) ~= "string" or not Items.IsValidClass(className) then
		-- fallback: jak klient wyśle nil/śmieci
		className = Items.GetDefaultClass()
	end

	local profile = {
		Id = newProfileId(player.UserId),
		CreatedAt = os.time(),
		Class = className,
		Race = Races.RollForClass(className),
		Stats = Items.GetBaseStats(className),
		Coins = 0,
		RaceRetryUsed = false,
	}

	mem[player.UserId] = profile

	-- zapis do globalnego PlayerStateStore (to już masz w systemie)
	PlayerStateStore.SetCreated(player, {
		Id = profile.Id,
		CreatedAt = profile.CreatedAt,
		Class = profile.Class,
		Race = profile.Race,
		Stats = profile.Stats,
		Coins = profile.Coins,
		RaceRetryUsed = profile.RaceRetryUsed,
	})

	return true, profile
end

function ProfilesManager.RerollRaceOnce(player: Player)
	local profile = mem[player.UserId]
	if not profile then
		ProfilesManager.LoadIfAny(player)
		profile = mem[player.UserId]
	end
	if not profile then
		return false, "NoActiveProfile"
	end
	if profile.RaceRetryUsed then
		return false, "RetryAlreadyUsed"
	end

	profile.Race = Races.RollForClass(profile.Class or Items.GetDefaultClass())
	profile.RaceRetryUsed = true

	-- update DS
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	state.Profile = state.Profile or {}
	state.Profile.Race = profile.Race
	state.Profile.RaceRetryUsed = true
	PlayerStateStore.Save(player)

	return true, profile
end

Players.PlayerAdded:Connect(function(player)
	PlayerStateStore.Load(player)
	ProfilesManager.LoadIfAny(player)
end)

Players.PlayerRemoving:Connect(function(player)
	mem[player.UserId] = nil
end)

return ProfilesManager
