-- DropService.server.lua (ServerScriptService)
-- Orby XP i monet + przyciąganie (jedna pętla Heartbeat)

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
	p.Transparency = 0
	p.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
	p.Parent = dropsFolder

	active[p] = {type = kind, amount = math.max(1, math.floor(amount)), born = time()}
	Debris:AddItem(p, 16) -- po 16s znika

	return p
end

-- API: wołane przez WaveController
function _G.SpawnDropsAt(pos: Vector3, xp: number, coins: number)
	-- lekki rozrzut
	local function jitter()
		return Vector3.new((math.random()-0.5)*2.0, 0, (math.random()-0.5)*2.0)
	end

	if xp and xp > 0 then
		makeOrb("xp", xp, pos + jitter())
	end
	if coins and coins > 0 then
		makeOrb("coins", coins, pos + jitter())
	end
end

-- jedna pętla update (bez per-orb tasków)
RunService.Heartbeat:Connect(function(dt)
	for orb,meta in pairs(active) do
		if not orb or not orb.Parent then
			active[orb] = nil
			continue
		end

		local plr, dist = nearestAlivePlayer(orb.Position)
		local age = time() - meta.born

		-- jeśli nikt żywy -> powoli opada/znika
		if not plr then
			orb.CFrame = orb.CFrame:Lerp(orb.CFrame + Vector3.new(0, -0.05, 0), 0.12)
			if age > 14 then
				orb:Destroy()
				active[orb] = nil
			end
			continue
		end

		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		-- przyciąganie od 28 studów
		local pullRadius = 28
		if dist <= 2.0 then
			-- zebrane
			if _G.AwardPlayer then
				if meta.type == "xp" then
					_G.AwardPlayer(plr, meta.amount, 0)
				else
					_G.AwardPlayer(plr, 0, meta.amount)
				end
			end
			orb:Destroy()
			active[orb] = nil
			continue
		end

		local targetPos = orb.Position
		if dist <= pullRadius then
			targetPos = hrp.Position + Vector3.new(0, 1.6, 0)
			local alpha = math.clamp(dt * 10, 0, 1) -- płynnie, bez “teleportów”
			orb.CFrame = CFrame.new(orb.Position:Lerp(targetPos, alpha))
		else
			-- idle “float”
			local bob = math.sin(time()*2.4) * 0.03
			orb.CFrame = orb.CFrame + Vector3.new(0, bob, 0)
		end
	end
end)
