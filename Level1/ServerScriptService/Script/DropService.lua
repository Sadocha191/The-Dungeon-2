-- DropService.server.lua (ServerScriptService) - większe orby, bez fizyki, wolne przyciąganie z bliska

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local dropsFolder = workspace:FindFirstChild("Drops")
if not dropsFolder then
	dropsFolder = Instance.new("Folder")
	dropsFolder.Name = "Drops"
	dropsFolder.Parent = workspace
end

local active = {} -- [part] = {type="xp"/"coins", amount=number}

local ATTRACT_RADIUS = 8 -- przyciąganie dopiero z bliska
local PICKUP_DIST = 2.5
local ATTRACT_SPEED_MULT = 1.15 -- trochę szybciej od aktualnej prędkości gracza
local ATTRACT_SPEED_BONUS = 4 -- zapas na przyszłe boosty prędkości
local ATTRACT_SPEED_MIN = 22 -- minimalna prędkość przyciągania (studs/s)

local ORB_SIZE = Vector3.new(1, 1, 1) -- większe orby
local ORB_HALF_HEIGHT = ORB_SIZE.Y * 0.5
local ORB_SPAWN_HEIGHT = 2.5

local GROUND_RAY_PARAMS = RaycastParams.new()
GROUND_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist
GROUND_RAY_PARAMS.IgnoreWater = false

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

local function makeOrb(kind: "xp" | "coins", amount: number, pos: Vector3)
	local p = Instance.new("Part")
	p.Name = (kind == "xp") and "XPOrb" or "CoinOrb"
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = (kind == "xp") and Color3.fromRGB(96, 165, 250) or Color3.fromRGB(255, 180, 60)
	p.Size = ORB_SIZE
	p.CanCollide = false
	p.CanQuery = false
	p.Anchored = true -- bez fizyki
	p.CFrame = CFrame.new(getGroundedPosition(pos))
	p.Parent = dropsFolder
	p.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 6, math.random(5, 8), (math.random() - 0.5) * 6)
	p.AssemblyAngularVelocity = Vector3.new((math.random() - 0.5) * 5, (math.random() - 0.5) * 5, (math.random() - 0.5) * 5)

	active[p] = { type = kind, amount = math.max(1, math.floor(amount)) }
	return p
end

function _G.SpawnDropsAt(pos: Vector3, xp: number, coins: number)
	local function jitter()
		return Vector3.new((math.random() - 0.5) * 2.6, 0, (math.random() - 0.5) * 2.6)
	end
	if xp and xp > 0 then makeOrb("xp", xp, pos + jitter()) end
	if coins and coins > 0 then makeOrb("coins", coins, pos + jitter()) end
end

RunService.Heartbeat:Connect(function(dt)
	for orb, meta in pairs(active) do
		if not orb or not orb.Parent then
			active[orb] = nil
			continue
		end

		local plr, dist = nearestAlivePlayer(orb.Position)
		if not plr then
			continue -- orby nie znikają
		end

		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp then continue end

		if dist <= PICKUP_DIST then
			if _G.AwardPlayer then
				if meta.type == "xp" then _G.AwardPlayer(plr, meta.amount, 0)
				else _G.AwardPlayer(plr, 0, meta.amount) end
			end
			orb:Destroy()
			active[orb] = nil
			continue
		end

		if dist <= ATTRACT_RADIUS then
			local target = hrp.Position + Vector3.new(0, 1.6, 0)
			local toTarget = target - orb.Position
			local toTargetDist = toTarget.Magnitude
			if toTargetDist > 0 then
				local walkSpeed = (hum and hum.WalkSpeed) or 16
				local attractSpeed = math.max(ATTRACT_SPEED_MIN, walkSpeed * ATTRACT_SPEED_MULT + ATTRACT_SPEED_BONUS)
				local step = math.min(toTargetDist, attractSpeed * dt)
				orb.CFrame = CFrame.new(orb.Position + toTarget.Unit * step)
			end
		end
	end
end)
