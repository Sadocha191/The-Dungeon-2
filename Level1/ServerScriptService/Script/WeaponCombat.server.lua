-- WeaponCombat.server.lua (Level1)
-- Server-authoritative auto-attack: nearest enemy hit with optional AoE by weapon type.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local VFXEvent = Remotes:WaitForChild("WeaponSwingVFX")

local function findModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then return direct end
	local folder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then return nested end
	end
	return nil
end

local PlayerData = require(findModule("PlayerData") or error("[WeaponCombat] Missing PlayerData"))
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local WeaponConfigs = moduleFolder and moduleFolder:FindFirstChild("WeaponConfigs") and require(moduleFolder.WeaponConfigs) or nil

local ENEMIES = workspace:FindFirstChild("Enemies")
if not ENEMIES then
	ENEMIES = Instance.new("Folder")
	ENEMIES.Name = "Enemies"
	ENEMIES.Parent = workspace
end

local CD_BY_TYPE = {
	Sword = 0.55, Scythe = 0.80, Halberd = 0.75, Claymore = 0.95, Greataxe = 1.05,
	Bow = 0.65, Wand = 0.55, Staff = 0.75, Pistol = 0.45
}

local RANGE_BY_TYPE = {
	Sword = 9, Scythe = 10, Halberd = 12, Claymore = 10, Greataxe = 10,
	Bow = 60, Wand = 45, Staff = 50, Pistol = 55
}

local AOE_RADIUS_BY_TYPE = {
	Scythe = 7,
	Halberd = 6.5,
}

local function getLoadoutEntry(plr: Player)
	local data = PlayerData.Get(plr)
	if not data or typeof(data.Loadout) ~= "table" then return nil end
	return data.Loadout[1]
end

local function getWeaponDef(entry)
	local id = entry and (entry.id or entry.Id)
	if WeaponConfigs and WeaponConfigs.Get and typeof(id) == "string" then
		return WeaponConfigs.Get(id)
	end
	return nil
end

local function resolveWeaponType(entry)
	local def = getWeaponDef(entry)
	if def and typeof(def.weaponType) == "string" then
		return def.weaponType
	end
	return "Sword"
end

local function getAttrNum(plr: Player, name: string, fallback: number): number
	local v = plr:GetAttribute(name)
	if typeof(v) ~= "number" then
		return fallback
	end
	return v
end

local function isEliteEnemy(enemyModel: Model): boolean
	if enemyModel:GetAttribute("IsElite") == true then
		return true
	end
	return string.sub(enemyModel.Name, 1, 5) == "Boss_"
end

local function calcAttackStats(plr: Player, entry)
	local level = tonumber(entry and (entry.level or entry.Level)) or 1
	level = math.max(1, math.floor(level))

	local def = getWeaponDef(entry)
	local combat = def and def.combat or nil

	local base = 10
	local perLvl = 1
	if combat then
		base = tonumber(combat.baseAtk or def.baseDamage) or base
		perLvl = tonumber(combat.atkPerLevel) or perLvl
	end

	local pdata = PlayerData.Get(plr) or {}
	local damageMult = getAttrNum(plr, "ShrineDamageMult", 1)
	local runAtkMult = getAttrNum(plr, "RunAtkMult", 1)
	local attackSpeedBonus = getAttrNum(plr, "ShrineAttackSpeedBonus", 0)
	local critDamageBonus = getAttrNum(plr, "ShrineCritDamageBonus", 0)
	local lifestealBonus = getAttrNum(plr, "ShrineLifestealPct", 0)
	local eliteBonus = getAttrNum(plr, "ShrineEliteDamageBonus", 0)
	local knockbackMult = math.max(0, getAttrNum(plr, "ShrineKnockbackMult", 1))

	local baseDamage = (base + ((level - 1) * perLvl)) * runAtkMult * damageMult

	local critChance = (tonumber(pdata.baseCritRate) or 0.05) + (tonumber(pdata.critChance) or 0)
	local critMult = (tonumber(pdata.baseCritDmg) or 1.5) + (tonumber(pdata.critMult) or 0)
	local lifesteal = (tonumber(pdata.baseLifesteal) or 0) + (tonumber(pdata.lifesteal) or 0)

	if combat then
		critChance += tonumber(combat.bonusCritRate) or 0
		critMult += tonumber(combat.bonusCritDmg) or 0
		lifesteal += tonumber(combat.bonusLifesteal) or 0
	end

	critChance = math.clamp(critChance, 0, 0.95)
	critMult = math.max(1.1, critMult + critDamageBonus)
	lifesteal = math.clamp(lifesteal + lifestealBonus, 0, 0.9)

	local attackSpeedMult = math.max(0.1, (tonumber(pdata.attackSpeed) or 1) * (1 + attackSpeedBonus))
	local eliteMult = 1 + math.max(0, eliteBonus)

	return {
		baseDamage = baseDamage,
		critChance = critChance,
		critMult = critMult,
		lifesteal = lifesteal,
		attackSpeedMult = attackSpeedMult,
		eliteMult = eliteMult,
		knockbackPower = 8 * knockbackMult,
	}
end

local function ensureHealthbar(enemyModel: Model, hum: Humanoid)
	local hrp = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel:FindFirstChild("Head")
	if not hrp or not hrp:IsA("BasePart") then return end

	local existing = enemyModel:FindFirstChild("EnemyHealthbar")
	if existing and existing:IsA("BillboardGui") then
		existing.Enabled = true
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyHealthbar"
	gui.Adornee = hrp
	gui.Size = UDim2.fromOffset(120, 16)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = true

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundTransparency = 0
	fill.BorderSizePixel = 0
	fill.Parent = bg

	gui.Parent = enemyModel
end

local function updateHealthbar(enemyModel: Model, hum: Humanoid)
	local gui = enemyModel:FindFirstChild("EnemyHealthbar")
	if not gui or not gui:IsA("BillboardGui") then return end
	local bg = gui:FindFirstChild("BG")
	local fill = bg and bg:FindFirstChild("Fill")
	if not fill or not fill:IsA("Frame") then return end

	local maxH = math.max(1, hum.MaxHealth)
	local pct = math.clamp(hum.Health / maxH, 0, 1)
	fill.Size = UDim2.fromScale(pct, 1)

	if hum.Health <= 0 then
		gui.Enabled = false
	end
end

local function tagCreator(hum: Humanoid, plr: Player)
	local old = hum:FindFirstChild("creator")
	if old then old:Destroy() end
	local tag = Instance.new("ObjectValue")
	tag.Name = "creator"
	tag.Value = plr
	tag.Parent = hum
	task.delay(1, function()
		if tag and tag.Parent then tag:Destroy() end
	end)
end

local function nearestEnemy(fromPos: Vector3, maxRange: number)
	local best, bestDist = nil, maxRange
	for _, enemy in ipairs(ENEMIES:GetChildren()) do
		if enemy:IsA("Model") then
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				local d = (hrp.Position - fromPos).Magnitude
				if d < bestDist then
					bestDist = d
					best = enemy
				end
			end
		end
	end
	return best, bestDist
end

local function getEnemiesInRadius(fromPos: Vector3, radius: number)
	local hits = {}
	for _, enemy in ipairs(ENEMIES:GetChildren()) do
		if enemy:IsA("Model") then
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 and (hrp.Position - fromPos).Magnitude <= radius then
				table.insert(hits, enemy)
			end
		end
	end
	return hits
end

local loops = {}

local function startLoop(plr: Player)
	if loops[plr] then loops[plr].alive = false end
	local state = { alive = true }
	loops[plr] = state

	task.spawn(function()
		local last = 0
		while state.alive and plr.Parent do
			task.wait(0.05)

			if PauseState.Value then
				continue
			end

			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then
				continue
			end

			local entry = getLoadoutEntry(plr)
			if not entry then
				continue
			end

			local wType = resolveWeaponType(entry)
			local stats = calcAttackStats(plr, entry)
			local baseCd = CD_BY_TYPE[wType] or 0.7
			local cd = baseCd / stats.attackSpeedMult
			local range = RANGE_BY_TYPE[wType] or 10

			local now = time()
			if (now - last) < cd then
				continue
			end

			local enemy = nearestEnemy(hrp.Position, range)
			if not enemy then
				continue
			end

			last = now

			local eh = enemy:FindFirstChildOfClass("Humanoid")
			local ehrp = enemy:FindFirstChild("HumanoidRootPart")
			if not eh or not ehrp or eh.Health <= 0 then
				continue
			end

			if stats.baseDamage <= 0 then
				continue
			end

			local hitEnemies = { enemy }
			local aoeRadius = AOE_RADIUS_BY_TYPE[wType]
			if aoeRadius then
				hitEnemies = getEnemiesInRadius(ehrp.Position, aoeRadius)
			end

			local totalHeal = 0
			for _, enemyModel in ipairs(hitEnemies) do
				local enemyHum = enemyModel:FindFirstChildOfClass("Humanoid")
				local enemyHrp = enemyModel:FindFirstChild("HumanoidRootPart")
				if enemyHum and enemyHum.Health > 0 then
					local isCrit = math.random() < stats.critChance
					local dealt = stats.baseDamage
					if isCrit then
						dealt *= stats.critMult
					end
					if isEliteEnemy(enemyModel) then
						dealt *= stats.eliteMult
					end
					dealt = math.max(1, math.floor(dealt + 0.5))

					ensureHealthbar(enemyModel, enemyHum)
					tagCreator(enemyHum, plr)
					enemyHum:TakeDamage(dealt)
					updateHealthbar(enemyModel, enemyHum)

					if enemyHrp and stats.knockbackPower > 0 then
						local dir = enemyHrp.Position - hrp.Position
						if dir.Magnitude > 0.1 then
							enemyHrp.AssemblyLinearVelocity += dir.Unit * stats.knockbackPower
						end
					end

					if stats.lifesteal > 0 then
						totalHeal += dealt * stats.lifesteal
					end
				end
			end

			if totalHeal > 0 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + totalHeal)
			end

			local weaponId = entry.id or entry.Id or ""
			VFXEvent:FireAllClients({
				weaponId = weaponId,
				pos = ehrp.Position,
				lookAt = hrp.Position,
			})
		end
	end)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		startLoop(plr)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	if loops[plr] then
		loops[plr].alive = false
		loops[plr] = nil
	end
end)
