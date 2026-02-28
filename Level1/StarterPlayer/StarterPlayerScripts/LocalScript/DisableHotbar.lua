local StarterGui = game:GetService("StarterGui")

-- czasem SetCoreGuiEnabled działa dopiero po chwili
task.wait(0.2)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)