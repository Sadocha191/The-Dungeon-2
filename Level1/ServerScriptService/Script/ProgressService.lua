-- ProgressService.server.lua (ServerScriptService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PauseState = ReplicatedStorage:WaitForChild("PauseState")
PauseState.Value = false

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
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

-- Collision groups
local PLAYERS_GROUP = "Players"
local MOBS_GROUP = "Mobs"
pcall(function() PhysicsService:CreateCollisionGroup(PLAYERS_GROUP) end)
pcall(function() PhysicsService:CreateCollisionGroup(MOBS_GROUP) end)
PhysicsService:CollisionGroupSetCollidable(PLAYERS_GROUP, MOBS_GROUP, false)

local function setCharacterGroup(char: Model)
	for _,d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(d, PLAYERS_GROUP)
		end
	end
end

-- Tools
local WeaponTemplates = ReplicatedStorage:WaitForChild("WeaponTemplates")

local function giveLoadout(plr)
	local d = PlayerData.Get(plr)
	local backpack = plr:WaitForChild("Backpack")

	local function give(toolName)
		for _,x in ipairs(backpack:GetChildren()) do
			if x:IsA("Tool") and x.Name == toolName then return end
		end
		local src = WeaponTemplates:FindFirstChild(toolName)
		if src then src:Clone().Parent = backpack end
	end

	give("Sword")
	if d.unlockBow then give("Bow") end
	if d.unlockWand then give("Wand") end
end

-- ===== HUD push =====
local function pushProgress(plr)
	local d = PlayerData.Get(plr)
	PlayerProgressEvent:FireClient(plr, {
		type="progress",
		level=d.level, xp=d.xp, nextXp=d.nextXp,
		coins=d.coins,
	})
end

-- ===== Upgrades (wracają) =====
local pending = {} -- [uid] = {token, choices}

local RAR = {
	Common={w=60, c=Color3.fromRGB(210,210,210), mult=1.0},
	Rare={w=28, c=Color3.fromRGB(90,170,255), mult=1.4},
	Epic={w=10, c=Color3.fromRGB(190,120,255), mult=2.0},
	Legendary={w=2, c=Color3.fromRGB(255,180,60), mult=3.0},
}

local POOL = {
	{ id="DMG", name="Obrażenia", stat="DMG", base=6 },
	{ id="ASPD", name="Szybkość ataku", stat="Atk Speed", base=0.12 },
	{ id="MULTI", name="Multi-shot", stat="Pociski", base=1 },
	{ id="FIRE", name="Podpalenie", stat="Fire DPS", base=6 },
	{ id="FCH", name="Szansa podp.", stat="Fire %", base=0.10 },
}

local function rollRarity()
	local sum=0; for _,r in pairs(RAR) do sum += r.w end
	local x = math.random()*sum
	local a=0
	for name,r in pairs(RAR) do
		a += r.w
		if x <= a then return name, r.c, r.mult end
	end
	return "Common", RAR.Common.c, RAR.Common.mult
end

local function pick3()
	local pool = table.clone(POOL)
	local out = {}
	for i=1,3 do
		local idx = math.random(1,#pool)
		local u = pool[idx]
		table.remove(pool, idx)

		local rn, col, mult = rollRarity()
		local val
		if u.id == "ASPD" or u.id == "FCH" then
			val = math.floor((u.base*mult)*100)/100
		else
			val = math.floor(u.base*mult)
		end

		out[i] = {id=u.id, name=u.name, stat=u.stat, value=val, rarity=rn, color=col}
	end
	return out
end

local function openUpgrade(plr)
	local token = ("%d_%d"):format(plr.UserId, math.floor(os.clock()*1000))
	local choices = pick3()
	pending[plr.UserId] = {token=token, choices=choices}
	PauseState.Value = true
	UpgradeEvent:FireClient(plr, {type="SHOW", token=token, choices=choices})
end

UpgradeEvent.OnServerEvent:Connect(function(plr, payload)
	if typeof(payload) ~= "table" or payload.type ~= "PICK" then return end
	local st = pending[plr.UserId]
	if not st or payload.token ~= st.token then return end

	local picked = tostring(payload.id or "")
	local choice
	for _,c in ipairs(st.choices) do
		if c.id == picked then choice = c break end
	end
	if not choice then return end

	local d = PlayerData.Get(plr)

	if picked == "DMG" then
		d.damage = math.max(25, (d.damage or 25) + choice.value)
	elseif picked == "ASPD" then
		d.attackSpeed = math.clamp((d.attackSpeed or 1.0) + choice.value, 0.7, 2.0)
	elseif picked == "MULTI" then
		d.multiShot = math.clamp((d.multiShot or 0) + choice.value, 0, 6)
	elseif picked == "FIRE" then
		d.fireDps = math.min(60, (d.fireDps or 0) + choice.value)
	elseif picked == "FCH" then
		d.fireChance = math.clamp((d.fireChance or 0) + choice.value, 0, 0.9)
	end

	pending[plr.UserId] = nil
	PauseState.Value = false

	PlayerData.MarkDirty(plr)
	pushProgress(plr)
	PlayerData.Save(plr, false)
end)

local function checkLevelUp(plr)
	local d = PlayerData.Get(plr)
	local leveled = false
	while d.xp >= d.nextXp do
		d.xp -= d.nextXp
		d.level += 1
		d.nextXp = PlayerData.RollNextXp(d.level)
		leveled = true
	end
	if leveled then
		PlayerData.MarkDirty(plr)
		pushProgress(plr)
		openUpgrade(plr)
	end
end

-- ===== Award (orby zbierają, a to dopisuje) =====
function _G.AwardPlayer(plr: Player, xp: number, coins: number)
	if not plr or not plr.Parent then return end
	local d = PlayerData.Get(plr)
	d.xp += math.max(0, math.floor(xp or 0))
	d.coins += math.max(0, math.floor(coins or 0))
	PlayerData.MarkDirty(plr)
	pushProgress(plr)
	checkLevelUp(plr)
end

-- ===== Combat =====
local function getStats(plr)
	local d = PlayerData.Get(plr)
	local dmg = math.max(30, tonumber(d.damage) or 30)
	local multi = math.clamp(tonumber(d.multiShot) or 0, 0, 6)
	local fch = math.clamp(tonumber(d.fireChance) or 0, 0, 0.9)
	local fdps = math.max(0, tonumber(d.fireDps) or 0)
	local aspd = math.clamp(tonumber(d.attackSpeed) or 1.0, 0.7, 2.0)
	return dmg, multi, fch, fdps, aspd
end

local function enemiesFolder()
	return workspace:FindFirstChild("Enemies")
end

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

-- Sword AoE: większy zasięg + promień
local function swordAoE(center: Vector3, radius: number, damage: number, fireChance: number, fireDps: number)
	local enf = enemiesFolder()
	if not enf then return end
	for _,m in ipairs(enf:GetChildren()) do
		local eh = m:FindFirstChildOfClass("Humanoid")
		local er = m:FindFirstChild("HumanoidRootPart")
		if eh and er and eh.Health > 0 then
			if (er.Position - center).Magnitude <= radius then
				eh:TakeDamage(damage)
				if fireDps > 0 and math.random() < fireChance then
					applyBurn(eh, fireDps, 3.0)
				end
			end
		end
	end
end

-- Projectile: ray + overlap hitbox (pewnie trafia)
local function overlapHit(pos: Vector3, radius: number, ignore: {Instance})
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local parts = workspace:GetPartBoundsInRadius(pos, radius, params)
	for _,p in ipairs(parts) do
		local model = p:FindFirstAncestorOfClass("Model")
		if model and model.Parent == enemiesFolder() then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then return hum end
		end
	end
	return nil
end

local function spawnProjectile(plr: Player, origin: Vector3, dir: Vector3, speed: number, life: number, damage: number, fireChance: number, fireDps: number)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.4,0.4,0.4)
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(180, 220, 255)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CFrame = CFrame.new(origin)
	p.Parent = workspace
	Debris:AddItem(p, life)

	local ignore = { plr.Character, p }
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore

	local pos = origin
	local vel = dir.Unit * speed
	local t0 = time()

	while p.Parent and (time()-t0) < life do
		if PauseState.Value then task.wait(0.05) continue end

		local dt = RunService.Heartbeat:Wait()
		local nextPos = pos + vel * dt

		local oh = overlapHit(nextPos, 1.6, ignore)
		if oh then
			oh:TakeDamage(damage)
			if fireDps > 0 and math.random() < fireChance then
				applyBurn(oh, fireDps, 3.0)
			end
			break
		end

		local hit = workspace:Raycast(pos, nextPos-pos, rayParams)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model and model.Parent == enemiesFolder() then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum:TakeDamage(damage)
					if fireDps > 0 and math.random() < fireChance then
						applyBurn(hum, fireDps, 3.0)
					end
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
	local ph = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not ph or ph.Health <= 0 then return end

	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then return end

	local wType = tool:GetAttribute("WeaponType")
	if typeof(wType) ~= "string" then return end

	local dmg, multi, fch, fdps, aspd = getStats(plr)

	if payload.action == "MELEE" and wType == "Melee" then
		local now = os.clock()
		local cd = 0.48 / aspd
		if swingCd[plr.UserId] and (now - swingCd[plr.UserId]) < cd then return end
		swingCd[plr.UserId] = now

		-- większy range: centrum dalej + większy radius
		local center = hrp.Position + hrp.CFrame.LookVector * 7
		swordAoE(center, 9.0, dmg, fch, fdps)

	elseif payload.action == "SHOOT" and (wType == "Bow" or wType == "Wand") then
		local aim = payload.aim
		if typeof(aim) ~= "Vector3" then return end

		-- POZWÓL strzelać do tyłu: brak dot-check
		if (aim - hrp.Position).Magnitude > 700 then return end

		local now = os.clock()
		local cd = (wType == "Bow") and (0.65 / aspd) or (0.55 / aspd)
		if shotCd[plr.UserId] and (now - shotCd[plr.UserId]) < cd then return end
		shotCd[plr.UserId] = now

		local origin = hrp.Position + Vector3.new(0, 1.35, 0)
		local dir = (aim - origin)
		if dir.Magnitude < 3 then return end

		local speed = (wType == "Bow") and 155 or 180
		local life = 2.8
		local projDmg = (wType == "Bow") and math.floor(dmg * 0.95) or math.floor(dmg * 0.85)

		local total = 1 + multi
		local spread = math.rad(4)

		for i=1,total do
			local angle = (i - (total+1)/2) * spread
			local rot = CFrame.fromAxisAngle(Vector3.new(0,1,0), angle)
			local shotDir = rot:VectorToWorldSpace(dir.Unit)
			spawnProjectile(plr, origin, shotDir, speed, life, projDmg, fch, fdps)
		end
	end
end)

-- Player baseline speed: gracz szybszy od mobów
local BASE_PLAYER_SPEED = 24

Players.PlayerAdded:Connect(function(plr)
	PlayerData.Get(plr)
	pushProgress(plr)

	plr.CharacterAdded:Connect(function(char)
		PauseState.Value = false
		task.wait(0.1)
		setCharacterGroup(char)

		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = BASE_PLAYER_SPEED
		end

		task.wait(0.15)
		giveLoadout(plr)
		pushProgress(plr)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	PlayerData.Save(plr, true)
end)

game:BindToClose(function()
	for _,plr in ipairs(Players:GetPlayers()) do
		PlayerData.Save(plr, true)
	end
end)
