local PathfindingService = game:GetService("PathfindingService")

local EnemyPathController = {}
EnemyPathController.__index = EnemyPathController

local DEFAULT_PATH_PARAMS = {
	AgentRadius = 2.5,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = true,
	AgentJumpHeight = 7,
	AgentMaxSlope = 35,
	WaypointSpacing = 5,
}

local function waitForMoveTo(humanoid: Humanoid, timeoutSec: number): (boolean, string?)
	local done = false
	local reached = false
	local conn: RBXScriptConnection? = nil

	conn = humanoid.MoveToFinished:Connect(function(ok)
		reached = ok
		done = true
	end)

	local startedAt = time()
	while not done and (time() - startedAt) < timeoutSec do
		task.wait(0.03)
	end

	if conn then
		conn:Disconnect()
	end

	if done and reached then
		return true, nil
	end

	if done then
		return false, "move_failed"
	end

	return false, "move_timeout"
end

function EnemyPathController.new(mob: Model, options)
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local hrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
	if not hum or not hrp then
		return nil
	end

	local self = setmetatable({}, EnemyPathController)
	self.Mob = mob
	self.Humanoid = hum
	self.RootPart = hrp
	self.Options = options or {}
	self.PathParams = self.Options.PathParams or DEFAULT_PATH_PARAMS
	self.RepathDistance = self.Options.RepathDistance or 10
	self.ComputeCooldown = self.Options.ComputeCooldown or 0.35
	self.MoveTimeout = self.Options.MoveTimeout or 2.0
	self.LOSUpdateInterval = self.Options.LOSUpdateInterval or 0.12

	self.LastTargetPos = nil
	self.LastComputeAt = 0
	self.CurrentPath = nil
	self.CurrentWaypoints = nil
	self.CurrentWaypointIndex = 1
	self.BlockedConnection = nil
	self.RepathRequested = false
	self.RepathReason = nil
	self.ConsecutiveRepathFails = 0
	self.LastLOSDirectMove = 0

	return self
end

function EnemyPathController:AcquireTarget(): BasePart?
	local getter = self.Options.GetTarget
	if typeof(getter) == "function" then
		return getter(self.RootPart.Position)
	end
	return nil
end

function EnemyPathController:HasLineOfSight(targetHRP: BasePart): boolean
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { self.Mob }
	rayParams.IgnoreWater = true

	local origin = self.RootPart.Position
	local direction = targetHRP.Position - origin
	local result = workspace:Raycast(origin, direction, rayParams)
	if not result then
		return true
	end

	return result.Instance ~= nil and result.Instance:IsDescendantOf(targetHRP.Parent)
end

function EnemyPathController:RequestRepath(reason: string)
	self.RepathRequested = true
	self.RepathReason = reason
end

function EnemyPathController:DisconnectPathSignals()
	if self.BlockedConnection then
		self.BlockedConnection:Disconnect()
		self.BlockedConnection = nil
	end
end

function EnemyPathController:ComputePath(targetPos: Vector3): boolean
	local now = time()
	if (now - self.LastComputeAt) < self.ComputeCooldown then
		return false
	end

	self.LastComputeAt = now
	self:DisconnectPathSignals()

	local path = PathfindingService:CreatePath(self.PathParams)
	path:ComputeAsync(self.RootPart.Position, targetPos)

	if path.Status ~= Enum.PathStatus.Success then
		self.CurrentPath = nil
		self.CurrentWaypoints = nil
		self.CurrentWaypointIndex = 1
		self.ConsecutiveRepathFails += 1
		return false
	end

	self.CurrentPath = path
	self.CurrentWaypoints = path:GetWaypoints()
	self.CurrentWaypointIndex = 1
	self.LastTargetPos = targetPos
	self.RepathRequested = false
	self.RepathReason = nil
	self.ConsecutiveRepathFails = 0

	self.BlockedConnection = path.Blocked:Connect(function(blockedWaypointIdx)
		if blockedWaypointIdx >= self.CurrentWaypointIndex then
			self:RequestRepath("path_blocked")
		end
	end)

	if self.CurrentWaypoints[1] and (self.CurrentWaypoints[1].Position - self.RootPart.Position).Magnitude <= 3 then
		self.CurrentWaypointIndex = 2
	end

	return true
end

function EnemyPathController:ClearPath()
	self:DisconnectPathSignals()
	self.CurrentPath = nil
	self.CurrentWaypoints = nil
	self.CurrentWaypointIndex = 1
end

function EnemyPathController:FollowPath()
	if not self.CurrentWaypoints or not self.CurrentWaypoints[self.CurrentWaypointIndex] then
		return false
	end

	local waypoint = self.CurrentWaypoints[self.CurrentWaypointIndex]
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	self.Humanoid:MoveTo(waypoint.Position)
	local ok, failReason = waitForMoveTo(self.Humanoid, self.MoveTimeout)
	if not ok then
		self:RequestRepath(failReason or "move_failed")
		self.ConsecutiveRepathFails += 1
		return false
	end

	self.CurrentWaypointIndex += 1
	if not self.CurrentWaypoints[self.CurrentWaypointIndex] then
		self:ClearPath()
		return true
	end

	return true
end

function EnemyPathController:TryUnstuckStep()
	if self.ConsecutiveRepathFails < 3 then
		return
	end

	self.ConsecutiveRepathFails = 0
	local side = self.RootPart.CFrame.RightVector * (math.random(0, 1) == 0 and -1 or 1)
	local offset = side * (4 + math.random() * 3)
	self.Humanoid:MoveTo(self.RootPart.Position + offset)
	task.wait(0.25)
	self:RequestRepath("unstuck")
end

function EnemyPathController:Run()
	task.spawn(function()
		while self.Mob.Parent and self.Humanoid.Health > 0 do
			local targetHRP = self:AcquireTarget()
			if not targetHRP then
				task.wait(0.15)
				continue
			end

			local now = time()
			local targetPos = targetHRP.Position
			local movedEnough = self.LastTargetPos and (targetPos - self.LastTargetPos).Magnitude > self.RepathDistance
			if movedEnough then
				self:RequestRepath("target_moved")
			end

			local los = self:HasLineOfSight(targetHRP)
			if los then
				self:ClearPath()
				if now - self.LastLOSDirectMove >= self.LOSUpdateInterval then
					self.Humanoid:MoveTo(targetPos)
					self.LastLOSDirectMove = now
				end
				task.wait(0.08)
				continue
			end

			if self.RepathRequested or not self.CurrentWaypoints or not self.CurrentWaypoints[self.CurrentWaypointIndex] then
				self:ComputePath(targetPos)
			end

			if self.CurrentWaypoints and self.CurrentWaypoints[self.CurrentWaypointIndex] then
				self:FollowPath()
			else
				self.Humanoid:MoveTo(targetPos)
				task.wait(0.1)
			end

			self:TryUnstuckStep()
		end

		self:DisconnectPathSignals()
	end)
end

return EnemyPathController
