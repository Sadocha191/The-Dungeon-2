-- RunDeathHandler.server.lua (Level1)
--
-- Single:
--   - when player dies => end run
-- Multiplayer:
--   - player goes "down" for 30s, then respawns
--   - if all party members are down/dead during that window => end run for everyone

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local RunProgressApi = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("RunProgressApi"))

Players.RespawnTime = 9999

local REVIVE_DELAY = 30

local function isAliveCharacter(plr: Player): boolean
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function isDown(plr: Player): boolean
	return plr:GetAttribute("Downed") == true
end

local function partyPlayers(plr: Player): {Player}
	local partyId = plr:GetAttribute("PartyId")
	if typeof(partyId) ~= "string" or partyId == "" then
		return { plr }
	end
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("PartyId") == partyId and p:GetAttribute("RunMode") == "Multi" then
			table.insert(out, p)
		end
	end
	return out
end

local function everyoneDownOrDead(plr: Player): boolean
	local group = partyPlayers(plr)
	for _, p in ipairs(group) do
		if p.Parent and p:GetAttribute("RunEnded") ~= true then
			if isAliveCharacter(p) and not isDown(p) then
				return false
			end
		end
	end
	return true
end

local function endForAll(plr: Player, reason: string)
	local group = partyPlayers(plr)
	for _, p in ipairs(group) do
		if p.Parent and p:GetAttribute("RunEnded") ~= true then
			pcall(function()
				RunProgressApi.EndRunForPlayer(p, reason)
			end)
		end
	end
end

Players.PlayerAdded:Connect(function(plr: Player)
	plr:SetAttribute("Downed", false)

	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum then return end

		plr:SetAttribute("Downed", false)

		hum.Died:Connect(function()
			-- if run already ended, ignore
			if plr:GetAttribute("RunEnded") == true then return end

			local mode = plr:GetAttribute("RunMode")
			if mode ~= "Multi" then
				-- single = immediate game over
				pcall(function()
					RunProgressApi.EndRunForPlayer(plr, "Defeated")
				end)
				return
			end

			-- multi: mark downed and check wipe
			plr:SetAttribute("Downed", true)

			if everyoneDownOrDead(plr) then
				endForAll(plr, "Defeated")
				return
			end

			-- revive after delay if run not ended
			task.delay(REVIVE_DELAY, function()
				if not plr.Parent then return end
				if plr:GetAttribute("RunEnded") == true then return end
				-- if party wiped while waiting, do nothing
				if everyoneDownOrDead(plr) then
					endForAll(plr, "Defeated")
					return
				end
				plr:SetAttribute("Downed", false)
				pcall(function()
					plr:LoadCharacter()
				end)
			end)
		end)
	end)
end)

print("[RunDeathHandler] Ready (single+multi)")
