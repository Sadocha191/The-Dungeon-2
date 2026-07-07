local BlacksmithSceneController = {}

function BlacksmithSceneController.new(deps)
	deps = deps or {}
	local player = deps.Player
	local playerGui = deps.PlayerGui
	local gui = deps.Gui
	local cameraPoint = deps.CameraPoint
	local workspaceService = deps.Workspace
	local runService = deps.RunService
	local hiddenLobbyGuiNames = deps.HiddenLobbyGuiNames or {}
	local cameraOffset = deps.CameraOffset or Vector3.new(0, 2.5, -8)
	local cameraFieldOfView = deps.CameraFieldOfView or 45
	local cameraRenderStepName = deps.CameraRenderStepName or "BlacksmithCameraView"

	local controller = {}
	local hiddenLobbyGuiStates = nil
	local savedCameraState = nil
	local cameraActive = false
	local characterAddedConnection = nil
	local characterDescendantAddedConnection = nil
	local hiddenCharacterParts = {}
	local hiddenCharacterEffects = {}
	local hiddenBlacksmithPromptStates = {}
	local blacksmithPromptWatcher = nil
	local savedMovementState = nil

	local function getBlacksmithModel()
		local npcs = workspaceService:FindFirstChild("NPCs")
		return npcs and (npcs:FindFirstChild("Blacksmith") or npcs:FindFirstChild("BlacksmithNPC")) or nil
	end

	local function computeBlacksmithCameraCFrame()
		local targetPosition = cameraPoint.WorldPosition
		local cameraPosition = targetPosition + cameraOffset
		return CFrame.lookAt(cameraPosition, targetPosition)
	end

	local function applyBlacksmithCamera()
		local camera = workspaceService.CurrentCamera
		if not camera then
			return
		end

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = cameraFieldOfView
		camera.CFrame = computeBlacksmithCameraCFrame()
	end

	local function disconnectCharacterVisibilityConnections()
		if characterDescendantAddedConnection then
			characterDescendantAddedConnection:Disconnect()
			characterDescendantAddedConnection = nil
		end
		if characterAddedConnection then
			characterAddedConnection:Disconnect()
			characterAddedConnection = nil
		end
	end

	local function trackHiddenCharacterPart(part)
		if hiddenCharacterParts[part] == nil then
			hiddenCharacterParts[part] = part.LocalTransparencyModifier
		end
		part.LocalTransparencyModifier = 1
	end

	local function trackHiddenCharacterEffect(effect)
		local enabled = nil
		if effect:IsA("ParticleEmitter") or effect:IsA("Trail") or effect:IsA("Beam") or effect:IsA("Highlight") then
			enabled = effect.Enabled
		elseif effect:IsA("BillboardGui") or effect:IsA("SurfaceGui") then
			enabled = effect.Enabled
		end

		if enabled == nil then
			return
		end

		if hiddenCharacterEffects[effect] == nil then
			hiddenCharacterEffects[effect] = enabled
		end
		effect.Enabled = false
	end

	local function hideCharacterDescendant(descendant)
		if descendant:IsA("BasePart") then
			trackHiddenCharacterPart(descendant)
		elseif descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Highlight")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("SurfaceGui")
		then
			trackHiddenCharacterEffect(descendant)
		end
	end

	local function applyLocalCharacterHidden(character)
		if not character then
			return
		end

		for _, descendant in ipairs(character:GetDescendants()) do
			hideCharacterDescendant(descendant)
		end

		if characterDescendantAddedConnection then
			characterDescendantAddedConnection:Disconnect()
		end
		characterDescendantAddedConnection = character.DescendantAdded:Connect(function(descendant)
			if gui.Enabled then
				hideCharacterDescendant(descendant)
			end
		end)
	end

	local function setPromptHidden(prompt)
		if not prompt or not prompt:IsA("ProximityPrompt") then
			return
		end
		if hiddenBlacksmithPromptStates[prompt] == nil then
			hiddenBlacksmithPromptStates[prompt] = prompt.Enabled
		end
		prompt.Enabled = false
	end

	function controller.HideLobbyUi()
		if hiddenLobbyGuiStates then
			return
		end

		hiddenLobbyGuiStates = {}
		for _, guiName in ipairs(hiddenLobbyGuiNames) do
			local lobbyGui = playerGui:FindFirstChild(guiName)
			if lobbyGui and lobbyGui:IsA("ScreenGui") then
				hiddenLobbyGuiStates[guiName] = lobbyGui.Enabled
				lobbyGui.Enabled = false
			end
		end
	end

	function controller.RestoreLobbyUi()
		if not hiddenLobbyGuiStates then
			return
		end

		for guiName, wasEnabled in pairs(hiddenLobbyGuiStates) do
			local lobbyGui = playerGui:FindFirstChild(guiName)
			if lobbyGui and lobbyGui:IsA("ScreenGui") then
				lobbyGui.Enabled = wasEnabled
			end
		end

		hiddenLobbyGuiStates = nil
	end

	function controller.StartCamera()
		if cameraActive then
			return
		end

		local camera = workspaceService.CurrentCamera
		if not camera then
			return
		end

		savedCameraState = {
			CameraType = camera.CameraType,
			CFrame = camera.CFrame,
			CameraSubject = camera.CameraSubject,
			FieldOfView = camera.FieldOfView,
		}

		cameraActive = true
		runService:UnbindFromRenderStep(cameraRenderStepName)
		runService:BindToRenderStep(cameraRenderStepName, Enum.RenderPriority.Camera.Value + 2, applyBlacksmithCamera)
		applyBlacksmithCamera()
	end

	function controller.StopCamera()
		if not cameraActive then
			return
		end

		cameraActive = false
		runService:UnbindFromRenderStep(cameraRenderStepName)

		local camera = workspaceService.CurrentCamera
		if camera and savedCameraState then
			camera.CameraType = savedCameraState.CameraType
			camera.CFrame = savedCameraState.CFrame
			camera.CameraSubject = savedCameraState.CameraSubject
			camera.FieldOfView = savedCameraState.FieldOfView
		end

		savedCameraState = nil
	end

	function controller.HideLocalCharacter()
		if characterAddedConnection then
			return
		end

		applyLocalCharacterHidden(player.Character)
		characterAddedConnection = player.CharacterAdded:Connect(function(character)
			if not gui.Enabled then
				return
			end
			task.defer(function()
				if gui.Enabled then
					applyLocalCharacterHidden(character)
				end
			end)
		end)
	end

	function controller.RestoreLocalCharacter()
		disconnectCharacterVisibilityConnections()

		for part, originalTransparency in pairs(hiddenCharacterParts) do
			if part and part.Parent then
				part.LocalTransparencyModifier = originalTransparency
			end
		end
		table.clear(hiddenCharacterParts)

		for effect, originalEnabled in pairs(hiddenCharacterEffects) do
			if effect and effect.Parent and effect.Enabled ~= originalEnabled then
				effect.Enabled = originalEnabled
			end
		end
		table.clear(hiddenCharacterEffects)
	end

	function controller.SnapshotMovementState()
		if savedMovementState then
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		savedMovementState = {
			humanoid = humanoid,
			walkSpeed = humanoid.WalkSpeed,
			jumpPower = humanoid.JumpPower,
			autoRotate = humanoid.AutoRotate,
			platformStand = humanoid.PlatformStand,
		}
	end

	function controller.RestoreMovementState()
		if not savedMovementState then
			return
		end

		local humanoid = savedMovementState.humanoid
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = savedMovementState.walkSpeed
			humanoid.JumpPower = savedMovementState.jumpPower
			humanoid.AutoRotate = savedMovementState.autoRotate
			humanoid.PlatformStand = savedMovementState.platformStand
		end

		savedMovementState = nil
	end

	function controller.HideBlacksmithPrompts()
		if blacksmithPromptWatcher then
			return
		end

		local smith = getBlacksmithModel()
		if not smith then
			return
		end

		for _, descendant in ipairs(smith:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				setPromptHidden(descendant)
			end
		end

		blacksmithPromptWatcher = smith.DescendantAdded:Connect(function(descendant)
			if gui.Enabled and descendant:IsA("ProximityPrompt") then
				setPromptHidden(descendant)
			end
		end)
	end

	function controller.RestoreBlacksmithPrompts()
		if blacksmithPromptWatcher then
			blacksmithPromptWatcher:Disconnect()
			blacksmithPromptWatcher = nil
		end

		for prompt, wasEnabled in pairs(hiddenBlacksmithPromptStates) do
			if prompt and prompt.Parent then
				prompt.Enabled = wasEnabled
			end
		end
		table.clear(hiddenBlacksmithPromptStates)
	end

	function controller.IsPromptInsideBlacksmith(prompt)
		local smith = getBlacksmithModel()
		if not smith then
			return false
		end

		local current = prompt and prompt.Parent
		while current do
			if current == smith then
				return true
			end
			current = current.Parent
		end

		return false
	end

	function controller.Cleanup()
		controller.StopCamera()
		controller.RestoreMovementState()
		controller.RestoreLobbyUi()
		controller.RestoreLocalCharacter()
		controller.RestoreBlacksmithPrompts()
	end

	return controller
end

return BlacksmithSceneController
