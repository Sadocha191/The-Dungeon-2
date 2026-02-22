-- MissionConfigs.lua (ReplicatedStorage/ModuleScripts)
-- Pools of Daily + Weekly missions.
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

-- NOTE: Keys are updated in Level1/ServerScriptService/ModuleScript/MissionProgress.lua
-- via ProgressService + WaveController hooks.

-- =========================
-- DAILY (30)
-- =========================

-- Kills / Elites / Boss
add({ Id="D_FIRST_BLOOD", Type="Daily", Title="First Blood", Description="Kill 150 enemies.", Reward={Coins=500,WeaponPoints=100}, Goal={Type="Counter",Key="KILLS",Target=150}, Repeatable=false })
add({ Id="D_MASSACRE", Type="Daily", Title="Massacre", Description="Kill 350 enemies.", Reward={Coins=800,WeaponPoints=120}, Goal={Type="Counter",Key="KILLS",Target=350}, Repeatable=false })
add({ Id="D_ELITE_HUNTER", Type="Daily", Title="Elite Hunter", Description="Kill 8 elite enemies.", Reward={Coins=700,WeaponPoints=80}, Goal={Type="Counter",Key="ELITE_KILLS",Target=8}, Repeatable=false })
add({ Id="D_ELITE_SWEEP", Type="Daily", Title="Elite Sweep", Description="Kill 15 elite enemies.", Reward={Coins=900,WeaponPoints=100}, Goal={Type="Counter",Key="ELITE_KILLS",Target=15}, Repeatable=false })
add({ Id="D_ELITE_STREAK", Type="Daily", Title="Elite Streak", Description="Kill 5 elite enemies.", Reward={Coins=600,WeaponPoints=90}, Goal={Type="Counter",Key="ELITE_KILLS",Target=5}, Repeatable=false })
add({ Id="D_BOSS_ATTEMPT", Type="Daily", Title="Boss Attempt", Description="Survive until the boss appears (20:00).", Reward={Coins=600,WeaponPoints=60}, Goal={Type="Counter",Key="BOSS_SPAWN_REACHED",Target=1}, Repeatable=false })
add({ Id="D_BOSS_SLAYER", Type="Daily", Title="Boss Slayer", Description="Defeat the boss (win a run).", Reward={Coins=1000,WeaponPoints=100}, Goal={Type="Counter",Key="BOSSES",Target=1}, Repeatable=false })
add({ Id="D_BOSS_BURST", Type="Daily", Title="Boss Burst", Description="Defeat the boss within 90s of spawn.", Reward={Coins=1200,WeaponPoints=120}, Goal={Type="Counter",Key="BOSS_BURST_90",Target=1}, Repeatable=false })
add({ Id="D_BOSS_CLUTCH", Type="Daily", Title="Boss Clutch", Description="Win a run with less than 30% HP at the end.", Reward={Coins=900,WeaponPoints=110}, Goal={Type="Counter",Key="BOSS_CLUTCH",Target=1}, Repeatable=false })
add({ Id="D_BOSS_NO_HIT", Type="Daily", Title="Boss Focus", Description="Win a run without taking damage in first 20s after boss spawn.", Reward={Coins=900,WeaponPoints=110}, Goal={Type="Counter",Key="BOSS_NO_HIT_20S",Target=1}, Repeatable=false })

-- Coins / Upgrades
add({ Id="D_COINS_COLLECTOR", Type="Daily", Title="Coins Collector", Description="Earn 2,500 coins.", Reward={Coins=0,WeaponPoints=70}, Goal={Type="Counter",Key="COINS_EARNED",Target=2500}, Repeatable=false })
add({ Id="D_BIG_PAYOUT", Type="Daily", Title="Big Payout", Description="Earn 6,000 coins.", Reward={Coins=0,WeaponPoints=90}, Goal={Type="Counter",Key="COINS_EARNED",Target=6000}, Repeatable=false })
add({ Id="D_WEALTHY_RUN", Type="Daily", Title="Wealthy Run", Description="Earn 4,000 coins in a single run.", Reward={Coins=400,WeaponPoints=90}, Goal={Type="MaxCounter",Key="COINS_RUN_MAX",Target=4000}, Repeatable=false })
add({ Id="D_SPEND_SMART", Type="Daily", Title="Spend Smart", Description="Spend 3,000 coins in the lobby.", Reward={Coins=0,WeaponPoints=80}, Goal={Type="Counter",Key="COINS_SPENT",Target=3000}, Repeatable=false })
add({ Id="D_UPGRADE_ADDICT", Type="Daily", Title="Upgrade Addict", Description="Pick 12 upgrades.", Reward={Coins=600,WeaponPoints=60}, Goal={Type="Counter",Key="UPGRADES_CHOSEN",Target=12}, Repeatable=false })
add({ Id="D_UPGRADE_RUSH", Type="Daily", Title="Upgrade Rush", Description="Reach level 10 in a single run.", Reward={Coins=700,WeaponPoints=80}, Goal={Type="Counter",Key="LEVEL10_RUNS",Target=1}, Repeatable=false })

-- Rerolls / Skips
add({ Id="D_NO_REROLL", Type="Daily", Title="No Reroll", Description="Win a run without rerolling.", Reward={Coins=900,WeaponPoints=120}, Goal={Type="Counter",Key="NO_REROLL_WINS",Target=1}, Repeatable=false })
add({ Id="D_REROLL_SAVER", Type="Daily", Title="Reroll Saver", Description="Win a run using at most 1 reroll.", Reward={Coins=800,WeaponPoints=100}, Goal={Type="Counter",Key="MAX1_REROLL_WINS",Target=1}, Repeatable=false })
add({ Id="D_SKIP_DISCIPLINE", Type="Daily", Title="Skip Discipline", Description="Win a run using at most 1 skip.", Reward={Coins=800,WeaponPoints=100}, Goal={Type="Counter",Key="MAX1_SKIP_WINS",Target=1}, Repeatable=false })
add({ Id="D_REROLL_SPREE", Type="Daily", Title="Reroll Spree", Description="Use 3 rerolls (any runs).", Reward={Coins=400,WeaponPoints=70}, Goal={Type="Counter",Key="REROLLS_USED",Target=3}, Repeatable=false })

-- Survival / Damage / Skill
add({ Id="D_CLOSE_CALL", Type="Daily", Title="Close Call", Description="Spend 60s below 30% HP.", Reward={Coins=700,WeaponPoints=90}, Goal={Type="Counter",Key="LOW_HP_SECONDS",Target=60}, Repeatable=false })
add({ Id="D_GLASS_CANNON", Type="Daily", Title="Glass Cannon", Description="Win a run without dropping below 50% HP.", Reward={Coins=900,WeaponPoints=120}, Goal={Type="Counter",Key="HP50PLUS_WINS",Target=1}, Repeatable=false })
add({ Id="D_HEAL_CHECK", Type="Daily", Title="Heal Check", Description="Heal 500 HP total.", Reward={Coins=600,WeaponPoints=80}, Goal={Type="Counter",Key="HEAL_AMOUNT",Target=500}, Repeatable=false })
add({ Id="D_DODGE_TIME", Type="Daily", Title="Dodge Time", Description="Go 5 minutes without taking damage (in a run).", Reward={Coins=800,WeaponPoints=110}, Goal={Type="Counter",Key="NO_DAMAGE_5MIN",Target=1}, Repeatable=false })
add({ Id="D_CROWD_CONTROL", Type="Daily", Title="Crowd Control", Description="Get 30 kills within 5 seconds.", Reward={Coins=600,WeaponPoints=100}, Goal={Type="Counter",Key="MULTIKILL_30_5",Target=1}, Repeatable=false })
add({ Id="D_CHAIN_KILLER", Type="Daily", Title="Chain Killer", Description="Get 60 kills within 20 seconds.", Reward={Coins=900,WeaponPoints=120}, Goal={Type="Counter",Key="MULTIKILL_60_20",Target=1}, Repeatable=false })
add({ Id="D_REVENGE", Type="Daily", Title="Revenge", Description="Kill an elite within 10s after taking damage.", Reward={Coins=600,WeaponPoints=100}, Goal={Type="Counter",Key="REVENGE_ELITE",Target=1}, Repeatable=false })
add({ Id="D_TANK_TEST", Type="Daily", Title="Tank Test", Description="Take 2,000 damage total.", Reward={Coins=700,WeaponPoints=90}, Goal={Type="Counter",Key="DAMAGE_TAKEN",Target=2000}, Repeatable=false })
add({ Id="D_DPS_CHECK", Type="Daily", Title="DPS Check", Description="Deal 30,000 total damage.", Reward={Coins=700,WeaponPoints=90}, Goal={Type="Counter",Key="DAMAGE",Target=30000}, Repeatable=false })
add({ Id="D_SPELL_MASTERY", Type="Daily", Title="Spell Mastery", Description="In a run, have at least 3 different spells active.", Reward={Coins=600,WeaponPoints=90}, Goal={Type="Counter",Key="SPELLS_3",Target=1}, Repeatable=false })

-- =========================
-- WEEKLY (15)
-- =========================
add({ Id="W_CONSISTENCY", Type="Weekly", Title="Consistency", Description="Win 5 runs.", Reward={Coins=4000,WeaponPoints=500}, Goal={Type="Counter",Key="BOSSES",Target=5}, Repeatable=false })
add({ Id="W_GRINDER", Type="Weekly", Title="Grinder", Description="Win 10 runs.", Reward={Coins=7000,WeaponPoints=700}, Goal={Type="Counter",Key="BOSSES",Target=10}, Repeatable=false })
add({ Id="W_BOSS_SPECIALIST", Type="Weekly", Title="Boss Specialist", Description="Defeat 7 bosses.", Reward={Coins=6000,WeaponPoints=600}, Goal={Type="Counter",Key="BOSSES",Target=7}, Repeatable=false })
add({ Id="W_BOSS_FARMER", Type="Weekly", Title="Boss Farmer", Description="Reach boss spawn (20:00) 15 times.", Reward={Coins=4500,WeaponPoints=450}, Goal={Type="Counter",Key="BOSS_SPAWN_REACHED",Target=15}, Repeatable=false })
add({ Id="W_QUICK_FINISHER", Type="Weekly", Title="Quick Finisher", Description="Defeat the boss within 120s of spawn 5 times.", Reward={Coins=5000,WeaponPoints=600}, Goal={Type="Counter",Key="BOSS_BURST_120",Target=5}, Repeatable=false })
add({ Id="W_ELITE_EXTERMINATOR", Type="Weekly", Title="Elite Exterminator", Description="Kill 80 elite enemies.", Reward={Coins=4500,WeaponPoints=500}, Goal={Type="Counter",Key="ELITE_KILLS",Target=80}, Repeatable=false })
add({ Id="W_ELITE_OVERKILL", Type="Weekly", Title="Elite Overkill", Description="Kill 150 elite enemies.", Reward={Coins=7000,WeaponPoints=700}, Goal={Type="Counter",Key="ELITE_KILLS",Target=150}, Repeatable=false })
add({ Id="W_MASSACRE", Type="Weekly", Title="Massacre", Description="Kill 12,000 enemies.", Reward={Coins=6000,WeaponPoints=600}, Goal={Type="Counter",Key="KILLS",Target=12000}, Repeatable=false })
add({ Id="W_BLOODBATH", Type="Weekly", Title="Bloodbath", Description="Kill 20,000 enemies.", Reward={Coins=9000,WeaponPoints=900}, Goal={Type="Counter",Key="KILLS",Target=20000}, Repeatable=false })
add({ Id="W_SURVIVOR", Type="Weekly", Title="Survivor", Description="Spend 180 minutes in dungeons.", Reward={Coins=3500,WeaponPoints=400}, Goal={Type="Counter",Key="SECONDS",Target=10800}, Repeatable=false })
add({ Id="W_MARATHON", Type="Weekly", Title="Marathon", Description="Spend 300 minutes in dungeons.", Reward={Coins=5000,WeaponPoints=500}, Goal={Type="Counter",Key="SECONDS",Target=18000}, Repeatable=false })
add({ Id="W_ECONOMY", Type="Weekly", Title="Economy", Description="Earn 60,000 coins.", Reward={Coins=0,WeaponPoints=400}, Goal={Type="Counter",Key="COINS_EARNED",Target=60000}, Repeatable=false })
add({ Id="W_RICH_WEEK", Type="Weekly", Title="Rich Week", Description="Earn 100,000 coins.", Reward={Coins=0,WeaponPoints=600}, Goal={Type="Counter",Key="COINS_EARNED",Target=100000}, Repeatable=false })
add({ Id="W_UPGRADE_ADDICT", Type="Weekly", Title="Upgrade Addict", Description="Pick 120 upgrades.", Reward={Coins=3000,WeaponPoints=400}, Goal={Type="Counter",Key="UPGRADES_CHOSEN",Target=120}, Repeatable=false })
add({ Id="W_WIN_STREAK", Type="Weekly", Title="Win Streak", Description="Win 3 runs in a row.", Reward={Coins=7000,WeaponPoints=800}, Goal={Type="Counter",Key="WIN_STREAK_3",Target=1}, Repeatable=false })

function MissionConfigs.Get(id: string)
	return defs[id]
end

function MissionConfigs.GetAll()
	return all
end

function MissionConfigs.GetPool(missionType: string)
	if missionType == "Daily" then return daily end
	if missionType == "Weekly" then return weekly end
	return {}
end

return MissionConfigs
