-- SCRIPT: LobbyPuppetRegen.server.lua
-- GDZIE: ServerScriptService/LobbyPuppetRegen.server.lua
-- CO: Regeneracja HP dla Puppetów w lobby (tag "Puppet").

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local REGEN_PERCENT_PER_SEC = 0.05
local TICK = 0.5

local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < TICK then return end
	accumulator -= TICK

	for _, model in ipairs(CollectionService:GetTagged("Puppet")) do
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
			local heal = hum.MaxHealth * REGEN_PERCENT_PER_SEC * TICK
			hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
		end
	end
end)

print("[LobbyPuppetRegen] Ready")
