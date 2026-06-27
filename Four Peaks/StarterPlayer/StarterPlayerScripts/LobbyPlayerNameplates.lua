local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts")
local Config = require(moduleFolder:WaitForChild("LobbyPresentationConfig"))

local NAMEPLATE_NAME = "LobbyPlayerNameplate"
local ACCOUNT_LEVEL_ATTRIBUTE = tostring(Config.AccountLevelAttribute or "AccountLevel")
local BASE_SIZE = Vector2.new(128, 42)
local MIN_DISTANCE_SCALE = 0.65
local MAX_DISTANCE_SCALE = 1

local maxDistance = math.max(20, tonumber(Config.NameplateMaxDistance) or 85)
local studsOffsetWorld = Config.NameplateStudsOffsetWorld
if typeof(studsOffsetWorld) ~= "Vector3" then
	studsOffsetWorld = Vector3.new(0, 2.75, 0)
end

local tracked = {}
local scaleConnection: RBXScriptConnection? = nil

local function getAccountLevel(player: Player): number
	local level = math.floor(tonumber(player:GetAttribute(ACCOUNT_LEVEL_ATTRIBUTE)) or 1)
	return math.max(1, level)
end

local function getPlayerName(player: Player): string
	local displayName = tostring(player.DisplayName or "")
	if displayName ~= "" then
		return displayName
	end
	return player.Name
end

local function buildTextLabel(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextScaled = false
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function removeExtraNameplates(head: BasePart): BillboardGui?
	local keeper: BillboardGui? = nil
	for _, child in ipairs(head:GetChildren()) do
		if child.Name == NAMEPLATE_NAME and child:IsA("BillboardGui") then
			if keeper then
				child:Destroy()
			else
				keeper = child
			end
		end
	end
	return keeper
end

local function createOrResetGui(head: BasePart): BillboardGui
	local gui = removeExtraNameplates(head)
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = NAMEPLATE_NAME
	end

	gui.Adornee = head
	gui.AlwaysOnTop = false
	gui.Enabled = true
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance
	gui.Size = UDim2.fromOffset(BASE_SIZE.X, BASE_SIZE.Y)
	gui.StudsOffsetWorldSpace = studsOffsetWorld
	pcall(function()
		gui.DistanceLowerLimit = 8
		gui.DistanceUpperLimit = maxDistance
	end)
	gui.Parent = head

	gui:ClearAllChildren()

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	buildTextLabel(frame, "PlayerName", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.55), 15, Color3.fromRGB(255, 255, 255))
	buildTextLabel(frame, "AccountLevel", UDim2.fromScale(0, 0.48), UDim2.fromScale(1, 0.45), 12, Color3.fromRGB(214, 232, 255))

	return gui
end

local function updateNameplateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	for _, state in pairs(tracked) do
		local gui = state.gui
		local adornee = gui and gui.Adornee
		if gui and gui.Parent and adornee and adornee:IsA("BasePart") then
			local distance = (camera.CFrame.Position - adornee.Position).Magnitude
			local distanceAlpha = math.clamp((distance - 18) / math.max(1, maxDistance - 18), 0, 1)
			local scale = MAX_DISTANCE_SCALE + (MIN_DISTANCE_SCALE - MAX_DISTANCE_SCALE) * distanceAlpha
			gui.Enabled = distance <= maxDistance
			gui.Size = UDim2.fromOffset(math.floor(BASE_SIZE.X * scale), math.floor(BASE_SIZE.Y * scale))
		end
	end
end

local function updateGui(player: Player)
	local state = tracked[player]
	local gui = state and state.gui
	if not gui or not gui.Parent then
		return
	end

	local frame = gui:FindFirstChild("Frame")
	local nameLabel = frame and frame:FindFirstChild("PlayerName")
	local levelLabel = frame and frame:FindFirstChild("AccountLevel")

	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = getPlayerName(player)
	end

	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Text = ("Lv. %d"):format(getAccountLevel(player))
	end
end

local function attachToCharacter(player: Player, character: Model)
	local head = character:FindFirstChild("Head")
	if not head then
		head = character:WaitForChild("Head", 5)
	end
	if not head or not head:IsA("BasePart") then
		return
	end

	local state = tracked[player]
	if not state then
		state = { connections = {} }
		tracked[player] = state
	end

	state.gui = createOrResetGui(head)
	updateGui(player)
end

local function cleanupPlayer(player: Player)
	local state = tracked[player]
	if not state then
		return
	end

	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end

	if state.gui and state.gui.Parent then
		state.gui:Destroy()
	end

	tracked[player] = nil
end

local function watchPlayer(player: Player)
	if tracked[player] then
		return
	end

	local state = { connections = {} }
	tracked[player] = state

	table.insert(state.connections, player.CharacterAdded:Connect(function(character)
		attachToCharacter(player, character)
	end))

	table.insert(state.connections, player.CharacterRemoving:Connect(function()
		if state.gui and state.gui.Parent then
			state.gui:Destroy()
		end
		state.gui = nil
	end))

	table.insert(state.connections, player:GetAttributeChangedSignal(ACCOUNT_LEVEL_ATTRIBUTE):Connect(function()
		updateGui(player)
	end))

	table.insert(state.connections, player:GetPropertyChangedSignal("DisplayName"):Connect(function()
		updateGui(player)
	end))

	if player.Character then
		attachToCharacter(player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

scaleConnection = RunService.RenderStepped:Connect(updateNameplateScale)

script.Destroying:Connect(function()
	if scaleConnection then
		scaleConnection:Disconnect()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		cleanupPlayer(player)
	end
end)

print("[LobbyPlayerNameplates] Ready")
