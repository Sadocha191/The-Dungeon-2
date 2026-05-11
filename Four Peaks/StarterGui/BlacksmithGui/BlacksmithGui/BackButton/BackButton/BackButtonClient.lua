local button = script.Parent
local gui = button:FindFirstAncestor("BlacksmithGui")

if gui then
	local closeRequested = gui:FindFirstChild("BlacksmithCloseRequested")
	if not closeRequested then
		closeRequested = Instance.new("BindableEvent")
		closeRequested.Name = "BlacksmithCloseRequested"
		closeRequested.Parent = gui
	end

	if button:IsA("GuiButton") and closeRequested:IsA("BindableEvent") then
		button.MouseButton1Click:Connect(function()
			closeRequested:Fire()
		end)
	end
end
