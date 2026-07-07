local InventoryCharacterPreview = {}

function InventoryCharacterPreview.new(deps)
	deps = deps or {}
	local player = deps.Player
	local viewportFrame = deps.ViewportFrame
	local viewportWorld = deps.ViewportWorld
	local viewportCamera = deps.ViewportCamera
	local userInputService = deps.UserInputService

	local controller = {}
	local previewModel = nil
	local previewPivotOffset = CFrame.new()
	local previewSize = Vector3.new(4, 6, 2)
	local previewYaw = math.rad(18)
	local previewDragging = false
	local previewLastX = 0

	local function rotatePreview(deltaX)
		if not previewModel then
			return
		end
		previewYaw += deltaX * 0.012
		previewModel:PivotTo(CFrame.Angles(0, previewYaw, 0) * previewPivotOffset)
	end

	function controller.Refresh()
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end
		for _, child in ipairs(viewportWorld:GetChildren()) do
			child:Destroy()
		end
		local character = player.Character
		if not character then
			return
		end
		local oldArchivable = character.Archivable
		character.Archivable = true
		local ok, clone = pcall(function()
			return character:Clone()
		end)
		character.Archivable = oldArchivable
		if not ok or not clone then
			return
		end
		clone.Name = "PreviewCharacter"
		for _, object in ipairs(clone:GetDescendants()) do
			if object:IsA("BaseScript") then
				object:Destroy()
			elseif object:IsA("BasePart") then
				object.Anchored = true
				object.CanCollide = false
				object.CanTouch = false
				object.CanQuery = false
			elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
				object.Enabled = false
			elseif object:IsA("Humanoid") then
				object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				object.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			end
		end
		clone.Parent = viewportWorld
		previewModel = clone
		local boxCFrame, size = clone:GetBoundingBox()
		previewSize = size
		previewPivotOffset = boxCFrame:ToObjectSpace(clone:GetPivot())
		clone:PivotTo(CFrame.Angles(0, previewYaw, 0) * previewPivotOffset)
		local focus = Vector3.new(0, 0, 0)
		local distance = math.max(previewSize.Y * 1.15, previewSize.X * 1.8, 7)
		viewportCamera.CFrame = CFrame.new(Vector3.new(0, previewSize.Y * 0.02, -distance), focus)
	end

	function controller.CancelDrag()
		previewDragging = false
	end

	viewportFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			previewDragging = true
			previewLastX = input.Position.X
		end
	end)

	viewportFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			previewDragging = false
		end
	end)

	userInputService.InputChanged:Connect(function(input)
		if not previewDragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position.X - previewLastX
			previewLastX = input.Position.X
			rotatePreview(delta)
		end
	end)

	return controller
end

return InventoryCharacterPreview
