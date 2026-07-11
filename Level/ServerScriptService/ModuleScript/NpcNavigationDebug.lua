local RunService = game:GetService("RunService")

local NpcNavigationDebug = {}

local enabled = false
local selectedNpcId = nil
local DEBUG_FOLDER_NAME = "_NpcNavigationDebug"
local MAX_DEBUG_NPCS = 24

local function clearFolder()
	local existing = workspace:FindFirstChild(DEBUG_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

local function makePart(parent: Instance, name: string, position: Vector3, color: Color3, size: number)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.25
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = parent
	return part
end

local function makeLine(parent: Instance, from: Vector3, to: Vector3, color: Color3, thickness: number)
	local delta = to - from
	if delta.Magnitude <= 0.05 then
		return
	end
	local line = Instance.new("Part")
	line.Name = "RouteSegment"
	line.Size = Vector3.new(thickness, thickness, delta.Magnitude)
	line.CFrame = CFrame.lookAt((from + to) * 0.5, to)
	line.Color = color
	line.Material = Enum.Material.Neon
	line.Transparency = 0.35
	line.Anchored = true
	line.CanCollide = false
	line.CanTouch = false
	line.CanQuery = false
	line.Parent = parent
end

local function waypointPosition(waypoint: any): Vector3?
	if typeof(waypoint) == "Vector3" then
		return waypoint
	end
	if type(waypoint) == "table" and typeof(waypoint.Position) == "Vector3" then
		return waypoint.Position
	end
	return nil
end

local function addLabel(adornee: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NavigationState"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(280, 74)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Code
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 245, 255)
	label.TextSize = 13
	label.TextWrapped = true
	label.Parent = billboard
end

function NpcNavigationDebug.SetEnabled(newEnabled: boolean, npcId: string?)
	if not RunService:IsStudio() then
		return false
	end
	enabled = newEnabled == true
	selectedNpcId = npcId and tostring(npcId) or nil
	if not enabled then
		clearFolder()
	end
	return enabled
end

function NpcNavigationDebug.IsEnabled(): boolean
	return RunService:IsStudio() and enabled
end

function NpcNavigationDebug.Render(npcPairs: () -> (), getDebug: (any) -> any, metrics: {[string]: any})
	if not NpcNavigationDebug.IsEnabled() then
		return
	end
	clearFolder()
	local folder = Instance.new("Folder")
	folder.Name = DEBUG_FOLDER_NAME
	folder.Parent = workspace

	local rendered = 0
	local renderedAirGraph = false
	for _, npc in npcPairs() do
		if rendered >= MAX_DEBUG_NPCS then
			break
		end
		if not selectedNpcId or npc.id == selectedNpcId then
			local debugInfo = getDebug(npc)
			if debugInfo then
				rendered += 1
				local npcFolder = Instance.new("Folder")
				npcFolder.Name = npc.id
				npcFolder.Parent = folder
				local marker = makePart(npcFolder, "Npc", npc.position, Color3.fromRGB(70, 210, 255), 0.8)
				addLabel(marker, string.format(
					"%s | %s | target=%s\n%s | unreachable=%s\nqueue=%d active=%d",
					debugInfo.profile or "?",
					debugInfo.status or "?",
					debugInfo.target or "none",
					debugInfo.lastRepathReason or "none",
					tostring(debugInfo.unreachable == true),
					metrics.ground and metrics.ground.pendingPaths or 0,
					metrics.ground and metrics.ground.activePaths or 0
				))

				local previous = npc.position
				for index, waypoint in ipairs(debugInfo.waypoints or {}) do
					local position = waypointPosition(waypoint)
					if position then
						local color = index == debugInfo.waypointIndex and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(90, 255, 130)
						makePart(npcFolder, "Waypoint_" .. index, position, color, 0.55)
						makeLine(npcFolder, previous, position, color, 0.18)
						previous = position
					end
				end
				if debugInfo.status == "Direct" and typeof(debugInfo.targetPosition) == "Vector3" then
					makeLine(npcFolder, npc.position, debugInfo.targetPosition, Color3.fromRGB(80, 220, 255), 0.12)
				end
				if typeof(debugInfo.groundProbe) == "Vector3" then
					makePart(npcFolder, "GroundProbe", debugInfo.groundProbe, Color3.fromRGB(255, 120, 70), 0.45)
				end
				if not renderedAirGraph and type(debugInfo.airConnections) == "table" then
					renderedAirGraph = true
					for _, edge in ipairs(debugInfo.airConnections) do
						if typeof(edge[1]) == "Vector3" and typeof(edge[2]) == "Vector3" then
							makeLine(folder, edge[1], edge[2], Color3.fromRGB(170, 110, 255), 0.1)
						end
					end
				end
			end
		end
	end
end

function NpcNavigationDebug.Destroy()
	enabled = false
	selectedNpcId = nil
	clearFolder()
end

return NpcNavigationDebug
