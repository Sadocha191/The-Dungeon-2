-- MissionConfigs.lua (ReplicatedStorage/ModuleScripts)
-- Pools of Daily + Weekly missions.
-- UI shows 6 Daily and 12 Weekly picked from these pools.

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

-- ===== DAILY (17) =====
add({
	Id = "D_FIRST_BLOOD",
	Type = "Daily",
	Title = "First Blood",
	Description = "Kill 50 enemies.",
	Reward = { Coins = 1500, WeaponPoints = 25 },
	Goal = { Type = "Counter", Key = "KILLS", Target = 50 },
	Repeatable = false,
})

add({
	Id = "D_DUNGEON_CLEAR",
	Type = "Daily",
	Title = "Dungeon Clear",
	Description = "Complete 1 run.",
	Reward = { Coins = 1800, WeaponPoints = 30 },
	Goal = { Type = "Counter", Key = "RUNS", Target = 1 },
	Repeatable = false,
})

add({
	Id = "D_WEAPON_MASTERY",
	Type = "Daily",
	Title = "Weapon Mastery",
	Description = "Complete 1 run with your equipped weapon.",
	Reward = { Coins = 1800, WeaponPoints = 30 },
	Goal = { Type = "Counter", Key = "RUNS_WITH_WEAPON", Target = 1 },
	Repeatable = false,
})

add({
	Id = "D_ELITE_HUNTER",
	Type = "Daily",
	Title = "Elite Hunter",
	Description = "Kill 3 elite enemies.",
	Reward = { Coins = 1700, WeaponPoints = 25 },
	Goal = { Type = "Counter", Key = "ELITE_KILLS", Target = 3 },
	Repeatable = false,
})

add({
	Id = "D_BOSS_SLAYER",
	Type = "Daily",
	Title = "Boss Slayer",
	Description = "Defeat 1 boss (finish a run).",
	Reward = { Coins = 2200, WeaponPoints = 40 },
	Goal = { Type = "Counter", Key = "BOSSES", Target = 1 },
	Repeatable = false,
})

add({
	Id = "D_CRIT_ENJOYER",
	Type = "Daily",
	Title = "Crit Enjoyer",
	Description = "Land 30 critical hits.",
	Reward = { Coins = 1400, WeaponPoints = 20 },
	Goal = { Type = "Counter", Key = "CRITS", Target = 30 },
	Repeatable = false,
})

add({
	Id = "D_SURVIVOR",
	Type = "Daily",
	Title = "Survivor",
	Description = "Finish a run without dying.",
	Reward = { Coins = 2000, WeaponPoints = 35 },
	Goal = { Type = "Counter", Key = "NO_DEATH_RUNS", Target = 1 },
	Repeatable = false,
})

-- +10 daily ode mnie (na tych samych licznikach)
add({ Id="D_WAVE_PUSHER", Type="Daily", Title="Wave Pusher", Description="Clear 40 waves total.", Reward={Coins=1700,WeaponPoints=25}, Goal={Type="Counter",Key="WAVES",Target=40}, Repeatable=false })
add({ Id="D_DAMAGE_DEALER", Type="Daily", Title="Damage Dealer", Description="Deal 10,000 total damage.", Reward={Coins=1700,WeaponPoints=25}, Goal={Type="Counter",Key="DAMAGE",Target=10000}, Repeatable=false })
add({ Id="D_GOLD_RUSH", Type="Daily", Title="Gold Rush", Description="Earn 6,000 coins.", Reward={Coins=1800,WeaponPoints=25}, Goal={Type="Counter",Key="COINS_EARNED",Target=6000}, Repeatable=false })
add({ Id="D_XP_HUNT", Type="Daily", Title="XP Hunt", Description="Earn 600 XP.", Reward={Coins=1500,WeaponPoints=20}, Goal={Type="Counter",Key="XP_EARNED",Target=600}, Repeatable=false })
add({ Id="D_CRIT_DAMAGE", Type="Daily", Title="Crit Damage", Description="Deal 2,500 damage via critical hits.", Reward={Coins=1700,WeaponPoints=25}, Goal={Type="Counter",Key="CRIT_DAMAGE",Target=2500}, Repeatable=false })
add({ Id="D_FAST_CLEAR", Type="Daily", Title="Fast Clear", Description="Complete 1 run in under 12 minutes.", Reward={Coins=1900,WeaponPoints=30}, Goal={Type="Counter",Key="FAST_RUNS",Target=1}, Repeatable=false })
add({ Id="D_DOUBLE_RUN", Type="Daily", Title="Double Run", Description="Complete 2 runs.", Reward={Coins=2100,WeaponPoints=35}, Goal={Type="Counter",Key="RUNS",Target=2}, Repeatable=false })
add({ Id="D_MASSACRE_LITE", Type="Daily", Title="Massacre (Lite)", Description="Kill 150 enemies.", Reward={Coins=2000,WeaponPoints=30}, Goal={Type="Counter",Key="KILLS",Target=150}, Repeatable=false })
add({ Id="D_TIME_ON_TASK", Type="Daily", Title="Time On Task", Description="Spend 20 minutes in dungeons.", Reward={Coins=1700,WeaponPoints=25}, Goal={Type="Counter",Key="SECONDS",Target=1200}, Repeatable=false })
add({ Id="D_CRIT_STREAK", Type="Daily", Title="Crit Streak", Description="Land 60 critical hits.", Reward={Coins=1900,WeaponPoints=30}, Goal={Type="Counter",Key="CRITS",Target=60}, Repeatable=false })

-- ===== WEEKLY (18) =====
add({
	Id = "W_DUNGEON_GRINDER",
	Type = "Weekly",
	Title = "Dungeon Grinder",
	Description = "Complete 10 runs.",
	Reward = { Coins = 25000, WeaponPoints = 200 },
	Goal = { Type = "Counter", Key = "RUNS", Target = 10 },
	Repeatable = false,
})

add({
	Id = "W_MASSACRE",
	Type = "Weekly",
	Title = "Massacre",
	Description = "Kill 1,000 enemies.",
	Reward = { Coins = 32000, WeaponPoints = 250 },
	Goal = { Type = "Counter", Key = "KILLS", Target = 1000 },
	Repeatable = false,
})

add({
	Id = "W_ELITE_EXTERMINATOR",
	Type = "Weekly",
	Title = "Elite Exterminator",
	Description = "Kill 25 elite enemies.",
	Reward = { Coins = 28000, WeaponPoints = 200 },
	Goal = { Type = "Counter", Key = "ELITE_KILLS", Target = 25 },
	Repeatable = false,
})

add({
	Id = "W_BOSS_HUNTER",
	Type = "Weekly",
	Title = "Boss Hunter",
	Description = "Defeat 7 bosses.",
	Reward = { Coins = 42000, WeaponPoints = 300 },
	Goal = { Type = "Counter", Key = "BOSSES", Target = 7 },
	Repeatable = false,
})

add({
	Id = "W_ENDLESS_CHALLENGER",
	Type = "Weekly",
	Title = "Endless Challenger",
	Description = "Reach wave 20 in Endless mode.",
	Reward = { Coins = 35000, WeaponPoints = 250 },
	Goal = { Type = "MaxCounter", Key = "WAVE_MAX", Target = 20 },
	Repeatable = false,
})

add({
	Id = "W_WEAPON_SPECIALIST",
	Type = "Weekly",
	Title = "Weapon Specialist",
	Description = "Complete 5 runs with the same weapon.",
	Reward = { Coins = 30000, WeaponPoints = 200 },
	Goal = { Type = "WeaponRunsAny", Target = 5 },
	Repeatable = false,
})

add({
	Id = "W_CRIT_MACHINE",
	Type = "Weekly",
	Title = "Crit Machine",
	Description = "Deal 5,000 damage via critical hits.",
	Reward = { Coins = 26000, WeaponPoints = 180 },
	Goal = { Type = "Counter", Key = "CRIT_DAMAGE", Target = 5000 },
	Repeatable = false,
})

add({
	Id = "W_WEEKLY_COMMITMENT",
	Type = "Weekly",
	Title = "Weekly Commitment",
	Description = "Complete 5 daily quests.",
	Reward = { Coins = 22000, WeaponPoints = 150 },
	Goal = { Type = "Counter", Key = "DAILY_CLAIMS", Target = 5 },
	Repeatable = false,
})

-- +10 weekly ode mnie
add({ Id="W_DAMAGE_MARATHON", Type="Weekly", Title="Damage Marathon", Description="Deal 250,000 total damage.", Reward={Coins=36000,WeaponPoints=220}, Goal={Type="Counter",Key="DAMAGE",Target=250000}, Repeatable=false })
add({ Id="W_GOLD_HOARDER", Type="Weekly", Title="Gold Hoarder", Description="Earn 150,000 coins.", Reward={Coins=38000,WeaponPoints=240}, Goal={Type="Counter",Key="COINS_EARNED",Target=150000}, Repeatable=false })
add({ Id="W_WAVE_MASTER", Type="Weekly", Title="Wave Master", Description="Clear 250 waves.", Reward={Coins=32000,WeaponPoints=200}, Goal={Type="Counter",Key="WAVES",Target=250}, Repeatable=false })
add({ Id="W_CRIT_ADDICT", Type="Weekly", Title="Crit Addict", Description="Land 600 critical hits.", Reward={Coins=34000,WeaponPoints=220}, Goal={Type="Counter",Key="CRITS",Target=600}, Repeatable=false })
add({ Id="W_XP_GRINDER", Type="Weekly", Title="XP Grinder", Description="Earn 10,000 XP.", Reward={Coins=32000,WeaponPoints=200}, Goal={Type="Counter",Key="XP_EARNED",Target=10000}, Repeatable=false })
add({ Id="W_SURVIVALIST", Type="Weekly", Title="Survivalist", Description="Finish 15 runs without dying.", Reward={Coins=38000,WeaponPoints=250}, Goal={Type="Counter",Key="NO_DEATH_RUNS",Target=15}, Repeatable=false })
add({ Id="W_SPEEDRUNNER", Type="Weekly", Title="Speedrunner", Description="Complete 10 fast runs (under 12 min).", Reward={Coins=34000,WeaponPoints=220}, Goal={Type="Counter",Key="FAST_RUNS",Target=10}, Repeatable=false })
add({ Id="W_ELITE_SWEEP", Type="Weekly", Title="Elite Sweep", Description="Kill 80 elite enemies.", Reward={Coins=36000,WeaponPoints=240}, Goal={Type="Counter",Key="ELITE_KILLS",Target=80}, Repeatable=false })
add({ Id="W_PLAYTIME", Type="Weekly", Title="Playtime", Description="Spend 4 hours in dungeons.", Reward={Coins=28000,WeaponPoints=180}, Goal={Type="Counter",Key="SECONDS",Target=14400}, Repeatable=false })
add({ Id="W_BATTLE_TEMPO", Type="Weekly", Title="Battle Tempo", Description="Complete 20 runs.", Reward={Coins=45000,WeaponPoints=300}, Goal={Type="Counter",Key="RUNS",Target=20}, Repeatable=false })

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
