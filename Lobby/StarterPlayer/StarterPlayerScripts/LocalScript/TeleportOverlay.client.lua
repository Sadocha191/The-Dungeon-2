-- TeleportOverlay.client.lua (Lobby)
-- Shows "Teleporting..." overlay + blocks input when PortalToDungeon fires TeleportStatus {type="teleporting"}.
-- Works with PortalToDungeon.server.lua (Lobby).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local plr = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local TeleportStatus = remotes:FindFirstChild("TeleportStatus")
if not TeleportStatus then
	warn("[TeleportOverlay] Missing TeleportStatus RemoteEvent")
	return
end

local gui = plr:WaitForChild("PlayerGui"):WaitForChild("TeleportOverlayGui")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false

local dim = gui:WaitForChild("dim")
dim.Size = UDim2.fromScale(1,1)
dim.BackgroundColor3 = Color3.new(0,0,0)
dim.BackgroundTransparency = 0.35
dim.Parent = gui

local label = gui:WaitForChild("label")
label.Size = UDim2.new(0, 520, 0, 70)
label.Position = UDim2.new(0.5, -260, 0.5, -35)
label.BackgroundTransparency = 1
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.new(1,1,1)
label.Text = "Teleporting..."
label.Parent = gui

local function sinkAll()
	return Enum.ContextActionResult.Sink
end

local function lockInput()
	-- High priority input sink to block movement/clicks while teleporting
	ContextActionService:BindActionAtPriority(
		"__TeleportLockAll",
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
	ContextActionService:UnbindAction("__TeleportLockAll")
end

local function setTeleporting(on: boolean, message: string?)
	gui.Enabled = on
	if on then
		label.Text = message or "Teleporting..."
		lockInput()
	else
		unlockInput()
	end
end

TeleportStatus.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type == "teleporting" then
		setTeleporting(true, payload.message)
	elseif payload.type == "failed" then
		-- Allow user to close/try again
		setTeleporting(false)
	end
end)
