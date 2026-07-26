-- MissionConfigs.lua (ReplicatedStorage/ModuleScripts)
-- Shared daily + weekly mission definitions used by lobby and dungeon places.
-- UI shows 6 Daily and 3 Weekly picked from these pools.

local MissionConfigs = {}

local defs: {[string]: any} = {}
local daily = {}
local weekly = {}
local all = {}

local function add(def)
	defs[def.Id] = def
	table.insert(all, def)
	if def.Type == "Daily" then
		table.insert(daily, def)
	elseif def.Type == "Weekly" then
		table.insert(weekly, def)
	end
end

-- Keys are updated in Level/ServerScriptService/ModuleScript/MissionProgress.lua
-- through ProgressService and WaveController hooks.
-- Daily missions are intended to finish naturally in roughly one normal run.
-- Weekly missions are intended to take a few runs, not an entire week of grinding.

-- =========================
-- DAILY (12)
-- =========================

add({ Id="D_RUN_FINISH", Type="Daily", Group="Run", Title="Dungeon Delver", Description="Finish 1 dungeon run.", Reward={Silver=400,WeaponPoints=50}, Goal={Type="Counter",Key="RUNS",Target=1}, Repeatable=false })
add({ Id="D_FIRST_BLOOD", Type="Daily", Group="Kills", Title="First Blood", Description="Kill 300 enemies.", Reward={Silver=450,WeaponPoints=55}, Goal={Type="Counter",Key="KILLS",Target=300}, Repeatable=false })
add({ Id="D_ELITE_HUNTER", Type="Daily", Group="Elites", Title="Elite Hunter", Description="Kill 4 elite enemies.", Reward={Silver=500,WeaponPoints=60}, Goal={Type="Counter",Key="ELITE_KILLS",Target=4}, Repeatable=false })
add({ Id="D_BOSS_ATTEMPT", Type="Daily", Group="Boss", Title="Boss Encounter", Description="Reach the boss phase once.", Reward={Silver=550,WeaponPoints=65}, Goal={Type="Counter",Key="BOSS_SPAWN_REACHED",Target=1}, Repeatable=false })
add({ Id="D_BOSS_SLAYER", Type="Daily", Group="Victory", Title="Boss Slayer", Description="Win 1 dungeon run.", Reward={Silver=800,WeaponPoints=90}, Goal={Type="Counter",Key="BOSSES",Target=1}, Repeatable=false })
add({ Id="D_COINS_COLLECTOR", Type="Daily", Group="Economy", Title="Silver Collector", Description="Earn 1,500 silver in dungeons.", Reward={Silver=0,WeaponPoints=60}, Goal={Type="Counter",Key="COINS_EARNED",Target=1500}, Repeatable=false })
add({ Id="D_UPGRADE_ADDICT", Type="Daily", Group="Upgrades", Title="Power Up", Description="Choose 8 upgrades.", Reward={Silver=450,WeaponPoints=55}, Goal={Type="Counter",Key="UPGRADES_CHOSEN",Target=8}, Repeatable=false })
add({ Id="D_UPGRADE_RUSH", Type="Daily", Group="Level", Title="Level Climber", Description="Reach level 10 in a run.", Reward={Silver=550,WeaponPoints=65}, Goal={Type="Counter",Key="LEVEL10_RUNS",Target=1}, Repeatable=false })
add({ Id="D_REROLL_SPREE", Type="Daily", Group="Reroll", Title="Second Choice", Description="Use 1 reroll.", Reward={Silver=350,WeaponPoints=45}, Goal={Type="Counter",Key="REROLLS_USED",Target=1}, Repeatable=false })
add({ Id="D_DPS_CHECK", Type="Daily", Group="Damage", Title="Damage Dealer", Description="Deal 25,000 total damage.", Reward={Silver=500,WeaponPoints=60}, Goal={Type="Counter",Key="DAMAGE",Target=25000}, Repeatable=false })
add({ Id="D_SPELL_MASTERY", Type="Daily", Group="Spells", Title="Spell Mastery", Description="Have at least 3 different spells active in a run.", Reward={Silver=450,WeaponPoints=55}, Goal={Type="Counter",Key="SPELLS_3",Target=1}, Repeatable=false })
add({ Id="D_SURVIVE_TEN", Type="Daily", Group="Time", Title="Hold the Line", Description="Spend 10 minutes in dungeons.", Reward={Silver=450,WeaponPoints=50}, Goal={Type="Counter",Key="SECONDS",Target=600}, Repeatable=false })

-- =========================
-- WEEKLY (10)
-- =========================

add({ Id="W_RUNNER", Type="Weekly", Group="Runs", Title="Dungeon Regular", Description="Finish 3 dungeon runs.", Reward={Silver=2500,WeaponPoints=300}, Goal={Type="Counter",Key="RUNS",Target=3}, Repeatable=false })
add({ Id="W_CONSISTENCY", Type="Weekly", Group="Victory", Title="Consistency", Description="Win 2 dungeon runs.", Reward={Silver=3000,WeaponPoints=350}, Goal={Type="Counter",Key="BOSSES",Target=2}, Repeatable=false })
add({ Id="W_BOSS_FARMER", Type="Weekly", Group="Boss", Title="Boss Hunter", Description="Reach the boss phase 3 times.", Reward={Silver=2500,WeaponPoints=300}, Goal={Type="Counter",Key="BOSS_SPAWN_REACHED",Target=3}, Repeatable=false })
add({ Id="W_MASSACRE", Type="Weekly", Group="Kills", Title="Massacre", Description="Kill 3,000 enemies.", Reward={Silver=2500,WeaponPoints=300}, Goal={Type="Counter",Key="KILLS",Target=3000}, Repeatable=false })
add({ Id="W_ELITE_EXTERMINATOR", Type="Weekly", Group="Elites", Title="Elite Exterminator", Description="Kill 20 elite enemies.", Reward={Silver=2500,WeaponPoints=300}, Goal={Type="Counter",Key="ELITE_KILLS",Target=20}, Repeatable=false })
add({ Id="W_SURVIVOR", Type="Weekly", Group="Time", Title="Dungeon Time", Description="Spend 45 minutes in dungeons.", Reward={Silver=2200,WeaponPoints=260}, Goal={Type="Counter",Key="SECONDS",Target=2700}, Repeatable=false })
add({ Id="W_ECONOMY", Type="Weekly", Group="Economy", Title="Strong Economy", Description="Earn 12,000 silver in dungeons.", Reward={Silver=0,WeaponPoints=280}, Goal={Type="Counter",Key="COINS_EARNED",Target=12000}, Repeatable=false })
add({ Id="W_UPGRADE_ADDICT", Type="Weekly", Group="Upgrades", Title="Upgrade Specialist", Description="Choose 30 upgrades.", Reward={Silver=2200,WeaponPoints=280}, Goal={Type="Counter",Key="UPGRADES_CHOSEN",Target=30}, Repeatable=false })
add({ Id="W_DAMAGE_DEALER", Type="Weekly", Group="Damage", Title="Heavy Hitter", Description="Deal 150,000 total damage.", Reward={Silver=2500,WeaponPoints=300}, Goal={Type="Counter",Key="DAMAGE",Target=150000}, Repeatable=false })
add({ Id="W_DAILY_ROUTINE", Type="Weekly", Group="Routine", Title="Daily Routine", Description="Claim 6 daily mission rewards.", Reward={Silver=2000,WeaponPoints=300}, Goal={Type="Counter",Key="DAILY_CLAIMS",Target=6}, Repeatable=false })

function MissionConfigs.Get(id: string)
	return defs[id]
end

function MissionConfigs.GetAll()
	return all
end

function MissionConfigs.GetPool(missionType: string)
	if missionType == "Daily" then
		return daily
	end
	if missionType == "Weekly" then
		return weekly
	end
	return {}
end

return MissionConfigs
