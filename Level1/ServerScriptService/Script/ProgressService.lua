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
		local d = PlayerData.Get(plr)
		local ws = BASE_PLAYER_SPEED + (d.upgrades.speed or 0) * 1
		local jp = BASE_JUMP_POWER + (d.upgrades.jump or 0) * 2
		hum.WalkSpeed = ws
		hum.JumpPower = jp
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

	local function give(toolName: string)
		for _,x in ipairs(backpack:GetChildren()) do
			if x:IsA("Tool") and x.Name == toolName then return end
		end
		local src = WeaponTemplates:FindFirstChild(toolName)
		if src and src:IsA("Tool") then src:Clone().Parent = backpack end
	end

	give("Sword")
	if d.unlockBow then give("Bow") end
	if d.unlockWand then give("Wand") end
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
	if stat == "critChance" and d.critChance == nil then d.critChance = 0.08 end
	if stat == "critMult" and d.critMult == nil then d.critMult = 1.60 end

	if stat == "attackSpeed" then
		d.attackSpeed = math.clamp((tonumber(d.attackSpeed) or 1.0) + choice.value, 0.6, 2.0)
	elseif stat == "multiShot" then
		d.multiShot = math.clamp((tonumber(d.multiShot) or 0) + choice.value, 0, 6)
	elseif stat == "fireChance" then
		d.fireChance = math.clamp((tonumber(d.fireChance) or 0) + choice.value, 0, 0.9)
	elseif stat == "fireDps" then
		d.fireDps = math.max(0, (tonumber(d.fireDps) or 0) + choice.value)
	elseif stat == "damage" then
		d.damage = math.max(1, (tonumber(d.damage) or 18) + choice.value)
	elseif stat == "critChance" then
		d.critChance = math.clamp((tonumber(d.critChance) or 0.08) + choice.value, 0, 0.6)
	elseif stat == "critMult" then
		d.critMult = math.clamp((tonumber(d.critMult) or 1.6) + choice.value, 1.2, 4.0)
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

local function getStats(plr: Player)
	local d = PlayerData.Get(plr)
	local dmg = math.max(10, tonumber(d.damage) or 18)
	local multi = math.clamp(tonumber(d.multiShot) or 0, 0, 6)
	local fch = math.clamp(tonumber(d.fireChance) or 0, 0, 0.9)
	local fdps = math.max(0, tonumber(d.fireDps) or 0)
	local aspd = math.clamp(tonumber(d.attackSpeed) or 1.0, 0.6, 2.0)

	local critC = math.clamp(tonumber(d.critChance) or 0.08, 0, 0.6)
	local critM = math.clamp(tonumber(d.critMult) or 1.60, 1.2, 4.0)
	return dmg, multi, fch, fdps, aspd, critC, critM
end

local function dealMobDamage(plr: Player, mobHum: Humanoid, mobRoot: BasePart, baseDamage: number, fireChance: number, fireDps: number, critC: number, critM: number)
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

	if fireDps > 0 and math.random() < fireChance then
		applyBurn(mobHum, fireDps, 3.0)
	end
end

-- melee AoE
local function swordAoE(plr: Player, center: Vector3, radius: number)
	local enf = enemiesFolder()
	if not enf then return end

	local dmg, _, fch, fdps, _, critC, critM = getStats(plr)

	for _,m in ipairs(enf:GetChildren()) do
		local eh = m:FindFirstChildOfClass("Humanoid")
		local er = m:FindFirstChild("HumanoidRootPart")
		if eh and er and eh.Health > 0 then
			if (er.Position - center).Magnitude <= radius then
				dealMobDamage(plr, eh, er, dmg, fch, fdps, critC, critM)
			end
		end
	end
end

-- projectile (ray + overlap)
local function overlapHit(pos: Vector3, radius: number, ignore: {Instance})
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local parts = workspace:GetPartBoundsInRadius(pos, radius, params)
	for _,p in ipairs(parts) do
		local model = p:FindFirstAncestorOfClass("Model")
		if model and model.Parent == enemiesFolder() then
			local hum = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				return hum, root
			end
		end
	end
	return nil
end

local function spawnProjectile(plr: Player, origin: Vector3, dir: Vector3, speed: number, life: number, dmgMul: number)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.4,0.4,0.4)
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(180,220,255)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CFrame = CFrame.new(origin)
	p.Parent = workspace
	Debris:AddItem(p, life)

	local baseDmg, _, fch, fdps, _, critC, critM = getStats(plr)
	local damage = math.max(1, math.floor(baseDmg * dmgMul))

	local ignore = { plr.Character, p }
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore

	local pos = origin
	local vel = dir.Unit * speed
	local t0 = time()

	while p.Parent and (time() - t0) < life do
		if PauseState.Value then task.wait(0.05) continue end
		local dt = RunService.Heartbeat:Wait()
		local nextPos = pos + vel * dt

		local oh, oroot = overlapHit(nextPos, 1.7, ignore)
		if oh and oroot then
			dealMobDamage(plr, oh, oroot, damage, fch, fdps, critC, critM)
			break
		end

		local hit = workspace:Raycast(pos, nextPos - pos, rayParams)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model and model.Parent == enemiesFolder() then
				local mh = model:FindFirstChildOfClass("Humanoid")
				local mr = model:FindFirstChild("HumanoidRootPart")
				if mh and mr and mh.Health > 0 then
					dealMobDamage(plr, mh, mr, damage, fch, fdps, critC, critM)
				end
			end
			break
		end

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

	local baseDmg, multi, _, _, aspd = getStats(plr)

	if payload.action == "MELEE" and wType == "Melee" then
		local now = os.clock()
		local cd = 0.50 / aspd
		if swingCd[plr.UserId] and (now - swingCd[plr.UserId]) < cd then return end
		swingCd[plr.UserId] = now

		-- większy range melee
		local center = hrp.Position + hrp.CFrame.LookVector * 8.5
		swordAoE(plr, center, 10.5)

	elseif payload.action == "SHOOT" and (wType == "Bow" or wType == "Wand") then
		local aim = payload.aim
		if typeof(aim) ~= "Vector3" then return end
		if (aim - hrp.Position).Magnitude > 800 then return end

		local now = os.clock()
		local cd = (wType == "Bow") and (0.65 / aspd) or (0.55 / aspd)
		if shotCd[plr.UserId] and (now - shotCd[plr.UserId]) < cd then return end
		shotCd[plr.UserId] = now

		local origin = hrp.Position + Vector3.new(0, 1.35, 0)
		local dir = (aim - origin)
		if dir.Magnitude < 3 then return end

		-- strzał do tyłu OK (bez ograniczeń)
		local speed = (wType == "Bow") and 160 or 185
		local life = 3.0
		local dmgMul = (wType == "Bow") and 0.95 or 0.85

		local total = 1 + multi
		local spread = math.rad(4)

		for i=1,total do
			local angle = (i - (total+1)/2) * spread
			local rot = CFrame.fromAxisAngle(Vector3.new(0,1,0), angle)
			local shotDir = rot:VectorToWorldSpace(dir.Unit)
			spawnProjectile(plr, origin, shotDir, speed, life, dmgMul)
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
		local dd = PlayerData.Get(plr)
		if hum then
			hum.WalkSpeed = BASE_PLAYER_SPEED + (dd.upgrades.speed or 0) * 1
			hum.JumpPower = BASE_JUMP_POWER + (dd.upgrades.jump or 0) * 2
		end

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
