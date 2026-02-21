-- DropService.server.lua (ServerScriptService) - orby z fizyką + przyciąganie z bliska

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local dropsFolder = workspace:FindFirstChild("Drops")
if not dropsFolder then
	dropsFolder = Instance.new("Folder")
	dropsFolder.Name = "Drops"
	dropsFolder.Parent = workspace
end

local active = {} -- [part] = {type="xp"/"coins", amount=number, born=number}

local ATTRACT_RADIUS = 8 -- przyciąganie dopiero z bliska
local PICKUP_DIST = 2.5

local ORB_LIFETIME = 18
local ORB_SPAWN_HEIGHT = 2.5

local ORB_SIZE = Vector3.new(0.55, 0.55, 0.55)
local ORB_HALF_HEIGHT = ORB_SIZE.Y * 0.5
local ORB_PHYS = PhysicalProperties.new(0.6, 0.95, 0.2, 1, 1)

local GROUND_RAY_PARAMS = RaycastParams.new()
GROUND_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist
GROUND_RAY_PARAMS.IgnoreWater = false

local function getGroundedPosition(pos: Vector3)
	GROUND_RAY_PARAMS.FilterDescendantsInstances = {dropsFolder}
	local origin = pos + Vector3.new(0, 10, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -80, 0), GROUND_RAY_PARAMS)
	if result then
		return Vector3.new(pos.X, result.Position.Y + ORB_HALF_HEIGHT + 0.04, pos.Z)
	end
	return pos + Vector3.new(0, ORB_SPAWN_HEIGHT, 0)
end

local function nearestAlivePlayer(pos: Vector3)
	local bestPlr, bestDist = nil, math.huge
	for _,plr in ipairs(Players:GetPlayers()) do
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

local function makeOrb(kind: "xp"|"coins", amount: number, pos: Vector3)
	local p = Instance.new("Part")
	p.Name = (kind == "xp") and "XPOrb" or "CoinOrb"
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = (kind == "xp") and Color3.fromRGB(96,165,250) or Color3.fromRGB(255,180,60)
	p.Size = ORB_SIZE
	p.CanCollide = true
	p.CanQuery = false
	p.Anchored = false
	p.CustomPhysicalProperties = ORB_PHYS
	p.Position = getGroundedPosition(pos)
	p.Parent = dropsFolder
	p.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 6, math.random(5, 8), (math.random() - 0.5) * 6)
	p.AssemblyAngularVelocity = Vector3.new((math.random() - 0.5) * 5, (math.random() - 0.5) * 5, (math.random() - 0.5) * 5)

	active[p] = {type = kind, amount = math.max(1, math.floor(amount)), born = time()}
	Debris:AddItem(p, ORB_LIFETIME)
	return p
end

function _G.SpawnDropsAt(pos: Vector3, xp: number, coins: number)
	local function jitter()
		return Vector3.new((math.random()-0.5)*2.6, 0, (math.random()-0.5)*2.6)
	end
	if xp and xp > 0 then makeOrb("xp", xp, pos + jitter()) end
	if coins and coins > 0 then makeOrb("coins", coins, pos + jitter()) end
end

RunService.Heartbeat:Connect(function(dt)
	for orb,meta in pairs(active) do
		if not orb or not orb.Parent then
			active[orb] = nil
			continue
		end

		local plr, dist = nearestAlivePlayer(orb.Position)
		local age = time() - meta.born

		if not plr then
			if age > 16 then
				orb:Destroy()
				active[orb] = nil
			end
			continue
		end

		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
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

		-- orb "budzi się" i leci do gracza dopiero przy bliskim dystansie
		if dist <= ATTRACT_RADIUS then
			orb.CanCollide = false
			local target = hrp.Position + Vector3.new(0, 1.6, 0)
			local alpha = math.clamp(dt * 12, 0, 1)
			local nextPos = orb.Position:Lerp(target, alpha)
			orb.AssemblyLinearVelocity = Vector3.zero
			orb.AssemblyAngularVelocity = Vector3.zero
			orb.CFrame = CFrame.new(nextPos)
		else
			orb.CanCollide = true
		end
	end
end)
