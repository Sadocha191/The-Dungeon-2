-- WeaponCombat.server.lua (Level1)
-- Server-authoritative auto-attack: 360° hit nearest enemy. VFX spawns at hit position only when damage is applied.

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
-- optional weapon configs
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local WeaponConfigs = moduleFolder and moduleFolder:FindFirstChild("WeaponConfigs") and require(moduleFolder.WeaponConfigs) or nil

-- Ensure Enemies folder exists (WaveController usually creates it, but be safe)
local ENEMIES = workspace:FindFirstChild("Enemies")
if not ENEMIES then
	ENEMIES = Instance.new("Folder")
	ENEMIES.Name = "Enemies"
	ENEMIES.Parent = workspace
end

-- simple per-weaponType cooldown defaults
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

local function resolveWeaponType(entry)
	local id = entry and (entry.id or entry.Id)
	if typeof(id) ~= "string" then return nil end
	if WeaponConfigs and WeaponConfigs.Get then
		local def = WeaponConfigs.Get(id)
		if def and typeof(def.weaponType) == "string" then
			return def.weaponType
		end
	end
	-- fallback: treat melee names as sword unless known
	return "Sword"
end

local function calcDamage(plr: Player, entry)
	local id = entry and (entry.id or entry.Id)
	local lvl = tonumber(entry and (entry.level or entry.Level)) or 1
	lvl = math.max(1, math.floor(lvl))

	local base = 10
	local perLvl = 1.0
	if WeaponConfigs and WeaponConfigs.Get and typeof(id) == "string" then
		local def = WeaponConfigs.Get(id)
		if def and def.combat then
			base = tonumber(def.combat.baseAtk or def.baseDamage) or base
			perLvl = tonumber(def.combat.atkPerLevel) or perLvl
		end
	end
	return base + (lvl - 1) * perLvl
end

local function ensureHealthbar(enemyModel: Model, hum: Humanoid)
	-- create once, show after damage
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

	-- hide when dead
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
			local cd = CD_BY_TYPE[wType] or 0.7
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

			local dmg = calcDamage(plr, entry)
			if dmg <= 0 then
				continue
			end

			local hitEnemies = { enemy }
			local aoeRadius = AOE_RADIUS_BY_TYPE[wType]
			if aoeRadius then
				hitEnemies = getEnemiesInRadius(ehrp.Position, aoeRadius)
			end

			for _, enemyModel in ipairs(hitEnemies) do
				local enemyHum = enemyModel:FindFirstChildOfClass("Humanoid")
				if enemyHum and enemyHum.Health > 0 then
					ensureHealthbar(enemyModel, enemyHum)
					tagCreator(enemyHum, plr)
					enemyHum:TakeDamage(dmg)
					updateHealthbar(enemyModel, enemyHum)
				end
			end

			-- VFX at enemy position (client local)
			local weaponId = entry.id or entry.Id or ""
			VFXEvent:FireAllClients({
				weaponId = weaponId,
				pos = ehrp.Position,
				lookAt = hrp.Position, -- face back to player
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
