-- SpellVFXClient.lua
-- Renders spell VFX locally (client-side) so orbiting effects stay perfectly attached to the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpellVFXEvent = remotes:WaitForChild("SpellVFXEvent")

local vfxRoot = workspace:FindFirstChild("SpellVFX")
if not vfxRoot then
	vfxRoot = Instance.new("Folder")
	vfxRoot.Name = "SpellVFX"
	vfxRoot.Parent = workspace
end

local active = {} -- id -> {params..., parts={}, t=0}

local function getHRP()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function applyPartDefaults(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function ensureParts(id: string, cfg)
	cfg.parts = cfg.parts or {}
	while #cfg.parts < (cfg.count or 0) do
		local p = Instance.new("Part")
		p.Name = id .. "_Orb"
		p.Shape = Enum.PartType.Ball
		applyPartDefaults(p)
		p.Parent = vfxRoot
		table.insert(cfg.parts, p)
	end
	while #cfg.parts > (cfg.count or 0) do
		local p = table.remove(cfg.parts)
		pcall(function() p:Destroy() end)
	end

	local size = tonumber(cfg.size) or 1.2
	local transparency = tonumber(cfg.transparency) or 0.25
	local color = typeof(cfg.color) == "Color3" and cfg.color or Color3.fromRGB(255, 255, 255)
	for _, p in ipairs(cfg.parts) do
		p.Size = Vector3.new(size, size, size)
		p.Transparency = transparency
		p.Color = color
	end
end

SpellVFXEvent.OnClientEvent:Connect(function(id: string, enabled: boolean, params)
	if not enabled then
		local cfg = active[id]
		if cfg and cfg.parts then
			for _, p in ipairs(cfg.parts) do
				pcall(function() p:Destroy() end)
			end
		end
		active[id] = nil
		return
	end

	params = params or {}
	local cfg = active[id]
	if not cfg then
		cfg = { parts = {}, t = 0 }
		active[id] = cfg
	end

	cfg.count = tonumber(params.count) or cfg.count or 0
	cfg.radius = tonumber(params.radius) or cfg.radius or 5
	cfg.orbitSpeed = tonumber(params.orbitSpeed) or cfg.orbitSpeed or 2
	cfg.height = tonumber(params.height) or cfg.height or 1.5
	cfg.size = tonumber(params.size) or cfg.size or 1.2
	cfg.transparency = tonumber(params.transparency) or cfg.transparency or 0.25
	cfg.color = typeof(params.color) == "Color3" and params.color or cfg.color

	ensureParts(id, cfg)
end)

RunService.RenderStepped:Connect(function(dt)
	local hrp = getHRP()
	if not hrp then return end

	-- IMPORTANT:
	-- Orbit must be independent from character rotation.
	-- Use world-space offsets from HRP position, not HRP.CFrame (which would add rotation).
	local basePos = hrp.Position
	for id, cfg in pairs(active) do
		local count = cfg.count or 0
		if count <= 0 then
			-- safety: cleanup
			if cfg.parts then
				for _, p in ipairs(cfg.parts) do pcall(function() p:Destroy() end) end
			end
			active[id] = nil
		else
			cfg.t = (cfg.t or 0) + (cfg.orbitSpeed or 2) * dt
			local t0 = cfg.t
			local radius = cfg.radius or 5
			local height = cfg.height or 1.5

			for i = 1, count do
				local p = cfg.parts[i]
				if p then
					local ang = t0 + (i / math.max(1, count)) * math.pi * 2
					local offset = Vector3.new(math.cos(ang) * radius, height, math.sin(ang) * radius)
					p.CFrame = CFrame.new(basePos + offset)
				end
			end
		end
	end
end)
