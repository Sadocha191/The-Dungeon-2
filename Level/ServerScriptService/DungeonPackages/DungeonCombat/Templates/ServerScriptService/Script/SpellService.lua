local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
if not remotesFolder then error("[SpellService] Missing ReplicatedStorage.Remotes") end

local SpellVFXEvent = remotesFolder:FindFirstChild("SpellVFXEvent")
if not SpellVFXEvent then
	SpellVFXEvent = Instance.new("RemoteEvent")
	SpellVFXEvent.Name = "SpellVFXEvent"
	SpellVFXEvent.Parent = remotesFolder
end

local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end

local function findServerModule(name)
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then return direct end
	local folder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then return nested end
	end
	return nil
end

local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = modFolder and require(modFolder:WaitForChild("SpellDefinitions"))
local NpcService = require(findServerModule("NpcService") or error("[SpellService] Missing NpcService"))
local DamageIndicatorService = require(findServerModule("DamageIndicatorService") or error("[SpellService] Missing DamageIndicatorService"))
local PlayerData = require(findServerModule("PlayerData") or error("[SpellService] Missing PlayerData"))
local SpellEffects = require(findServerModule("SpellEffects") or error("[SpellService] Missing SpellEffects"))
local SpellProjectiles = require(findServerModule("SpellProjectiles") or error("[SpellService] Missing SpellProjectiles"))
local SpellTargeting = require(findServerModule("SpellTargeting") or error("[SpellService] Missing SpellTargeting"))
local SpellVisuals = require(findServerModule("SpellVisuals") or error("[SpellService] Missing SpellVisuals"))
local SpellSustained = require(findServerModule("SpellSustained") or error("[SpellService] Missing SpellSustained"))
local WeaponConfigs = modFolder and require(modFolder:WaitForChild("WeaponConfigs"))

SpellVisuals.Configure({
	spellVfxEvent = SpellVFXEvent,
	getServerTimeNow = function() return workspace:GetServerTimeNow() end,
})

local pauseAccum = 0
local pauseStart = nil
local state = {}
local doomBoundEnemies = setmetatable({}, { __mode = "k" })
local random = Random.new()

local function isPaused() return PauseState.Value == true end

local function spellClock()
	local realNow = os.clock()
	if PauseState.Value then
		if not pauseStart then pauseStart = realNow end
		return pauseStart - pauseAccum
	end
	if pauseStart then
		pauseAccum += realNow - pauseStart
		pauseStart = nil
	end
	return realNow - pauseAccum
end

local function getState(plr)
	local s = state[plr.UserId]
	if not s then
		s = { cds = {}, orbit = {}, vfx = {}, impact = {}, windBladeSoundToggle = 1, doomEnergy = 0 }
		state[plr.UserId] = s
	end
	return s
end

local function isPlayerRunActive(plr)
	if not plr or plr.Parent ~= Players or plr:GetAttribute("RunEnded") == true then return false end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and hum.Health > 0 and hrp ~= nil
end

local function enemyAlive(model) return SpellTargeting.IsEnemyAlive(model) end
local function getEnemyPosition(model) return SpellTargeting.GetEnemyPosition(model) end
local function getNearestEnemy(pos, range) return SpellTargeting.GetNearestEnemy(pos, range) end
local function getEnemiesInRadius(pos, radius) return SpellTargeting.GetEnemiesInRadius(pos, radius) end
local function getAllEnemies() return SpellTargeting.GetAllEnemies() end
local function pickPriorityEnemy(pos, range) return SpellTargeting.PickPriorityEnemy(pos, range) end
local function pickPriorityEnemyList(pos, range, count) return SpellTargeting.PickPriorityEnemyList(pos, range, count) end
local function distancePointToSegment(point, a, b) return SpellTargeting.DistancePointToSegment(point, a, b) end

local function safeDamage(enemyModel, dmg, meta)
	if isPaused() then return 0 end
	if meta and meta.player and not isPlayerRunActive(meta.player) then return 0 end
	dmg = math.floor(tonumber(dmg) or 0)
	if dmg <= 0 then return 0 end
	return DamageIndicatorService.ApplyDamage(enemyModel, dmg, meta)
end

local function getSpellState(plr, spellId)
	return {
		level = tonumber(plr:GetAttribute(("Spell_%s_Level"):format(spellId))) or 0,
		upgradePower = tonumber(plr:GetAttribute(("Spell_%s_UpgradePower"):format(spellId))) or 0,
		baseMultiplier = tonumber(plr:GetAttribute(("Spell_%s_BaseMultiplier"):format(spellId))) or 1,
		basePower = tonumber(plr:GetAttribute(("Spell_%s_BasePower"):format(spellId))) or 0,
	}
end

local function getEquippedWeaponCombat(plr)
	local data = PlayerData.Get(plr)
	local entry = data and typeof(data.Loadout) == "table" and data.Loadout[1] or nil
	local weaponId = entry and (entry.id or entry.Id)
	if typeof(weaponId) ~= "string" or weaponId == "" or not WeaponConfigs or not WeaponConfigs.Get then return nil end
	local def = WeaponConfigs.Get(weaponId)
	return def and def.combat or nil
end

local function getAtkMult(plr)
	local runAtkMult = tonumber(plr:GetAttribute("RunAtkMult")) or 1
	local shrineDamageMult = tonumber(plr:GetAttribute("ShrineDamageMult")) or 1
	local spellDamageMult = tonumber(plr:GetAttribute("SpellDamageMult")) or 1
	local weaponCombat = getEquippedWeaponCombat(plr)
	local weaponSpellDamage = 1 + math.max(0, tonumber(weaponCombat and weaponCombat.spellDamageBonus) or 0)
	return runAtkMult * shrineDamageMult * spellDamageMult * weaponSpellDamage
end

local function getDurationMult(plr)
	local weaponCombat = getEquippedWeaponCombat(plr)
	local weaponEffectBonus = math.max(0, tonumber(weaponCombat and weaponCombat.spellEffectBonus) or 0)
	return math.max(0.1, (1 + (tonumber(plr:GetAttribute("ShrineDurationBonus")) or 0)) * (1 + weaponEffectBonus))
end

local function getCooldownMult(plr)
	local weaponCombat = getEquippedWeaponCombat(plr)
	local weaponCooldownBonus = math.max(0, tonumber(weaponCombat and weaponCombat.spellCooldownBonus) or 0)
	return math.max(0.72, 1 - weaponCooldownBonus)
end

SpellEffects.Configure({
	addImpulse = function(model, impulse, kind) NpcService.AddImpulse(model, impulse, kind) end,
	applyFreeze = function(model, duration) NpcService.ApplyFreeze(model, duration) end,
	applySlow = function(model, pct, duration) NpcService.ApplySlow(model, pct, duration) end,
	getDurationMult = getDurationMult,
	getEnemyPosition = getEnemyPosition,
	isEnemyAlive = enemyAlive,
	safeDamage = safeDamage,
	spellClock = spellClock,
})

local function shouldSpawnImpact(plr, spellId, enemy)
	local s = getState(plr)
	s.impact[spellId] = s.impact[spellId] or {}
	local bucket = s.impact[spellId]
	local now = spellClock()
	if now < (bucket[enemy] or 0) then return false end
	bucket[enemy] = now + 0.16
	return true
end

local function applySecondaryComboEffect(plr, enemy, stats)
	local secondary = stats and stats.secondaryElement
	if secondary == "Fire" then
		local duration = 1.8 * getDurationMult(plr)
		task.spawn(function()
			local endAt = spellClock() + duration
			while spellClock() < endAt and enemyAlive(enemy) do
				safeDamage(enemy, 2.5 * (stats.effectPower or 1), { player=plr, showFloating=false, element="Fire", sourceId=stats.spellId })
				task.wait(0.5)
			end
		end)
	elseif secondary == "Ice" then
		NpcService.ApplySlow(enemy, 0.3, 1.2 * getDurationMult(plr))
	elseif secondary == "Lightning" then
		NpcService.ApplyFreeze(enemy, 0.18 * getDurationMult(plr))
	elseif secondary == "Light" then
		enemy:SetAttribute("VulnerableUntil", spellClock() + 1.2 * getDurationMult(plr))
		enemy:SetAttribute("VulnerablePct", 0.08)
	end
end

local function hitEnemy(plr, enemy, damage, stats, sourcePos, impactPos)
	if not enemy or not enemyAlive(enemy) then return 0 end
	local dealt = damage * getAtkMult(plr) * SpellEffects.GetTargetDamageMultiplier(enemy, stats)
	dealt *= SpellEffects.GetVulnerabilityDamageMultiplier(enemy, spellClock())
	local applied = safeDamage(enemy, dealt, { player=plr, element=stats and stats.element, secondaryElement=stats and stats.secondaryElement, sourceId=tostring(stats and stats.spellId or "Spell") })
	if applied <= 0 then return 0 end

	if not (stats and stats.noBaseEffects) then SpellEffects.Apply(plr, enemy, stats or {}, sourcePos) end
	applySecondaryComboEffect(plr, enemy, stats)

	if stats and tonumber(stats.beamPush) and sourcePos then
		local enemyPos = getEnemyPosition(enemy)
		local dir = enemyPos and (enemyPos - sourcePos)
		if dir and dir.Magnitude > 0.01 then NpcService.AddImpulse(enemy, dir.Unit * stats.beamPush, "knockback") end
	end
	if stats and tonumber(stats.lifesteal) and stats.lifesteal > 0 then
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then hum.Health = math.min(hum.MaxHealth, hum.Health + applied * stats.lifesteal) end
	end

	if shouldSpawnImpact(plr, tostring(stats and stats.spellId or "Spell"), enemy) then
		local hitPos = impactPos or getEnemyPosition(enemy) or sourcePos
		if hitPos then
			local asset = stats and stats.impactAsset
			if typeof(asset) == "string" and asset ~= "" then
				SpellVisuals.Broadcast("authoredImpact", { pos=hitPos, target=enemy, assetName=asset, stats=SpellVisuals.ExtractStats(stats) })
			else
				SpellVisuals.Broadcast("impact", { pos=hitPos, stats=SpellVisuals.ExtractStats(stats) })
			end
		end
	end
	return applied
end

SpellProjectiles.Configure({
	broadcastProjectile = function(payload)
		local spellId = payload.stats and payload.stats.spellId
		if spellId == "FireBall" or spellId == "GatesOfBabilon" or spellId == "FrozenArsenal" then
			local assetName = spellId == "FireBall" and "FireballVFX" or "GilProjectile"
			payload.assetName = assetName
			SpellVisuals.Broadcast("authoredProjectile", payload)
		else
			SpellVisuals.Broadcast("projectile", payload)
		end
	end,
	extractVisualStats = function(stats)
		local out = SpellVisuals.ExtractStats(stats)
		out.impactRadius = stats.impactRadius
		out.visualScale = stats.visualScale
		return out
	end,
	getEnemiesInRadius = getEnemiesInRadius,
	getEnemyPosition = getEnemyPosition,
	getNearestEnemy = getNearestEnemy,
	hitEnemy = hitEnemy,
	isPaused = isPaused,
	isPlayerRunActive = isPlayerRunActive,
})

SpellSustained.Configure({
	broadcastBeam = function(payload) SpellVisuals.Broadcast("beam", payload) end,
	broadcastRing = function(payload) SpellVisuals.Broadcast("ring", payload) end,
	distancePointToSegment = distancePointToSegment,
	extractVisualStats = SpellVisuals.ExtractStats,
	getAllEnemies = getAllEnemies,
	getDurationMult = getDurationMult,
	getEnemiesInRadius = getEnemiesInRadius,
	getEnemyPosition = getEnemyPosition,
	hitEnemy = hitEnemy,
	isPlayerRunActive = isPlayerRunActive,
	pickPriorityEnemy = pickPriorityEnemy,
	spellClock = spellClock,
})

local function getCastOrigin(hrp) return hrp.Position + Vector3.new(0, 1.2, 0) end

local function fireProjectile(plr, origin, target, stats)
	local targetPos = target and getEnemyPosition(target)
	if not targetPos then return end
	local direction = targetPos - origin
	if direction.Magnitude <= 0.01 then return end
	SpellProjectiles.Fire({
		player=plr, origin=origin, dir=direction.Unit,
		speed=stats.projectileSpeed or 90, range=stats.range or 60,
		damage=stats.damage, pierce=stats.pierce or 0, stats=stats,
		target=target, homing=stats.homing == true, homingTurnRate=stats.homingTurnRate,
	})
end

local function runProjectile(plr, spellId, stats, hrp)
	local s, now = getState(plr), spellClock()
	if now < (s.cds[spellId] or 0) then return end
	local targets = pickPriorityEnemyList(hrp.Position, stats.range or 60, math.max(1, stats.count or 1))
	if #targets == 0 then return end
	s.cds[spellId] = now + ((stats.cooldown or 1) * getCooldownMult(plr))
	local origin = getCastOrigin(hrp)
	local shotCount = math.max(1, stats.count or 1)
	if stats.features and (stats.features.split3 or stats.features.splitRocks or stats.features.burstShards) then shotCount = math.max(shotCount, 3) end
	for index = 1, shotCount do
		local assigned = targets[((index - 1) % #targets) + 1]
		task.delay((index - 1) * 0.05, function()
			if not isPlayerRunActive(plr) then return end
			local target = assigned
			if not target or not enemyAlive(target) then target = pickPriorityEnemy(hrp.Position, stats.range or 60) end
			if target then fireProjectile(plr, origin, target, stats) end
		end)
	end
end

local function runGates(plr, spellId, stats, hrp)
	local s, now = getState(plr), spellClock()
	if now < (s.cds[spellId] or 0) then return end
	local count = math.max(1, math.floor(stats.baseCount or stats.count or 1))
	local targets = pickPriorityEnemyList(hrp.Position, stats.range or 72, count)
	if #targets == 0 then return end
	s.cds[spellId] = now + ((stats.cooldown or 2.5) * getCooldownMult(plr))

	for index = 1, count do
		local target = targets[((index - 1) % #targets) + 1]
		local targetPos = target and getEnemyPosition(target)
		if targetPos then
			local angle = random:NextNumber(0, math.pi * 2)
			local radius = random:NextNumber(0, tonumber(stats.portalRadius) or 5)
			local castPos = hrp.Position + Vector3.new(math.cos(angle) * radius, tonumber(stats.portalHeight) or 5, math.sin(angle) * radius)
			local dir = targetPos - castPos
			if dir.Magnitude > 0.01 then
				local castCFrame = CFrame.lookAt(castPos, targetPos)
				SpellVisuals.Broadcast("authoredCast", { cframe=castCFrame, assetName="GilgameshMain", duration=0.45, stats=SpellVisuals.ExtractStats(stats) })
				task.delay(0.08 + ((index - 1) * 0.04), function()
					if isPlayerRunActive(plr) and target and enemyAlive(target) then fireProjectile(plr, castPos, target, stats) end
				end)
			end
		end
	end
end

local function runOrbit(plr, spellId, stats, hrp, dt)
	local s = getState(plr)
	local bucket = s.orbit[spellId]
	if not bucket then bucket={t=0,lastHit={}}; s.orbit[spellId]=bucket end
	local count = math.max(1, stats.count or stats.baseCount or 1)
	local radius = stats.radius > 0 and stats.radius or stats.baseRadius or 5.5
	local orbitSpeed = stats.orbitSpeed or 2.6
	local hitCooldown = stats.hitCooldown or 0.35
	SpellVisuals.SyncOrbit(s.vfx, plr, spellId, true, { count=count, radius=radius, orbitSpeed=orbitSpeed, height=1.1, size=stats.visualScale or 1, transparency=0.18, color=stats.visualColor, secondaryColor=stats.visualSecondaryColor, element=stats.element, secondaryElement=stats.secondaryElement, attackType=stats.attackType, spellType=stats.spellType, isCombo=stats.isCombo==true, level=stats.level or 1 })
	bucket.t += orbitSpeed * dt
	for index=1,count do
		local angle=bucket.t+(index/count)*math.pi*2
		local pos=hrp.Position+Vector3.new(math.cos(angle)*radius,1.1,math.sin(angle)*radius)
		local enemy=getNearestEnemy(pos,3.25)
		if enemy and enemyAlive(enemy) and spellClock()-(bucket.lastHit[enemy] or 0)>=hitCooldown then
			bucket.lastHit[enemy]=spellClock(); hitEnemy(plr,enemy,stats.damage,stats,pos,pos)
		end
	end
end

local function runNova(plr, spellId, stats, hrp)
	local s,now=getState(plr),spellClock()
	if now < (s.cds[spellId] or 0) then return end
	local center=hrp.Position
	if stats.spawnAtEnemy then
		local target=pickPriorityEnemy(hrp.Position,math.max(45,stats.range or 70))
		local p=target and getEnemyPosition(target)
		if not p then return end
		center=p
	end
	s.cds[spellId]=now+((stats.cooldown or 3)*getCooldownMult(plr))
	local radius=stats.radius or 8
	SpellVisuals.Broadcast("nova",{pos=center,effectPos=center+Vector3.new(0,1,0),dir=hrp.CFrame.LookVector,radius=radius,stats=SpellVisuals.ExtractStats(stats)})
	local repeats=(stats.features and (stats.features.doubleHit or stats.features.secondStrike or stats.features.secondSpearWave or stats.features.secondSpikeWave)) and 2 or 1
	for pass=1,repeats do
		task.delay((pass-1)*0.35,function()
			if not isPlayerRunActive(plr) then return end
			for _,enemy in ipairs(getEnemiesInRadius(center,radius)) do hitEnemy(plr,enemy,stats.damage*(pass==1 and 1 or 0.72),stats,center,getEnemyPosition(enemy)) end
		end)
	end
end

local function groundPoint(position)
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	local result=workspace:Raycast(position+Vector3.new(0,40,0),Vector3.new(0,-120,0),params)
	return result and result.Position or position
end

local function runMovingZoneInstance(plr, stats, startPos, dir, scale)
	scale=scale or 1
	local duration=(stats.duration or 4)*getDurationMult(plr)
	local speed=(stats.moveSpeed or 4)*scale
	local radius=(stats.radius or 7)*scale
	local center=groundPoint(startPos)
	local follow=stats.features and stats.features.follow
	local localStats=table.clone(stats)
	localStats.noBaseEffects=true
	SpellVisuals.Broadcast("authoredMovingZone",{startPos=center,dir=dir,speed=speed,duration=duration,radius=radius,followTarget=follow==true,target=follow and pickPriorityEnemy(center,80) or nil,assetName="TornadoVFX",scale=scale,stats=SpellVisuals.ExtractStats(stats)})
	local endAt=spellClock()+duration
	task.spawn(function()
		local last=spellClock()
		while spellClock()<endAt and isPlayerRunActive(plr) do
			if isPaused() then task.wait(0.1); continue end
			local now=spellClock(); local dt=math.max(0.05,now-last); last=now
			if follow then
				local target=pickPriorityEnemy(center,80); local p=target and getEnemyPosition(target)
				if p then local desired=Vector3.new(p.X-center.X,0,p.Z-center.Z); if desired.Magnitude>0.01 then dir=desired.Unit end end
			end
			center=groundPoint(center+dir*speed*dt)
			for _,enemy in ipairs(getEnemiesInRadius(center,radius)) do
				hitEnemy(plr,enemy,localStats.damage*(stats.tickRate or 0.35),localStats,center,getEnemyPosition(enemy))
				local rank=enemy:GetAttribute("EnemyRank")
				if rank==nil or rank=="Normal" then
					NpcService.AddImpulse(enemy,Vector3.new(0,stats.liftStrength or 12,0),"knockback")
					local ep=getEnemyPosition(enemy); if ep then local inward=center-ep; if inward.Magnitude>0.01 then NpcService.AddImpulse(enemy,inward.Unit*12*(stats.pullStrength or 1),"pull") end end
				else
					NpcService.ApplySlow(enemy,0.28,0.55)
				end
			end
			task.wait(stats.tickRate or 0.35)
		end
	end)
end

local function runMovingZone(plr,spellId,stats,hrp)
	local s,now=getState(plr),spellClock()
	if now<(s.cds[spellId] or 0) then return end
	local target=pickPriorityEnemy(hrp.Position,70); local p=target and getEnemyPosition(target)
	local dir=p and Vector3.new(p.X-hrp.Position.X,0,p.Z-hrp.Position.Z) or Vector3.new(hrp.CFrame.LookVector.X,0,hrp.CFrame.LookVector.Z)
	if dir.Magnitude<=0.01 then dir=Vector3.new(0,0,-1) else dir=dir.Unit end
	s.cds[spellId]=now+((stats.cooldown or 5)*getCooldownMult(plr))
	local offset=Vector3.new(random:NextNumber(-4,4),0,random:NextNumber(-4,4))
	runMovingZoneInstance(plr,stats,hrp.Position+offset,dir,1)
	if stats.features and stats.features.secondTornado then task.delay(0.4,function() if isPlayerRunActive(plr) then runMovingZoneInstance(plr,stats,hrp.Position-offset,dir,0.7) end end) end
end

local function runZone(plr,spellId,stats,hrp)
	local s,now=getState(plr),spellClock(); if now<(s.cds[spellId] or 0) then return end
	s.cds[spellId]=now+((stats.cooldown or 4)*getCooldownMult(plr))
	SpellSustained.RunZone({player=plr,stats=stats,origin=hrp.Position})
end

local function runBeam(plr,spellId,stats,hrp)
	local s,now=getState(plr),spellClock(); if now<(s.cds[spellId] or 0) then return end
	s.cds[spellId]=now+((stats.cooldown or 5)*getCooldownMult(plr))
	SpellSustained.RunBeam({player=plr,stats=stats,origin=getCastOrigin(hrp),targetSearchPosition=hrp.Position,fallbackDirection=hrp.CFrame.LookVector})
	if stats.features and (stats.features.secondRay or stats.features.secondWhip or stats.features.sideStreams or stats.features.secondPass) then
		task.delay(0.18,function() if isPlayerRunActive(plr) then SpellSustained.RunBeam({player=plr,stats=stats,origin=getCastOrigin(hrp),targetSearchPosition=hrp.Position,fallbackDirection=-hrp.CFrame.LookVector}) end end)
	end
end

local function runChain(plr,spellId,stats,hrp)
	local s,now=getState(plr),spellClock(); if now<(s.cds[spellId] or 0) then return end
	local current=pickPriorityEnemy(hrp.Position,stats.range or 60); if not current then return end
	s.cds[spellId]=now+((stats.cooldown or 2.2)*getCooldownMult(plr))
	local visited={}; local origin=getCastOrigin(hrp); local jumps=math.max(1,math.floor(stats.jumpCount or 4))
	for jump=1,jumps do
		if not current or visited[current] or not enemyAlive(current) then break end
		visited[current]=true; local pos=getEnemyPosition(current); if not pos then break end
		SpellVisuals.Broadcast("beam",{origin=origin,dir=(pos-origin).Unit,range=(pos-origin).Magnitude,width=1.1,duration=0.10,stats=SpellVisuals.ExtractStats(stats)})
		local ramp=(stats.features and stats.features.ramp) and (1+((jump-1)*0.12)) or 1
		hitEnemy(plr,current,stats.damage*ramp,stats,origin,pos); origin=pos
		local best,bestDist=nil,stats.chainRange or 16
		for _,candidate in ipairs(getEnemiesInRadius(pos,bestDist)) do
			if not visited[candidate] then local cp=getEnemyPosition(candidate); local d=cp and (cp-pos).Magnitude or math.huge; if d<bestDist then best,bestDist=candidate,d end end
		end
		current=best
	end
end

local function runDash(plr,spellId,stats,hrp)
	local s,now=getState(plr),spellClock(); if now<(s.cds[spellId] or 0) then return end
	local target=pickPriorityEnemy(hrp.Position,45); local p=target and getEnemyPosition(target); if not p then return end
	local dir=Vector3.new(p.X-hrp.Position.X,0,p.Z-hrp.Position.Z); if dir.Magnitude<=0.01 then return end; dir=dir.Unit
	s.cds[spellId]=now+((stats.cooldown or 5)*getCooldownMult(plr))
	local distance=math.min(stats.dashDistance or 15,SpellTargeting.GetUnobstructedDistance(hrp.Position+Vector3.new(0,1,0),dir,stats.dashDistance or 15))
	local start=hrp.Position; local finish=start+dir*distance
	SpellVisuals.Broadcast("beam",{origin=start+Vector3.new(0,1,0),dir=dir,range=distance,width=(stats.trailRadius or 4)*2,duration=0.28,stats=SpellVisuals.ExtractStats(stats)})
	hrp.CFrame=CFrame.lookAt(finish,finish+dir)
	for _,enemy in ipairs(getAllEnemies()) do local ep=getEnemyPosition(enemy); if ep and distancePointToSegment(ep,start,finish)<=(stats.trailRadius or 4) then hitEnemy(plr,enemy,stats.damage,stats,start,ep) end end
	if stats.features and stats.features.explosion then for _,enemy in ipairs(getEnemiesInRadius(finish,7)) do hitEnemy(plr,enemy,stats.damage*0.8,stats,finish,getEnemyPosition(enemy)) end end
end

local function runPillar(plr,spellId,stats,hrp)
	local s,now=getState(plr),spellClock(); if now<(s.cds[spellId] or 0) then return end
	s.cds[spellId]=now+((stats.cooldown or 7)*getCooldownMult(plr))
	local center=groundPoint(hrp.Position+hrp.CFrame.LookVector*4)
	local duration=(stats.duration or 6)*getDurationMult(plr); local radius=stats.radius or 8
	SpellVisuals.Broadcast("ring",{pos=center,radius=radius,duration=duration,stats=SpellVisuals.ExtractStats(stats)})
	local char=plr.Character
	if char then local shield=Instance.new("ForceField"); shield.Name="PillarShield"; shield.Visible=false; shield.Parent=char; Debris:AddItem(shield,stats.shieldDuration or 4) end
	task.spawn(function()
		local endAt=spellClock()+duration
		while spellClock()<endAt and isPlayerRunActive(plr) do
			for _,enemy in ipairs(getEnemiesInRadius(center,radius)) do hitEnemy(plr,enemy,stats.damage,stats,center,getEnemyPosition(enemy)) end
			task.wait(math.max(0.3,stats.tickRate or 1))
		end
		if stats.features and stats.features.shatter and isPlayerRunActive(plr) then for _,enemy in ipairs(getEnemiesInRadius(center,radius*1.2)) do hitEnemy(plr,enemy,stats.damage*2.2,stats,center,getEnemyPosition(enemy)) end end
	end)
end

local function bindDoomDeathCallbacks()
	for _,enemy in ipairs(getAllEnemies()) do
		if not doomBoundEnemies[enemy] then
			doomBoundEnemies[enemy]=true
			NpcService.BindDeath(enemy,function(_,meta)
				local killer=meta and meta.player
				if killer and killer.Parent==Players and (tonumber(killer:GetAttribute("Spell_Doom_Level")) or 0)>0 then
					local stats=SpellDefs.ComputeRuntimeStats("Doom",getSpellState(killer,"Doom"))
					local s=getState(killer); s.doomEnergy += stats and (stats.energyGainMultiplier or 1) or 1
				end
			end)
		end
	end
end

local function isSunExposed(position,exclude)
	local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances=exclude and {exclude} or {}
	local direction=Lighting:GetSunDirection()*1000
	return workspace:Raycast(position+Vector3.new(0,2,0),direction,params)==nil
end

local function runGlobal(plr,spellId,stats,hrp)
	local s,now=getState(plr),spellClock(); if now<(s.cds[spellId] or 0) then return end
	if spellId=="Doom" then
		bindDoomDeathCallbacks()
		if s.doomEnergy < (stats.energyRequired or 16) then return end
		s.doomEnergy=math.max(0,s.doomEnergy-(stats.energyRequired or 16))
		s.cds[spellId]=now+((stats.cooldown or 14)*getCooldownMult(plr))
		local pulses=(stats.features and stats.features.multiPulse) and 3 or 1
		for pulse=1,pulses do task.delay((pulse-1)*0.35,function()
			if not isPlayerRunActive(plr) then return end
			SpellVisuals.Broadcast("nova",{pos=hrp.Position,radius=28,stats=SpellVisuals.ExtractStats(stats)})
			for _,enemy in ipairs(getAllEnemies()) do hitEnemy(plr,enemy,stats.damage*(pulses>1 and 0.48 or 1),stats,hrp.Position,getEnemyPosition(enemy)); NpcService.ApplyFreeze(enemy,stats.fearDuration or 0.8) end
		end) end
		return
	end

	-- Sun Penalty
	s.cds[spellId]=now+((stats.cooldown or 10)*getCooldownMult(plr))
	local duration=(stats.duration or 3)*getDurationMult(plr); local tickRate=stats.tickRate or 0.75; local endAt=spellClock()+duration
	SpellVisuals.Broadcast("nova",{pos=hrp.Position,radius=32,stats=SpellVisuals.ExtractStats(stats)})
	task.spawn(function()
		while spellClock()<endAt and isPlayerRunActive(plr) do
			for _,enemy in ipairs(getAllEnemies()) do
				local ep=getEnemyPosition(enemy); local ignoreShadow=stats.features and stats.features.shadowsIgnore
				if ep and (ignoreShadow or isSunExposed(ep,enemy)) then hitEnemy(plr,enemy,stats.damage*tickRate,stats,ep,ep) end
			end
			local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); local root=char and char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health>0 and isSunExposed(root.Position,char) then hum:TakeDamage(math.max(1,stats.damage*tickRate*0.35)) end
			task.wait(tickRate)
		end
	end)
end

local function stopOrbitIfNeeded(plr,spellId)
	local s=getState(plr)
	if s.vfx[spellId] and s.vfx[spellId].enabled then SpellVisuals.SyncOrbit(s.vfx,plr,spellId,false) end
end
local function stopAllOrbitVfx(plr) SpellVisuals.StopAllOrbits(getState(plr).vfx,plr) end

local function stepPlayer(plr,dt)
	if not isPlayerRunActive(plr) then stopAllOrbitVfx(plr); return end
	if isPaused() then return end
	local char=plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then stopAllOrbitVfx(plr); return end
	for _,spellId in ipairs(SpellDefs.SPELL_ORDER or {}) do
		local spellState=getSpellState(plr,spellId)
		if spellState.level>0 then
			local def=SpellDefs.GetSpell(spellId); local stats=SpellDefs.ComputeRuntimeStats(def,spellState); local archetype=stats and stats.archetype
			if archetype=="Projectile" then runProjectile(plr,spellId,stats,hrp)
			elseif archetype=="Gates" then runGates(plr,spellId,stats,hrp)
			elseif archetype=="Orbit" then runOrbit(plr,spellId,stats,hrp,dt)
			elseif archetype=="Nova" then runNova(plr,spellId,stats,hrp)
			elseif archetype=="MovingZone" then runMovingZone(plr,spellId,stats,hrp)
			elseif archetype=="Zone" then runZone(plr,spellId,stats,hrp)
			elseif archetype=="Beam" then runBeam(plr,spellId,stats,hrp)
			elseif archetype=="Chain" then runChain(plr,spellId,stats,hrp)
			elseif archetype=="Dash" then runDash(plr,spellId,stats,hrp)
			elseif archetype=="Pillar" then runPillar(plr,spellId,stats,hrp)
			elseif archetype=="Global" then runGlobal(plr,spellId,stats,hrp) end
		else
			local def=SpellDefs.GetSpell(spellId); if def and def.attackType=="Orbit" then stopOrbitIfNeeded(plr,spellId) end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	if isPaused() then return end
	for _,plr in ipairs(Players:GetPlayers()) do if isPlayerRunActive(plr) then stepPlayer(plr,dt) else stopAllOrbitVfx(plr) end end
end)

Players.PlayerRemoving:Connect(function(plr) state[plr.UserId]=nil end)

print("[SpellService] Ready (documented spell roster)")
