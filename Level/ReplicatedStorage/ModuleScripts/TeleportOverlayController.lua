local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local TeleportOverlayController = {}

local LOCK_ACTION = "__TeleportOverlayLock"

local initialized = false
local gui = nil
local label = nil

local function sinkAll()
	return Enum.ContextActionResult.Sink
end

local function lockInput()
	ContextActionService:BindActionAtPriority(
		LOCK_ACTION,
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
end

local function unlockInput()
	ContextActionService:UnbindAction(LOCK_ACTION)
end

local function ensureGui()
	if gui and gui.Parent and label and label.Parent then
		return gui, label
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	gui = playerGui:FindFirstChild("TeleportOverlay")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "TeleportOverlay"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 200
		gui.Enabled = false
		gui.Parent = playerGui
	end

	local dim = gui:FindFirstChild("Dim")
	if not dim then
		dim = Instance.new("Frame")
		dim.Name = "Dim"
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		dim.BackgroundTransparency = 0.35
		dim.BorderSizePixel = 0
		dim.Parent = gui
	end

	label = gui:FindFirstChild("Label")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(0, 520, 0, 70)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "Teleporting..."
		label.Parent = gui
	end

	return gui, label
end

local function setTeleporting(on: boolean, message: string?)
	local overlayGui, overlayLabel = ensureGui()
	overlayGui.Enabled = on
	if on then
		overlayLabel.Text = message or "Teleporting..."
		lockInput()
	else
		unlockInput()
	end
end

function TeleportOverlayController.Show(message: string?)
	TeleportOverlayController.Init()
	setTeleporting(true, message)
end

function TeleportOverlayController.Hide()
	if initialized or gui then
		setTeleporting(false)
	end
end

function TeleportOverlayController.Init()
	if initialized then
		return
	end
	initialized = true
	ensureGui()

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local teleportStatus = remotes:WaitForChild("TeleportStatus")
	teleportStatus.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.type == "teleporting" then
			setTeleporting(true, payload.message)
		elseif payload.type == "failed" then
			setTeleporting(false)
		end
	end)
end

return TeleportOverlayController