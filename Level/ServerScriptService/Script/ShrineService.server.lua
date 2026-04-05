-- ShrineService.server.lua (Level1)
-- Spawns random charge shrines on map. Staying in range for 5s grants a random stat bonus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBounds = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("WorldBounds"))

local MIN_SHRINES = 10
local MAX_SHRINES = 20
local CHARGE_SECONDS = 5
local CHARGE_RADIUS = 12
local MIN_SHRINE_GAP = 22
local SHRINE_RAYCAST_TRIES = 45
local SHRINE_HEIGHT = 2.2

local SHIELD_REGEN_PER_SEC = 12

local RunStarted = ReplicatedStorage:FindFirstChild("RunStarted")
if not RunStarted then
	RunStarted = Instance.new("BoolValue")
	RunStarted.Name = "RunStarted"
	RunStarted.Value = false
	RunStarted.Parent = ReplicatedStorage
end

local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local WaveStatusEvent = Remotes:FindFirstChild("WaveStatusEvent")
if not WaveStatusEvent then
	WaveStatusEvent = Instance.new("RemoteEvent")
	WaveStatusEvent.Name = "WaveStatusEvent"
	WaveStatusEvent.Parent = Remotes
end

local shrinesFolder = workspace:FindFirstChild("Shrines")
if not shrinesFolder then
	shrinesFolder = Instance.new("Folder")
	shrinesFolder.Name = "Shrines"
	shrinesFolder.Parent = workspace
end

local shrines = {}
local spawnedForRun = false

local SHRINE_DEFAULTS = {
	ShrineDamageMult = 1,
	ShrineCritDamageBonus = 0,
	ShrineAttackSpeedBonus = 0,
	ShrinePickupRangeBonus = 0,
	ShrineLuckBonus = 0,
	ShrineProjectileBonus = 0,
	ShrineHpRegenFlat = 0,
	ShrineKnockbackMult = 1,
	ShrineDifficultyPct = 0,
	ShrineLifestealPct = 0,
	ShrinePowerupMult = 1,
	ShrineEliteDamageBonus = 0,
	ShrineDurationBonus = 0,
	ShrineJumpHeightBonus = 0,
	ShrineShieldMax = 0,
	ShrineShieldCurrent = 0,
	ShrineBuffCount = 0,
	ShrineMoveSpeedAdded = 0,
}

local BUFFS = {
	{ rarity = "Common", id = "damage_12", label = "Gain 12% Damage", value = 0.12 },
	{ rarity = "Common", id = "shield_5", label = "Gain +5 Shield", value = 5 },
	{ rarity = "Common", id = "pickup_20", label = "Gain 20% Pickup Range", value = 0.20 },
	{ rarity = "Common", id = "damage_10", label = "Gain 10% Damage", value = 0.10 },
	{ rarity = "Common", id = "crit_dmg_10", label = "Gain 10% Crit Damage", value = 0.10 },
	{ rarity = "Common", id = "luck_5", label = "Gain 5% Luck", value = 0.05 },
	{ rarity = "Common", id = "projectile_1", label = "Gain +1 Projectile Count", value = 1 },
	{ rarity = "Common", id = "hp_regen_20", label = "Gain +20 HP Regen", value = 20 },
	{ rarity = "Common", id = "knockback_10", label = "Gain 10% Knockback", value = 0.10 },
	{ rarity = "Uncommon", id = "knockback_12", label = "Gain 12% Knockback", value = 0.12 },
	{ rarity = "Uncommon", id = "atkspd_72", label = "Gain 7.2% Attack Speed", value = 0.072 },
	{ rarity = "Rare", id = "atkspd_84", label = "Gain 8.4% Attack Speed", value = 0.084 },
	{ rarity = "Common", id = "difficulty_8", label = "Gain 8% Difficulty", value = 0.08 },
	{ rarity = "Common", id = "lifesteal_6", label = "Gain 6% Lifesteal", value = 0.06 },
	{ rarity = "Common", id = "powerup_10", label = "Gain 10% Powerup Multiplier", value = 0.10 },
	{ rarity = "Common", id = "elite_dmg_10", label = "Gain 10% Damage to Elites", value = 0.10 },
	{ rarity = "Common", id = "duration_8", label = "Gain 8% Duration", value = 0.08 },
	{ rarity = "Common", id = "jump_10", label = "Gain 10% Jump Height", value = 0.10 },
	{ rarity = "Common", id = "move_8", label = "Gain 8% Movement Speed", value = 0.08 },
}

local BUFFS_BY_RARITY = {
	Common = {},
	Uncommon = {},
	Rare = {},
}
for _, buff in ipairs(BUFFS) do
	table.insert(BUFFS_BY_RARITY[buff.rarity], buff)
end

local function getNumAttr(plr, name, fallback)
	local v = plr:GetAttribute(name)
	if typeof(v) ~= "number" then
		return fallback
	end
	return v
end

local function setNumAttr(plr, name, value)
	plr:SetAttribute(name, tonumber(value) or 0)
end

local function ensurePlayerDefaults(plr)
	for attr, defaultValue in pairs(SHRINE_DEFAULTS) do
		if typeof(plr:GetAttribute(attr)) ~= "number" then
			setNumAttr(plr, attr, defaultValue)
		end
	end
end

local applyMovementBonus

local function resetPlayerBuffs(plr)
	local moveAdded = getNumAttr(plr, "ShrineMoveSpeedAdded", 0)
	if moveAdded ~= 0 then
		setNumAttr(plr, "RunBonusSpeed", math.max(0, getNumAttr(plr, "RunBonusSpeed", 0) - moveAdded))
	end

	for attr, defaultValue in pairs(SHRINE_DEFAULTS) do
		setNumAttr(plr, attr, defaultValue)
	end

	applyMovementBonus(plr)
end

local function applyJumpBonus(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	local baseJumpPower = getNumAttr(plr, "BaseJumpPower", 50)
	local jumpBonus = getNumAttr(plr, "ShrineJumpHeightBonus", 0)
	hum.JumpPower = baseJumpPower * (1 + jumpBonus)
end

applyMovementBonus = function(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	local baseSpeed = getNumAttr(plr, "BaseWalkSpeed", 21)
	local runBonusSpeed = getNumAttr(plr, "RunBonusSpeed", 0)
	hum.WalkSpeed = baseSpeed + runBonusSpeed
end

local function broadcast(payload)
	for _, plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

local function clearShrines()
	for _, shrine in ipairs(shrines) do
		if shrine.model and shrine.model.Parent then
			shrine.model:Destroy()
		end
	end
	table.clear(shrines)
end

local function buildRaycastIgnore()
	local list = {
		shrinesFolder,
		workspace:FindFirstChild("Enemies"),
		workspace:FindFirstChild("Drops"),
		workspace:FindFirstChild("Chests"),
		workspace:FindFirstChild("Statues"),
	}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	return list
end

local function buildOverlapIgnore()
	local list = {
		workspace:FindFirstChild("Enemies"),
		workspace:FindFirstChild("Drops"),
	}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	return list
end

local function farEnoughFromOthers(pos, used)
	for _, other in ipairs(used) do
		if (other - pos).Magnitude < MIN_SHRINE_GAP then
			return false
		end
	end
	return true
end

local function randomGroundPoint(existing)
	return WorldBounds.FindRandomTerrainPoint({
		pad = 20,
		tries = SHRINE_RAYCAST_TRIES,
		heightOffset = SHRINE_HEIGHT,
		raycastIgnoreInstances = buildRaycastIgnore(),
		overlapIgnoreInstances = buildOverlapIgnore(),
		clearanceRadius = 7,
		clearanceHeight = 9,
		maxSlopeDeg = 35,
		fallbackMin = Vector2.new(-180, -180),
		fallbackMax = Vector2.new(180, 180),
		isValid = function(pos)
			return farEnoughFromOthers(pos, existing)
		end,
	})
end

local function newPart(parent, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.Parent = parent
	return p
end

local function buildShrine(pos, idx)
	local model = Instance.new("Model")
	model.Name = ("Shrine_%d"):format(idx)

	local pedestal = newPart(model, "Pedestal", Vector3.new(8, 1.2, 8), Color3.fromRGB(68, 74, 87), Enum.Material.Slate)
	pedestal.CFrame = CFrame.new(pos - Vector3.new(0, 1.4, 0))
	pedestal.CanCollide = true

	local pillar = newPart(model, "Pillar", Vector3.new(1.6, 3.6, 1.6), Color3.fromRGB(100, 110, 128), Enum.Material.Rock)
	pillar.CFrame = CFrame.new(pos - Vector3.new(0, 0.1, 0))
	pillar.CanCollide = true

	local core = newPart(model, "Core", Vector3.new(2.2, 2.2, 2.2), Color3.fromRGB(0, 224, 196), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CFrame = CFrame.new(pos + Vector3.new(0, 2.7, 0))
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false

	local zone = newPart(
		model,
		"ChargeZone",
		Vector3.new(CHARGE_RADIUS * 2, CHARGE_RADIUS * 2, CHARGE_RADIUS * 2),
		Color3.fromRGB(0, 214, 186),
		Enum.Material.ForceField
	)
	zone.Shape = Enum.PartType.Ball
	zone.CFrame = core.CFrame
	zone.Transparency = 0.93
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 230, 197)
	light.Brightness = 2
	light.Range = CHARGE_RADIUS + 4
	light.Parent = core

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Billboard"
	billboard.Size = UDim2.fromOffset(240, 62)
	billboard.StudsOffset = Vector3.new(0, 2.9, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = core

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(235, 255, 250)
	text.TextStrokeTransparency = 0.25
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = "0%"
	text.Parent = billboard

	model.PrimaryPart = core
	model.Parent = shrinesFolder

	return {
		model = model,
		core = core,
		billboard = billboard,
		label = text,
		progress = {},
		completed = false,
	}
end

local function getAlivePlayers()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 and plr:GetAttribute("RunEnded") ~= true then
			table.insert(list, plr)
		end
	end
	return list
end

local function pickRarity(plr)
	local luck = math.max(0, getNumAttr(plr, "ShrineLuckBonus", 0))
	local commonW = math.max(10, 80 * (1 - luck * 0.9))
	local uncommonW = 16 * (1 + luck * 1.8)
	local rareW = 4 * (1 + luck * 2.4)

	local total = commonW + uncommonW + rareW
	local roll = math.random() * total
	if roll <= commonW then
		return "Common"
	end
	if roll <= commonW + uncommonW then
		return "Uncommon"
	end
	return "Rare"
end

local function pickRandomBuff(plr)
	local rarity = pickRarity(plr)
	local bucket = BUFFS_BY_RARITY[rarity]
	if not bucket or #bucket == 0 then
		bucket = BUFFS_BY_RARITY.Common
		rarity = "Common"
	end
	return bucket[math.random(1, #bucket)], rarity
end

local function applyBuff(plr, buff)
	ensurePlayerDefaults(plr)

	local powerMult = math.max(1, getNumAttr(plr, "ShrinePowerupMult", 1))
	local scaled = buff.value
	if buff.id ~= "powerup_10" then
		scaled = scaled * powerMult
	end

	if buff.id == "damage_12" or buff.id == "damage_10" then
		setNumAttr(plr, "ShrineDamageMult", getNumAttr(plr, "ShrineDamageMult", 1) * (1 + scaled))

	elseif buff.id == "shield_5" then
		local addShield = math.max(1, math.floor(scaled + 0.5))
		setNumAttr(plr, "ShrineShieldMax", getNumAttr(plr, "ShrineShieldMax", 0) + addShield)
		setNumAttr(plr, "ShrineShieldCurrent", getNumAttr(plr, "ShrineShieldCurrent", 0) + addShield)

	elseif buff.id == "pickup_20" then
		setNumAttr(plr, "ShrinePickupRangeBonus", getNumAttr(plr, "ShrinePickupRangeBonus", 0) + scaled)

	elseif buff.id == "crit_dmg_10" then
		setNumAttr(plr, "ShrineCritDamageBonus", getNumAttr(plr, "ShrineCritDamageBonus", 0) + scaled)

	elseif buff.id == "luck_5" then
		setNumAttr(plr, "ShrineLuckBonus", getNumAttr(plr, "ShrineLuckBonus", 0) + scaled)

	elseif buff.id == "projectile_1" then
		local addProj = math.max(1, math.floor(scaled + 0.5))
		setNumAttr(plr, "ShrineProjectileBonus", getNumAttr(plr, "ShrineProjectileBonus", 0) + addProj)

	elseif buff.id == "hp_regen_20" then
		setNumAttr(plr, "ShrineHpRegenFlat", getNumAttr(plr, "ShrineHpRegenFlat", 0) + scaled)

	elseif buff.id == "knockback_10" or buff.id == "knockback_12" then
		setNumAttr(plr, "ShrineKnockbackMult", getNumAttr(plr, "ShrineKnockbackMult", 1) * (1 + scaled))

	elseif buff.id == "atkspd_72" or buff.id == "atkspd_84" then
		setNumAttr(plr, "ShrineAttackSpeedBonus", getNumAttr(plr, "ShrineAttackSpeedBonus", 0) + scaled)

	elseif buff.id == "difficulty_8" then
		setNumAttr(plr, "ShrineDifficultyPct", getNumAttr(plr, "ShrineDifficultyPct", 0) + scaled)

	elseif buff.id == "lifesteal_6" then
		setNumAttr(plr, "ShrineLifestealPct", getNumAttr(plr, "ShrineLifestealPct", 0) + scaled)

	elseif buff.id == "powerup_10" then
		setNumAttr(plr, "ShrinePowerupMult", getNumAttr(plr, "ShrinePowerupMult", 1) * (1 + scaled))

	elseif buff.id == "elite_dmg_10" then
		setNumAttr(plr, "ShrineEliteDamageBonus", getNumAttr(plr, "ShrineEliteDamageBonus", 0) + scaled)

	elseif buff.id == "duration_8" then
		setNumAttr(plr, "ShrineDurationBonus", getNumAttr(plr, "ShrineDurationBonus", 0) + scaled)

	elseif buff.id == "jump_10" then
		setNumAttr(plr, "ShrineJumpHeightBonus", getNumAttr(plr, "ShrineJumpHeightBonus", 0) + scaled)
		applyJumpBonus(plr)

	elseif buff.id == "move_8" then
		local baseSpeed = getNumAttr(plr, "BaseWalkSpeed", 21)
		local addSpeed = baseSpeed * scaled
		setNumAttr(plr, "RunBonusSpeed", getNumAttr(plr, "RunBonusSpeed", 0) + addSpeed)
		setNumAttr(plr, "ShrineMoveSpeedAdded", getNumAttr(plr, "ShrineMoveSpeedAdded", 0) + addSpeed)
		applyMovementBonus(plr)
	end

	setNumAttr(plr, "ShrineBuffCount", getNumAttr(plr, "ShrineBuffCount", 0) + 1)
end

local function completeShrine(shrine, plr)
	shrine.completed = true

	local buff, rarity = pickRandomBuff(plr)
	applyBuff(plr, buff)

	if shrine.label then
		shrine.label.Text = "100%"
	end
	if shrine.billboard then
		shrine.billboard.Enabled = false
	end

	local zone = shrine.model:FindFirstChild("ChargeZone")
	if zone and zone:IsA("BasePart") then
		zone.Color = Color3.fromRGB(58, 255, 123)
		zone.Transparency = 0.96
	end
	local core = shrine.model:FindFirstChild("Core")
	if core and core:IsA("BasePart") then
		core.Color = Color3.fromRGB(55, 255, 135)
	end

	broadcast({
		type = "shrineComplete",
		playerName = plr.DisplayName ~= "" and plr.DisplayName or plr.Name,
		bonusName = buff.label,
		rarity = rarity,
	})

	task.delay(1.6, function()
		if shrine.model and shrine.model.Parent then
			shrine.model:Destroy()
		end
	end)
end

local function spawnShrinesForRun()
	if spawnedForRun then
		return
	end
	spawnedForRun = true

	for _, plr in ipairs(Players:GetPlayers()) do
		resetPlayerBuffs(plr)
		applyJumpBonus(plr)
	end

	clearShrines()

	local count = math.random(MIN_SHRINES, MAX_SHRINES)
	local usedPositions = {}
	for i = 1, count do
		local pos = randomGroundPoint(usedPositions)
		if pos then
			table.insert(usedPositions, pos)
			table.insert(shrines, buildShrine(pos, i))
		end
	end

end

_G.PrepareRunShrines = function()
	spawnShrinesForRun()
	return #shrines
end

_G.ApplyDamageToPlayer = function(plr, amount)
	if not plr or not plr.Parent then
		return 0
	end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return 0
	end

	ensurePlayerDefaults(plr)

	local incoming = math.max(0, tonumber(amount) or 0)
	incoming = incoming * (1 + getNumAttr(plr, "ShrineDifficultyPct", 0))

	local shield = math.max(0, getNumAttr(plr, "ShrineShieldCurrent", 0))
	if shield > 0 and incoming > 0 then
		local absorbed = math.min(shield, incoming)
		incoming -= absorbed
		setNumAttr(plr, "ShrineShieldCurrent", shield - absorbed)
	end

	if incoming > 0 then
		hum:TakeDamage(incoming)
	end
	return incoming
end

Players.PlayerAdded:Connect(function(plr)
	ensurePlayerDefaults(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.1)
		ensurePlayerDefaults(plr)
		applyJumpBonus(plr)
	end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
	ensurePlayerDefaults(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.1)
		ensurePlayerDefaults(plr)
		applyJumpBonus(plr)
	end)
end

RunStarted.Changed:Connect(function(v)
	if v == true then
		spawnShrinesForRun()
	else
		spawnedForRun = false
		clearShrines()
		for _, plr in ipairs(Players:GetPlayers()) do
			resetPlayerBuffs(plr)
			applyJumpBonus(plr)
		end
	end
end)

if RunStarted.Value == true then
	spawnShrinesForRun()
end

RunService.Heartbeat:Connect(function(dt)
	if RunStarted.Value and not PauseState.Value then
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local maxShield = math.max(0, getNumAttr(plr, "ShrineShieldMax", 0))
				local shield = math.max(0, getNumAttr(plr, "ShrineShieldCurrent", 0))
				if maxShield > 0 then
					if shield < maxShield then
						shield = math.min(maxShield, shield + SHIELD_REGEN_PER_SEC * dt)
						setNumAttr(plr, "ShrineShieldCurrent", shield)
					end
				elseif shield ~= 0 then
					setNumAttr(plr, "ShrineShieldCurrent", 0)
				end

				local hpRegen = math.max(0, getNumAttr(plr, "ShrineHpRegenFlat", 0))
				if hpRegen > 0 and hum.Health < hum.MaxHealth then
					hum.Health = math.min(hum.MaxHealth, hum.Health + hpRegen * dt)
				end

				applyJumpBonus(plr)
			end
		end
	end

	if not RunStarted.Value then
		return
	end
	if PauseState.Value then
		return
	end
	if #shrines == 0 then
		return
	end

	local alivePlayers = getAlivePlayers()
	if #alivePlayers == 0 then
		return
	end

	for _, shrine in ipairs(shrines) do
		if shrine.completed then
			continue
		end
		if not shrine.core or not shrine.core.Parent then
			continue
		end

		local topProgress = 0
		local anyoneCharging = false

		for _, plr in ipairs(alivePlayers) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				continue
			end

			local uid = plr.UserId
			local dist = (hrp.Position - shrine.core.Position).Magnitude
			local progress = shrine.progress[uid] or 0

			if dist <= CHARGE_RADIUS then
				progress = math.min(CHARGE_SECONDS, progress + dt)
				shrine.progress[uid] = progress
				anyoneCharging = true

				if progress >= CHARGE_SECONDS then
					completeShrine(shrine, plr)
					break
				end
			else
				progress = 0
				shrine.progress[uid] = nil
			end

			if progress > topProgress then
				topProgress = progress
			end
		end

		if shrine.completed then
			continue
		end

		if shrine.label then
			if anyoneCharging and topProgress > 0 then
				local pct = math.floor((topProgress / CHARGE_SECONDS) * 100 + 0.5)
				shrine.label.Text = ("%d%%"):format(math.clamp(pct, 0, 100))
				if shrine.billboard then shrine.billboard.Enabled = true end
			else
				if shrine.billboard then shrine.billboard.Enabled = false end
			end
		end
	end
end)

print("[ShrineService] Ready")
