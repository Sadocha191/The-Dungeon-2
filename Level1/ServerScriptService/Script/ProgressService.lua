-- ProgressService.server.lua (ServerScriptService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")

local function findModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	local folder = ServerScriptService:FindFirstChild("ModuleScript")
		or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end
	return nil
end

local playerDataModule = findModule("PlayerData")
local weaponServiceModule = findModule("WeaponService")
if not playerDataModule or not weaponServiceModule then
	error("[ProgressService] Missing PlayerData/WeaponService module.")
end

local PlayerData = require(playerDataModule)
local WeaponService = require(weaponServiceModule)
local UpDefs = require(ReplicatedStorage:WaitForChild("UpgradeDefinitions"))

-- Ensure PauseState
local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end
PauseState.Value = false

-- Remotes folder
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(name: string)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end

local PlayerProgressEvent = getRemote("PlayerProgressEvent")
local UpgradeEvent = getRemote("UpgradeEvent")
local WeaponEvent = getRemote("WeaponEvent")
local DamageIndicatorEvent = getRemote("DamageIndicatorEvent")
local MissionSummaryEvent = getRemote("MissionSummaryEvent")

-- baseline movement
local BASE_PLAYER_SPEED = 24
local BASE_JUMP_POWER = 50

-- Pause => freeze players too
local frozen = {} -- [uid] = {ws, jp}
local battleFocus = {} -- [uid] = { untilTime }
local momentumStacks = {} -- [uid] = stacks
local riposteReady = {} -- [uid] = untilTime
local bladeDanceHits = {} -- [uid] = count
local parryUntil = {} -- [uid] = untilTime
local quickDrawUntil = {} -- [uid] = untilTime
local manaSurgeStacks = {} -- [uid] = count
local arcaneOverflowCd = {} -- [uid] = untilTime
local lastPistolShot = {} -- [uid] = time
local lastHealth = {} -- [uid] = health
local getFinalStats
local function updatePlayerDerivedStats(plr: Player)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local tool = char:FindFirstChildOfClass("Tool")
	local stats = getFinalStats(plr, tool)
	local d = PlayerData.Get(plr)

	local prevMax = hum.MaxHealth
	local ratio = prevMax > 0 and (hum.Health / prevMax) or 1
	hum.MaxHealth = math.max(1, stats.maxHP)
	hum.Health = math.min(hum.MaxHealth, math.max(1, ratio * hum.MaxHealth))

	hum.WalkSpeed = (BASE_PLAYER_SPEED * stats.speedMult) + (d.upgrades.speed or 0) * 1
	hum.JumpPower = BASE_JUMP_POWER + (d.upgrades.jump or 0) * 2

	plr:SetAttribute("FinalMaxHP", hum.MaxHealth)
	plr:SetAttribute("FinalSpeedMult", stats.speedMult)
	plr:SetAttribute("FinalCritRate", stats.critRate)
	plr:SetAttribute("FinalCritDmg", stats.critDmg)
	plr:SetAttribute("FinalLifesteal", stats.lifesteal)
	plr:SetAttribute("FinalDefense", stats.defense)
end

local function applyPauseToPlayer(plr: Player, paused: boolean)
	local c = plr.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if paused then
		if not frozen[plr.UserId] then
			frozen[plr.UserId] = { ws = hum.WalkSpeed, jp = hum.JumpPower }
		end
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	else
		updatePlayerDerivedStats(plr)
		frozen[plr.UserId] = nil
	end
end

PauseState.Changed:Connect(function()
	for _,plr in ipairs(Players:GetPlayers()) do
		applyPauseToPlayer(plr, PauseState.Value)
	end
end)

-- Tools

local function pushProgress(plr: Player)
	local d = PlayerData.Get(plr)
	PlayerProgressEvent:FireClient(plr, {
		type="progress",
		level=d.level, xp=d.xp, nextXp=d.nextXp,
		coins=d.coins,
	})
end

-- ===== Upgrade roll (3) =====
local pending = {} -- [uid] = {token, choices}

local function roll3(weaponType: string?)
	local pool = UpDefs.GetPool and UpDefs.GetPool(weaponType) or table.clone(UpDefs.POOL)
	if #pool < 3 then
		pool = table.clone(UpDefs.POOL)
	end
	local out = {}
	for i=1,3 do
		local idx = math.random(1, #pool)
		local base = pool[idx]
		table.remove(pool, idx)

		local rarity, color, mult = UpDefs.RollRarity()
		local raw = (base.base or 0) * (mult or 1)
		local value
		if base.mode == "count" then
			value = math.max(1, math.floor(raw + 0.5))
		elseif base.mode == "flat" then
			value = math.floor(raw * 100) / 100
		elseif base.mode == "percent" then
			value = math.max(1, math.floor(raw + 0.5))
		else
			value = math.floor(raw * 100) / 100
		end

		out[i] = {
			id = base.id,
			name = base.name,
			desc = base.desc,
			stat = base.stat,
			value = value,
			rarity = rarity,
			color = color,
			applyScale = base.applyScale or 1,
			secondaryStat = base.secondaryStat,
			secondaryScale = base.secondaryScale,
		}
	end
	return out
end

local function openUpgrade(plr: Player)
	local token = ("%d_%d"):format(plr.UserId, math.floor(os.clock()*1000))
	local char = plr.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local weaponType = tool and resolveWeaponType(tool:GetAttribute("WeaponType")) or ""
	local choices = roll3(weaponType)
	pending[plr.UserId] = { token = token, choices = choices }
	PauseState.Value = true
	UpgradeEvent:FireClient(plr, { type="SHOW", token=token, choices=choices })
end

UpgradeEvent.OnServerEvent:Connect(function(plr, payload)
	if typeof(payload) ~= "table" or payload.type ~= "PICK" then return end
	local st = pending[plr.UserId]
	if not st or payload.token ~= st.token then return end

	local pickId = tostring(payload.id or "")
	local choice
	for _,c in ipairs(st.choices) do
		if c.id == pickId then choice = c break end
	end
	if not choice then return end

	local d = PlayerData.Get(plr)
	local stat = choice.stat
	local scaledValue = (tonumber(choice.value) or 0) * (tonumber(choice.applyScale) or 1)

	-- defaults if missing in datastore (compat)
	if stat == "critChance" and d.critChance == nil then d.critChance = 0 end
	if stat == "critMult" and d.critMult == nil then d.critMult = 0 end

	if stat == "attackSpeed" then
		d.attackSpeed = math.clamp((tonumber(d.attackSpeed) or 1.0) + scaledValue, 0.6, 2.0)
	elseif stat == "multiShot" then
		d.multiShot = math.clamp((tonumber(d.multiShot) or 0) + scaledValue, 0, 6)
	elseif stat == "fireChance" then
		d.fireChance = math.clamp((tonumber(d.fireChance) or 0) + scaledValue, 0, 0.9)
	elseif stat == "fireDps" then
		d.fireDps = math.max(0, (tonumber(d.fireDps) or 0) + scaledValue)
	elseif stat == "damage" then
		d.damage = math.max(0, (tonumber(d.damage) or 0) + scaledValue)
	elseif stat == "critChance" then
		d.critChance = math.clamp((tonumber(d.critChance) or 0) + scaledValue, 0, 0.6)
	elseif stat == "critMult" then
		d.critMult = math.clamp((tonumber(d.critMult) or 0) + scaledValue, 0, 1.0)
	elseif stat == "damageBonusPct" then
		d.damageBonusPct = math.max(0, (tonumber(d.damageBonusPct) or 0) + scaledValue)
	elseif stat == "lifesteal" then
		d.lifesteal = math.clamp((tonumber(d.lifesteal) or 0) + scaledValue, 0, 0.12)
	elseif stat == "rangeBonus" then
		d.rangeBonus = math.max(0, (tonumber(d.rangeBonus) or 0) + scaledValue)
	elseif stat == "battleFocusBonus" then
		d.battleFocusBonus = math.max(0, (tonumber(d.battleFocusBonus) or 0) + scaledValue)
	elseif stat == "momentumBonus" then
		d.momentumBonus = math.max(0, (tonumber(d.momentumBonus) or 0) + scaledValue)
	elseif stat == "cleaveBonus" then
		d.cleaveBonus = math.max(0, (tonumber(d.cleaveBonus) or 0) + scaledValue)
	elseif stat == "riposteBonus" then
		d.riposteBonus = math.max(0, (tonumber(d.riposteBonus) or 0) + scaledValue)
	elseif stat == "bladeDanceEvery" then
		d.bladeDanceEvery = math.max(0, (tonumber(d.bladeDanceEvery) or 0) + scaledValue)
	elseif stat == "parryReduction" then
		d.parryReduction = math.clamp((tonumber(d.parryReduction) or 0) + scaledValue, 0, 0.6)
	elseif stat == "staggerDuration" then
		d.staggerDuration = math.max(0, (tonumber(d.staggerDuration) or 0) + scaledValue)
	elseif stat == "executeBonus" then
		d.executeBonus = math.max(0, (tonumber(d.executeBonus) or 0) + scaledValue)
	elseif stat == "overchargeBonus" then
		d.overchargeBonus = math.max(0, (tonumber(d.overchargeBonus) or 0) + scaledValue)
	elseif stat == "sweepBonus" then
		d.sweepBonus = math.max(0, (tonumber(d.sweepBonus) or 0) + scaledValue)
	elseif stat == "thrustBonus" then
		d.thrustBonus = math.max(0, (tonumber(d.thrustBonus) or 0) + scaledValue)
	elseif stat == "pierceBonus" then
		d.pierceBonus = math.max(0, (tonumber(d.pierceBonus) or 0) + scaledValue)
	elseif stat == "slamRadiusBonus" then
		d.slamRadiusBonus = math.max(0, (tonumber(d.slamRadiusBonus) or 0) + scaledValue)
	elseif stat == "aftershockMultiplier" then
		d.aftershockMultiplier = math.max(0, (tonumber(d.aftershockMultiplier) or 0) + scaledValue)
	elseif stat == "eagleEyeBonus" then
		d.eagleEyeBonus = math.max(0, (tonumber(d.eagleEyeBonus) or 0) + scaledValue)
	elseif stat == "quickDrawBonus" then
		d.quickDrawBonus = math.max(0, (tonumber(d.quickDrawBonus) or 0) + scaledValue)
	elseif stat == "arrowPierce" then
		d.arrowPierce = math.max(0, (tonumber(d.arrowPierce) or 0) + scaledValue)
	elseif stat == "elementalPowerBonus" then
		d.elementalPowerBonus = math.max(0, (tonumber(d.elementalPowerBonus) or 0) + scaledValue)
	elseif stat == "arcaneOverflowHeal" then
		d.arcaneOverflowHeal = math.max(0, (tonumber(d.arcaneOverflowHeal) or 0) + scaledValue)
	elseif stat == "manaSurgeEvery" then
		d.manaSurgeEvery = math.max(0, (tonumber(d.manaSurgeEvery) or 0) + scaledValue)
	elseif stat == "deadeyeDelay" then
		d.deadeyeDelay = math.max(0, (tonumber(d.deadeyeDelay) or 0) + scaledValue)
	elseif stat == "ricochet" then
		d.ricochet = math.clamp((tonumber(d.ricochet) or 0) + scaledValue, 0, 6)
	end

	if choice.secondaryStat then
		local secondaryScale = tonumber(choice.secondaryScale) or 1
		local secondaryValue = (tonumber(choice.value) or 0) * secondaryScale
		if choice.secondaryStat == "attackSpeed" then
			d.attackSpeed = math.clamp((tonumber(d.attackSpeed) or 1.0) + secondaryValue, 0.6, 2.0)
		end
	end

	-- track owned upgrades for UI
	d._owned = d._owned or {}
	table.insert(d._owned, { id=choice.id, rarity=choice.rarity, value=choice.value })

	pending[plr.UserId] = nil
	PauseState.Value = false

	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)
	pushProgress(plr)
end)

-- ===== Award =====
local sessionStart = {} -- [uid] = {xp, coins, time}
function _G.AwardPlayer(plr: Player, xp: number, coins: number)
	if not plr or not plr.Parent then return end
	local d = PlayerData.Get(plr)

	d.xp += math.max(0, math.floor(xp or 0))
	d.coins += math.max(0, math.floor(coins or 0))

	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)
	pushProgress(plr)

	-- level-up
	local leveled = false
	while d.xp >= d.nextXp do
		d.xp -= d.nextXp
		d.level += 1
		d.nextXp = PlayerData.RollNextXp(d.level)
		leveled = true
	end
	if leveled then
		PlayerData.MarkDirty(plr)
		PlayerData.Save(plr, false)
		pushProgress(plr)
		openUpgrade(plr)
	end
end

-- ===== Damage pipeline with crit + indicator =====
local function enemiesFolder() return workspace:FindFirstChild("Enemies") end

local function applyBurn(h: Humanoid, dps: number, seconds: number)
	if dps <= 0 then return end
	task.spawn(function()
		local tEnd = time() + seconds
		while h.Parent and h.Health > 0 and time() < tEnd do
			h:TakeDamage(dps * 0.5)
			task.wait(0.5)
		end
	end)
end

local EXECUTE_THRESHOLD = 0.3
local MOMENTUM_MAX = 5
local BATTLE_FOCUS_DURATION = 4
local RIPOSTE_DURATION = 5
local QUICK_DRAW_DURATION = 3
local ARCANE_OVERFLOW_COOLDOWN = 4
local PARRY_WINDOW_DURATION = 0.6
local MANA_SURGE_BONUS = 0.25
local RICOCHET_RADIUS = 10

local function applyStagger(hum: Humanoid, duration: number)
	if duration <= 0 then return end
	local previous = hum.WalkSpeed
	hum.WalkSpeed = 0
	task.delay(duration, function()
		if hum.Parent then
			hum.WalkSpeed = previous
		end
	end)
end

local function applyExecute(plr: Player, mobHum: Humanoid, baseDamage: number)
	local d = PlayerData.Get(plr)
	local executeBonus = tonumber(d.executeBonus) or 0
	if executeBonus <= 0 or mobHum.MaxHealth <= 0 then
		return baseDamage
	end
	if (mobHum.Health / mobHum.MaxHealth) <= EXECUTE_THRESHOLD then
		return math.max(1, math.floor(baseDamage * (1 + executeBonus)))
	end
	return baseDamage
end

local function applyRiposte(plr: Player, baseDamage: number)
	local d = PlayerData.Get(plr)
	local bonus = tonumber(d.riposteBonus) or 0
	if bonus <= 0 then return baseDamage end
	local readyUntil = riposteReady[plr.UserId]
	if readyUntil and readyUntil > time() then
		riposteReady[plr.UserId] = nil
		return math.max(1, math.floor(baseDamage * (1 + bonus)))
	end
	return baseDamage
end

local function applyMomentum(plr: Player, baseDamage: number)
	local d = PlayerData.Get(plr)
	local bonus = tonumber(d.momentumBonus) or 0
	if bonus <= 0 then return baseDamage end
	local stacks = momentumStacks[plr.UserId] or 0
	local mult = 1 + (stacks * bonus)
	return math.max(1, math.floor(baseDamage * mult))
end

local function updateMomentum(plr: Player, hitSuccess: boolean)
	local uid = plr.UserId
	if hitSuccess then
		local current = momentumStacks[uid] or 0
		momentumStacks[uid] = math.min(MOMENTUM_MAX, current + 1)
	else
		momentumStacks[uid] = 0
	end
end

local function grantBattleFocus(plr: Player)
	local d = PlayerData.Get(plr)
	if (tonumber(d.battleFocusBonus) or 0) <= 0 then return end
	battleFocus[plr.UserId] = { untilTime = time() + BATTLE_FOCUS_DURATION }
end

local function grantQuickDraw(plr: Player)
	local d = PlayerData.Get(plr)
	if (tonumber(d.quickDrawBonus) or 0) <= 0 then return end
	quickDrawUntil[plr.UserId] = time() + QUICK_DRAW_DURATION
end
local function resolveWeaponType(rawType: string?): string
	if rawType == "Melee" then return "Sword" end
	if rawType == "Wand" then return "Staff" end
	return rawType or ""
end

local function getWeaponStats(tool: Tool?)
	if not tool then
		return {
			type = "",
			atk = 0,
			bonusHP = 0,
			bonusSpeed = 0,
			bonusCritRate = 0,
			bonusCritDmg = 0,
			bonusLifesteal = 0,
			bonusDefense = 0,
		}
	end

	local wType = resolveWeaponType(tool:GetAttribute("WeaponType"))
	local level = math.max(1, math.floor(tonumber(tool:GetAttribute("WeaponLevel")) or 1))
	local baseAtk = tonumber(tool:GetAttribute("BaseATK")) or tonumber(tool:GetAttribute("ATK")) or 0
	local atkPerLevel = tonumber(tool:GetAttribute("ATKPerLevel")) or 0
	local atk = baseAtk + (level - 1) * atkPerLevel
	local bonusScale = 1 + (level - 1) * 0.02

	return {
		type = wType,
		atk = atk,
		bonusHP = (tonumber(tool:GetAttribute("BonusHP")) or 0) * bonusScale,
		bonusSpeed = (tonumber(tool:GetAttribute("BonusSpeed")) or 0) * bonusScale,
		bonusCritRate = (tonumber(tool:GetAttribute("BonusCritRate")) or 0) * bonusScale,
		bonusCritDmg = (tonumber(tool:GetAttribute("BonusCritDmg")) or 0) * bonusScale,
		bonusLifesteal = (tonumber(tool:GetAttribute("BonusLifesteal")) or 0) * bonusScale,
		bonusDefense = (tonumber(tool:GetAttribute("BonusDefense")) or 0) * bonusScale,
	}
end

local function getDamageBonusPct(d): number
	local raw = tonumber(d.damageBonusPct)
	if raw ~= nil then
		return math.max(0, raw)
	end
	local legacy = tonumber(d.damage)
	if legacy ~= nil then
		return math.max(0, legacy / 100)
	end
	return 0
end

local function getBattleFocusBonus(plr: Player, d)
	local bonus = tonumber(d.battleFocusBonus) or 0
	if bonus <= 0 then return 0 end
	local active = battleFocus[plr.UserId]
	if active and active.untilTime and active.untilTime > time() then
		return bonus
	end
	return 0
end

local function getQuickDrawBonus(plr: Player, d)
	local bonus = tonumber(d.quickDrawBonus) or 0
	if bonus <= 0 then return 0 end
	local active = quickDrawUntil[plr.UserId]
	if active and active > time() then
		return bonus
	end
	return 0
end

local function getCritMultBonus(d, baseCritDmg: number): number
	local raw = tonumber(d.critMult)
	if raw == nil then return 0 end
	if raw > 1.0 then
		return raw - baseCritDmg
	end
	return raw
end

getFinalStats = function(plr: Player, tool: Tool?)
	local d = PlayerData.Get(plr)
	local w = getWeaponStats(tool)

	local baseHP = tonumber(d.baseHP) or 100
	local baseSpeed = tonumber(d.baseSpeed) or 1.0
	local baseCritRate = tonumber(d.baseCritRate) or 0.05
	local baseCritDmg = tonumber(d.baseCritDmg) or 1.5
	local baseDefense = tonumber(d.baseDefense) or 0
	local baseLifesteal = tonumber(d.baseLifesteal) or 0

	local finalHP = baseHP + w.bonusHP + (tonumber(d.bonusHP) or 0)
	local finalSpeed = math.clamp(baseSpeed + w.bonusSpeed + (tonumber(d.speedBonus) or 0), 0.85, 1.35)
	local finalCritRate = math.clamp(baseCritRate + w.bonusCritRate + (tonumber(d.critChance) or 0), 0, 0.6)
	local finalCritDmg = math.clamp(baseCritDmg + w.bonusCritDmg + getCritMultBonus(d, baseCritDmg), 1.5, 2.5)
	local finalLifesteal = math.clamp(baseLifesteal + w.bonusLifesteal + (tonumber(d.lifesteal) or 0), 0, 0.12)
	local finalDefense = baseDefense + w.bonusDefense + (tonumber(d.defense) or 0)

	return {
		weaponType = w.type,
		weaponAtk = w.atk,
		damageBonusPct = getDamageBonusPct(d),
		multiShot = math.clamp(tonumber(d.multiShot) or 0, 0, 6),
		fireChance = math.clamp(tonumber(d.fireChance) or 0, 0, 0.9),
		fireDps = math.max(0, tonumber(d.fireDps) or 0),
		attackSpeed = math.clamp(tonumber(d.attackSpeed) or 1.0, 0.6, 2.0),
		critRate = finalCritRate,
		critDmg = finalCritDmg,
		lifesteal = finalLifesteal,
		speedMult = finalSpeed,
		maxHP = finalHP,
		defense = finalDefense,
	}
end

local function getCombatStats(plr: Player, tool: Tool?)
	local d = PlayerData.Get(plr)
	local stats = getFinalStats(plr, tool)
	local battleBonus = getBattleFocusBonus(plr, d)
	local quickDrawBonus = getQuickDrawBonus(plr, d)
	local elementalPower = tonumber(d.elementalPowerBonus) or 0

	stats.damageBonusPct = math.max(0, stats.damageBonusPct + battleBonus)
	stats.attackSpeed = math.clamp(stats.attackSpeed + quickDrawBonus, 0.6, 2.0)
	stats.fireDps = math.max(0, stats.fireDps * (1 + elementalPower))
	local finalAtk = math.max(1, stats.weaponAtk * (1 + stats.damageBonusPct))
	stats.finalAtk = finalAtk
	return stats
end

local function dealMobDamage(plr: Player, mobHum: Humanoid, mobRoot: BasePart, baseDamage: number, fireChance: number, fireDps: number, critC: number, critM: number, lifesteal: number, extraCritBonus: number?)
	local critChance = math.clamp(critC + (extraCritBonus or 0), 0, 1)
	local damage = applyExecute(plr, mobHum, baseDamage)
	damage = applyRiposte(plr, damage)
	local isCrit = (math.random() < critChance)
	local final = damage
	if isCrit then final = math.floor(damage * critM) end

	local willDie = mobHum.Health - final <= 0
	mobHum:TakeDamage(final)

	-- stimmy indicator (client draws)
	DamageIndicatorEvent:FireAllClients({
		pos = mobRoot.Position + Vector3.new(0, 2.6, 0),
		amount = final,
		crit = isCrit,
	})

	if willDie then
		grantBattleFocus(plr)
	end

	if isCrit then
		grantQuickDraw(plr)
	end

	if lifesteal > 0 then
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local heal = math.floor(final * lifesteal)
			if heal > 0 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
			end
		end
	end

	if fireDps > 0 and math.random() < fireChance then
		applyBurn(mobHum, fireDps, 3.0)
	end
end

-- melee AoE
local MELEE_ENEMY_SCALE = 1.1
local function getMeleeTargetsArc(origin: Vector3, forward: Vector3, range: number, angleDeg: number, hitLimit: number?)
	local enf = enemiesFolder()
	if not enf then return {} end

	local out = {}
	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	local halfAngle = math.rad(angleDeg / 2)

	for _,m in ipairs(enf:GetChildren()) do
		local eh = m:FindFirstChildOfClass("Humanoid")
		local er = m:FindFirstChild("HumanoidRootPart")
		if eh and er and eh.Health > 0 then
			local toEnemy = er.Position - origin
			local flatToEnemy = Vector3.new(toEnemy.X, 0, toEnemy.Z)
			local dist = flatToEnemy.Magnitude
			local enemyRadius = math.max(er.Size.X, er.Size.Z) * 0.55 * MELEE_ENEMY_SCALE

			if dist <= (range + enemyRadius) and dist > 0.1 and flatForward.Magnitude > 0 then
				local angle = math.acos(math.clamp(flatForward.Unit:Dot(flatToEnemy.Unit), -1, 1))
				if angle <= halfAngle then
					table.insert(out, { hum = eh, root = er, dist = dist })
				end
			end
		end
	end

	table.sort(out, function(a, b) return a.dist < b.dist end)
	if hitLimit and #out > hitLimit then
		for i = #out, hitLimit + 1, -1 do
			out[i] = nil
		end
	end
	return out
end

local function getMeleeTargetsLine(origin: Vector3, forward: Vector3, length: number, width: number, hitLimit: number?)
	local enf = enemiesFolder()
	if not enf then return {} end

	local out = {}
	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	if flatForward.Magnitude <= 0.01 then return out end
	flatForward = flatForward.Unit

	for _,m in ipairs(enf:GetChildren()) do
		local eh = m:FindFirstChildOfClass("Humanoid")
		local er = m:FindFirstChild("HumanoidRootPart")
		if eh and er and eh.Health > 0 then
			local toEnemy = er.Position - origin
			local flatToEnemy = Vector3.new(toEnemy.X, 0, toEnemy.Z)
			local forwardDist = flatToEnemy:Dot(flatForward)
			if forwardDist > 0 and forwardDist <= length then
				local lateral = (flatToEnemy - flatForward * forwardDist).Magnitude
				local enemyRadius = math.max(er.Size.X, er.Size.Z) * 0.55 * MELEE_ENEMY_SCALE
				if lateral <= (width / 2 + enemyRadius) then
					table.insert(out, { hum = eh, root = er, dist = forwardDist })
				end
			end
		end
	end

	table.sort(out, function(a, b) return a.dist < b.dist end)
	if hitLimit and #out > hitLimit then
		for i = #out, hitLimit + 1, -1 do
			out[i] = nil
		end
	end
	return out
end

-- projectile (ray + overlap)
local function overlapHit(pos: Vector3, radius: number, ignore: {Instance}, hitModels: {[Model]: boolean}?)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local parts = workspace:GetPartBoundsInRadius(pos, radius, params)
	for _,p in ipairs(parts) do
		local model = p:FindFirstAncestorOfClass("Model")
		if model and model.Parent == enemiesFolder() then
			if hitModels and hitModels[model] then
				continue
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				return hum, root, model
			end
		end
	end
	return nil
end

local function findNearestEnemy(pos: Vector3, excludeModel: Model?)
	local enf = enemiesFolder()
	if not enf then return nil end
	local best, bestRoot, bestDist
	for _,m in ipairs(enf:GetChildren()) do
		if m ~= excludeModel then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local dist = (root.Position - pos).Magnitude
				if dist <= RICOCHET_RADIUS and (not bestDist or dist < bestDist) then
					best = hum
					bestRoot = root
					bestDist = dist
				end
			end
		end
	end
	return best, bestRoot
end

local function applyAreaDamage(plr: Player, center: Vector3, radius: number, hitLimit: number?, damage: number, stats)
	local enf = enemiesFolder()
	if not enf then return 0 end

	local targets = {}
	for _,m in ipairs(enf:GetChildren()) do
		local eh = m:FindFirstChildOfClass("Humanoid")
		local er = m:FindFirstChild("HumanoidRootPart")
		if eh and er and eh.Health > 0 then
			local dist = (er.Position - center).Magnitude
			if dist <= radius then
				table.insert(targets, { hum = eh, root = er, dist = dist })
			end
		end
	end

	table.sort(targets, function(a, b) return a.dist < b.dist end)
	local maxHits = hitLimit or #targets
	local hits = 0
	for i = 1, math.min(maxHits, #targets) do
		local entry = targets[i]
		dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, 0)
		hits += 1
	end
	return hits
end

local function spawnProjectile(plr: Player, origin: Vector3, dir: Vector3, speed: number, range: number, damage: number, radius: number, pierce: number, impactAoE: {radius: number, hitLimit: number, damageMul: number}?, extraCritBonus: number?)
	local p = Instance.new("Part")
	p.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(180,220,255)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CFrame = CFrame.new(origin)
	p.Parent = workspace
	Debris:AddItem(p, range / speed)

	local stats = getCombatStats(plr, plr.Character and plr.Character:FindFirstChildOfClass("Tool"))
	local ignore = { plr.Character, p }
	local hitModels = {}
	local hits = 0
	local maxHits = math.max(1, pierce)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore

	local pos = origin
	local vel = dir.Unit * speed
	local traveled = 0

	while p.Parent and traveled < range do
		if PauseState.Value then task.wait(0.05) continue end
		local dt = RunService.Heartbeat:Wait()
		local nextPos = pos + vel * dt

		local oh, oroot, omodel = overlapHit(nextPos, radius, ignore, hitModels)
		if oh and oroot and omodel then
			dealMobDamage(plr, oh, oroot, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, extraCritBonus)
			if impactAoE then
				local aoeDamage = math.max(1, math.floor(damage * impactAoE.damageMul))
				applyAreaDamage(plr, oroot.Position, impactAoE.radius, impactAoE.hitLimit, aoeDamage, stats)
			end
			hitModels[omodel] = true
			hits += 1
			if hits >= maxHits then
				break
			end
		end

		local hit = workspace:Raycast(pos, nextPos - pos, rayParams)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model and model.Parent == enemiesFolder() then
				local mh = model:FindFirstChildOfClass("Humanoid")
				local mr = model:FindFirstChild("HumanoidRootPart")
				if mh and mr and mh.Health > 0 then
					dealMobDamage(plr, mh, mr, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, extraCritBonus)
					if impactAoE then
						local aoeDamage = math.max(1, math.floor(damage * impactAoE.damageMul))
						applyAreaDamage(plr, mr.Position, impactAoE.radius, impactAoE.hitLimit, aoeDamage, stats)
					end
					hitModels[model] = true
					hits += 1
				end
			end
			if hits >= maxHits then
				break
			end
		end

		traveled += (nextPos - pos).Magnitude
		pos = nextPos
		p.CFrame = CFrame.new(pos)
	end

	if p.Parent then p:Destroy() end
end

local swingCd, shotCd = {}, {}

WeaponEvent.OnServerEvent:Connect(function(plr, payload)
	if PauseState.Value then return end
	if typeof(payload) ~= "table" then return end

	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then return end
	local wType = tool:GetAttribute("WeaponType")
	if typeof(wType) ~= "string" then return end

	local weaponType = resolveWeaponType(wType)
	local stats = getCombatStats(plr, tool)
	local aspd = stats.attackSpeed
	local d = PlayerData.Get(plr)
	local rangeBonus = tonumber(d.rangeBonus) or 0

	if payload.action == "MELEE" and (weaponType == "Sword" or weaponType == "Scythe" or weaponType == "Halberd" or weaponType == "Claymore" or weaponType == "Greataxe") then
		local now = os.clock()
		local cdBase = (weaponType == "Scythe") and 0.70
			or (weaponType == "Halberd" and 0.60)
			or (weaponType == "Claymore" and 0.85)
			or (weaponType == "Greataxe" and 1.0)
			or 0.50
		local cd = cdBase / aspd
		if swingCd[plr.UserId] and (now - swingCd[plr.UserId]) < cd then return end
		swingCd[plr.UserId] = now

		local forward = hrp.CFrame.LookVector
		local hitCount = 0

		if weaponType == "Sword" then
			local hitLimit = 3 + math.floor(tonumber(d.cleaveBonus) or 0)
			local targets = getMeleeTargetsArc(hrp.Position + forward * 2, forward, 6 + rangeBonus, 90, hitLimit)
			local damage = applyMomentum(plr, math.max(1, math.floor(stats.finalAtk * 0.75)))
			local bladeEvery = tonumber(d.bladeDanceEvery) or 0
			local extraSwing = false
			if bladeEvery > 0 then
				local totalHits = (bladeDanceHits[plr.UserId] or 0) + #targets
				if totalHits >= bladeEvery then
					extraSwing = true
					totalHits -= bladeEvery
				end
				bladeDanceHits[plr.UserId] = totalHits
			end
			for _,entry in ipairs(targets) do
				dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, 0)
				hitCount += 1
			end
			if extraSwing then
				for _,entry in ipairs(targets) do
					dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, 0)
					hitCount += 1
				end
			end

			if (tonumber(d.parryReduction) or 0) > 0 then
				local untilTime = time() + PARRY_WINDOW_DURATION
				parryUntil[plr.UserId] = untilTime
				plr:SetAttribute("ParryReduction", d.parryReduction)
				plr:SetAttribute("ParryUntil", untilTime)
			end
		elseif weaponType == "Scythe" then
			local angle = 220 + (tonumber(d.sweepBonus) or 0)
			local targets = getMeleeTargetsArc(hrp.Position, forward, 7.5 + rangeBonus, angle, nil)
			local damage = applyMomentum(plr, math.max(1, math.floor(stats.finalAtk * 0.65)))
			for _,entry in ipairs(targets) do
				dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, 0)
				hitCount += 1
			end
		elseif weaponType == "Halberd" then
			local hitLimit = 3 + math.floor(tonumber(d.pierceBonus) or 0)
			local length = 9 + rangeBonus + (tonumber(d.thrustBonus) or 0)
			local targets = getMeleeTargetsLine(hrp.Position, forward, length, 2.5, hitLimit)
			local damage = applyMomentum(plr, math.max(1, math.floor(stats.finalAtk * 0.75)))
			for _,entry in ipairs(targets) do
				dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, 0)
				hitCount += 1
			end
		elseif weaponType == "Claymore" then
			local damage = applyMomentum(plr, math.max(1, math.floor(stats.finalAtk * 0.95)))
			local staggerDuration = tonumber(d.staggerDuration) or 0
			task.delay(0.2, function()
				local charNow = plr.Character
				local hrpNow = charNow and charNow:FindFirstChild("HumanoidRootPart")
				if not hrpNow then return end
				local forwardNow = hrpNow.CFrame.LookVector
				local targets = getMeleeTargetsArc(hrpNow.Position + forwardNow * 2.5, forwardNow, 7 + rangeBonus, 120, 4)
				local hits = 0
				for _,entry in ipairs(targets) do
					dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, 0)
					if staggerDuration > 0 then
						applyStagger(entry.hum, staggerDuration)
					end
					hits += 1
				end
				updateMomentum(plr, hits > 0)
			end)
			return
		elseif weaponType == "Greataxe" then
			local damage = applyMomentum(plr, math.max(1, math.floor(stats.finalAtk * 1.1)))
			local slamRadius = 4.5 + rangeBonus + (tonumber(d.slamRadiusBonus) or 0)
			local aftershock = tonumber(d.aftershockMultiplier) or 0
			task.delay(0.25, function()
				local charNow = plr.Character
				local hrpNow = charNow and charNow:FindFirstChild("HumanoidRootPart")
				if not hrpNow then return end
				local forwardNow = hrpNow.CFrame.LookVector
				local center = hrpNow.Position + forwardNow * 3.5
				local hits = applyAreaDamage(plr, center, slamRadius, nil, damage, stats)
				if aftershock > 0 then
					task.delay(0.35, function()
						applyAreaDamage(plr, center, slamRadius + 0.5, nil, math.max(1, math.floor(damage * aftershock)), stats)
					end)
				end
				updateMomentum(plr, hits > 0)
			end)
			return
		end

		updateMomentum(plr, hitCount > 0)

	elseif payload.action == "SHOOT" and (weaponType == "Bow" or weaponType == "Staff" or weaponType == "Pistol") then
		local aim = payload.aim
		if typeof(aim) ~= "Vector3" then return end
		if (aim - hrp.Position).Magnitude > 800 then return end

		local now = os.clock()
		local cdBase = (weaponType == "Bow") and 0.65 or (weaponType == "Staff" and 0.60 or 0.35)
		local cd = cdBase / aspd
		if shotCd[plr.UserId] and (now - shotCd[plr.UserId]) < cd then return end
		shotCd[plr.UserId] = now

		local origin = hrp.Position + Vector3.new(0, 1.35, 0)
		local dir = (aim - origin)
		if dir.Magnitude < 3 then return end

		local total = 1 + stats.multiShot
		local spread = math.rad(4)

		if weaponType == "Bow" then
			local speed = 160
			local range = 45
			local damage = math.max(1, math.floor(stats.finalAtk))
			local pierce = 1 + math.floor(tonumber(d.arrowPierce) or 0)
			local eagleEye = tonumber(d.eagleEyeBonus) or 0
			local extraCrit = 0
			if eagleEye > 0 then
				extraCrit = math.min(0.25, (dir.Magnitude / 10) * eagleEye)
			end
			for i=1,total do
				local angle = (i - (total+1)/2) * spread
				local rot = CFrame.fromAxisAngle(Vector3.new(0,1,0), angle)
				local shotDir = rot:VectorToWorldSpace(dir.Unit)
				spawnProjectile(plr, origin, shotDir, speed, range, damage, 0.3, pierce, nil, extraCrit)
			end
		elseif weaponType == "Staff" then
			local speed = 175
			local range = 40
			local damage = math.max(1, math.floor(stats.finalAtk))
			local empowered = false
			local surgeEvery = tonumber(d.manaSurgeEvery) or 0
			if surgeEvery > 0 then
				local count = (manaSurgeStacks[plr.UserId] or 0) + 1
				if count >= surgeEvery then
					empowered = true
					count = 0
				end
				manaSurgeStacks[plr.UserId] = count
			end
			if empowered then
				damage = math.max(1, math.floor(damage * (1 + MANA_SURGE_BONUS)))
			end

			local heal = tonumber(d.arcaneOverflowHeal) or 0
			local cd = arcaneOverflowCd[plr.UserId] or 0
			if heal > 0 and cd <= time() then
				arcaneOverflowCd[plr.UserId] = time() + ARCANE_OVERFLOW_COOLDOWN
				local currentHum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
				if currentHum and currentHum.Health > 0 then
					currentHum.Health = math.min(currentHum.MaxHealth, currentHum.Health + heal)
				end
			end

			local aoeRadius = empowered and 4.5 or 3.5
			for i=1,1 do
				spawnProjectile(
					plr,
					origin,
					dir.Unit,
					speed,
					range,
					damage,
					0.35,
					1,
					{ radius = aoeRadius, hitLimit = 4, damageMul = 0.7 },
					0
				)
			end
		elseif weaponType == "Pistol" then
			local range = 35
			local damage = math.max(1, math.floor(stats.finalAtk))
			local pierce = math.max(1, math.floor(tonumber(tool:GetAttribute("Pierce")) or 1))
			local extraCrit = 0
			local deadeyeDelay = tonumber(d.deadeyeDelay) or 0
			if deadeyeDelay > 0 then
				local lastShot = lastPistolShot[plr.UserId] or 0
				if (now - lastShot) >= deadeyeDelay then
					extraCrit = 1
				end
				lastPistolShot[plr.UserId] = now
			end
			local ricochetCount = math.floor(tonumber(d.ricochet) or 0)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { plr.Character }
			local remaining = range
			local currentOrigin = origin
			local hits = 0

			while hits < pierce and remaining > 0 do
				local result = workspace:Raycast(currentOrigin, dir.Unit * remaining, params)
				if not result then break end
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				if model and model.Parent == enemiesFolder() then
					local mh = model:FindFirstChildOfClass("Humanoid")
					local mr = model:FindFirstChild("HumanoidRootPart")
					if mh and mr and mh.Health > 0 then
						dealMobDamage(plr, mh, mr, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, extraCrit)
						local ricHits = 0
						local lastModel = model
						while ricHits < ricochetCount do
							local rh, rr = findNearestEnemy(mr.Position, lastModel)
							if not rh or not rr then break end
							local ricDamage = math.max(1, math.floor(damage * 0.6))
							dealMobDamage(plr, rh, rr, ricDamage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal, 0)
							lastModel = rh.Parent
							ricHits += 1
						end
						hits += 1
						params.FilterDescendantsInstances = { plr.Character, model }
					end
				end

				local traveled = (result.Position - currentOrigin).Magnitude
				remaining -= traveled + 0.1
				currentOrigin = result.Position + dir.Unit * 0.2
			end
		end
	end
end)

-- Mission summary: WaveController wyśle _G.MissionComplete(waves, seconds)
function _G.MissionComplete(totalWaves: number, seconds: number)
	for _,plr in ipairs(Players:GetPlayers()) do
		local d = PlayerData.Get(plr)
		local start = sessionStart[plr.UserId]
		local gainedXp, gainedCoins = 0, 0
		if start then
			gainedXp = math.max(0, (d._sessionXp or 0) - start.xp)
			gainedCoins = math.max(0, (d._sessionCoins or 0) - start.coins)
		end

		MissionSummaryEvent:FireClient(plr, {
			type="summary",
			waves = totalWaves,
			time = seconds,
			level = d.level,
			coins = d.coins,
			xp = d.xp,
		})
	end
end

-- Player lifecycle
Players.PlayerAdded:Connect(function(plr)
	local d = PlayerData.Get(plr)
	d._sessionXp = 0
	d._sessionCoins = 0
	sessionStart[plr.UserId] = { xp = 0, coins = 0, t = time() }

	pushProgress(plr)

	plr.CharacterAdded:Connect(function(char)
		PauseState.Value = false

		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			updatePlayerDerivedStats(plr)
			lastHealth[plr.UserId] = hum.Health
			hum.HealthChanged:Connect(function(current)
				local prev = lastHealth[plr.UserId] or current
				if current < prev then
					riposteReady[plr.UserId] = time() + RIPOSTE_DURATION
				end
				lastHealth[plr.UserId] = current
			end)
		end

		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				updatePlayerDerivedStats(plr)
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				updatePlayerDerivedStats(plr)
			end
		end)

		task.wait(0.1)
		WeaponService.EquipLoadout(plr)
		pushProgress(plr)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	PlayerData.Save(plr, true)
	sessionStart[plr.UserId] = nil
end)

game:BindToClose(function()
	for _,plr in ipairs(Players:GetPlayers()) do
		PlayerData.Save(plr, true)
	end
end)
