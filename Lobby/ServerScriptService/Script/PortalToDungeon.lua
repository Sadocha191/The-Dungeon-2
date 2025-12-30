-- SCRIPT: PortalToLevel1.server.lua
-- GDZIE: ServerScriptService/PortalToLevel1.server.lua
-- ZMIANA: TeleportData zawiera Profile + StarterWeaponName

local TeleportService = game:GetService("TeleportService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfilesManager = require(ServerScriptService:WaitForChild("ProfilesManager"))
local PlayerStateStore = require(ServerScriptService:WaitForChild("PlayerStateStore"))

local LEVEL1_PLACE_ID = 82864046258949
local LEVELS = {
	{
		id = LEVEL1_PLACE_ID,
		name = "Level 1",
	},
}

local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local openLevelSelect = remoteFolder:WaitForChild("OpenLevelSelect")
local levelSelectRequest = remoteFolder:WaitForChild("LevelSelectRequest")

local portalModel = workspace:WaitForChild("Portal")
local portalPart = portalModel:WaitForChild("PortalTeleport")

local prompt = portalPart:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Wybierz poziom"
	prompt.ObjectText = "Portal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = portalPart
end

local lastTp: {[number]: number} = {}
local COOLDOWN = 2.0
local pendingSelect: {[number]: number} = {}
local SELECT_TIMEOUT = 15.0

local function canCall(player: Player): boolean
	local now = os.clock()
	local last = lastTp[player.UserId] or 0
	if (now - last) < COOLDOWN then return false end
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

local function buildTeleportData(player: Player)
	local profile = ProfilesManager.GetActiveProfile(player)
	if not profile then
		return nil
	end

	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if not state.StarterWeaponClaimed or typeof(state.StarterWeaponName) ~= "string" then
		-- wymuszamy broń przed wejściem do dungeona
		return nil
	end

	return {
		Profile = sanitizeProfile(profile),
		StarterWeaponName = state.StarterWeaponName, -- ✅
		FromPlace = game.PlaceId,
	}
end

local function isLevelAvailable(placeId: number): boolean
	for _, level in ipairs(LEVELS) do
		if level.id == placeId then
			return true
		end
	end
	return false
end

prompt.Triggered:Connect(function(player: Player)
	if not canCall(player) then return end
	if not distanceOk(player) then return end

	local tdata = buildTeleportData(player)
	if not tdata then
		return
	end

	pendingSelect[player.UserId] = os.clock()
	openLevelSelect:FireClient(player, LEVELS)
end)

levelSelectRequest.OnServerEvent:Connect(function(player: Player, placeId: any)
	if typeof(placeId) ~= "number" then return end
	if not isLevelAvailable(placeId) then return end
	if not distanceOk(player) then return end

	local pendingAt = pendingSelect[player.UserId]
	if not pendingAt or (os.clock() - pendingAt) > SELECT_TIMEOUT then
		return
	end
	pendingSelect[player.UserId] = nil

	local tdata = buildTeleportData(player)
	if not tdata then
		return
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(tdata)

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, {player}, options)
	end)

	if not ok then
		warn("[PortalToLevel1] TeleportAsync failed:", err)
	end
end)

print("[PortalToLevel1] Ready ->", LEVEL1_PLACE_ID)
