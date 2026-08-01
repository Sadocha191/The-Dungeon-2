local TweenService = game:GetService("TweenService")

local screenGui = script.Parent

local GROUP_NAMES = {
	Frame = true,
	Frame1 = true,
}

local HOVER_MULTIPLIER = 1.2
local HOVER_ZINDEX_OFFSET = 50
local HOVER_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LEAVE_TWEEN_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local boundButtons = setmetatable({}, { __mode = "k" })
local watchedGroups = setmetatable({}, { __mode = "k" })

local function findButton(item)
	if item:IsA("GuiButton") then
		return item
	end

	local matchingChild = item:FindFirstChild(item.Name)
	if matchingChild and matchingChild:IsA("GuiButton") then
		return matchingChild
	end

	for _, child in ipairs(item:GetChildren()) do
		if child:IsA("GuiButton") then
			return child
		end
	end

	return item:FindFirstChildWhichIsA("GuiButton", true)
end

local function getOrCreateScale(item)
	local scale = item:FindFirstChildWhichIsA("UIScale")
	if scale then
		return scale
	end

	scale = Instance.new("UIScale")
	scale.Name = "HoverScale"
	scale.Scale = 1
	scale.Parent = item
	return scale
end

local function captureZIndexes(item)
	local values = {}

	if item:IsA("GuiObject") then
		values[item] = item.ZIndex
	end

	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			values[descendant] = descendant.ZIndex
		end
	end

	return values
end

local function applyRaisedZIndexes(values)
	for guiObject, originalZIndex in pairs(values) do
		if guiObject.Parent then
			guiObject.ZIndex = originalZIndex + HOVER_ZINDEX_OFFSET
		end
	end
end

local function restoreZIndexes(values)
	for guiObject, originalZIndex in pairs(values) do
		if guiObject.Parent then
			guiObject.ZIndex = originalZIndex
		end
	end
end

local function bindItem(item)
	if not item:IsA("GuiObject") then
		return
	end

	local button = findButton(item)
	if not button or boundButtons[button] then
		return
	end

	boundButtons[button] = true

	local scaleHost = item
	local uiScale = getOrCreateScale(scaleHost)
	local state = {
		baseScale = uiScale.Scale,
		hovered = false,
		isAnimating = false,
		tween = nil,
		completedConnection = nil,
		zIndexes = nil,
	}

	local function cancelTween()
		if state.completedConnection then
			state.completedConnection:Disconnect()
			state.completedConnection = nil
		end

		if state.tween then
			state.tween:Cancel()
			state.tween = nil
		end

		state.isAnimating = false
	end

	local function playScaleTween(targetScale, tweenInfo)
		cancelTween()
		state.isAnimating = true

		local tween = TweenService:Create(uiScale, tweenInfo, {
			Scale = targetScale,
		})
		state.tween = tween
		state.completedConnection = tween.Completed:Connect(function()
			if state.completedConnection then
				state.completedConnection:Disconnect()
				state.completedConnection = nil
			end

			if state.tween ~= tween then
				return
			end

			state.tween = nil
			state.isAnimating = false
		end)
		tween:Play()
	end

	uiScale:GetPropertyChangedSignal("Scale"):Connect(function()
		if not state.hovered and not state.isAnimating then
			state.baseScale = uiScale.Scale
		end
	end)

	button.MouseEnter:Connect(function()
		if state.hovered then
			return
		end

		state.hovered = true
		state.zIndexes = captureZIndexes(scaleHost)
		applyRaisedZIndexes(state.zIndexes)
		playScaleTween(state.baseScale * HOVER_MULTIPLIER, HOVER_TWEEN_INFO)
	end)

	button.MouseLeave:Connect(function()
		if not state.hovered then
			return
		end

		state.hovered = false
		if state.zIndexes then
			restoreZIndexes(state.zIndexes)
			state.zIndexes = nil
		end
		playScaleTween(state.baseScale, LEAVE_TWEEN_INFO)
	end)

	button.Destroying:Connect(function()
		cancelTween()
		if state.zIndexes then
			restoreZIndexes(state.zIndexes)
			state.zIndexes = nil
		end
		boundButtons[button] = nil
	end)
end

local function watchGroup(group)
	if watchedGroups[group] then
		return
	end

	watchedGroups[group] = true
	for _, child in ipairs(group:GetChildren()) do
		bindItem(child)
	end

	group.ChildAdded:Connect(function(child)
		task.defer(bindItem, child)
	end)
end

for _, child in ipairs(screenGui:GetChildren()) do
	if GROUP_NAMES[child.Name] and child:IsA("GuiObject") then
		watchGroup(child)
	end
end

screenGui.ChildAdded:Connect(function(child)
	if GROUP_NAMES[child.Name] and child:IsA("GuiObject") then
		task.defer(watchGroup, child)
	end
end)
