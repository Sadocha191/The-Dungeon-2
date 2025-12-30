-- ProgressService.server.lua (ServerScriptService)
-- FIX: PauseState fail-safe, pewne trafianie (ray + overlap), sword AoE splash, większy dmg

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PauseState = ReplicatedStorage:WaitForChild("PauseState")

-- FAIL-SAFE: nigdy nie startuj na pauzie
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

-- Collision groups (Players vs Mobs no-collide)
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

-- Tools (server gives)
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

-- ===== Progress =====
local function pushProgress(plr)
	local d = PlayerData.Get(plr)
	PlayerProgressEvent:FireClient(plr, {
		type="progress",
		level=d.level, xp=d.xp, nextXp=d.nextXp,
		coins=d.coins,
	})
end

function _G.AwardPlayer(plr: Player, xp: number, coins: number)
	if not plr or not plr.Parent then return end
	local d = PlayerData.Get(plr)
	d.xp += math.max(0, math.floor(xp or 0))
	d.coins += math.max(0, math.floor(coins or 0))
	PlayerData.MarkDirty(plr)
	pushProgress(plr)

	-- level-up (prosto)
	while d.xp >= d.nextXp do
		d.xp -= d.nextXp
		d.level += 1
		d.nextXp = PlayerData.RollNextXp(d.level)
		PlayerData.MarkDirty(plr)
		pushProgress(plr)
		-- tu możesz odpalić upgrade popup jak chcesz
	end
end

-- ===== Combat stats (podkręcone) =====
local function getStats(plr)
	local d = PlayerData.Get(plr)
	-- Podbij bazę jeśli masz za mało w PlayerData:
	local dmg = math.max(35, tonumber(d.damage) or 35)
	local multi = math.clamp(tonumber(d.multiShot) or 0, 0, 6)
	local fch = math.clamp(tonumber(d.fireChance) or 0, 0, 0.9)
	local fdps = math.max(0, tonumber(d.fireDps) or 0)
	local aspd = math.clamp(tonumber(d.attackSpeed) or 1.0, 0.6, 2.0)
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

-- ===== Sword AoE (zawsze działa) =====
local function swordAoE(plr: Player, center: Vector3, radius: number, damage: number, fireChance: number, fireDps: number)
	local enf = enemiesFolder()
	if not enf then return end

	for _,m in ipairs(enf:GetChildren()) do
		local eh = m:FindFirstChildOfClass("Humanoid")
		local er = m:FindFirstChild("HumanoidRootPart")
		if eh and er and eh.Health > 0 then
			local dist = (er.Position - center).Magnitude
			if dist <= radius then
				eh:TakeDamage(damage)
				if fireDps > 0 and math.random() < fireChance then
					applyBurn(eh, fireDps, 3.0)
				end
			end
		end
	end
end

-- ===== Projectile hit: ray + overlap “hitbox” =====
local function overlapHit(position: Vector3, radius: number, ignore: {Instance})
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local parts = workspace:GetPartBoundsInRadius(position, radius, params)
	for _,p in ipairs(parts) do
		local model = p:FindFirstAncestorOfClass("Model")
		if model and model.Parent == enemiesFolder() then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				return hum
			end
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
	p.CanCollide = false
	p.CanQuery = false
	p.Anchored = true
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
		if PauseState.Value then
			task.wait(0.05)
			continue
		end

		local dt = RunService.Heartbeat:Wait()
		local nextPos = pos + vel * dt

		-- overlap hitbox (pewne trafienie)
		local oh = overlapHit(nextPos, 1.6, ignore)
		if oh then
			oh:TakeDamage(damage)
			if fireDps > 0 and math.random() < fireChance then
				applyBurn(oh, fireDps, 3.0)
			end
			break
		end

		-- ray hit
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

-- ===== Input throttles =====
local swingCd = {}
local shotCd = {}

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
		local cd = 0.5 / aspd
		if swingCd[plr.UserId] and (now - swingCd[plr.UserId]) < cd then return end
		swingCd[plr.UserId] = now

		-- AoE centrum przed graczem
		local center = hrp.Position + hrp.CFrame.LookVector * 5
		swordAoE(plr, center, 7.5, dmg, fch, fdps)

	elseif payload.action == "SHOOT" and (wType == "Bow" or wType == "Wand") then
		local aim = payload.aim
		if typeof(aim) ~= "Vector3" then return end

		-- walidacja: max dystans celu
		if (aim - hrp.Position).Magnitude > 650 then return end

		local now = os.clock()
		local cd = (wType == "Bow") and (0.7 / aspd) or (0.6 / aspd)
		if shotCd[plr.UserId] and (now - shotCd[plr.UserId]) < cd then return end
		shotCd[plr.UserId] = now

		local origin = hrp.Position + Vector3.new(0, 1.35, 0)
		local dir = (aim - origin)
		if dir.Magnitude < 3 then return end

		local baseSpeed = (wType == "Bow") and 150 or 175
		local baseLife = 2.8
		local projDmg = (wType == "Bow") and math.floor(dmg * 0.95) or math.floor(dmg * 0.85)

		local total = 1 + multi
		local spread = math.rad(4)

		for i=1,total do
			local angle = (i - (total+1)/2) * spread
			local rot = CFrame.fromAxisAngle(Vector3.new(0,1,0), angle)
			local shotDir = rot:VectorToWorldSpace(dir.Unit)
			spawnProjectile(plr, origin + hrp.CFrame.LookVector * 1.6, shotDir, baseSpeed, baseLife, projDmg, fch, fdps)
		end
	end
end)

-- Lifecycle
Players.PlayerAdded:Connect(function(plr)
	PlayerData.Get(plr)
	pushProgress(plr)

	plr.CharacterAdded:Connect(function(char)
		PauseState.Value = false -- FAIL-SAFE po respawnie
		task.wait(0.1)
		setCharacterGroup(char)
		task.wait(0.1)
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
