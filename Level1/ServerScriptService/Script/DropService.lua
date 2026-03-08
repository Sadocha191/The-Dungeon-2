-- DropService.server.lua (ServerScriptService) - larger orbs, no physics, close-range magnet

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local dropsFolder = workspace:FindFirstChild("Drops")
if not dropsFolder then
	dropsFolder = Instance.new("Folder")
	dropsFolder.Name = "Drops"
	dropsFolder.Parent = workspace
end

local active = {} -- [part] = {type="xp"/"coins"/"souls", amount=number}
local activeGlobalMagnets = {} -- [userId] = { player = Player, expiresAt = number }

local ATTRACT_RADIUS = 8
local PICKUP_DIST = 2.5
local ATTRACT_SPEED_MULT = 1.15
local ATTRACT_SPEED_BONUS = 4
local ATTRACT_SPEED_MIN = 22
local GLOBAL_MAGNET_SPEED = 180

local ORB_SIZE = Vector3.new(1, 1, 1)
local ORB_HALF_HEIGHT = ORB_SIZE.Y * 0.5
local ORB_SPAWN_HEIGHT = 2.5

local GROUND_RAY_PARAMS = RaycastParams.new()
GROUND_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist
GROUND_RAY_PARAMS.IgnoreWater = false

local function getPickupRangeMult(plr)
	local bonus = plr and plr:GetAttribute("ShrinePickupRangeBonus")
	if typeof(bonus) ~= "number" then
		return 1
	end
	return math.max(0.1, 1 + bonus)
end

local function getGroundedPosition(pos: Vector3)
	local ignore = {dropsFolder}

	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then table.insert(ignore, enemiesFolder) end

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(ignore, plr.Character) end
	end

	GROUND_RAY_PARAMS.FilterDescendantsInstances = ignore

	local origin = pos + Vector3.new(0, 10, 0)
	local direction = Vector3.new(0, -120, 0)
	local result = workspace:Raycast(origin, direction, GROUND_RAY_PARAMS)
	if result then
		local grounded = result.Position + result.Normal * ORB_HALF_HEIGHT
		return Vector3.new(grounded.X, grounded.Y, grounded.Z)
	end

	return pos + Vector3.new(0, ORB_SPAWN_HEIGHT, 0)
end

local function nearestAlivePlayer(pos: Vector3)
	local bestPlr, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if hrp and h and h.Health > 0 then
			local d = (hrp.Position - pos).Magnitude
			if d < bestDist then
				bestDist = d
				bestPlr = plr
			end
		end
	end
	return bestPlr, bestDist
end

local function cleanupGlobalMagnets()
	local now = os.clock()
	for userId, info in pairs(activeGlobalMagnets) do
		local plr = info.player
		local char = plr and plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if info.expiresAt <= now or not plr or not plr.Parent or not hrp or not hum or hum.Health <= 0 then
			activeGlobalMagnets[userId] = nil
		end
	end
end

local function getGlobalMagnetTarget(pos: Vector3, kind: string)
	if kind ~= "xp" and kind ~= "coins" then
		return nil, math.huge
	end

	local bestPlr, bestDist = nil, math.huge
	for _, info in pairs(activeGlobalMagnets) do
		local plr = info.player
		local char = plr and plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local dist = (hrp.Position - pos).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestPlr = plr
			end
		end
	end

	return bestPlr, bestDist
end

local function makeOrb(kind: "xp" | "coins" | "souls", amount: number, pos: Vector3)
	local p = Instance.new("Part")
	if kind == "xp" then
		p.Name = "XPOrb"
	elseif kind == "coins" then
		p.Name = "CoinOrb"
	else
		p.Name = "SoulOrb"
	end
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	if kind == "xp" then
		p.Color = Color3.fromRGB(96, 165, 250)
	elseif kind == "coins" then
		p.Color = Color3.fromRGB(255, 180, 60)
	else
		p.Color = Color3.fromRGB(168, 85, 247)
	end
	p.Size = ORB_SIZE
	p.CanCollide = false
	p.CanQuery = false
	p.Anchored = true
	p.CFrame = CFrame.new(getGroundedPosition(pos))
	p.Parent = dropsFolder
	p.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 6, math.random(5, 8), (math.random() - 0.5) * 6)
	p.AssemblyAngularVelocity = Vector3.new((math.random() - 0.5) * 5, (math.random() - 0.5) * 5, (math.random() - 0.5) * 5)

	active[p] = { type = kind, amount = math.max(1, math.floor(amount)) }
	return p
end

function _G.SpawnDropsAt(pos: Vector3, xp: number, coins: number, souls: number)
	local function jitter()
		return Vector3.new((math.random() - 0.5) * 2.6, 0, (math.random() - 0.5) * 2.6)
	end
	if xp and xp > 0 then makeOrb("xp", xp, pos + jitter()) end
	if coins and coins > 0 then makeOrb("coins", coins, pos + jitter()) end
	if souls and souls > 0 then makeOrb("souls", souls, pos + jitter()) end
end

function _G.ActivateGlobalMagnet(plr: Player, duration: number)
	if not plr or not plr.Parent then
		return false
	end

	activeGlobalMagnets[plr.UserId] = {
		player = plr,
		expiresAt = os.clock() + math.max(1, tonumber(duration) or 10),
	}
	return true
end

RunService.Heartbeat:Connect(function(dt)
	cleanupGlobalMagnets()

	for orb, meta in pairs(active) do
		if not orb or not orb.Parent then
			active[orb] = nil
			continue
		end

		local plr, dist = getGlobalMagnetTarget(orb.Position, meta.type)
		local usingGlobalMagnet = plr ~= nil
		if not plr then
			plr, dist = nearestAlivePlayer(orb.Position)
		end
		if not plr then
			continue
		end

		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp then continue end

		local pickupMult = getPickupRangeMult(plr)
		local pickupDist = PICKUP_DIST * pickupMult
		local attractRadius = ATTRACT_RADIUS * pickupMult

		if dist <= pickupDist then
			if meta.type == "xp" then
				if _G.AwardPlayer then _G.AwardPlayer(plr, meta.amount, 0) end
			elseif meta.type == "coins" then
				if _G.AwardPlayer then _G.AwardPlayer(plr, 0, meta.amount) end
			elseif meta.type == "souls" then
				if _G.AwardSouls then _G.AwardSouls(plr, meta.amount) end
			end
			orb:Destroy()
			active[orb] = nil
			continue
		end

		if usingGlobalMagnet or dist <= attractRadius then
			local target = hrp.Position + Vector3.new(0, 1.6, 0)
			local toTarget = target - orb.Position
			local toTargetDist = toTarget.Magnitude
			if toTargetDist > 0 then
				local walkSpeed = (hum and hum.WalkSpeed) or 16
				local attractSpeed
				if usingGlobalMagnet then
					attractSpeed = math.max(GLOBAL_MAGNET_SPEED, walkSpeed * 6)
				else
					attractSpeed = math.max(ATTRACT_SPEED_MIN, walkSpeed * ATTRACT_SPEED_MULT + ATTRACT_SPEED_BONUS)
				end
				local step = math.min(toTargetDist, attractSpeed * dt)
				orb.CFrame = CFrame.new(orb.Position + toTarget.Unit * step)
			end
		end
	end
end)
