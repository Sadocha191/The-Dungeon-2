-- SCRIPT: LobbyRaceBroadcaster.server.lua
-- GDZIE: ServerScriptService/LobbyRaceBroadcaster.server.lua
-- CO: wysyła RaceUpdated dopiero PO ZAKOŃCZENIU LOSOWANIA (delay),
--     a nie w trakcie animacji. Ustawia player:SetAttribute("Race") tylko finalnie.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ProfilesManager = require(ServerScriptService:WaitForChild("ProfilesManager"))
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- >>> DOPASUJ do długości Twojej animacji losowania rasy (sekundy)
local ROLL_DURATION = 3.5

local function ensureRemote(name: string): RemoteEvent
	local ev = remoteEvents:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remoteEvents
	return ev
end

local RaceUpdated = ensureRemote("RaceUpdated")

local function getRaceFromProfile(plr: Player): string?
	local profile = ProfilesManager.GetActiveProfile(plr)
	if not profile then return nil end
	if typeof(profile.Race) == "string" and profile.Race ~= "" then return profile.Race end
	if typeof(profile.race) == "string" and profile.race ~= "" then return profile.race end
	return nil
end

local function pushRaceFinal(plr: Player)
	if not plr.Parent then return end
	local race = getRaceFromProfile(plr)
	if not race then return end

	-- finalne ustawienie
	plr:SetAttribute("Race", race)
	RaceUpdated:FireClient(plr, {
		race = race,
		final = true,
	})
end

-- Debounce: nie planuj wielu "finalnych" update'ów na raz
local pending: {[number]: boolean} = {}

local function scheduleFinal(plr: Player, delaySec: number)
	local uid = plr.UserId
	if pending[uid] then return end
	pending[uid] = true

	task.delay(delaySec, function()
		pending[uid] = nil
		pushRaceFinal(plr)
	end)
end

local function hookRequest(evName: string, delaySec: number)
	local ev = remoteEvents:FindFirstChild(evName)
	if not (ev and ev:IsA("RemoteEvent")) then
		warn("[LobbyRaceBroadcaster] Missing RemoteEvent:", evName)
		return
	end

	ev.OnServerEvent:Connect(function(plr: Player)
		-- NIE wysyłamy od razu (żeby HUD nie zmieniał w trakcie animacji)
		scheduleFinal(plr, delaySec)
	end)
end

-- CreateProfile i Reroll mają animację losowania
hookRequest("CreateProfileRequest", ROLL_DURATION)
hookRequest("RerollRaceRequest", ROLL_DURATION)

-- ChangeRace (jeśli używasz) zwykle bez animacji -> prawie natychmiast
hookRequest("ChangeRace", 0.1)

-- Join: ustaw bieżącą rasę od razu (bez animacji)
Players.PlayerAdded:Connect(function(plr)
	task.defer(function()
		local race = getRaceFromProfile(plr)
		if race then
			plr:SetAttribute("Race", race)
			-- tu nie musimy strzelać RaceUpdated; HUD i tak zaciągnie atrybut przy render()
		else
			-- placeholder
			plr:SetAttribute("Race", plr:GetAttribute("Race") or "-")
		end
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	pending[plr.UserId] = nil
end)

print("[LobbyRaceBroadcaster] Ready (final-only updates, ROLL_DURATION=" .. tostring(ROLL_DURATION) .. ")")
