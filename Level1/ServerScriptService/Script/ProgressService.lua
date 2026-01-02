-- ProgressService.server.lua (ServerScriptService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
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
local WeaponTemplates = ReplicatedStorage:WaitForChild("WeaponTemplates")
local function giveLoadout(plr: Player)
	local d = PlayerData.Get(plr)
	local backpack = plr:WaitForChild("Backpack")
	local starterWeapon = plr:GetAttribute("StarterWeaponName")

	local function give(toolName: string): boolean
		for _,x in ipairs(backpack:GetChildren()) do
			if x:IsA("Tool") and x.Name == toolName then return end
		end
		local src = WeaponTemplates:FindFirstChild(toolName)
		if src and src:IsA("Tool") then
			src:Clone().Parent = backpack
			return true
		end
		return false
	end

	if typeof(starterWeapon) == "string" and starterWeapon ~= "" then
		if give(starterWeapon) then
			return
		end
	end

	if typeof(starterWeapon) == "string" and starterWeapon ~= "" then
		give(starterWeapon)
		return
	end

	give("Sword")
	if d.unlockBow then give("Bow") end
	if d.unlockWand then give("Staff") end
end

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

local function roll3()
	local pool = table.clone(UpDefs.POOL)
	local out = {}
	for i=1,3 do
		local idx = math.random(1, #pool)
		local base = pool[idx]
		table.remove(pool, idx)

		local rarity, color = UpDefs.RollRarity()
		-- lekkie wzmocnienie per rarity
		local mult = (rarity=="Common" and 1.0) or (rarity=="Rare" and 1.4) or (rarity=="Epic" and 2.0) or 3.0

		local value
		if base.id == "ASPD" or base.id == "CRITR" or base.id == "CRITM" or base.id == "FCH" then
			value = math.floor((base.base * mult) * 100) / 100
		else
			value = math.floor(base.base * mult)
		end

		out[i] = {
			id = base.id,
			name = base.name,
			desc = base.desc,
			stat = base.stat,
			value = value,
			rarity = rarity,
			color = color,
		}
	end
	return out
end

local function openUpgrade(plr: Player)
	local token = ("%d_%d"):format(plr.UserId, math.floor(os.clock()*1000))
	local choices = roll3()
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

	-- defaults if missing in datastore (compat)
	if stat == "critChance" and d.critChance == nil then d.critChance = 0 end
	if stat == "critMult" and d.critMult == nil then d.critMult = 0 end

	if stat == "attackSpeed" then
		d.attackSpeed = math.clamp((tonumber(d.attackSpeed) or 1.0) + choice.value, 0.6, 2.0)
	elseif stat == "multiShot" then
		d.multiShot = math.clamp((tonumber(d.multiShot) or 0) + choice.value, 0, 6)
	elseif stat == "fireChance" then
		d.fireChance = math.clamp((tonumber(d.fireChance) or 0) + choice.value, 0, 0.9)
	elseif stat == "fireDps" then
		d.fireDps = math.max(0, (tonumber(d.fireDps) or 0) + choice.value)
	elseif stat == "damage" then
		d.damage = math.max(0, (tonumber(d.damage) or 0) + choice.value)
	elseif stat == "critChance" then
		d.critChance = math.clamp((tonumber(d.critChance) or 0) + choice.value, 0, 0.6)
	elseif stat == "critMult" then
		d.critMult = math.clamp((tonumber(d.critMult) or 0) + choice.value, 0, 1.0)
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
	local stats = getFinalStats(plr, tool)
	local finalAtk = math.max(1, stats.weaponAtk * (1 + stats.damageBonusPct))
	stats.finalAtk = finalAtk
	return stats
end

local function dealMobDamage(plr: Player, mobHum: Humanoid, mobRoot: BasePart, baseDamage: number, fireChance: number, fireDps: number, critC: number, critM: number, lifesteal: number)
	local isCrit = (math.random() < critC)
	local final = baseDamage
	if isCrit then final = math.floor(baseDamage * critM) end

	mobHum:TakeDamage(final)

	-- stimmy indicator (client draws)
	DamageIndicatorEvent:FireAllClients({
		pos = mobRoot.Position + Vector3.new(0, 2.6, 0),
		amount = final,
		crit = isCrit,
	})

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

local function applyAreaDamage(plr: Player, center: Vector3, radius: number, hitLimit: number?, damage: number, stats)
	local enf = enemiesFolder()
	if not enf then return end

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
	for i = 1, math.min(maxHits, #targets) do
		local entry = targets[i]
		dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal)
	end
end

local function spawnProjectile(plr: Player, origin: Vector3, dir: Vector3, speed: number, range: number, damage: number, radius: number, pierce: number, impactAoE: {radius: number, hitLimit: number, damageMul: number}?)
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
			dealMobDamage(plr, oh, oroot, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal)
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
					dealMobDamage(plr, mh, mr, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal)
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

	if payload.action == "MELEE" and (weaponType == "Sword" or weaponType == "Scythe" or weaponType == "Halberd") then
		local now = os.clock()
		local cdBase = (weaponType == "Scythe") and 0.70 or (weaponType == "Halberd" and 0.60 or 0.50)
		local cd = cdBase / aspd
		if swingCd[plr.UserId] and (now - swingCd[plr.UserId]) < cd then return end
		swingCd[plr.UserId] = now

		local forward = hrp.CFrame.LookVector
		if weaponType == "Sword" then
			local targets = getMeleeTargetsArc(hrp.Position + forward * 2, forward, 6, 90, 3)
			local damage = math.max(1, math.floor(stats.finalAtk * 0.75))
			for _,entry in ipairs(targets) do
				dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal)
			end
		elseif weaponType == "Scythe" then
			local targets = getMeleeTargetsArc(hrp.Position, forward, 7.5, 220, nil)
			local damage = math.max(1, math.floor(stats.finalAtk * 0.65))
			for _,entry in ipairs(targets) do
				dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal)
			end
		elseif weaponType == "Halberd" then
			local targets = getMeleeTargetsLine(hrp.Position, forward, 9, 2.5, 3)
			local damage = math.max(1, math.floor(stats.finalAtk * 0.75))
			for _,entry in ipairs(targets) do
				dealMobDamage(plr, entry.hum, entry.root, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal)
			end
		end

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
			for i=1,total do
				local angle = (i - (total+1)/2) * spread
				local rot = CFrame.fromAxisAngle(Vector3.new(0,1,0), angle)
				local shotDir = rot:VectorToWorldSpace(dir.Unit)
				spawnProjectile(plr, origin, shotDir, speed, range, damage, 0.3, 1)
			end
		elseif weaponType == "Staff" then
			local speed = 175
			local range = 40
			local damage = math.max(1, math.floor(stats.finalAtk))
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
					{ radius = 3.5, hitLimit = 4, damageMul = 0.7 }
				)
			end
		elseif weaponType == "Pistol" then
			local range = 35
			local damage = math.max(1, math.floor(stats.finalAtk))
			local pierce = math.max(1, math.floor(tonumber(tool:GetAttribute("Pierce")) or 1))
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
						dealMobDamage(plr, mh, mr, damage, stats.fireChance, stats.fireDps, stats.critRate, stats.critDmg, stats.lifesteal)
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
		giveLoadout(plr)
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
