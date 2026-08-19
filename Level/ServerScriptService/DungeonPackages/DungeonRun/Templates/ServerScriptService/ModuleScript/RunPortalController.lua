local RunPortalController = {}
RunPortalController.__index = RunPortalController

function RunPortalController.new(options)
	assert(type(options) == "table", "[RunPortalController] options table is required")
	assert(typeof(options.parent) == "Instance", "[RunPortalController] parent is required")
	assert(type(options.getPortalPosition) == "function", "[RunPortalController] getPortalPosition callback is required")

	return setmetatable({
		parent = options.parent,
		getPortalPosition = options.getPortalPosition,
		canUsePortal = options.canUsePortal,
		onActivated = options.onActivated,
		onVictory = options.onVictory,
		portalModel = nil,
		basePart = nil,
		prompt = nil,
		activated = false,
		bossDefeated = false,
	}, RunPortalController)
end

function RunPortalController:IsActivated(): boolean
	return self.activated == true
end

function RunPortalController:IsBossDefeated(): boolean
	return self.bossDefeated == true
end

function RunPortalController:GetBasePart(): BasePart?
	return self.basePart
end

function RunPortalController:GetModel(): Model?
	return self.portalModel
end

function RunPortalController:RefreshPrompt()
	local prompt = self.prompt
	if not prompt then
		return
	end

	if not self.activated then
		prompt.ActionText = "Awaken Boss"
		prompt.ObjectText = "Portal"
		prompt.Enabled = true
	elseif not self.bossDefeated then
		prompt.ActionText = "Boss Active"
		prompt.ObjectText = "Portal"
		prompt.Enabled = false
	else
		prompt.ActionText = "Enter Portal"
		prompt.ObjectText = "Portal"
		prompt.Enabled = true
	end
end

function RunPortalController:SetBossDefeated(defeated: boolean)
	self.bossDefeated = defeated == true
	self:RefreshPrompt()
end

function RunPortalController:Activate()
	self.activated = true
	self.bossDefeated = false
	self:RefreshPrompt()
end

function RunPortalController:Ensure()
	if self.portalModel and self.portalModel.Parent then
		return self.portalModel
	end

	local model = Instance.new("Model")
	model.Name = "RunPortal"

	local base = Instance.new("Part")
	base.Name = "Portal"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.Material = Enum.Material.Neon
	base.Size = Vector3.new(10, 10, 1)
	base.CFrame = CFrame.new(self.getPortalPosition()) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	base.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalPrompt"
	prompt.ActionText = "Awaken Boss"
	prompt.ObjectText = "Portal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	self.portalModel = model
	self.basePart = base
	self.prompt = prompt
	model.PrimaryPart = base
	model.Parent = self.parent

	prompt.Triggered:Connect(function(player)
		if type(self.canUsePortal) == "function" and not self.canUsePortal(player) then
			return
		end

		if not self.activated then
			self:Activate()
			if type(self.onActivated) == "function" then
				self.onActivated(player, base)
			end
			self:RefreshPrompt()
			return
		end

		if self.bossDefeated and type(self.onVictory) == "function" then
			self.onVictory(player)
		end
	end)

	self:RefreshPrompt()
	return model
end

return RunPortalController
