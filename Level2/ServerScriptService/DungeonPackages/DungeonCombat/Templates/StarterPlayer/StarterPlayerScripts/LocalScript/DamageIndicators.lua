-- DamageIndicators.client.lua (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local damageIndicatorEvent = remotes:WaitForChild("DamageIndicatorEvent")

local BATCH_HZ = 20
local BATCH_WINDOW = 1 / BATCH_HZ
local LIFETIME = 1.05
local MAX_ACTIVE = 36
local MAX_POOL = 24
local MAX_PENDING = 128

local localPlayer = Players.LocalPlayer
local random = Random.new()
local activeCount = 0
local pool = {}
local activeIndicators = {}
local pending = {}
local pendingCount = 0
local flushAccumulator = 0

local ELEMENTS = {
	Physical = {
		label = "PHYSICAL",
		color = Color3.fromRGB(232, 232, 236),
		secondary = Color3.fromRGB(150, 154, 166),
		order = 1,
	},
	Fire = {
		label = "FIRE",
		color = Color3.fromRGB(255, 105, 54),
		secondary = Color3.fromRGB(255, 188, 76),
		order = 2,
	},
	Electricity = {
		label = "ELECTRIC",
		color = Color3.fromRGB(255, 224, 84),
		secondary = Color3.fromRGB(255, 250, 184),
		order = 3,
	},
	Air = {
		label = "AIR",
		color = Color3.fromRGB(207, 244, 255),
		secondary = Color3.fromRGB(114, 214, 235),
		order = 4,
	},
	Water = {
		label = "WATER",
		color = Color3.fromRGB(75, 166, 255),
		secondary = Color3.fromRGB(139, 226, 255),
		order = 5,
	},
	Earth = {
		label = "EARTH",
		color = Color3.fromRGB(131, 190, 91),
		secondary = Color3.fromRGB(210, 221, 116),
		order = 6,
	},
	Void = {
		label = "VOID",
		color = Color3.fromRGB(176, 94, 255),
		secondary = Color3.fromRGB(94, 57, 174),
		order = 7,
	},
	Light = {
		label = "LIGHT",
		color = Color3.fromRGB(255, 237, 164),
		secondary = Color3.fromRGB(255, 177, 76),
		order = 8,
	},
}

local ELEMENT_ALIASES = {
	Electric = "Electricity",
	Lightning = "Electricity",
	Wind = "Air",
	Nature = "Earth",
	Holy = "Light",
	Dark = "Void",
	Shadow = "Void",
}

local function normalizeElement(value)
	local element = tostring(value or "")
	element = ELEMENT_ALIASES[element] or element
	if ELEMENTS[element] then
		return element
	end
	return "Physical"
end

local function formatAmount(amount)
	local value = math.max(0, math.floor((tonumber(amount) or 0) + 0.5))
	if value >= 1_000_000_000 then
		return string.format("%.1fB", value / 1_000_000_000)
	end
	if value >= 1_000_000 then
		return string.format("%.1fM", value / 1_000_000)
	end
	if value >= 10_000 then
		return string.format("%.1fK", value / 1_000)
	end
	return tostring(value)
end

local function createIndicator()
	local part = Instance.new("Part")
	part.Name = "DamageIndicatorAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Billboard"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150
	billboard.Size = UDim2.fromOffset(190, 78)
	billboard.Parent = part

	local group = Instance.new("CanvasGroup")
	group.Name = "Group"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = billboard

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = group

	local shadow = Instance.new("TextLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Position = UDim2.fromOffset(3, 4)
	shadow.Size = UDim2.new(1, -6, 0, 52)
	shadow.Font = Enum.Font.GothamBlack
	shadow.TextColor3 = Color3.fromRGB(0, 0, 0)
	shadow.TextTransparency = 0.35
	shadow.TextScaled = true
	shadow.Parent = group

	local shadowConstraint = Instance.new("UITextSizeConstraint")
	shadowConstraint.MinTextSize = 18
	shadowConstraint.MaxTextSize = 38
	shadowConstraint.Parent = shadow

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "Amount"
	amountLabel.BackgroundTransparency = 1
	amountLabel.Position = UDim2.fromOffset(0, 0)
	amountLabel.Size = UDim2.new(1, 0, 0, 52)
	amountLabel.Font = Enum.Font.GothamBold
	amountLabel.TextColor3 = Color3.new(1, 1, 1)
	amountLabel.TextScaled = true
	amountLabel.TextStrokeColor3 = Color3.fromRGB(14, 11, 18)
	amountLabel.TextStrokeTransparency = 0.05
	amountLabel.Parent = group

	local amountConstraint = Instance.new("UITextSizeConstraint")
	amountConstraint.MinTextSize = 18
	amountConstraint.MaxTextSize = 38
	amountConstraint.Parent = amountLabel

	local amountGradient = Instance.new("UIGradient")
	amountGradient.Rotation = 90
	amountGradient.Parent = amountLabel

	local elementTag = Instance.new("TextLabel")
	elementTag.Name = "Element"
	elementTag.AnchorPoint = Vector2.new(0.5, 0)
	elementTag.Position = UDim2.new(0.5, 0, 0, 51)
	elementTag.Size = UDim2.fromOffset(116, 20)
	elementTag.BackgroundTransparency = 0.18
	elementTag.BorderSizePixel = 0
	elementTag.Font = Enum.Font.GothamBold
	elementTag.TextColor3 = Color3.fromRGB(18, 14, 20)
	elementTag.TextScaled = true
	elementTag.Parent = group

	local elementConstraint = Instance.new("UITextSizeConstraint")
	elementConstraint.MinTextSize = 8
	elementConstraint.MaxTextSize = 11
	elementConstraint.Parent = elementTag

	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = UDim.new(1, 0)
	tagCorner.Parent = elementTag

	local tagStroke = Instance.new("UIStroke")
	tagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tagStroke.Thickness = 1
	tagStroke.Transparency = 0.2
	tagStroke.Parent = elementTag

	local critTag = Instance.new("TextLabel")
	critTag.Name = "Crit"
	critTag.AnchorPoint = Vector2.new(0, 0)
	critTag.Position = UDim2.new(0.5, 61, 0, 51)
	critTag.Size = UDim2.fromOffset(40, 20)
	critTag.BackgroundColor3 = Color3.fromRGB(255, 88, 63)
	critTag.BackgroundTransparency = 0.08
	critTag.BorderSizePixel = 0
	critTag.Font = Enum.Font.GothamBlack
	critTag.Text = "CRIT"
	critTag.TextColor3 = Color3.fromRGB(255, 247, 226)
	critTag.TextSize = 10
	critTag.Visible = false
	critTag.Parent = group

	local critCorner = Instance.new("UICorner")
	critCorner.CornerRadius = UDim.new(1, 0)
	critCorner.Parent = critTag

	return {
		part = part,
		billboard = billboard,
		group = group,
		scale = scale,
		shadow = shadow,
		amountLabel = amountLabel,
		amountGradient = amountGradient,
		elementTag = elementTag,
		tagStroke = tagStroke,
		critTag = critTag,
		tweens = {},
		generation = 0,
		inUse = false,
	}
end

local function cancelTweens(indicator)
	for _, tween in ipairs(indicator.tweens) do
		tween:Cancel()
	end
	table.clear(indicator.tweens)
end

local function releaseIndicator(indicator)
	if not indicator.inUse then
		return
	end
	indicator.inUse = false
	indicator.generation += 1
	indicator.releaseAt = nil
	activeIndicators[indicator] = nil
	cancelTweens(indicator)
	indicator.part.Parent = nil
	activeCount = math.max(0, activeCount - 1)
	if #pool < MAX_POOL then
		table.insert(pool, indicator)
	else
		indicator.part:Destroy()
	end
end

local function acquireIndicator()
	if activeCount >= MAX_ACTIVE then
		return nil
	end
	local indicator = table.remove(pool) or createIndicator()
	indicator.inUse = true
	indicator.generation += 1
	activeIndicators[indicator] = true
	activeCount += 1
	cancelTweens(indicator)
	return indicator
end

local function elementText(primaryElement, secondaryElement, hits)
	local text = ELEMENTS[primaryElement].label
	if secondaryElement then
		text ..= " + " .. ELEMENTS[secondaryElement].label
	end
	if hits > 1 then
		text ..= "  ×" .. tostring(hits)
	end
	return text
end

local function popText(worldPos, amount, crit, primaryElement, secondaryElement, hits)
	local indicator = acquireIndicator()
	if not indicator then
		return
	end

	local primaryStyle = ELEMENTS[primaryElement]
	local secondaryStyle = secondaryElement and ELEMENTS[secondaryElement] or primaryStyle
	local lane = ((primaryStyle.order - 1) % 5) - 2
	local startJitter = Vector3.new((lane * 0.16) + random:NextNumber(-0.14, 0.14), random:NextNumber(-0.05, 0.18), random:NextNumber(-0.18, 0.18))
	local travel = Vector3.new((lane * 0.23) + random:NextNumber(-0.42, 0.42), random:NextNumber(1.65, 2.15), random:NextNumber(-0.45, 0.45))

	indicator.part.CFrame = CFrame.new(worldPos + startJitter)
	indicator.part.Parent = workspace
	indicator.group.GroupTransparency = 0
	indicator.scale.Scale = crit and 0.58 or 0.7
	indicator.billboard.Size = crit and UDim2.fromOffset(220, 88) or UDim2.fromOffset(190, 78)
	indicator.amountLabel.Font = crit and Enum.Font.GothamBlack or Enum.Font.GothamBold
	indicator.amountLabel.Text = formatAmount(amount) .. (crit and "!" or "")
	indicator.shadow.Text = indicator.amountLabel.Text
	indicator.amountGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.42, primaryStyle.color),
		ColorSequenceKeypoint.new(1, secondaryStyle.secondary),
	})
	indicator.elementTag.Text = elementText(primaryElement, secondaryElement, hits)
	indicator.elementTag.BackgroundColor3 = primaryStyle.color
	indicator.tagStroke.Color = secondaryStyle.secondary
	indicator.critTag.Visible = crit

	local moveTween = TweenService:Create(
		indicator.part,
		TweenInfo.new(LIFETIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(worldPos + startJitter + travel) }
	)
	local popTween = TweenService:Create(
		indicator.scale,
		TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = crit and 1.18 or 1.05 }
	)
	local settleTween = TweenService:Create(
		indicator.scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.12),
		{ Scale = crit and 1.05 or 0.96 }
	)
	local fadeTween = TweenService:Create(
		indicator.group,
		TweenInfo.new(0.46, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFETIME - 0.46),
		{ GroupTransparency = 1 }
	)

	indicator.tweens = { moveTween, popTween, settleTween, fadeTween }
	for _, tween in ipairs(indicator.tweens) do
		tween:Play()
	end
	indicator.releaseAt = os.clock() + LIFETIME + 0.06
end

local function fallbackTargetKey(pos)
	return string.format(
		"%d:%d:%d",
		math.floor(pos.X * 0.5 + 0.5),
		math.floor(pos.Y * 0.5 + 0.5),
		math.floor(pos.Z * 0.5 + 0.5)
	)
end

local function queueIndicator(payload)
	local pos = payload.pos
	local amount = payload.amount
	if typeof(pos) ~= "Vector3" or typeof(amount) ~= "number" or amount <= 0 then
		return
	end

	local primaryElement = normalizeElement(payload.element)
	local secondaryElement = nil
	if payload.secondaryElement ~= nil then
		local candidate = normalizeElement(payload.secondaryElement)
		if candidate ~= primaryElement then
			secondaryElement = candidate
		end
	end
	local crit = payload.crit == true
	local incomingHits = math.clamp(math.floor(tonumber(payload.hits) or 1), 1, 999)
	if payload.batched == true then
		popText(pos, amount, crit, primaryElement, secondaryElement, incomingHits)
		return
	end

	local targetKey = payload.targetId ~= nil and tostring(payload.targetId) or fallbackTargetKey(pos)
	local key = table.concat({
		targetKey,
		primaryElement,
		secondaryElement or "",
		crit and "crit" or "normal",
		tostring(payload.kind or "hit"),
	}, "|")

	local bucket = pending[key]
	if bucket then
		bucket.amount += amount
		bucket.hits += incomingHits
		bucket.pos = bucket.pos:Lerp(pos, 0.35)
		return
	end
	if pendingCount >= MAX_PENDING then
		return
	end

	bucket = {
		amount = amount,
		hits = incomingHits,
		pos = pos,
		crit = crit,
		primaryElement = primaryElement,
		secondaryElement = secondaryElement,
		flushAt = os.clock() + BATCH_WINDOW,
	}
	pending[key] = bucket
	pendingCount += 1
end

damageIndicatorEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	queueIndicator(payload)
end)

local function clearPending()
	table.clear(pending)
	pendingCount = 0
end

RunService.Heartbeat:Connect(function(dt)
	flushAccumulator += dt
	if flushAccumulator < BATCH_WINDOW then
		return
	end
	flushAccumulator %= BATCH_WINDOW

	local now = os.clock()
	local runEnded = localPlayer:GetAttribute("RunEnded") == true
	if runEnded then
		clearPending()
	else
		for key, bucket in pairs(pending) do
			if bucket.flushAt <= now then
				pending[key] = nil
				pendingCount = math.max(0, pendingCount - 1)
				popText(
					bucket.pos,
					bucket.amount,
					bucket.crit,
					bucket.primaryElement,
					bucket.secondaryElement,
					bucket.hits
				)
			end
		end
	end

	for indicator in pairs(activeIndicators) do
		if runEnded or (indicator.releaseAt and indicator.releaseAt <= now) then
			releaseIndicator(indicator)
		end
	end
end)
