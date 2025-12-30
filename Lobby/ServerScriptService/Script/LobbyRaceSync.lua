-- SCRIPT: LobbyRaceSync.server.lua
-- GDZIE: ServerScriptService/LobbyRaceSync.server.lua
-- CO: ustawia player:SetAttribute("Race") NATYCHMIAST na podstawie payloadu response.
--     Działa z Twoimi eventami: CreateProfileResponse, RerollRaceResponse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

local CreateProfileResponse = remoteFolder:WaitForChild("CreateProfileResponse")
local RerollRaceResponse = remoteFolder:WaitForChild("RerollRaceResponse")

-- Owijamy FireClient, żeby za każdym razem, gdy serwer wysyła wynik losowania,
-- równolegle ustawić atrybut Race na graczu.
local function wrapResponseEvent(ev: RemoteEvent, extractRace: (any) -> (string?))
	local original = ev.FireClient
	ev.FireClient = function(self, player: Player, ...)
		local args = { ... }
		local race = nil
		for _, arg in ipairs(args) do
			race = extractRace(arg)
			if race then break end
		end
		if typeof(race) == "string" and race ~= "" then
			player:SetAttribute("Race", race)
		end
		return original(self, player, table.unpack(args))
	end
end

-- payloady u Ciebie mogą wyglądać różnie, więc obsługujemy kilka formatów
local function extractRace(payload: any): string?
	if typeof(payload) ~= "table" then return nil end
	-- najczęstsze:
	if typeof(payload.race) == "string" then return payload.race end
	if typeof(payload.Race) == "string" then return payload.Race end
	if typeof(payload.newRace) == "string" then return payload.newRace end
	if typeof(payload.NewRace) == "string" then return payload.NewRace end
	-- czasem w profilu:
	if typeof(payload.profile) == "table" and typeof(payload.profile.Race) == "string" then
		return payload.profile.Race
	end
	if typeof(payload.profile) == "table" and typeof(payload.profile.race) == "string" then
		return payload.profile.race
	end
	return nil
end

wrapResponseEvent(CreateProfileResponse, extractRace)
wrapResponseEvent(RerollRaceResponse, extractRace)

-- na wszelki wypadek: ustaw Race przy joinie, jeśli już jest gdzieś w atrybutach/GUI (fallback)
Players.PlayerAdded:Connect(function(plr)
	if plr:GetAttribute("Race") == nil then
		plr:SetAttribute("Race", "-")
	end
end)

print("[LobbyRaceSync] Ready (hooks CreateProfileResponse + RerollRaceResponse)")
