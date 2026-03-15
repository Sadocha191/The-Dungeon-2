local Workspace = game:GetService("Workspace")

local DEFAULT_MARGIN = 24

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function ensureScale(target)
	local scale = target:FindFirstChild("ResponsiveScale")
	if scale and not scale:IsA("UIScale") then
		scale:Destroy()
		scale = nil
	end
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "ResponsiveScale"
		scale.Parent = target
	end
	return scale
end

local function attachCenteredPanel(target, designSize, options)
	options = options or {}

	local margin = options.margin or DEFAULT_MARGIN
	local topOverflow = options.topOverflow or 0
	local centerYOffset = options.centerYOffset or 0

	target.Size = UDim2.fromOffset(designSize.X, designSize.Y)

	local scale = ensureScale(target)
	local viewportConnection = nil

	local function update()
		local viewport = getViewportSize()
		local availableWidth = math.max(1, viewport.X - margin * 2)
		local availableHeight = math.max(1, viewport.Y - margin * 2)
		local scaleValue = math.min(
			availableWidth / designSize.X,
			availableHeight / (designSize.Y + topOverflow),
			1
		)

		scale.Scale = scaleValue
		target.Position = UDim2.fromOffset(
			viewport.X * 0.5,
			viewport.Y * 0.5 + centerYOffset + (topOverflow * scaleValue * 0.5)
		)
	end

	local function bindCamera(camera)
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
	end

	bindCamera(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindCamera(Workspace.CurrentCamera)
		task.defer(update)
	end)
	task.defer(update)

	return update
end

return {
	attachCenteredPanel = attachCenteredPanel,
}
