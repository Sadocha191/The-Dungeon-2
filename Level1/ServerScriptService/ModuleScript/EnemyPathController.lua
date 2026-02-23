-- EnemyPathController.lua (SCRAPE VERSION)
-- No pathfinding. Chase straight to player.
-- If blocked by a wall/ledge, do smooth mantle (slow climb) to top surface, then step onto platform.
-- Includes Run/Stop to match WaveController expectations.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local EnemyPathController = {}
EnemyPathController.__index = EnemyPathController

-- ======================
-- TUNING
-- ======================
local MOVE_UPDATE_NEAR = 0.10   -- how often we call MoveTo when near
local MOVE_UPDATE_FAR  = 0.25   -- how often we call MoveTo when far
local NEAR_DIST = 40

-- Mantle detection
local FORWARD_CHECK_DIST = 3.0  -- how far ahead to check for a wall
local CHEST_Y = 2.2             -- ray origin height above root
local MAX_MANTLE_HEIGHT = 30.0  -- max climb height (set 25-40)
local MIN_MANTLE_HEIGHT = 0.75  -- ignore tiny bumps

-- Mantle motion (smooth)
local MANTLE_UP_TIME = 0.30
local MANTLE_FWD_TIME = 0.20
local MANTLE_FORWARD_STEP = 1.5
local MANTLE_COOLDOWN = 0.8

-- Clearance check
local CLEARANCE_UP = 4.0

-- ======================
-- helpers
-- ======================
local function flatDist(a: Vector3, b: Vector3)
	local d = a - b
	return math.sqrt(d.X*d.X + d.Z*d.Z)
end

local function unitXZ(v: Vector3)
	local xz = Vector3.new(v.X, 0, v.Z)
	if xz.Magnitude < 1e-6 then
		return Vector3.new(0, 0, -1)
	end
	return xz.Unit
end

local function getEnemiesFolder()
	return workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Mobs")
end

-- ======================
-- Controller
-- ======================
function EnemyPathController.new(mobModel: Model)
	local self = setmetatable({}, EnemyPathController)

	self.Mob = mobModel
	self.Root = mobModel:FindFirstChild("HumanoidRootPart") or mobModel.PrimaryPart
	self.Humanoid = mobModel:FindFirstChildOfClass("Humanoid")

	self.TargetPlayer = nil

	self._nextMoveT = 0
	self._nextMantleT = 0
	self._mantling = false
	self._hbConn = nil

	-- cached raycast params (ignore self + other mobs folder)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	self._rayParams = params

	return self
end

function EnemyPathController:Destroy()
	self:Stop()
end

function EnemyPathController:SetTargetPlayer(plr: Player?)
	self.TargetPlayer = plr
end

local function setRaycastIgnore(self)
	local enemiesFolder = getEnemiesFolder()
	self._rayParams.FilterDescendantsInstances = { self.Mob, enemiesFolder }
end

local function smoothMantle(self, upPos: Vector3, forwardPos: Vector3, forwardDir: Vector3)
	local root = self.Root
	local hum = self.Humanoid
	if not root or not hum then return false end

	-- cooldown
	local now = os.clock()
	if now < (self._nextMantleT or 0) then return false end
	self._nextMantleT = now + MANTLE_COOLDOWN

	self._mantling = true

	-- freeze physics briefly for stable tween
	local oldAutoRotate = hum.AutoRotate
	hum.AutoRotate = false

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true

	local f = unitXZ(forwardDir)
	local look = CFrame.lookAt(Vector3.zero, Vector3.new(f.X, 0, f.Z))
	local function cf(p) return CFrame.new(p) * look end

	local t1 = TweenService:Create(
		root,
		TweenInfo.new(MANTLE_UP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cf(upPos) }
	)
	local t2 = TweenService:Create(
		root,
		TweenInfo.new(MANTLE_FWD_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cf(forwardPos) }
	)

	t1:Play()
	t1.Completed:Wait()

	t2:Play()
	t2.Completed:Wait()

	root.Anchored = false
	hum.AutoRotate = oldAutoRotate

	self._mantling = false
	return true
end

function EnemyPathController:TryMantleToward(playerPos: Vector3)
	if self._mantling then return false end
	if not self.Root or not self.Humanoid then return false end
	if self.Humanoid.FloorMaterial == Enum.Material.Air then return false end

	setRaycastIgnore(self)

	local root = self.Root
	local hum = self.Humanoid

	local forward = unitXZ(playerPos - root.Position)

	-- 1) detect wall in front at chest height
	local chestOrigin = root.Position + Vector3.new(0, CHEST_Y, 0)
	local wallHit = workspace:Raycast(chestOrigin, forward * FORWARD_CHECK_DIST, self._rayParams)
	if not wallHit then
		return false
	end

	-- 2) find top surface by raycasting down from above the hit point
	local above = wallHit.Position + Vector3.new(0, MAX_MANTLE_HEIGHT + 3.0, 0)
	local downHit = workspace:Raycast(above, Vector3.new(0, -(MAX_MANTLE_HEIGHT + 6.0), 0), self._rayParams)
	if not downHit then
		return false
	end

	local height = downHit.Position.Y - root.Position.Y
	if height < MIN_MANTLE_HEIGHT or height > MAX_MANTLE_HEIGHT then
		return false
	end

	-- 3) clearance (no ceiling immediately above landing)
	local clearanceOrigin = downHit.Position + Vector3.new(0, hum.HipHeight + 1.5, 0)
	local clearanceHit = workspace:Raycast(clearanceOrigin, Vector3.new(0, CLEARANCE_UP, 0), self._rayParams)
	if clearanceHit then
		return false
	end

	-- 4) compute mantle positions: climb up in place then step forward onto platform
	local start = root.Position
	local upPos = Vector3.new(start.X, downHit.Position.Y + hum.HipHeight + 0.5, start.Z)

	local forwardPos = Vector3.new(
		upPos.X + forward.X * MANTLE_FORWARD_STEP,
		upPos.Y,
		upPos.Z + forward.Z * MANTLE_FORWARD_STEP
	)

	return smoothMantle(self, upPos, forwardPos, forward)
end

function EnemyPathController:Update(dt: number)
	if not self.Mob or not self.Root or not self.Humanoid then return end

	local plr = self.TargetPlayer
	if not plr or not plr.Character then return end

	local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local playerPos = hrp.Position
	local dist = flatDist(self.Root.Position, playerPos)

	local now = os.clock()
	local cadence = (dist <= NEAR_DIST) and MOVE_UPDATE_NEAR or MOVE_UPDATE_FAR
	if now < self._nextMoveT then return end
	self._nextMoveT = now + cadence

	-- if something blocks us, try mantle (slow climb). If mantling, do nothing else this tick.
	if self:TryMantleToward(playerPos) then
		return
	end

	-- otherwise, just go straight at the player
	self.Humanoid:MoveTo(playerPos)
end

-- ======================
-- Compatibility API (WaveController expects Run)
-- ======================
function EnemyPathController:Run(target)
	-- target może być Player albo Model/HRP – próbujemy wywnioskować Playera
	if typeof(target) == "Instance" then
		if target:IsA("Player") then
			self:SetTargetPlayer(target)
		elseif target:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(target)
			if p then self:SetTargetPlayer(p) end
		elseif target:IsA("BasePart") then
			local p = Players:GetPlayerFromCharacter(target.Parent)
			if p then self:SetTargetPlayer(p) end
		end
	end

	self:Stop()
	self._hbConn = RunService.Heartbeat:Connect(function(dt)
		if not self.Mob or not self.Mob.Parent then
			self:Stop()
			return
		end
		self:Update(dt)
	end)

	return self
end

function EnemyPathController:Stop()
	if self._hbConn then
		self._hbConn:Disconnect()
		self._hbConn = nil
	end
end

return EnemyPathController