-- WeaponCombat.server.lua (ServerScriptService/Script)
-- Server-authoritative auto-attacks with angle sectors.
-- No need to hold tools; weapons can be purely visual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local EnemiesFolder = workspace:WaitForChild("Enemies")

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
if not playerDataModule then
	error("[WeaponCombat] Missing PlayerData module.")
end
local PlayerData = require(playerDataModule)

-- Weapon configs (optional, used to read weaponType/base damage)
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local WeaponConfigs = moduleFolder and moduleFolder:FindFirstChild("WeaponConfigs")
	and require(moduleFolder.WeaponConfigs) or nil

-- Profiles: tune per weaponType
local Profiles = {
	Sword    = { cd = 0.55, range = 8,  halfAngleDeg = 45,  maxHits = 2,  falloff2 = 0.60 }, -- ~90°
	Scythe   = { cd = 0.80, range = 9,  halfAngleDeg = 90,  maxHits = 99 },                  -- ~180°
	Halberd  = { cd = 0.75, range = 11, halfAngleDeg = 35,  maxHits = 3,  falloff2 = 0.75 },
	Claymore = { cd = 0.95, range = 9,  halfAngleDeg = 65,  maxHits = 4,  falloff2 = 0.70 },
	Greataxe = { cd = 1.05, range = 9,  halfAngleDeg = 75,  maxHits = 4,  falloff2 = 0.70 },
}

local function getActiveWeaponEntry(plr: Player)
	local data = PlayerData.Get(plr)
	if not data or typeof(data.Loadout) ~= "table" then return nil end
	return data.Loadout[1] -- w runie grasz 1 bronią
end

local function resolveWeaponType(entry)
	local id = entry and (entry.id or entry.Id)
	if typeof(id) ~= "string" then return nil end
	if WeaponConfigs and WeaponConfigs.Get then
		local def = WeaponConfigs.Get(id)
		if def and typeof(def.weaponType) == "string" then
			return def.weaponType
		end
	end
	return nil
end

local function calcBaseDamage(entry)
	local id = entry and (entry.id or entry.Id)
	local level = tonumber(entry and (entry.level or entry.Level)) or 1
	level = math.max(1, math.floor(level))

	local baseAtk, atkPerLevel = 10, 0.8
	if WeaponConfigs and WeaponConfigs.Get and typeof(id) == "string" then
		local def = WeaponConfigs.Get(id)
		if def and def.combat then
			baseAtk = tonumber(def.combat.baseAtk or def.baseDamage) or baseAtk
			atkPerLevel = tonumber(def.combat.atkPerLevel) or atkPerLevel
		end
	end

	return baseAtk + (level - 1) * atkPerLevel
end

local function tagCreator(humanoid: Humanoid, plr: Player)
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

local function isEnemyModel(m: Instance): boolean
	return m and m:IsA("Model") and m.Parent == EnemiesFolder and m:FindFirstChildOfClass("Humanoid") ~= nil
end

local function pickTargets(hrpPos: Vector3, look: Vector3, prof)
	local targets = {}

	for _, enemy in ipairs(EnemiesFolder:GetChildren()) do
		if isEnemyModel(enemy) then
			local ehrp = enemy:FindFirstChild("HumanoidRootPart")
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			if ehrp and hum and hum.Health > 0 then
				local offset = ehrp.Position - hrpPos
				local dist = offset.Magnitude
				if dist <= prof.range then
					local dir = offset.Unit
					local dot = look:Dot(dir)
					local minDot = math.cos(math.rad(prof.halfAngleDeg))
					if dot >= minDot then
						table.insert(targets, { hum = hum, dist = dist })
					end
				end
			end
		end
	end

	table.sort(targets, function(a, b) return a.dist < b.dist end)
	return targets
end

local function doSwing(plr: Player, char: Model, entry)
	if PauseState.Value then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	local wType = resolveWeaponType(entry)
	if typeof(wType) ~= "string" then return end

	local prof = Profiles[wType]
	if not prof then return end

	local dmg = calcBaseDamage(entry)
	local targets = pickTargets(hrp.Position, hrp.CFrame.LookVector, prof)
	if #targets == 0 then return end

	local hits = math.min(#targets, prof.maxHits or 1)
	for i = 1, hits do
		local t = targets[i]
		if t.hum and t.hum.Health > 0 then
			tagCreator(t.hum, plr)

			local dealt = dmg
			if i >= 2 and prof.falloff2 then
				dealt = dmg * prof.falloff2
			end

			pcall(function()
				t.hum:TakeDamage(dealt)
			end)
		end
	end
end

local loops: {[Player]: {alive: boolean}} = {}

local function startLoop(plr: Player, char: Model)
	if loops[plr] then loops[plr].alive = false end
	local state = { alive = true }
	loops[plr] = state

	task.spawn(function()
		local last = 0
		while state.alive and plr.Parent == Players do
			task.wait(0.05)

			if not char or not char.Parent then
				char = plr.Character
			end

			local entry = getActiveWeaponEntry(plr)
			if not entry then
				continue
			end

			local wType = resolveWeaponType(entry)
			local prof = wType and Profiles[wType]
			if not prof then
				continue
			end

			local now = time()
			if now - last >= prof.cd then
				last = now
				if char then
					doSwing(plr, char, entry)
				end
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
