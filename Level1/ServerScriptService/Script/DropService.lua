-- DropService.server.lua (ServerScriptService) - orby + dalekie przyciąganie

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

local PULL_RADIUS = 60 -- było za mało
local PICKUP_DIST = 2.2

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
	p.Size = Vector3.new(0.55, 0.55, 0.55)
	p.CanCollide = false
	p.CanQuery = false
	p.Anchored = true
	p.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
	p.Parent = dropsFolder

	active[p] = {type = kind, amount = math.max(1, math.floor(amount)), born = time()}
	Debris:AddItem(p, 18)
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

		-- smooth pull from far
		if dist <= PULL_RADIUS then
			local target = hrp.Position + Vector3.new(0, 1.6, 0)
			local alpha = math.clamp(dt * 12, 0, 1)
			orb.CFrame = CFrame.new(orb.Position:Lerp(target, alpha))
		end
	end
end)
