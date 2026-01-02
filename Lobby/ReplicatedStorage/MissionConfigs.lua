-- MissionConfigs.lua (ReplicatedStorage)
-- Definicje misji dla systemu Missions.

local MissionConfigs = {}

local defs: {[string]: any} = {}
local list = {}

local function add(def)
	defs[def.Id] = def
	table.insert(list, def)
end

add({
	Id = "TEST_CLAIM",
	Type = "Test",
	Title = "Test Claim",
	Description = "Testowa misja do nieskończonego odbierania nagród.",
	Reward = {
		Coins = 500,
		WeaponPoints = 50,
	},
	Repeatable = true,
	Goal = "AlwaysClaimable",
})

function MissionConfigs.Get(id: string)
	return defs[id]
end

function MissionConfigs.GetAll()
	return list
end

return MissionConfigs
