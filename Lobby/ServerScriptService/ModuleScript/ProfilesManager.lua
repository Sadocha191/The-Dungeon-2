-- MODULE: ProfilesManager.lua
-- GDZIE: ServerScriptService/ProfilesManager.lua (ModuleScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Races = require(ReplicatedStorage:WaitForChild("Races"))
local Classes = require(ReplicatedStorage:WaitForChild("Classes"))

local PlayerStateStore = require(script.Parent:WaitForChild("PlayerStateStore"))

local ProfilesManager = {}
local mem: {[number]: any} = {} -- userId -> active profile (w pamięci)

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

	if typeof(className) ~= "string" or not Classes.IsValid(className) then
		return false, "InvalidClass"
	end

	local profile = {
		Id = newProfileId(player.UserId),
		CreatedAt = os.time(),
		Class = className,
		Race = Races.RollForClass(className),
		Stats = Classes.GetBaseStats(className),
		Coins = 0,
		RaceRetryUsed = false,
	}

	mem[player.UserId] = profile

	PlayerStateStore.SetCreated(player, {
		Id = profile.Id,
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

	profile.Race = Races.RollForClass(profile.Class or "Default")
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
