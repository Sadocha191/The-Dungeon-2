local ServerScriptService = game:GetService("ServerScriptService")

local PathfindingManager = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PathfindingManager"))

local EnemyPathController = {}
EnemyPathController.__index = EnemyPathController

local DEFAULT_PATH_PARAMS = {
	AgentRadius = 2.5,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = false,
	AgentJumpHeight = 7,
	AgentMaxSlope = 35,
	WaypointSpacing = 10,
}

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
	self.StopMove = self.Options.StopMove
	self.IsPaused = self.Options.IsPaused

	self.RepathDistance = self.Options.RepathDistance or 10
	self.RepathCooldown = self.Options.RepathCooldown or 1.2
	self.NoLOSRepathDelay = self.Options.NoLOSRepathDelay or 0.45
	self.StuckCheckWindow = self.Options.StuckCheckWindow or 0.55
	self.StuckProgressDistance = self.Options.StuckProgressDistance or 1.2
	self.WaypointReachedDistance = self.Options.WaypointReachedDistance or 3
	self.LOSDirectMoveInterval = self.Options.LOSDirectMoveInterval or 0.12
	self.IdleUpdateInterval = self.Options.IdleUpdateInterval or 0.08
	self.FullUpdateRadius = self.Options.FullUpdateRadius or 90
	self.FarNoPathRadius = self.Options.FarNoPathRadius or 120
	self.MidUpdateInterval = self.Options.MidUpdateInterval or 0.5
	self.FarUpdateInterval = self.Options.FarUpdateInterval or 0.8

	self.LastTargetPos = nil
	self.LastRepathAt = 0
	self.LastLOSDirectMove = 0
	self.LastProgressCheckAt = 0
	self.LastProgressPos = hrp.Position
	self.LastNoLOSAt = nil

	self.CurrentPath = nil
	self.CurrentWaypoints = nil
	self.CurrentWaypointIndex = 1
	self.BlockedConnection = nil

	self.PathRequestToken = nil
	self.PendingPath = false

	return self
end

function EnemyPathController:AcquireTarget(): BasePart?
	local getter = self.Options.GetTarget
	if typeof(getter) == "function" then
		return getter(self.RootPart.Position)
	end
	return nil
end

function EnemyPathController:CanRaycastTo(targetPos: Vector3, targetParent: Instance?): boolean
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { self.Mob }
	rayParams.IgnoreWater = true

	local origin = self.RootPart.Position
	local result = workspace:Raycast(origin, targetPos - origin, rayParams)
	if not result then
		return true
	end

	return targetParent ~= nil and result.Instance and result.Instance:IsDescendantOf(targetParent)
end

function EnemyPathController:HasLineOfSight(targetHRP: BasePart): boolean
	return self:CanRaycastTo(targetHRP.Position, targetHRP.Parent)
end

function EnemyPathController:DisconnectPathSignals()
	if self.BlockedConnection then
		self.BlockedConnection:Disconnect()
		self.BlockedConnection = nil
	end
end

function EnemyPathController:ClearPath()
	self:DisconnectPathSignals()
	self.CurrentPath = nil
	self.CurrentWaypoints = nil
	self.CurrentWaypointIndex = 1
	self.PendingPath = false
end

function EnemyPathController:IsStuck(now: number): boolean
	if (now - self.LastProgressCheckAt) < self.StuckCheckWindow then
		return false
	end

	local progress = (self.RootPart.Position - self.LastProgressPos).Magnitude
	self.LastProgressPos = self.RootPart.Position
	self.LastProgressCheckAt = now
	return progress < self.StuckProgressDistance
end

function EnemyPathController:ShouldRequestPath(now: number, targetPos: Vector3, hasLOS: boolean): boolean
	if self.PendingPath then
		return false
	end

	if (now - self.LastRepathAt) < self.RepathCooldown then
		return false
	end

	if hasLOS then
		self.LastNoLOSAt = nil
		return false
	end

	if not self.LastNoLOSAt then
		self.LastNoLOSAt = now
	end

	if self.LastTargetPos and (targetPos - self.LastTargetPos).Magnitude > self.RepathDistance then
		return true
	end

	if (now - self.LastNoLOSAt) >= self.NoLOSRepathDelay then
		return true
	end

	if self:IsStuck(now) then
		return true
	end

	return not self.CurrentWaypoints or not self.CurrentWaypoints[self.CurrentWaypointIndex]
end

function EnemyPathController:ComputePriority(targetDistance: number): number
	local base = 100
	if self.Mob:GetAttribute("IsBoss") then
		base = 400
	elseif self.Mob:GetAttribute("IsElite") then
		base = 250
	end

	local proximityBoost = math.clamp(200 - targetDistance, 0, 200)
	return base + proximityBoost
end

function EnemyPathController:RequestPath(targetPos: Vector3, priority: number)
	self.PendingPath = true
	self.PathRequestToken = PathfindingManager.RequestPath(
		self.Mob,
		self.RootPart.Position,
		targetPos,
		self.PathParams,
		priority,
		function(result)
			if not self.Mob.Parent then
				return
			end

			if result.token ~= self.PathRequestToken then
				return
			end

			self.PendingPath = false
			self.LastRepathAt = time()
			if result.status ~= Enum.PathStatus.Success or not result.waypoints then
				self:ClearPath()
				return
			end

			self:DisconnectPathSignals()
			self.CurrentPath = result.path
			self.CurrentWaypoints = result.waypoints
			self.CurrentWaypointIndex = 1
			self.LastTargetPos = targetPos

			self.BlockedConnection = result.path.Blocked:Connect(function(blockedIdx)
				if blockedIdx >= self.CurrentWaypointIndex then
					self.LastRepathAt = 0
				end
			end)
		end
	)
end

function EnemyPathController:StepPath()
	if not self.CurrentWaypoints then
		return false
	end

	local current = self.CurrentWaypoints[self.CurrentWaypointIndex]
	if not current then
		self:ClearPath()
		return false
	end

	while self.CurrentWaypoints[self.CurrentWaypointIndex + 1] do
		local nextWaypoint = self.CurrentWaypoints[self.CurrentWaypointIndex + 1]
		if self:CanRaycastTo(nextWaypoint.Position, nil) then
			self.CurrentWaypointIndex += 1
			current = self.CurrentWaypoints[self.CurrentWaypointIndex]
		else
			break
		end
	end

	if (current.Position - self.RootPart.Position).Magnitude <= self.WaypointReachedDistance then
		self.CurrentWaypointIndex += 1
		current = self.CurrentWaypoints[self.CurrentWaypointIndex]
		if not current then
			self:ClearPath()
			return false
		end
	end

	if current.Action == Enum.PathWaypointAction.Jump then
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	self.Humanoid:MoveTo(current.Position)
	return true
end

function EnemyPathController:Run()
	task.spawn(function()
		while self.Mob.Parent and self.Humanoid.Health > 0 do
			if self.IsPaused and self.IsPaused() then
				if self.StopMove then
					self.StopMove()
				end
				task.wait(0.05)
				continue
			end

			local targetHRP = self:AcquireTarget()
			if not targetHRP then
				task.wait(0.15)
				continue
			end

			local now = time()
			local targetPos = targetHRP.Position
			local distanceToTarget = (targetPos - self.RootPart.Position).Magnitude

			if distanceToTarget > self.FarNoPathRadius then
				self:ClearPath()
				self.Humanoid:MoveTo(targetPos)
				task.wait(self.FarUpdateInterval)
				continue
			end

			if distanceToTarget > self.FullUpdateRadius then
				self:ClearPath()
				self.Humanoid:MoveTo(targetPos)
				task.wait(self.MidUpdateInterval)
				continue
			end

			local hasLOS = self:HasLineOfSight(targetHRP)
			if hasLOS then
				self:ClearPath()
				if (now - self.LastLOSDirectMove) >= self.LOSDirectMoveInterval then
					self.Humanoid:MoveTo(targetPos)
					self.LastLOSDirectMove = now
				end
				task.wait(self.IdleUpdateInterval)
				continue
			end

			if self:ShouldRequestPath(now, targetPos, hasLOS) then
				self:RequestPath(targetPos, self:ComputePriority(distanceToTarget))
			end

			if not self:StepPath() then
				self.Humanoid:MoveTo(targetPos)
			end

			task.wait(self.IdleUpdateInterval)
		end

		PathfindingManager.CancelForNpc(self.Mob)
		self:DisconnectPathSignals()
	end)
end

return EnemyPathController
