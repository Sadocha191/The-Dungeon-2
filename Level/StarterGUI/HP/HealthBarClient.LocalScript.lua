-- HealthBarClient (LocalScript)
-- Expected structure:
-- HP(ScreenGui)
--   HealthBar(Frame)
--     Inner(Frame)
--       FillMask(Frame, ClipsDescendants=true)
--         Fill(ImageLabel)
--     BG(ImageLabel)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local gui = script.Parent
local HP_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function findFirstChildByNames(parent: Instance, names: { string })
	for _, name in ipairs(names) do
		local child = parent:FindFirstChild(name)
		if child then
			return child
		end
	end

	return nil
end

gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local root = gui:WaitForChild("HealthBar")
local bg = root:FindFirstChild("BG") or root:FindFirstChildWhichIsA("ImageLabel")
assert(bg, "Health bar BG image was not found")

local inner = root:FindFirstChild("Inner") or root
local mask = findFirstChildByNames(inner, { "FillMask", "FIllMask" })
	or findFirstChildByNames(bg, { "FillMask", "FIllMask" })
	or root:FindFirstChild("FillMask", true)
	or root:FindFirstChild("FIllMask", true)
assert(mask, "Health bar FillMask was not found")

local fill = mask:FindFirstChild("Fill") or mask:FindFirstChildWhichIsA("ImageLabel")
assert(fill, "Health bar Fill image was not found")

inner.ZIndex = 1
mask.ZIndex = 1
fill.ZIndex = 1

mask.ClipsDescendants = true
fill.SizeConstraint = Enum.SizeConstraint.RelativeXY
fill.ScaleType = Enum.ScaleType.Crop

local baseMaskSize = mask.Size
local baseMaskPosition = mask.Position
local baseMaskAnchorPoint = mask.AnchorPoint
local currentHumanoid: Humanoid? = nil
local maskTween: Tween? = nil

local function stopMaskTween()
	if maskTween then
		maskTween:Cancel()
		maskTween = nil
	end
end

local function setBar(hp: number, maxHp: number, animated: boolean?)
	maxHp = math.max(1, maxHp)
	local ratio = math.clamp(hp / maxHp, 0, 1)

	-- Keep the mask aligned to the original left edge and only scale its width.
	local leftXScale = baseMaskPosition.X.Scale - (baseMaskSize.X.Scale * baseMaskAnchorPoint.X)
	local leftXOffset = baseMaskPosition.X.Offset - math.round(baseMaskSize.X.Offset * baseMaskAnchorPoint.X)
	local targetSize = UDim2.new(
		baseMaskSize.X.Scale * ratio,
		math.round(baseMaskSize.X.Offset * ratio),
		baseMaskSize.Y.Scale,
		baseMaskSize.Y.Offset
	)

	mask.AnchorPoint = Vector2.new(0, baseMaskAnchorPoint.Y)
	mask.Position = UDim2.new(leftXScale, leftXOffset, baseMaskPosition.Y.Scale, baseMaskPosition.Y.Offset)

	if mask.Size == targetSize then
		stopMaskTween()
		return
	end

	stopMaskTween()
	if not animated then
		mask.Size = targetSize
		return
	end

	maskTween = TweenService:Create(mask, HP_TWEEN_INFO, {
		Size = targetSize,
	})
	maskTween.Completed:Connect(function()
		if maskTween then
			maskTween = nil
		end
	end)
	maskTween:Play()
end

local function bindHumanoid(hum: Humanoid)
	currentHumanoid = hum
	setBar(hum.Health, hum.MaxHealth, false)

	hum.HealthChanged:Connect(function()
		if currentHumanoid ~= hum then
			return
		end
		setBar(hum.Health, hum.MaxHealth, true)
	end)

	hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		if currentHumanoid ~= hum then
			return
		end
		setBar(hum.Health, hum.MaxHealth, true)
	end)
end

local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		bindHumanoid(hum)
	end
end

if plr.Character then
	onCharacter(plr.Character)
end

plr.CharacterAdded:Connect(onCharacter)
