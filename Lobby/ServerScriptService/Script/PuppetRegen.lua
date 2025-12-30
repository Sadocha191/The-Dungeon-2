-- SCRIPT: PuppetRegen.server.lua
-- CO: regeneruje HP Puppetów do testów

local CollectionService = game:GetService("CollectionService")

local REGEN_FRACTION_PER_SEC = 0.05
local TICK = 1.0

local tracked: {[Instance]: boolean} = {}

local function startRegen(model: Instance)
	if tracked[model] then return end
	tracked[model] = true

	task.spawn(function()
		while model.Parent do
			local hum = model:FindFirstChildWhichIsA("Humanoid")
			if hum then
				local maxHp = math.max(1, hum.MaxHealth)
				if hum.Health < maxHp then
					hum.Health = math.min(maxHp, hum.Health + (maxHp * REGEN_FRACTION_PER_SEC))
				end
			end
			task.wait(TICK)
		end
		tracked[model] = nil
	end)
end

for _, model in ipairs(CollectionService:GetTagged("Puppet")) do
	startRegen(model)
end

CollectionService:GetInstanceAddedSignal("Puppet"):Connect(startRegen)

print("[PuppetRegen] Ready")
