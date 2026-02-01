-- HealthBarClient (LocalScript) - full
-- Wymaga struktury:
-- HP(ScreenGui)
--  └ HealthBar(Frame)
--     ├ Inner(Frame)
--     │   └ FillMask(Frame, ClipsDescendants=true)
--     │       └ Fill(ImageLabel)
--     └ BG(ImageLabel)

local Players = game:GetService("Players")

local plr = Players.LocalPlayer
local gui = script.Parent

-- dobrze żeby to było ustawione w Properties, ale tu też zabezpieczamy
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local root = gui:WaitForChild("HealthBar")
local bg = root:WaitForChild("BG")

local inner = root:WaitForChild("Inner")
local mask = inner:WaitForChild("FillMask")
local fill = mask:WaitForChild("Fill")

-- warstwy (BG jako overlay)
inner.ZIndex = 1
mask.ZIndex = 1
fill.ZIndex = 1
bg.ZIndex = 2

-- sanity: pozycje/rozmiary (żeby nic nie “uciekało”)
root.AnchorPoint = Vector2.new(0.5, 1)
-- root.Position/Size ustawiasz w Properties

inner.BackgroundTransparency = 1
inner.Position = UDim2.new(0, 0, 0, 0)
inner.Size = UDim2.new(1, 0, 1, 0)

mask.BackgroundTransparency = 1
mask.Position = UDim2.new(0, 0, 0, 0)
mask.Size = UDim2.new(1, 0, 1, 0)
mask.ClipsDescendants = true

fill.BackgroundTransparency = 1
fill.Position = UDim2.new(0, 0, 0, 0)
fill.Size = UDim2.new(1, 0, 1, 0)
fill.SizeConstraint = Enum.SizeConstraint.RelativeXY
-- Polecam Crop, żeby nie rozciągało tekstury
fill.ScaleType = Enum.ScaleType.Crop

bg.BackgroundTransparency = 1
bg.Position = UDim2.new(0, 0, 0, 0)
bg.Size = UDim2.new(1, 0, 1, 0)
bg.SizeConstraint = Enum.SizeConstraint.RelativeXY
bg.ScaleType = Enum.ScaleType.Stretch

local function getHumanoid()
	local char = plr.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function setBar(hp: number, maxHp: number)
	maxHp = math.max(1, maxHp)
	local ratio = math.clamp(hp / maxHp, 0, 1)

	-- ZMIENIAMY SZEROKOŚĆ MASKI (to obcina fill)
	mask.Size = UDim2.new(ratio, 0, 1, 0)
end

local function bindHumanoid(hum: Humanoid)
	setBar(hum.Health, hum.MaxHealth)

	hum.HealthChanged:Connect(function()
		setBar(hum.Health, hum.MaxHealth)
	end)

	hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		setBar(hum.Health, hum.MaxHealth)
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
