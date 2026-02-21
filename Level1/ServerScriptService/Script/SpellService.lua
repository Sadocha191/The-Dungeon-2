
-- SpellService.server.lua (Level1/ServerScriptService/Script)
-- Horde-oriented spells + crowd control.
-- Activates spells by player attributes Spell_<id>_Level (set by ProgressService picks).
-- VFX are simple Parts, no external assets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DamageIndicatorEvent = Remotes:WaitForChild("DamageIndicatorEvent")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
local DamageIndicatorEvent = remotesFolder and remotesFolder:FindFirstChild("DamageIndicatorEvent")
if remotesFolder and not DamageIndicatorEvent then
	DamageIndicatorEvent = Instance.new("RemoteEvent")
	DamageIndicatorEvent.Name = "DamageIndicatorEvent"
	DamageIndicatorEvent.Parent = remotesFolder
end

local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = modFolder and require(modFolder:WaitForChild("SpellDefinitions"))

local function getEnemiesRoot()
	return workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Mobs")
end

local vfxRoot = workspace:FindFirstChild("SpellVFX")
if not vfxRoot then
	vfxRoot = Instance.new("Folder")
	vfxRoot.Name = "SpellVFX"
	vfxRoot.Parent = workspace
end

-- ===== Utils =====
local function safeDamage(hum: Humanoid, dmg: number)
	if not hum or hum.Health <= 0 then return end
	dmg = math.floor(tonumber(dmg) or 0)
	if dmg <= 0 then return end
	pcall(function() hum:TakeDamage(dmg) end)
end

local function getEnemyModels()
	local out = {}
	local enemiesRoot = getEnemiesRoot()
	if not enemiesRoot then return out end
	for _, d in ipairs(enemiesRoot:GetDescendants()) do
		if d:IsA("Model") then
			local hum = d:FindFirstChildOfClass("Humanoid")
			local hrp = d:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function getNearestEnemy(pos: Vector3, range: number)
	local best, bestD = nil, range or 9999
	for _, m in ipairs(getEnemyModels()) do
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp then
			local d = (hrp.Position - pos).Magnitude
			if d < bestD then
				bestD = d
				best = m
			end
		end
	end
	return best, bestD
end

local function getEnemiesInRadius(pos: Vector3, radius: number)
	local list = {}
	radius = radius or 10
	local r2 = radius * radius
	for _, m in ipairs(getEnemyModels()) do
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp then
			local d2 = (hrp.Position - pos).Magnitude
			if d2 <= radius then
				table.insert(list, m)
			end
		end
	end
	return list
end

local function applySlow(model: Model, slowPct: number, duration: number)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	slowPct = math.clamp(tonumber(slowPct) or 0, 0, 0.95)
	duration = math.max(0.05, tonumber(duration) or 0.5)

	local now = os.clock()
	local curEnd = hum:GetAttribute("SlowEnd") or 0
	local curPct = hum:GetAttribute("SlowPct") or 0
	local newEnd = math.max(curEnd, now + duration)
	local newPct = math.max(curPct, slowPct)

	hum:SetAttribute("SlowEnd", newEnd)
	hum:SetAttribute("SlowPct", newPct)
end

local function applyFreeze(model: Model, duration: number)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	duration = math.max(0.1, tonumber(duration) or 0.5)
	local now = os.clock()
	local curEnd = hum:GetAttribute("FreezeEnd") or 0
	hum:SetAttribute("FreezeEnd", math.max(curEnd, now + duration))
end

-- Status maintenance: slow/freeze
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, m in ipairs(getEnemyModels()) do
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local base = hum:GetAttribute("BaseWalkSpeed")
			if not base then
				base = hum.WalkSpeed
				hum:SetAttribute("BaseWalkSpeed", base)
			end

			local freezeEnd = hum:GetAttribute("FreezeEnd") or 0
			if freezeEnd > now then
				hum.WalkSpeed = 0
			else
				local slowEnd = hum:GetAttribute("SlowEnd") or 0
				local slowPct = hum:GetAttribute("SlowPct") or 0
				if slowEnd > now and slowPct > 0 then
					hum.WalkSpeed = math.max(2, base * (1 - slowPct))
				else
					hum.WalkSpeed = base
					if slowEnd ~= 0 then
						hum:SetAttribute("SlowEnd", 0)
						hum:SetAttribute("SlowPct", 0)
					end
				end
			end
		end
	end
end)

-- ===== Per-player state =====
local state = {} :: {[number]: any}

local function getState(plr: Player)
	local s = state[plr.UserId]
	if not s then
		s = {
			orbit = {}, -- id -> {parts={...}, lastHit = {[enemy]=t}}
			cds = {},   -- id -> nextFire
			timers = {},-- id -> acc
			cloneDelay = 0.15,
		}
		state[plr.UserId] = s
	end
	return s
end

local function ensurePart(name: string, size: Vector3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = true
	p.CastShadow = false
	p.Size = size
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = vfxRoot
	return p
end

local function getSpellLevel(plr: Player, id: string): number
	return tonumber(plr:GetAttribute("Spell_"..id.."_Level")) or 0
end

local function getAtkMult(plr: Player): number
	return tonumber(plr:GetAttribute("RunAtkMult")) or 1
end

local function projHitDamage(plr: Player, enemy: Model, dmg: number, opts)
	opts = opts or {}
	local hum = enemy and enemy:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- Soul Link (spell-only): splash dmg from anchor
	if enemy:GetAttribute("SoulLinkAnchor") then
		local linkPct = tonumber(plr:GetAttribute("SoulLinkPct")) or 0
		local linkRadius = tonumber(plr:GetAttribute("SoulLinkRadius")) or 0
		if linkPct > 0 and linkRadius > 0 then
			for _, other in ipairs(getEnemiesInRadius(enemy.HumanoidRootPart.Position, linkRadius)) do
				if other ~= enemy then
					local oh = other:FindFirstChildOfClass("Humanoid")
					if oh then
						safeDamage(oh, dmg * linkPct)
					end
				end
			end
		end
	end
	local dealt = math.floor(tonumber(dmg) or 0)
	if dealt > 0 then
		safeDamage(hum, dealt)
		if opts.showFloating ~= false then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			if hrp then
				DamageIndicatorEvent:FireAllClients({ pos = hrp.Position, amount = dealt, crit = opts.crit == true })
			end
		end
	end

	if opts.slowPct then
		applySlow(enemy, opts.slowPct, opts.slowDuration or 1)
	end
	if opts.freezeChance and (math.random() < opts.freezeChance) then
		applyFreeze(enemy, opts.freezeDuration or 0.8)
	end
	if opts.burnDps and opts.burnDuration then
		local endT = os.clock() + opts.burnDuration
		task.spawn(function()
			while os.clock() < endT and hum.Health > 0 do
				safeDamage(hum, opts.burnDps * 0.5) -- tick 0.5s
				task.wait(0.5)
			end
		end)
	end
	if opts.poisonDps and opts.poisonDuration then
		local endT = os.clock() + opts.poisonDuration
		task.spawn(function()
			while os.clock() < endT and hum.Health > 0 do
				safeDamage(hum, opts.poisonDps * 0.5)
				task.wait(0.5)
			end
		end)
	end
end

local function fireProjectile(plr: Player, origin: Vector3, dir: Vector3, speed: number, range: number, dmg: number, pierce: number, opts)
	local s = getState(plr)
	local cloneLv = getSpellLevel(plr, "PhantomClone")
	local copyPct = 0
	if cloneLv > 0 then
		copyPct = ({0.35,0.45,0.45,0.60,0.35,0.90})[math.clamp(cloneLv,1,6)] or 0.35
	end

	local function spawnOne(mult: number)
		local p = ensurePart("Proj", Vector3.new(0.6,0.6,0.6))
		p.CFrame = CFrame.new(origin)
		p.Transparency = 0.3
		local traveled = 0
		local hit = {}
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not p.Parent then conn:Disconnect() return end
			local step = speed * dt
			traveled += step
			p.CFrame = p.CFrame + (dir * step)
			if traveled >= range then
				conn:Disconnect()
				p:Destroy()
				return
			end
			-- cheap hit test: nearest enemy within 2 studs of projectile
			local nearest, d = getNearestEnemy(p.Position, 3)
			if nearest and nearest:FindFirstChild("HumanoidRootPart") then
				local hrp = nearest.HumanoidRootPart
				if (hrp.Position - p.Position).Magnitude <= 2.5 then
					if not hit[nearest] then
						hit[nearest] = true
						projHitDamage(plr, nearest, dmg * mult, opts)
						if pierce <= 0 then
							conn:Disconnect()
							p:Destroy()
							return
						else
							pierce -= 1
						end
					end
				end
			end
		end)
		Debris:AddItem(p, 5)
	end

	spawnOne(1)

	if cloneLv > 0 and copyPct > 0 then
		task.delay(s.cloneDelay, function()
			if plr.Parent then
				spawnOne(copyPct)
			end
		end)
	end
end

-- ===== Spell implementations (best-effort, gameplay first) =====
local function tickOrbit(plr: Player, dt: number, id: string, count: number, radius: number, orbitSpeed: number, hitCd: number, baseDmg: number, onHit)
	local s = getState(plr)
	local bucket = s.orbit[id]
	if not bucket then
		bucket = { parts = {}, lastHit = {} }
		s.orbit[id] = bucket
	end

	-- ensure parts
	while #bucket.parts < count do
		local p = ensurePart(id.."_Orb", Vector3.new(1.2,1.2,1.2))
		p.Transparency = 0.25
		table.insert(bucket.parts, p)
	end
	while #bucket.parts > count do
		local p = table.remove(bucket.parts)
		p:Destroy()
	end

	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	bucket.t = (bucket.t or 0) + orbitSpeed * (dt or 0.016)

	local t0 = bucket.t
	for i, p in ipairs(bucket.parts) do
		local ang = t0 + (i / math.max(1, count)) * math.pi * 2
		local pos = hrp.Position + Vector3.new(math.cos(ang), 0.5, math.sin(ang)) * radius
		p.Position = pos

		local nearest, d = getNearestEnemy(pos, 3)
		if nearest then
			local hum = nearest:FindFirstChildOfClass("Humanoid")
			if hum then
				local key = nearest
				local last = bucket.lastHit[key] or 0
				if os.clock() - last >= hitCd then
					bucket.lastHit[key] = os.clock()
					safeDamage(hum, baseDmg * getAtkMult(plr))
					if onHit then onHit(nearest) end
				end
			end
		end
	end
end

local function spawnZone(pos: Vector3, radius: number, duration: number)
	local p = ensurePart("Zone", Vector3.new(radius*2, 0.4, radius*2))
	p.Position = pos + Vector3.new(0, 0.2, 0)
	p.Transparency = 0.6
	p.Shape = Enum.PartType.Cylinder
	p.Orientation = Vector3.new(0,0,90)
	Debris:AddItem(p, duration)
	return p
end

local function pulseAt(plr: Player, pos: Vector3, radius: number, dmg: number, opts)
	for _, enemy in ipairs(getEnemiesInRadius(pos, radius)) do
		projHitDamage(plr, enemy, dmg * getAtkMult(plr), opts)
	end
end

-- ===== Main loop per player =====
local function stepPlayer(plr: Player, dt: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local pos = hrp.Position
	local s = getState(plr)

	-- COMMON: Fire Orb
	local lv = getSpellLevel(plr, "FireOrb")
	if lv > 0 then
		local count = (lv >= 6 and 3) or (lv >= 3 and 2) or 1
		local dmg = 10 + (lv * 4)
		local radius = 5 * (lv >= 4 and 1.10 or 1.0)
		local hitCd = 0.25
		local burn = (lv >= 5)
		local burnDps = (lv >= 6 and 8 or 4)
		local burnDur = 2.0
		tickOrbit(plr, dt, "FireOrb", count, radius, 2.6, hitCd, dmg, function(enemy)
			if burn then
				applySlow(enemy, 0.05, 0.5)
				local hum = enemy:FindFirstChildOfClass("Humanoid")
				if hum then
					local endT = os.clock() + burnDur
					task.spawn(function()
						while os.clock() < endT and hum.Health > 0 do
							safeDamage(hum, burnDps)
							task.wait(0.5)
						end
					end)
				end
			end
		end)
	end

	-- COMMON: Wind Blades
	lv = getSpellLevel(plr, "WindBlades")
	if lv > 0 then
		local count = (lv >= 3 and 2) or 1
		local dmg = 8 + (lv * 3)
		local radius = 8 * (lv >= 4 and 1.15 or 1.0)
		local speed = 2.2 * (1 + ((lv==2 and 0.10) or (lv>=6 and 0.30) or 0))
		local hitCd = 0.35
		local knock = (lv >= 5)
		tickOrbit(plr, dt, "WindBlades", count, radius, speed, hitCd, dmg, function(enemy)
			if knock and enemy:FindFirstChild("HumanoidRootPart") then
				local epos = enemy.HumanoidRootPart.Position
				local dir = (epos - pos).Unit
				enemy.HumanoidRootPart.AssemblyLinearVelocity += dir * 12
			end
		end)
	end

	-- UNCOMMON: Toxic Blades
	lv = getSpellLevel(plr, "ToxicBlades")
	if lv > 0 then
		local count = math.clamp(1 + lv, 2, 6)
		local dmg = 7 + (lv * 2)
		local radius = 7
		local speed = 2.2
		local hitCd = 0.35
		local poisonDps = 3 + (lv * 2)
		local poisonDur = 2.5
		tickOrbit(plr, dt, "ToxicBlades", count, radius, speed, hitCd, dmg, function(enemy)
			applySlow(enemy, 0.10, 0.6)
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			if hum then
				local endT = os.clock() + poisonDur
				task.spawn(function()
					while os.clock() < endT and hum.Health > 0 do
						safeDamage(hum, poisonDps)
						task.wait(0.5)
					end
				end)
			end
		end)
	end

	-- COMMON: Shadow Dagger
	lv = getSpellLevel(plr, "ShadowDagger")
	if lv > 0 then
		local cd = 0.8 * (lv >= 2 and 0.9 or 1)
		if lv >= 2 then cd = cd * (0.9 ^ (lv-1)) end
		local nextT = s.cds.ShadowDagger or 0
		if os.clock() >= nextT then
			s.cds.ShadowDagger = os.clock() + cd
			local target = getNearestEnemy(pos, 40)
			if target and target:FindFirstChild("HumanoidRootPart") then
				local dir = (target.HumanoidRootPart.Position - pos).Unit
				local knives = (lv >= 3 and 2) or 1
				for k=1,knives do
					task.delay((k-1)*0.1, function()
						local dmg = 14 + (lv*4)
						local critChance = (lv >= 5 and 0.10) or 0
						local mult = 1
						if critChance > 0 and math.random() < critChance then
							mult = 1.8
						end
						local pierce = (lv >= 6 and 2) or 0
						fireProjectile(plr, pos + Vector3.new(0,2,0), dir, 85, 50, dmg*mult, pierce, { crit = mult > 1 })
					end)
				end
			end
		end
	end

	-- COMMON: Bone Spear
	lv = getSpellLevel(plr, "BoneSpear")
	if lv > 0 then
		local cd = 1.4
		local nextT = s.cds.BoneSpear or 0
		if os.clock() >= nextT then
			s.cds.BoneSpear = os.clock() + cd
			local target = getNearestEnemy(pos, 60)
			if target and target:FindFirstChild("HumanoidRootPart") then
				local dir0 = (target.HumanoidRootPart.Position - pos).Unit
				local spears = (lv >= 6 and 3) or (lv >= 3 and 2) or 1
				local pierce = (lv >= 6 and 5) or (lv >= 4 and 3) or (lv >= 1 and 2) or 1
				for i=1,spears do
					local ang = math.rad((math.random()*2-1) * (lv>=1 and 8 or 5))
					local dir = (CFrame.fromAxisAngle(Vector3.new(0,1,0), ang) * dir0)
					local dmg = 18 + (lv*6)
					local speed = 95 * (lv >= 5 and 1.2 or 1.0)
					fireProjectile(plr, pos + Vector3.new(0,2,0), dir, speed, 70, dmg, pierce, {})
				end
			end
		end
	end

	-- COMMON: Ice Shards
	lv = getSpellLevel(plr, "IceShards")
	if lv > 0 then
		local cd = 2.0
		local nextT = s.cds.IceShards or 0
		if os.clock() >= nextT then
			s.cds.IceShards = os.clock() + cd
			local count = (lv >= 6 and 5) or (lv >= 3 and 3) or 2
			local impactR = 5 * (lv >= 2 and 1.15 or 1.0)
			local slowPct = 0.25
			local slowDur = 1.2 + (lv>=4 and 0.5 or 0)
			local freezeChance = (lv >= 6 and 0.20) or (lv >= 5 and 0.10) or 0
			for i=1,count do
				local r = 6 + math.random()*12
				local ang = math.random()*math.pi*2
				local p = pos + Vector3.new(math.cos(ang)*r, 0, math.sin(ang)*r)
				task.delay(0.25 + i*0.03, function()
					pulseAt(plr, p, impactR, 18 + lv*5, {slowPct=slowPct, slowDuration=slowDur, freezeChance=freezeChance, freezeDuration=0.9})
				end)
			end
		end
	end

	-- COMMON: Poison Cloud
	lv = getSpellLevel(plr, "PoisonCloud")
	if lv > 0 then
		local interval = 2.5
		local nextT = s.cds.PoisonCloud or 0
		if os.clock() >= nextT then
			s.cds.PoisonCloud = os.clock() + interval
			local radius = 7 * (lv >= 2 and 1.15 or 1.0)
			local dur = (2.5 + (lv>=3 and 1 or 0))
			local tick = (lv>=4 and 0.4 or 0.5)
			local dps = 8 + lv*3
			local cloud = spawnZone(pos - hrp.CFrame.LookVector*3, radius, dur)
			local endT = os.clock() + dur
			task.spawn(function()
				while os.clock() < endT and cloud.Parent do
					for _, enemy in ipairs(getEnemiesInRadius(cloud.Position, radius)) do
						projHitDamage(plr, enemy, dps*tick, {poisonDps=0, poisonDuration=0})
					end
					task.wait(tick)
				end
			end)
		end
	end

	-- COMMON: Flame Trail
	lv = getSpellLevel(plr, "FlameTrail")
	if lv > 0 then
		local every = 0.35
		s.timers.FlameTrail = (s.timers.FlameTrail or 0) + dt
		if s.timers.FlameTrail >= every then
			s.timers.FlameTrail = 0
			local dur = (lv>=3 and 3.0) or 2.0
			local tick = (lv>=4 and 0.4) or 0.5
			local size = 5 * (lv>=2 and 1.10 or 1.0)
			local zone = spawnZone(pos, size/2, dur)
			local dps = 10 + lv*4
			local endT = os.clock() + dur
			task.spawn(function()
				while os.clock() < endT and zone.Parent do
					for _, enemy in ipairs(getEnemiesInRadius(zone.Position, size/2)) do
						projHitDamage(plr, enemy, dps*tick, {burnDps=0,burnDuration=0})
					end
					task.wait(tick)
				end
			end)
		end
	end

	-- UNCOMMON: Lightning Chain
	lv = getSpellLevel(plr, "LightningChain")
	if lv > 0 then
		local cd = 1.8
		local nextT = s.cds.LightningChain or 0
		if os.clock() >= nextT then
			s.cds.LightningChain = os.clock() + cd
			local start = getNearestEnemy(pos, 55)
			if start and start:FindFirstChild("HumanoidRootPart") then
				local jumps = (lv >= 6 and 6) or (lv >= 3 and 4) or 3
				local jumpR = 12 * (lv>=4 and 1.2 or 1.0)
				local dmg = 20 + lv*6
				local stun = (lv >= 5) and ((lv>=6 and 0.5) or 0.3) or 0
				local hit = {}
				local cur = start
				for j=1,jumps do
					if not cur then break end
					hit[cur] = true
					projHitDamage(plr, cur, dmg, { })
					if stun > 0 then
						applyFreeze(cur, stun)
				 end
					-- next
					local best=nil
					local bestD=jumpR
					local cpos = cur.HumanoidRootPart.Position
					for _, e in ipairs(getEnemyModels()) do
						if not hit[e] and e:FindFirstChild("HumanoidRootPart") then
							local d = (e.HumanoidRootPart.Position - cpos).Magnitude
							if d < bestD then bestD=d best=e end
						end
					end
					cur = best
				end
			end
		end
	end

	-- UNCOMMON: Frost Nova
	lv = getSpellLevel(plr, "FrostNova")
	if lv > 0 then
		local cd = 6.0 * (lv>=3 and 0.9 or 1.0)
		local nextT = s.cds.FrostNova or 0
		if os.clock() >= nextT then
			s.cds.FrostNova = os.clock() + cd
			local radius = (10 * (lv>=2 and 1.15 or 1.0)) * (lv>=6 and 1.15 or 1.0)
			local slowPct = 0.35
			local slowDur = 1.5
			local freezeChance = (lv>=6 and 0.25) or (lv>=4 and 0.10) or 0
			local freezeDur = (lv>=5 and 1.0) or 0.8
			pulseAt(plr, pos, radius, 0, {slowPct=slowPct, slowDuration=slowDur, freezeChance=freezeChance, freezeDuration=freezeDur})
		end
	end

	-- UNCOMMON: Gravity Pulse
	lv = getSpellLevel(plr, "GravityPulse")
	if lv > 0 then
		local cd = 5.0 * (lv>=4 and 0.9 or 1.0)
		local nextT = s.cds.GravityPulse or 0
		if os.clock() >= nextT then
			s.cds.GravityPulse = os.clock() + cd
			local radius = (lv>=6 and 14) or (lv>=1 and 10)
			local force = 40 * (lv>=2 and 1.2 or 1.0)
			local dmg = 22 + lv*6
			local pull = (lv>=5) and ((lv>=6 and 0.6) or 0.3) or 0
			for _, e in ipairs(getEnemiesInRadius(pos, radius)) do
				if e:FindFirstChild("HumanoidRootPart") then
					local dir = (e.HumanoidRootPart.Position - pos)
					if dir.Magnitude < 0.1 then dir = Vector3.new(1,0,0) end
					dir = dir.Unit
					local vel = e.HumanoidRootPart.AssemblyLinearVelocity
					if pull > 0 then
						e.HumanoidRootPart.AssemblyLinearVelocity = vel - dir*force
						applySlow(e, 0.25, pull)
					else
						e.HumanoidRootPart.AssemblyLinearVelocity = vel + dir*force
					end
					projHitDamage(plr, e, dmg, {})
				end
			end
		end
	end

	-- UNCOMMON: Arcane Missile
	lv = getSpellLevel(plr, "ArcaneMissile")
	if lv > 0 then
		local cd = 2.2
		local nextT = s.cds.ArcaneMissile or 0
		if os.clock() >= nextT then
			s.cds.ArcaneMissile = os.clock() + cd
			local count = (lv>=6 and 5) or (lv>=3 and 3) or 2
			local range = 60
			local speed = 75 * (lv>=2 and 1.15 or 1.0)
			local dmg = 16 + lv*6
			local impactR = (lv>=5 and 4) or 0
			local enemies = getEnemyModels()
			table.sort(enemies, function(a,b)
				return (a.HumanoidRootPart.Position - pos).Magnitude < (b.HumanoidRootPart.Position - pos).Magnitude
			end)
			for i=1,count do
				local t = enemies[i]
				if t and t:FindFirstChild("HumanoidRootPart") then
					local dir = (t.HumanoidRootPart.Position - pos).Unit
					fireProjectile(plr, pos + Vector3.new(0,2,0), dir, speed, range, dmg, 0, { })
					if impactR > 0 then
						task.delay(0.15 + i*0.05, function()
							pulseAt(plr, t.HumanoidRootPart.Position, impactR, dmg*0.6, {})
						end)
					end
				end
			end
		end
	end

	-- UNCOMMON: Crystal Barrage
	lv = getSpellLevel(plr, "CrystalBarrage")
	if lv > 0 then
		local cd = 2.6
		local nextT = s.cds.CrystalBarrage or 0
		if os.clock() >= nextT then
			s.cds.CrystalBarrage = os.clock() + cd
			local target = getNearestEnemy(pos, 55)
			if target and target:FindFirstChild("HumanoidRootPart") then
				local dir0 = (target.HumanoidRootPart.Position - pos).Unit
				local shards = (lv>=6 and 10) or (lv>=3 and 7) or 5
				local cone = math.rad(28)
				local dmg = 10 + lv*4
				local speed = 90
				local impactR = (lv>=4 and 3.5) or 0
				for i=1,shards do
					local ang = (math.random()-0.5) * cone
					local dir = (CFrame.fromAxisAngle(Vector3.new(0,1,0), ang) * dir0)
					fireProjectile(plr, pos + Vector3.new(0,2,0), dir, speed, 60, dmg, 0, {})
					if impactR > 0 then
						task.delay(0.10, function()
							-- handled by projectile hit test; simple extra AoE not perfect
						end)
					end
				end
			end
		end
	end

	-- UNCOMMON: Chain Hooks
	lv = getSpellLevel(plr, "ChainHooks")
	if lv > 0 then
		local cd = 4.0
		local nextT = s.cds.ChainHooks or 0
		if os.clock() >= nextT then
			s.cds.ChainHooks = os.clock() + cd
			local hooks = (lv>=3 and 2) or 1
			local range = 35 * (lv>=2 and 1.15 or 1.0)
			local force = 60 * (lv>=4 and 1.2 or 1.0)
			local stun = (lv>=5 and 0.3) or 0
			local enemies = getEnemyModels()
			table.sort(enemies, function(a,b)
				return (a.HumanoidRootPart.Position - pos).Magnitude < (b.HumanoidRootPart.Position - pos).Magnitude
			end)
			local pulled = 0
			for _, e in ipairs(enemies) do
				if pulled >= hooks then break end
				local hrpE = e:FindFirstChild("HumanoidRootPart")
				if hrpE and (hrpE.Position - pos).Magnitude <= range then
					local dir = (pos - hrpE.Position).Unit
					hrpE.AssemblyLinearVelocity += dir * force
					if stun>0 then applyFreeze(e, stun) end
					pulled += 1
				end
			end
		end
	end

	-- UNCOMMON: Ice Wall (path block in 3D: simple collision wall)
	lv = getSpellLevel(plr, "IceWall")
	if lv > 0 then
		local cd = 8.0
		local nextT = s.cds.IceWall or 0
		if os.clock() >= nextT then
			s.cds.IceWall = os.clock() + cd
			local count = (lv>=3 and 2) or 1
			local dur = (lv>=6 and 6) or (lv>=4 and 4) or 3
			local size = Vector3.new(10, 8, 1.2)
			for i=1,count do
				local ang = math.random()*math.pi*2
				local dist = 6 + math.random()*4
				local p = ensurePart("IceWall", size)
				p.Transparency = 0.4
				p.CanCollide = true
				p.Position = pos + Vector3.new(math.cos(ang)*dist, 4, math.sin(ang)*dist)
				p.Orientation = Vector3.new(0, math.deg(ang), 0)
				Debris:AddItem(p, dur)
			end
		end
	end

	-- RARE: Thunder Totem
	lv = getSpellLevel(plr, "ThunderTotem")
	if lv > 0 then
		local cd = 10.0
		local nextT = s.cds.ThunderTotem or 0
		if os.clock() >= nextT then
			s.cds.ThunderTotem = os.clock() + cd
			local totems = (lv>=6 and 2) or 1
			local dur = 10 + (lv>=3 and 2 or 0)
			local range = 45
			local fireRate = 0.9 * (lv>=2 and 0.9 or 1.0)
			local baseDmg = 20 + lv*8
			local chainJumps = (lv>=5 and 1) or 0
			for i=1,totems do
				local t = ensurePart("Totem", Vector3.new(1.2,4,1.2))
				t.Position = pos + Vector3.new((i-1)*2,2,0)
				t.Transparency = 0.2
				local endT = os.clock() + dur
				task.spawn(function()
					while os.clock() < endT and t.Parent do
						local target = getNearestEnemy(t.Position, range)
						if target and target:FindFirstChild("HumanoidRootPart") then
							projHitDamage(plr, target, baseDmg*getAtkMult(plr), {})
							if chainJumps > 0 then
								-- one extra jump
								local next = nil
								local bestD = 12
								local cpos = target.HumanoidRootPart.Position
								for _, e in ipairs(getEnemyModels()) do
									if e ~= target and e:FindFirstChild("HumanoidRootPart") then
										local d = (e.HumanoidRootPart.Position - cpos).Magnitude
										if d < bestD then bestD = d next = e end
									end
								end
								if next then projHitDamage(plr, next, baseDmg*0.7*getAtkMult(plr), {}) end
							end
						end
						task.wait(fireRate)
					end
					if t.Parent then t:Destroy() end
				end)
				Debris:AddItem(t, dur+0.5)
			end
		end
	end

	-- RARE: Spirit Wolves (simple orbit + dash bite)
	lv = getSpellLevel(plr, "SpiritWolves")
	if lv > 0 then
		-- lightweight: treated as orbiting hitboxes that occasionally dash to nearest target
		local count = (lv>=6 and 3) or (lv>=3 and 2) or 1
		local dmg = 18 + lv*6
		local hitCd = 1.0 * (lv>=2 and 0.9 or 1.0)
		tickOrbit(plr, dt, "SpiritWolves", count, 9, 1.6, hitCd, dmg, function(enemy)
			applySlow(enemy, 0.15, 0.8)
		end)
	end

	-- RARE: Necro Swarm (homing skulls)
	lv = getSpellLevel(plr, "NecroSwarm")
	if lv > 0 then
		local interval = 1.6
		local nextT = s.cds.NecroSwarm or 0
		if os.clock() >= nextT then
			s.cds.NecroSwarm = os.clock() + interval
			local count = (lv>=6 and 3) or (lv>=3 and 2) or 1
			local speed = 55 * (lv>=2 and 1.15 or 1.0)
			local dmg = 22 + lv*7
			local aoe = 6 * (lv>=4 and 1.15 or 1.0)
			for i=1,count do
				local skull = ensurePart("Skull", Vector3.new(0.9,0.9,0.9))
				skull.Position = pos + Vector3.new(0,2,0)
				skull.Transparency = 0.2
				local target = getNearestEnemy(pos, 70)
				local life = 3.2
				task.spawn(function()
					local t0 = os.clock()
					while os.clock() - t0 < life and skull.Parent do
						local t = target
						if not t or not t:FindFirstChild("HumanoidRootPart") or t:FindFirstChildOfClass("Humanoid").Health <= 0 then
							t = getNearestEnemy(skull.Position, 70)
							target = t
						end
						if t and t:FindFirstChild("HumanoidRootPart") then
							local dir = (t.HumanoidRootPart.Position - skull.Position).Unit
							skull.Position = skull.Position + dir * speed * RunService.Heartbeat:Wait()
							if (t.HumanoidRootPart.Position - skull.Position).Magnitude <= 3 then
								pulseAt(plr, skull.Position, aoe, dmg, {})
								skull:Destroy()
								return
							end
						else
							skull.Position = skull.Position + Vector3.new(0,0,1) * speed * RunService.Heartbeat:Wait()
						end
					end
					if skull.Parent then skull:Destroy() end
				end)
				Debris:AddItem(skull, life+1)
			end
		end
	end

	-- RARE: Arcane Mine
	lv = getSpellLevel(plr, "ArcaneMine")
	if lv > 0 then
		local interval = 3.5
		local nextT = s.cds.ArcaneMine or 0
		if os.clock() >= nextT then
			s.cds.ArcaneMine = os.clock() + interval
			local mines = (lv>=6 and 5) or (lv>=3 and 3) or 2
			local arm = 0.3
			local trig = 4
			local aoe = 7 * (lv>=4 and 1.15 or 1.0)
			local dmg = 30 + lv*10
			for i=1,mines do
				local r = 6 + math.random()*8
				local ang = math.random()*math.pi*2
				local mpos = pos + Vector3.new(math.cos(ang)*r, 0.2, math.sin(ang)*r)
				local mine = ensurePart("Mine", Vector3.new(1.2,0.6,1.2))
				mine.Position = mpos
				mine.Transparency = 0.2
				local armed = false
				task.delay(arm, function() armed = true end)
				local maxLife = 5
				task.spawn(function()
					local t0 = os.clock()
					while os.clock() - t0 < maxLife and mine.Parent do
						if armed then
							local e = getNearestEnemy(mine.Position, trig)
							if e then
								pulseAt(plr, mine.Position, aoe, dmg, {})
								mine:Destroy()
								return
							end
						end
						task.wait(0.1)
					end
					if mine.Parent then mine:Destroy() end
				end)
				Debris:AddItem(mine, maxLife+1)
			end
		end
	end

	-- RARE: Dark Rift
	lv = getSpellLevel(plr, "DarkRift")
	if lv > 0 then
		local interval = 7.0
		local nextT = s.cds.DarkRift or 0
		if os.clock() >= nextT then
			s.cds.DarkRift = os.clock() + interval
			local count = (lv>=6 and 2) or 1
			local radius = 10 * (lv>=2 and 1.15 or 1.0)
			local dur = 4 + (lv>=3 and 1 or 0)
			local tick = (lv>=5 and 0.35) or 0.5
			local pull = 70 * (lv>=4 and 1.2 or 1.0)
			local dmg = 16 + lv*6
			for i=1,count do
				local ang = math.random()*math.pi*2
				local r = 8 + math.random()*8
				local rpos = pos + Vector3.new(math.cos(ang)*r,0,math.sin(ang)*r)
				local zone = spawnZone(rpos, radius, dur)
				local endT = os.clock() + dur
				task.spawn(function()
					while os.clock() < endT and zone.Parent do
						for _, e in ipairs(getEnemiesInRadius(zone.Position, radius)) do
							if e:FindFirstChild("HumanoidRootPart") then
								local dir = (zone.Position - e.HumanoidRootPart.Position).Unit
								e.HumanoidRootPart.AssemblyLinearVelocity += dir * pull * tick
								projHitDamage(plr, e, dmg, {})
							end
						end
						task.wait(tick)
					end
				end)
			end
		end
	end

	-- RARE: Meteor Strike
	lv = getSpellLevel(plr, "MeteorStrike")
	if lv > 0 then
		local interval = 4.5 * (lv>=4 and 0.9 or 1.0)
		local nextT = s.cds.MeteorStrike or 0
		if os.clock() >= nextT then
			s.cds.MeteorStrike = os.clock() + interval
			local count = (lv>=6 and 3) or (lv>=3 and 2) or 1
			local aoe = 10 * (lv>=2 and 1.15 or 1.0)
			local dmg = 50 + lv*16
			for i=1,count do
				local r = 10 + math.random()*15
				local ang = math.random()*math.pi*2
				local p = pos + Vector3.new(math.cos(ang)*r,0,math.sin(ang)*r)
				task.delay(0.6, function()
					pulseAt(plr, p, aoe, dmg, {})
					if lv>=5 then
						-- fire pool 2s
						local pool = spawnZone(p, aoe*0.7, 2)
						local endT = os.clock()+2
						task.spawn(function()
							while os.clock()<endT and pool.Parent do
								for _, e in ipairs(getEnemiesInRadius(pool.Position, aoe*0.7)) do
									projHitDamage(plr, e, 12*0.5, {})
								end
								task.wait(0.5)
							end
						end)
					end
				end)
			end
		end
	end

	-- RARE: Solar Beam
	lv = getSpellLevel(plr, "SolarBeam")
	if lv > 0 then
		local interval = 6.5
		local nextT = s.cds.SolarBeam or 0
		if os.clock() >= nextT then
			s.cds.SolarBeam = os.clock() + interval
			local dur = (lv>=6 and 2.2) or (lv>=3 and 1.6) or 1.2
			local range = (lv>=6 and 90) or 70
			local tick = 0.2
			local dmg = (22 + lv*9)
			local burn = (lv>=5)
			local target = getNearestEnemy(pos, 70)
			if target and target:FindFirstChild("HumanoidRootPart") then
				local dir = (target.HumanoidRootPart.Position - pos).Unit
				local t0 = os.clock()
				while os.clock()-t0 < dur do
					-- damage all enemies close to beam line (cheap)
					for _, e in ipairs(getEnemyModels()) do
						local hrpE = e:FindFirstChild("HumanoidRootPart")
						if hrpE then
							local rel = hrpE.Position - pos
							local proj = rel:Dot(dir)
							if proj > 0 and proj < range then
								local closest = (pos + dir*proj)
								local dist = (hrpE.Position - closest).Magnitude
								local width = (lv>=4 and 4) or 3
								if dist <= width then
									projHitDamage(plr, e, dmg*tick, {burnDps = burn and 6 or nil, burnDuration = burn and 2 or nil})
								end
							end
						end
					end
					task.wait(tick)
				end
			end
		end
	end

	-- EPIC: Void Ring
	lv = getSpellLevel(plr, "VoidRing")
	if lv > 0 then
		local interval = 5.5
		local nextT = s.cds.VoidRing or 0
		if os.clock() >= nextT then
			s.cds.VoidRing = os.clock() + interval
			local endR = 18 * (lv>=2 and 1.15 or 1.0)
			local dmg = 40 + lv*14
			local pull = (lv>=5 and 30) or 0
			local waves = (lv>=6 and 3) or (lv>=3 and 2) or 1
			for w=1,waves do
				task.delay((w-1)*0.25, function()
					local r = 2
					while r <= endR do
						-- hit enemies near ring
						for _, e in ipairs(getEnemiesInRadius(pos, r+3)) do
							if e:FindFirstChild("HumanoidRootPart") then
								local d = (e.HumanoidRootPart.Position - pos).Magnitude
								if math.abs(d - r) <= 2.2 then
									projHitDamage(plr, e, dmg*0.12, {})
									if pull > 0 then
										local dir = (pos - e.HumanoidRootPart.Position).Unit
										e.HumanoidRootPart.AssemblyLinearVelocity += dir * pull
									end
								end
							end
						end
						r += 2
						task.wait(0.05)
					end
				end)
			end
		end
	end

	-- EPIC: Blood Nova
	lv = getSpellLevel(plr, "BloodNova")
	if lv > 0 then
		local interval = 7.0 * (lv>=3 and 0.9 or 1.0)
		local nextT = s.cds.BloodNova or 0
		if os.clock() >= nextT then
			s.cds.BloodNova = os.clock() + interval
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				local hpPct = hum.Health / math.max(1, hum.MaxHealth)
				local missing = (1 - hpPct)
				local base = 35 + lv*12
				local mult = 80 * (lv>=6 and 1.25 or 1.0)
				local radius = 12 * (lv>=2 and 1.15 or 1.0)
				local dmg = base + missing*mult
				pulseAt(plr, pos, radius, dmg, {})
				if lv>=4 then
					local lifesteal = (lv>=6 and 0.10) or 0.05
					local healed = math.floor(dmg * lifesteal)
					hum.Health = math.min(hum.MaxHealth, hum.Health + healed)
				end
			end
		end
	end

	-- EPIC: Rage Pulse (buff helper used by SpellService only)
	lv = getSpellLevel(plr, "RagePulse")
	if lv > 0 then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local hpPct = hum.Health / math.max(1, hum.MaxHealth)
			local maxBonus = ({0.20,0.30,0.30,0.30,0.30,0.50})[math.clamp(lv,1,6)] or 0.20
			local bonus = (0.05 + (1-hpPct) * (maxBonus-0.05))
			plr:SetAttribute("SpellDamageMult", 1 + bonus)
		end
	else
		if plr:GetAttribute("SpellDamageMult") then
			plr:SetAttribute("SpellDamageMult", nil)
		end
	end

	-- EPIC: Time Fracture
	lv = getSpellLevel(plr, "TimeFracture")
	if lv > 0 then
		local interval = 10
		local nextT = s.cds.TimeFracture or 0
		if os.clock() >= nextT then
			s.cds.TimeFracture = os.clock() + interval
			local radius = 14 * (lv>=2 and 1.15 or 1.0)
			local dur = (lv>=6 and 5) or (lv>=4 and 4) or 3
			local slowPct = (lv>=6 and 0.55) or (lv>=3 and 0.40) or 0.30
			local vuln = (lv>=5 and 0.20) or 0
			local endT = os.clock() + dur
			task.spawn(function()
				while os.clock()<endT do
					for _, e in ipairs(getEnemiesInRadius(pos, radius)) do
						applySlow(e, slowPct, 0.35)
						if vuln > 0 then
							e:SetAttribute("VulnerableUntil", os.clock()+0.4)
							e:SetAttribute("VulnerablePct", vuln)
						end
					end
					task.wait(0.2)
				end
			end)
		end
	end

	-- EPIC: Soul Link
	lv = getSpellLevel(plr, "SoulLink")
	if lv > 0 then
		local interval = 9
		local nextT = s.cds.SoulLink or 0
		if os.clock() >= nextT then
			s.cds.SoulLink = os.clock() + interval
			local dur = 4 + (lv>=4 and 1.5 or 0)
			local linkPct = (lv>=6 and 0.50) or (lv>=3 and 0.35) or 0.25
			local radius = 14 * (lv>=2 and 1.15 or 1.0)
			local anchor = getNearestEnemy(pos, 70)
			if anchor and anchor:FindFirstChild("HumanoidRootPart") then
				anchor:SetAttribute("SoulLinkAnchor", true)
				plr:SetAttribute("SoulLinkPct", linkPct)
				plr:SetAttribute("SoulLinkRadius", radius)
				task.delay(dur, function()
					if anchor and anchor.Parent then
						anchor:SetAttribute("SoulLinkAnchor", nil)
					end
					plr:SetAttribute("SoulLinkPct", nil)
					plr:SetAttribute("SoulLinkRadius", nil)
				end)
			end
		end
	end

	-- EPIC: Starfall
	lv = getSpellLevel(plr, "Starfall")
	if lv > 0 then
		local interval = 8.5
		local nextT = s.cds.Starfall or 0
		if os.clock() >= nextT then
			s.cds.Starfall = os.clock() + interval
			local strikes = ({5,5,7,7,9,12})[math.clamp(lv,1,6)] or 5
			local stun = (lv>=4 and 0.3) or 0
			local aoe = 8 * (lv>=2 and 1.15 or 1.0)
			local dmg = 28 + lv*9
			for i=1,strikes do
				task.delay(i*0.08, function()
					local r = 20 + math.random()*15
					local ang = math.random()*math.pi*2
					local p = pos + Vector3.new(math.cos(ang)*r,0,math.sin(ang)*r)
					task.delay(0.6, function()
						pulseAt(plr, p, aoe, dmg, {})
						if stun>0 then
							for _, e in ipairs(getEnemiesInRadius(p, aoe)) do
								applyFreeze(e, stun)
							end
						end
					end)
				end)
			end
		end
	end

	-- COMMON: Ember Spirits (orbit then launch)
	lv = getSpellLevel(plr, "EmberSpirits")
	if lv > 0 then
		local count = (lv>=6 and 5) or (lv>=3 and 3) or 2
		-- orbit hitboxes handled by orbit function, but we only use them as visuals; launch is real dmg
		tickOrbit(plr, dt, "EmberSpirits", count, 4, 2.2, 999, 0, nil)
		local interval = 1.2 * (lv>=4 and 0.9 or 1.0)
		local nextT = s.cds.EmberSpirits or 0
		if os.clock() >= nextT then
			s.cds.EmberSpirits = os.clock() + interval
			local target = getNearestEnemy(pos, 50)
			if target and target:FindFirstChild("HumanoidRootPart") then
				local dir = (target.HumanoidRootPart.Position - pos).Unit
				local dmg = 24 + lv*8
				local aoe = 7 * (lv>=2 and 1.10 or 1.0)
				fireProjectile(plr, pos + Vector3.new(0,2,0), dir, 85, 55, dmg, 0, {})
				task.delay(0.2, function()
					pulseAt(plr, target.HumanoidRootPart.Position, aoe, dmg*0.7, {})
				end)
			end
		end
	end
end

-- Heartbeat driver
RunService.Heartbeat:Connect(function(dt)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Parent and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
			stepPlayer(plr, dt)
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	state[plr.UserId] = nil
end)

print("[SpellService] Ready (horde spells)")
