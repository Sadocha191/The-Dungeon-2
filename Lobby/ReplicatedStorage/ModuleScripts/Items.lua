--[[
MODULE: ProfilesManager.lua
GDZIE: ServerScriptService/ProfilesManager.lua (ModuleScript)

CO ROBI: Trzyma profile na serwerze (na razie w pamięci) + tworzenie profilu z walidacją.
UWAGA: To jest minimalny fundament. Zapis do DataStore dodamy jako kolejny krok.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts")

local Races = require(moduleFolder:WaitForChild("Races"))
local Classes = require(moduleFolder:WaitForChild("Classes"))

local ProfilesManager = {}

-- In-memory storage: userId -> { ActiveProfileId, Profiles = { [profileId] = profileData } }
local store: {[number]: any} = {}

local function newProfileId(userId: number): string
	-- prosty unikalny id (wystarczy do prototypu)
	return tostring(userId) .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
end

function ProfilesManager.GetUserData(userId: number)
	if not store[userId] then
		store[userId] = { ActiveProfileId = nil, Profiles = {} }
	end
	return store[userId]
end

function ProfilesManager.CreateProfile(player: Player, className: string)
	-- WALIDACJA SERWEROWA
	if typeof(className) ~= "string" then
		return false, "InvalidClassType"
	end
	if not Classes.IsValid(className) then
		return false, "InvalidClass"
	end

	local userData = ProfilesManager.GetUserData(player.UserId)

	-- LIMIT profili (wg założeń “kilka profili”)
	local count = 0
	for _ in pairs(userData.Profiles) do count += 1 end
	if count >= 5 then
		return false, "ProfileLimit"
	end

	local profileId = newProfileId(player.UserId)
	local raceName = Races.RollRandom()

	local profile = {
		Id = profileId,
		CreatedAt = os.time(),
		Class = className,
		Race = raceName,

		Stats = Classes.GetBaseStats(className),

		Inventory = {
			Weapons = {},
			Armor = {},
			Spells = {},
		},

		Unlocks = {
			RacesOwned = { [raceName] = true }, -- startowo ma wylosowaną rasę
		},
	}

	userData.Profiles[profileId] = profile
	userData.ActiveProfileId = profileId

	return true, profile
end

function ProfilesManager.Clear(player: Player)
	store[player.UserId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	ProfilesManager.Clear(player)
end)

return ProfilesManager
