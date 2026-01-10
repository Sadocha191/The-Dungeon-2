-- SCRIPT: PortalToLevel1.server.lua
-- GDZIE: ServerScriptService/PortalToLevel1.server.lua
-- ZMIANA: TeleportData zawiera Profile + StarterWeaponName

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = ReplicatedStorage:WaitForChild("ModuleScripts")

local ProfilesManager = require(serverModules:WaitForChild("ProfilesManager"))
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local Levels = require(replicatedModules:WaitForChild("Levels"))

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemote(name: string): RemoteEvent
	local ev = remoteEvents:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remoteEvents
	return ev
end

local OpenLevelSelect = ensureRemote("OpenLevelSelect")
local RequestLevelTeleport = ensureRemote("RequestLevelTeleport")

local portalModel = workspace:WaitForChild("Portal")
local portalPart = portalModel:WaitForChild("PortalTeleport")

local prompt = portalPart:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Portal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = portalPart
end
prompt.ActionText = "Select level"

local lastOpen: {[number]: number} = {}
local lastTp: {[number]: number} = {}
local OPEN_COOLDOWN = 0.6
local TP_COOLDOWN = 2.0

local function canOpen(player: Player): boolean
	local now = os.clock()
	local last = lastOpen[player.UserId] or 0
	if (now - last) < OPEN_COOLDOWN then return false end
	lastOpen[player.UserId] = now
	return true
end

local function canTeleport(player: Player): boolean
	local now = os.clock()
	local last = lastTp[player.UserId] or 0
	if (now - last) < TP_COOLDOWN then return false end
	lastTp[player.UserId] = now
	return true
end

local function distanceOk(player: Player): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then return false end
	return (hrp.Position - portalPart.Position).Magnitude <= (prompt.MaxActivationDistance + 2)
end

local function sanitizeProfile(profile: any)
	return {
		Id = tostring(profile.Id),
		Class = tostring(profile.Class),
		Race = tostring(profile.Race),
		Stats = profile.Stats,
		Coins = tonumber(profile.Coins) or 0,
		RaceRetryUsed = profile.RaceRetryUsed == true,
	}
end

local WeaponTemplates = ServerStorage:WaitForChild("WeaponTemplates", 10)
if not WeaponTemplates then
	warn("[PortalToLevel1] Missing ServerStorage.WeaponTemplates; fallback to WeaponType attributes only.")
end

local function isWeaponTool(inst: Instance): boolean
	if not inst:IsA("Tool") then
		return false
	end
	if typeof(inst:GetAttribute("WeaponType")) == "string" then
		return true
	end
	return WeaponTemplates and WeaponTemplates:FindFirstChild(inst.Name, true) ~= nil
end

local function findWeaponName(player: Player): string?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, inst in ipairs(backpack:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	local char = player.Character
	if char then
		for _, inst in ipairs(char:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, inst in ipairs(starterGear:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	return nil
end

local function tryTeleport(player: Player, placeId: number)
	local profile = ProfilesManager.GetActiveProfile(player)
	if not profile then
		return
	end

	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	local equipped = PlayerStateStore.GetEquippedWeaponInstance(player)
	if not equipped then
		warn("[PortalToLevel1] Missing equipped weapon instance for", player.Name)
		return
	end
	local weaponName = equipped.weaponId
	if typeof(weaponName) ~= "string" or weaponName == "" then
		warn("[PortalToLevel1] Equipped instance has no weaponId for", player.Name)
		return
	end
	-- utrzymuj legacy pola w sync
	PlayerStateStore.SetStarterWeaponClaimed(player, weaponName)
	PlayerStateStore.EnsureOwnedWeapon(player, weaponName)
	state = PlayerStateStore.Get(player) or state

	local tdata = {
		Profile = sanitizeProfile(profile),
		StarterWeaponName = state.StarterWeaponName,
		EquippedWeaponInstance = {
			InstanceId = equipped.instanceId,
			WeaponId = equipped.weaponId,
			Level = equipped.level,
			Prefix = equipped.prefix,
			RollStats = equipped.rollStats,
		},
		FromPlace = game.PlaceId,
	}

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(tdata)

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, {player}, options)
	end)

	if not ok then
		warn("[PortalToLevel1] TeleportAsync failed:", err)
	end
end

prompt.Triggered:Connect(function(player: Player)
	if player:GetAttribute("TutorialComplete") ~= true then
		return
	end
	if not canOpen(player) then return end
	if not distanceOk(player) then return end
	OpenLevelSelect:FireClient(player)
end)

RequestLevelTeleport.OnServerEvent:Connect(function(player: Player, levelKey: string)
	if player:GetAttribute("TutorialComplete") ~= true then
		return
	end
	if typeof(levelKey) ~= "string" then return end
	if not canTeleport(player) then return end
	if not distanceOk(player) then return end

	local entry = Levels.GetByKey(levelKey)
	if not entry or typeof(entry.placeId) ~= "number" then
		warn("[PortalToLevel1] Unknown level key:", levelKey)
		return
	end

	tryTeleport(player, entry.placeId)
end)

print("[PortalToLevel1] Ready -> Level selector")
