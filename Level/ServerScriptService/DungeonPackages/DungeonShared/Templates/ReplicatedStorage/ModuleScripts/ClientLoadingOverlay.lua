local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local Overlay = {}

local ACTION_NAME = "__GlobalLoadingLockAll"

local nextTokenId = 0
local activeTokens = {}
local inputLocked = false

local gui: ScreenGui? = nil
local titleLabel: TextLabel? = nil
local detailLabel: TextLabel? = nil
local barBg: Frame? = nil
local barFill: Frame? = nil
local pctLabel: TextLabel? = nil

local function sinkAll()
	return Enum.ContextActionResult.Sink
end

local function lockInput()
	if inputLocked then
		return
	end

	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		sinkAll,
		false,
		1000000,
		Enum.UserInputType.Keyboard,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.MouseButton2,
		Enum.UserInputType.MouseMovement,
		Enum.UserInputType.Touch,
		Enum.UserInputType.Gamepad1
	)
	inputLocked = true
end

local function unlockInput()
	if not inputLocked then
		return
	end

	ContextActionService:UnbindAction(ACTION_NAME)
	inputLocked = false
end

local function ensureGui()
	if gui and gui.Parent then
		return
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("LoadingGui")
	if existing and existing:IsA("ScreenGui") then
		gui = existing
		titleLabel = gui:FindFirstChild("Title", true) :: TextLabel
		detailLabel = gui:FindFirstChild("Detail", true) :: TextLabel
		barBg = gui:FindFirstChild("BarBg", true) :: Frame
		barFill = gui:FindFirstChild("BarFill", true) :: Frame
		pctLabel = gui:FindFirstChild("Pct", true) :: TextLabel
		if titleLabel and detailLabel and barBg and barFill and pctLabel then
			return
		end
		gui:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "LoadingGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10000
	gui.Enabled = false
	gui.Parent = playerGui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(560, 160)
	box.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	box.BackgroundTransparency = 0.15
	box.BorderSizePixel = 0
	box.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = box

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -40, 0, 42)
	titleLabel.Position = UDim2.new(0, 20, 0, 18)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Loading..."
	titleLabel.Parent = box

	detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "Detail"
	detailLabel.Size = UDim2.new(1, -40, 0, 28)
	detailLabel.Position = UDim2.new(0, 20, 0, 62)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = Enum.Font.Gotham
	detailLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
	detailLabel.TextScaled = true
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.Text = ""
	detailLabel.Parent = box

	barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, -40, 0, 18)
	barBg.Position = UDim2.new(0, 20, 0, 108)
	barBg.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
	barBg.BorderSizePixel = 0
	barBg.Parent = box

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 9)
	barCorner.Parent = barBg

	barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(102, 178, 255)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 9)
	fillCorner.Parent = barFill

	pctLabel = Instance.new("TextLabel")
	pctLabel.Name = "Pct"
	pctLabel.Size = UDim2.new(1, -40, 0, 20)
	pctLabel.Position = UDim2.new(0, 20, 0, 132)
	pctLabel.BackgroundTransparency = 1
	pctLabel.Font = Enum.Font.Gotham
	pctLabel.TextColor3 = Color3.new(1, 1, 1)
	pctLabel.TextScaled = true
	pctLabel.TextXAlignment = Enum.TextXAlignment.Right
	pctLabel.Text = "0%"
	pctLabel.Parent = box
end

local function chooseDisplayToken()
	local bestId = nil
	local bestState = nil
	local bestProgressId = nil
	local bestProgressState = nil

	for tokenId, state in pairs(activeTokens) do
		if not bestId or tokenId > bestId then
			bestId = tokenId
			bestState = state
		end
		if typeof(state.progress) == "number" and (not bestProgressId or tokenId > bestProgressId) then
			bestProgressId = tokenId
			bestProgressState = state
		end
	end

	return bestProgressState or bestState
end

local function refresh()
	ensureGui()

	local displayState = chooseDisplayToken()
	if not displayState then
		if gui then
			gui.Enabled = false
		end
		unlockInput()
		return
	end

	lockInput()
	gui.Enabled = true

	titleLabel.Text = tostring(displayState.title or "Loading...")
	detailLabel.Text = tostring(displayState.message or "")
	detailLabel.Visible = detailLabel.Text ~= ""

	local progress = displayState.progress
	local hasProgress = typeof(progress) == "number"
	barBg.Visible = hasProgress
	pctLabel.Visible = hasProgress
	if hasProgress then
		local alpha = math.clamp(progress, 0, 1)
		barFill.Size = UDim2.new(alpha, 0, 1, 0)
		pctLabel.Text = tostring(math.floor(alpha * 100 + 0.5)) .. "%"
	else
		barFill.Size = UDim2.new(0, 0, 1, 0)
		pctLabel.Text = ""
	end
end

function Overlay.Acquire(config: {[string]: any}?): number
	nextTokenId += 1
	activeTokens[nextTokenId] = {
		title = config and config.title or "Loading...",
		message = config and config.message or "",
		progress = config and config.progress or nil,
	}
	refresh()
	return nextTokenId
end

function Overlay.Update(tokenId: number, config: {[string]: any}?)
	local state = activeTokens[tokenId]
	if not state or not config then
		return
	end

	for key, value in pairs(config) do
		state[key] = value
	end
	refresh()
end

function Overlay.Release(tokenId: number)
	if not activeTokens[tokenId] then
		return
	end

	activeTokens[tokenId] = nil
	refresh()
end

return Overlay
