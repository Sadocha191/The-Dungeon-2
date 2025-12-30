-- ProgressService.server.lua (ServerScriptService) - zgodny z PlayerData (nowy profil)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

-- Ensure PauseState exists
local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end
PauseState.Value = false

-- Remotes
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

-- Collision groups (player vs mobs no-collide)
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

local function giveLoadout(plr: Player)
	local d = PlayerData.Get(plr)
	local backpack = plr:WaitForChild("Backpack")

	local function give(toolName: string)
		for _,x in ipairs(backpack:GetChildren()) do
			if x:IsA("Tool") and x.Name == toolName then return end
		end
		local src = WeaponTemplates:FindFirstChild(toolName)
		if src and src:IsA("Tool") then
			src:Clone().Parent = backpack
		end
	end

	give("Sword")
	if d.unlockBow then give("Bow") end
	if d.unlockWand then give("Wand") end
end

-- HUD push
local function pushProgress(plr: Player)
	local d = PlayerData.Get(plr)
	PlayerProgressEvent:FireClient(plr, {
		type = "progress",
		level = d.level,
		xp = d.xp,
		nextXp = d.nextXp,
		coins = d.coins,
	})
end

-- ===== Upgrades: proste (dmg/speed/jump) =====
local pending = {} -- [uid] = {token=string, choices=table}

local function mkChoice(id, title, desc)
	return { id=id, title=title, desc=desc }
end

local function rollChoices()
	-- minimalnie na teraz (żeby działało pewnie)
	local pool = {
		mkChoice("DMG", "Obrażenia +", "+4 dmg na stałe"),
		mkChoice("SPEED", "Prędkość +", "+1 WalkSpeed na stałe"),
		mkChoice("JUMP", "Skok +", "+2 JumpPower na stałe"),
	}
	-- losuj 3 bez powtórzeń
	local out = {}
	while #out < 3 do
		local idx = math.random(1, #pool)
		out[#out+1] = table.remove(pool, idx)
	end
	return out
end

local function openUpgrade(plr: Player)
	local token = ("%d_%d"):format(plr.UserId, math.floor(os.clock()*1000))
	local choices = rollChoices()
	pending[plr.UserId] = { token = token, choices = choices }

	PauseState.Value = true
	UpgradeEvent:FireClient(plr, { type="SHOW", token=token, choices=choices })
end

UpgradeEvent.OnServerEvent:Connect(function(plr, payload)
	if typeof(payload) ~= "table" or payload.type ~= "PICK" then return end
	local st = pending[plr.UserId]
	if not st or payload.token ~= st.token then return end

	local picked = tostring(payload.id or "")
	local d = PlayerData.Get(plr)

	if picked == "DMG" then
		d.damage = math.max(1, (tonumber(d.damage) or 18) + 4)
		d.upgrades.dmg = (d.upgrades.dmg or 0) + 1
	elseif picked == "SPEED" then
		d.upgrades.speed = (d.upgrades.speed or 0) + 1
	elseif picked == "JUMP" then
		d.upgrades.jump = (d.upgrades.jump or 0) + 1
	else
		return
	end

	pending[plr.UserId] = nil
	PauseState.Value = false

	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)
	pushProgress(plr)

	-- reaplikuj movement po wybraniu
	local c = plr.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then
		local baseSpeed = 24
		hum.WalkSpeed = baseSpeed + (d.upgrades.speed or 0) * 1
		-- JumpPower vs JumpHeight zależy co masz ustawione w grze:
		hum.JumpPower = 50 + (d.upgrades.jump or 0) * 2
	end
end)

-- ===== Award from drops / kills =====
local function checkLevelUp(plr: Player)
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
		PlayerData.Save(plr, false)
		pushProgress(plr)
		openUpgrade(plr)
	end
end

function _G.AwardPlayer(plr: Player, xp: number, coins: number)
	if not plr or not plr.Parent then return end
	local d = PlayerData.Get(plr)

	d.xp += math.max(0, math.floor(xp or 0))
	d.coins += math.max(0, math.floor(coins or 0))

	PlayerData.MarkDirty(plr)
	PlayerData.Save(plr, false)
	pushProgress(plr)

	checkLevelUp(plr)
end

-- ===== Combat stats =====
local function getStats(plr: Player)
	local d = PlayerData.Get(plr)
	local dmg = math.max(10, tonumber(d.damage) or 18)
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

local function overlapHit(pos: Vector3, radius: number, ignore: {Instance})
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local parts = workspace:GetPartBoundsInRadius(pos, radius, params)
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
		local cd = 0.50 / aspd
		if swingCd[plr.UserId] and (now - swingCd[plr.UserId]) < cd then return end
		swingCd[plr.UserId] = now

		local center = hrp.Position + hrp.CFrame.LookVector * 7
		swordAoE(center, 9.0, dmg, fch, fdps)

	elseif payload.action == "SHOOT" and (wType == "Bow" or wType == "Wand") then
		local aim = payload.aim
		if typeof(aim) ~= "Vector3" then return end
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

-- baseline movement (player faster than mobs)
local BASE_PLAYER_SPEED = 24
local BASE_JUMP_POWER = 50

Players.PlayerAdded:Connect(function(plr)
	PlayerData.Get(plr)
	pushProgress(plr)

	plr.CharacterAdded:Connect(function(char)
		PauseState.Value = false
		task.wait(0.1)

		setCharacterGroup(char)

		local d = PlayerData.Get(plr)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = BASE_PLAYER_SPEED + (d.upgrades.speed or 0) * 1
			hum.JumpPower = BASE_JUMP_POWER + (d.upgrades.jump or 0) * 2
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
