-- WeaponCombat.server.lua (ServerScriptService/Script)
-- Auto-attack: 360° + zawsze najbliższy przeciwnik (później: wybór targetowania).
-- Serwer zadaje dmg i odpala VFX w miejscu trafienia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WeaponSwingVFX = Remotes:WaitForChild("WeaponSwingVFX")

local EnemiesFolder = workspace:WaitForChild("Enemies")

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PlayerData"))

local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))

-- Per-weapon profile (cooldown/range). Kąty nie są już używane (360°).
local Profiles = {
	Sword    = { cd = 0.55, range = 10 },
	Scythe   = { cd = 0.80, range = 11 },
	Halberd  = { cd = 0.75, range = 13 },
	Claymore = { cd = 0.95, range = 11 },
	Greataxe = { cd = 1.05, range = 11 },
}

local function getActiveWeaponEntry(plr: Player)
	local data = PlayerData.Get(plr)
	if not data or typeof(data.Loadout) ~= "table" then return nil end
	return data.Loadout[1]
end

local function resolveWeaponDef(entry)
	local id = entry and (entry.id or entry.Id)
	if typeof(id) ~= "string" then return nil end
	if WeaponConfigs and WeaponConfigs.Get then
		return WeaponConfigs.Get(id)
	end
	return nil
end

local function resolveWeaponType(entry)
	local def = resolveWeaponDef(entry)
	return def and def.weaponType or nil
end

local function calcDamage(plr: Player, entry)
	local def = resolveWeaponDef(entry)
	local level = tonumber(entry and (entry.level or entry.Level)) or 1
	level = math.max(1, math.floor(level))

	local baseAtk = 10
	local atkPerLevel = 0.8
	if def and def.combat then
		baseAtk = tonumber(def.combat.baseAtk or def.baseDamage) or baseAtk
		atkPerLevel = tonumber(def.combat.atkPerLevel) or atkPerLevel
	end

	return baseAtk + (level - 1) * atkPerLevel
end

local function tagCreator(humanoid, plr: Player)
	local old = humanoid:FindFirstChild("creator")
	if old then old:Destroy() end
	local tag = Instance.new("ObjectValue")
	tag.Name = "creator"
	tag.Value = plr
	tag.Parent = humanoid
	task.delay(1.0, function()
		if tag and tag.Parent then tag:Destroy() end
	end)
end

local function isEnemyModel(m)
	return m and m:IsA("Model") and m.Parent == EnemiesFolder and m:FindFirstChildOfClass("Humanoid")
end

local function getClosestTarget(origin: Vector3, maxRange: number)
	local best, bestDist
	for _, enemy in ipairs(EnemiesFolder:GetChildren()) do
		if isEnemyModel(enemy) then
			local ehrp = enemy:FindFirstChild("HumanoidRootPart")
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			if ehrp and hum and hum.Health > 0 then
				local dist = (ehrp.Position - origin).Magnitude
				if dist <= maxRange and (not bestDist or dist < bestDist) then
					best = { model = enemy, hrp = ehrp, hum = hum, dist = dist }
					bestDist = dist
				end
			end
		end
	end
	return best
end

local function doSwing(plr: Player, char: Model, entry)
	if PauseState.Value then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	local wType = resolveWeaponType(entry)
	if typeof(wType) ~= "string" then return end
	local prof = Profiles[wType]
	if not prof then
		-- fallback: sensowny domyślny zasięg/cd
		prof = { cd = 0.7, range = 10 }
	end

	local target = getClosestTarget(hrp.Position, prof.range)
	if not target then return end

	local dmg = calcDamage(plr, entry)

	-- Server damage
	tagCreator(target.hum, plr)
	target.hum:TakeDamage(dmg)

	-- VFX w miejscu trafienia (broń ma się pojawić tam gdzie atakuje)
	local dir = (target.hrp.Position - hrp.Position)
	if dir.Magnitude < 0.001 then
		dir = hrp.CFrame.LookVector
	else
		dir = dir.Unit
	end

	local weaponId = entry and (entry.id or entry.Id) or ""
	WeaponSwingVFX:FireAllClients(weaponId, wType, target.hrp.Position, dir)
end

local loops: {[Player]: {alive: boolean}} = {}

local function startLoop(plr: Player, char: Model)
	if loops[plr] then loops[plr].alive = false end
	local state = { alive = true }
	loops[plr] = state

	task.spawn(function()
		local lastAttack = 0.0
		while state.alive and plr.Parent do
			task.wait(0.05)

			if not char or not char.Parent then
				char = plr.Character
			end

			local entry = getActiveWeaponEntry(plr)
			if not entry or not char then
				continue
			end

			local wType = resolveWeaponType(entry)
			local prof = wType and Profiles[wType] or { cd = 0.7, range = 10 }

			local now = time()
			if (now - lastAttack) >= prof.cd then
				lastAttack = now
				doSwing(plr, char, entry)
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		startLoop(plr, char)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	if loops[plr] then
		loops[plr].alive = false
		loops[plr] = nil
	end
end)
