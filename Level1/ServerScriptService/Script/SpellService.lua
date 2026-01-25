-- SpellService.server.lua (Level1/ServerScriptService/Script)
-- Aktywuje spelle z SpellDefinitions na bazie atrybutów Spell_<id>_Level.
-- Efekty oparte o Part'y, bez assetów.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = modFolder and require(modFolder:WaitForChild("SpellDefinitions"))

local enemiesFolder = workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Mobs")

local vfxRoot = workspace:FindFirstChild("SpellVFX")
if not vfxRoot then
	vfxRoot = Instance.new("Folder")
	vfxRoot.Name = "SpellVFX"
	vfxRoot.Parent = workspace
end

local function getEnemyHumanoids()
	local out = {}
	if not enemiesFolder then return out end
	for _, m in ipairs(enemiesFolder:GetChildren()) do
		local hum = m:FindFirstChildOfClass("Humanoid")
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then
			table.insert(out, {model=m, hum=hum, hrp=hrp})
		end
	end
	return out
end

local function nearestEnemy(pos: Vector3, maxDist: number)
	local best, bestD = nil, maxDist
	for _, e in ipairs(getEnemyHumanoids()) do
		local d = (e.hrp.Position - pos).Magnitude
		if d < bestD then bestD = d; best = e end
	end
	return best, bestD
end

local function enemiesInRadius(pos: Vector3, radius: number)
	local out = {}
	for _, e in ipairs(getEnemyHumanoids()) do
		if (e.hrp.Position - pos).Magnitude <= radius then
			table.insert(out, e)
		end
	end
	return out
end

local function mkPart(name: string, size: Vector3, cf: CFrame, transparency: number)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Transparency = transparency
	p.Material = Enum.Material.Neon
	p.Parent = vfxRoot
	return p
end

local function safeDamage(hum: Humanoid, dmg: number)
	if dmg <= 0 then return end
	pcall(function() hum:TakeDamage(dmg) end)
end

-- Per-player spell state
local state = {} -- [uid] = {cooldowns={}, orbitParts={...}}

local function getState(plr: Player)
	local s = state[plr.UserId]
	if not s then
		s = { cooldowns = {}, orbitParts = {} }
		state[plr.UserId] = s
	end
	return s
end

local function level(plr: Player, id: string): number
	return tonumber(plr:GetAttribute(("Spell_%s_Level"):format(id))) or 0
end

-- === SPELLS ===

-- SeekerBolt: homing bolt to nearest enemy
local function castSeekerBolt(plr: Player, lv: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local e = nearestEnemy(hrp.Position, 90)
	if not e then return end

	local dmg = 8 + lv * 4
	local bolt = mkPart("SeekerBolt", Vector3.new(0.4,0.4,0.4), CFrame.new(hrp.Position + Vector3.new(0,1.6,0)), 0.15)
	bolt.Shape = Enum.PartType.Ball

	local start = time()
	local ttl = 2.2
	local speed = 65 + lv * 6

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not bolt.Parent then conn:Disconnect(); return end
		if not e.hrp.Parent or e.hum.Health <= 0 then
			conn:Disconnect()
			bolt:Destroy()
			return
		end
		local pos = bolt.Position
		local dir = (e.hrp.Position + Vector3.new(0,1.2,0) - pos)
		local dist = dir.Magnitude
		if dist < 2.3 then
			safeDamage(e.hum, dmg)
			conn:Disconnect()
			bolt:Destroy()
			return
		end
		bolt.CFrame = CFrame.new(pos + dir.Unit * math.min(dist, speed * dt))
		if (time() - start) > ttl then
			conn:Disconnect()
			bolt:Destroy()
		end
	end)
end

-- WardingSigils: orbiting hitboxes (no damage while paused handled elsewhere)
local function ensureSigils(plr: Player, lv: number)
	local s = getState(plr)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local count = math.clamp(2 + math.floor(lv/2), 2, 5)
	local parts = s.orbitParts.WardingSigils
	if not parts then parts = {}; s.orbitParts.WardingSigils = parts end

	-- create missing
	while #parts < count do
		local p = mkPart("WardingSigil", Vector3.new(0.7,0.7,0.2), CFrame.new(hrp.Position), 0.25)
		parts[#parts+1] = p
	end
	-- remove extra
	while #parts > count do
		local p = table.remove(parts)
		if p and p.Parent then p:Destroy() end
	end
end

-- HexAura: periodic aura pulse
local function castHexAura(plr: Player, lv: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local radius = 7 + lv * 1.2
	local dmg = 6 + lv * 3
	for _, e in ipairs(enemiesInRadius(hrp.Position, radius)) do
		safeDamage(e.hum, dmg)
	end

	local ring = mkPart("HexAura", Vector3.new(0.2, 0.2, 0.2), CFrame.new(hrp.Position) * CFrame.new(0,0.4,0), 0.65)
	ring.Shape = Enum.PartType.Cylinder
	ring.Orientation = Vector3.new(0,0,90)
	local tw = TweenService:Create(ring, TweenInfo.new(0.35), {Size = Vector3.new(0.2, radius*2, radius*2), Transparency = 1})
	tw:Play()
	Debris:AddItem(ring, 0.4)
end

-- StormMark: lightning strike nearest enemy
local function castStormMark(plr: Player, lv: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local e = nearestEnemy(hrp.Position, 110)
	if not e then return end
	local dmg = 10 + lv * 5

	local a = hrp.Position + Vector3.new(0,2.2,0)
	local b = e.hrp.Position + Vector3.new(0,1.6,0)
	local mid = (a + b) * 0.5
	local len = (b - a).Magnitude

	local beam = mkPart("StormMark", Vector3.new(0.25, 0.25, len), CFrame.lookAt(mid, b) * CFrame.new(0,0,-len/2), 0.15)
	beam.Material = Enum.Material.Neon
	Debris:AddItem(beam, 0.15)

	safeDamage(e.hum, dmg)
end

-- CursedPuddle: place puddle at player feet, DoT in area
local function castCursedPuddle(plr: Player, lv: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local radius = 6 + lv * 0.9
	local tickDmg = 3 + lv * 2
	local duration = 5 + lv * 0.4

	local puddle = mkPart("CursedPuddle", Vector3.new(0.4, radius*2, radius*2), CFrame.new(hrp.Position.X, hrp.Position.Y-2.5, hrp.Position.Z), 0.55)
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Orientation = Vector3.new(0,0,90)
	puddle.Color = Color3.fromRGB(140, 60, 255)

	local t0 = time()
	local lastTick = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not puddle.Parent then conn:Disconnect(); return end
		local t = time() - t0
		if t >= duration then
			conn:Disconnect()
			puddle:Destroy()
			return
		end
		if t - lastTick >= 1.0 then
			lastTick = t
			for _, e in ipairs(enemiesInRadius(puddle.Position, radius)) do
				safeDamage(e.hum, tickDmg)
			end
		end
	end)
	Debris:AddItem(puddle, duration + 0.2)
end

-- RicochetShard: hit nearest, then chain 1..N extra
local function castRicochetShard(plr: Player, lv: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local jumps = math.clamp(1 + math.floor(lv/2), 1, 5)
	local dmg = 7 + lv * 3
	local pos = hrp.Position

	local hit = {}
	for _=1, (jumps+1) do
		local best, bestD = nil, 85
		for _, e in ipairs(getEnemyHumanoids()) do
			if not hit[e.model] then
				local d = (e.hrp.Position - pos).Magnitude
				if d < bestD then bestD = d; best = e end
			end
		end
		if not best then break end
		hit[best.model] = true

		local a = pos + Vector3.new(0,1.6,0)
		local b = best.hrp.Position + Vector3.new(0,1.2,0)
		local mid = (a+b)*0.5
		local len = (b-a).Magnitude
		local shard = mkPart("RicochetShard", Vector3.new(0.18,0.18,len), CFrame.lookAt(mid, b) * CFrame.new(0,0,-len/2), 0.2)
		Debris:AddItem(shard, 0.12)

		safeDamage(best.hum, dmg)
		pos = best.hrp.Position
	end
end

-- ChainSpark: faster smaller chain
local function castChainSpark(plr: Player, lv: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local jumps = math.clamp(2 + math.floor(lv/2), 2, 6)
	local dmg = 5 + lv * 2
	local pos = hrp.Position
	local hit = {}
	for _=1, jumps do
		local best, bestD = nil, 65
		for _, e in ipairs(getEnemyHumanoids()) do
			if not hit[e.model] then
				local d = (e.hrp.Position - pos).Magnitude
				if d < bestD then bestD = d; best = e end
			end
		end
		if not best then break end
		hit[best.model] = true
		local spark = mkPart("ChainSpark", Vector3.new(0.12,0.12,(best.hrp.Position-pos).Magnitude), CFrame.lookAt((pos+best.hrp.Position)*0.5, best.hrp.Position) * CFrame.new(0,0,-(best.hrp.Position-pos).Magnitude/2), 0.35)
		Debris:AddItem(spark, 0.10)
		safeDamage(best.hum, dmg)
		pos = best.hrp.Position
	end
end

-- GravityWell: pull enemies briefly
local function castGravityWell(plr: Player, lv: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local radius = 8 + lv * 1.2
	local pull = 20 + lv * 5
	local dur = 1.3 + lv * 0.1

	local well = mkPart("GravityWell", Vector3.new(0.35, radius*2, radius*2), CFrame.new(hrp.Position) * CFrame.new(0,0.2,0), 0.75)
	well.Shape = Enum.PartType.Cylinder
	well.Orientation = Vector3.new(0,0,90)
	well.Color = Color3.fromRGB(90, 180, 255)
	Debris:AddItem(well, dur + 0.2)

	local t0 = time()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not well.Parent then conn:Disconnect(); return end
		if (time() - t0) >= dur then
			conn:Disconnect()
			return
		end
		for _, e in ipairs(enemiesInRadius(hrp.Position, radius)) do
			local dir = (hrp.Position - e.hrp.Position)
			local d = dir.Magnitude
			if d > 1 then
				local step = dir.Unit * math.min(pull * dt, d)
				e.hrp.CFrame = e.hrp.CFrame + step
			end
		end
	end)
end

-- FrostNeedle: projectile + slow
local function castFrostNeedle(plr: Player, lv: number)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local e = nearestEnemy(hrp.Position, 90)
	if not e then return end

	local dmg = 7 + lv * 3
	local slow = math.clamp(0.15 + lv*0.03, 0.15, 0.45)
	local slowDur = 1.4 + lv*0.15

	local needle = mkPart("FrostNeedle", Vector3.new(0.18,0.18,1.2), CFrame.new(hrp.Position + Vector3.new(0,1.6,0)), 0.25)
	needle.Color = Color3.fromRGB(160, 220, 255)

	local start = time()
	local ttl = 1.6
	local speed = 90 + lv * 7

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not needle.Parent then conn:Disconnect(); return end
		if not e.hrp.Parent or e.hum.Health <= 0 then conn:Disconnect(); needle:Destroy(); return end

		local pos = needle.Position
		local dir = (e.hrp.Position + Vector3.new(0,1.1,0) - pos)
		local dist = dir.Magnitude
		if dist < 2.0 then
			safeDamage(e.hum, dmg)
			local old = e.hum.WalkSpeed
			e.hum.WalkSpeed = math.max(6, old * (1 - slow))
			task.delay(slowDur, function()
				if e.hum and e.hum.Parent and e.hum.Health > 0 then
					e.hum.WalkSpeed = old
				end
			end)
			conn:Disconnect()
			needle:Destroy()
			return
		end
		needle.CFrame = CFrame.lookAt(pos, e.hrp.Position) * CFrame.new(0,0,-math.min(dist, speed*dt))
		if (time() - start) > ttl then
			conn:Disconnect()
			needle:Destroy()
		end
	end)
end

-- cooldown config per spell id
local function cooldownFor(id: string, lv: number): number
	if not SpellDefs or not SpellDefs.SPELLS then return 2 end
	local def = SpellDefs.SPELLS[id]
	if not def or typeof(def.scale) ~= "table" then
		return 2
	end
	local cd = tonumber(def.scale.cd) or 2
	-- higher lv slightly faster
	return math.max(0.35, cd - (lv-1)*0.06)
end

local CASTERS = {
	SeekerBolt = castSeekerBolt,
	WardingSigils = function(plr, lv) ensureSigils(plr, lv) end,
	HexAura = castHexAura,
	StormMark = castStormMark,
	CursedPuddle = castCursedPuddle,
	RicochetShard = castRicochetShard,
	ChainSpark = castChainSpark,
	GravityWell = castGravityWell,
	FrostNeedle = castFrostNeedle,
}

-- orbit update for WardingSigils
local orbitAngle = 0
RunService.Heartbeat:Connect(function(dt)
	orbitAngle += dt * 2.2
	for _, plr in ipairs(Players:GetPlayers()) do
		local lv = level(plr, "WardingSigils")
		if lv <= 0 then
			-- cleanup if exists
			local s = state[plr.UserId]
			if s and s.orbitParts.WardingSigils then
				for _, p in ipairs(s.orbitParts.WardingSigils) do if p and p.Parent then p:Destroy() end end
				s.orbitParts.WardingSigils = nil
			end
		else
			ensureSigils(plr, lv)
			local s = getState(plr)
			local parts = s.orbitParts.WardingSigils
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and parts then
				local r = 3.2 + lv * 0.15
				for i, p in ipairs(parts) do
					if p and p.Parent then
						local a = orbitAngle + (i * (math.pi*2/#parts))
						local offset = Vector3.new(math.cos(a)*r, 1.6, math.sin(a)*r)
						p.CFrame = CFrame.new(hrp.Position + offset) * CFrame.Angles(0, a, 0)
						-- contact damage (simple radius check)
						for _, e in ipairs(enemiesInRadius(p.Position, 2.2)) do
							local key = tostring(e.model:GetDebugId())
							s.cooldowns[key] = s.cooldowns[key] or 0
							if s.cooldowns[key] <= time() then
								s.cooldowns[key] = time() + 0.45
								safeDamage(e.hum, 4 + lv*2)
							end
						end
					end
				end
			end
		end
	end
end)

-- main casting loop
task.spawn(function()
	while true do
		task.wait(0.12)

		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				continue
			end

			local s = getState(plr)
			for id, caster in pairs(CASTERS) do
				local lv = level(plr, id)
				if lv > 0 and id ~= "WardingSigils" then
					local cd = cooldownFor(id, lv)
					local nextAt = s.cooldowns["spell:"..id] or 0
					if time() >= nextAt then
						s.cooldowns["spell:"..id] = time() + cd
						-- cast
						pcall(function() caster(plr, lv) end)
					end
				end
			end
		end
	end
end)

print("[SpellService] Ready (v14)")
