local ModalUiState = {}

local function isEnabledScreenGui(gui: Instance?): boolean
	return gui ~= nil and gui:IsA("ScreenGui") and gui.Enabled
end

function ModalUiState.IsPauseMenuOpen(playerGui: PlayerGui): boolean
	local pauseGui = playerGui:FindFirstChild("Pause")
	if not pauseGui or not pauseGui:IsA("ScreenGui") then
		return false
	end

	local overlay = pauseGui:FindFirstChild("MenuOverlay")
	local menuOpen = pauseGui:GetAttribute("MenuOpen") == true
	return menuOpen or (overlay and overlay:IsA("GuiObject") and overlay.Visible) == true
end

function ModalUiState.IsDailyMissionsOpen(playerGui: PlayerGui): boolean
	local dailyMissionsGui = playerGui:FindFirstChild("DailyMissions")
	if not dailyMissionsGui or not dailyMissionsGui:IsA("ScreenGui") then
		return false
	end

	return dailyMissionsGui:GetAttribute("BoardShown") == true
end

function ModalUiState.IsRewardRevealOpen(playerGui: PlayerGui): boolean
	return isEnabledScreenGui(playerGui:FindFirstChild("RewardRevealGui"))
end

function ModalUiState.IsChestRewardOpen(playerGui: PlayerGui): boolean
	return isEnabledScreenGui(playerGui:FindFirstChild("ChestRewardGui"))
		or isEnabledScreenGui(playerGui:FindFirstChild("ChestOpening"))
end

function ModalUiState.IsBlockingUiOpen(playerGui: PlayerGui): boolean
	local upgradesGui = playerGui:FindFirstChild("UpgradesGUI")
	local upgradesMain = upgradesGui and upgradesGui:FindFirstChild("Main")
	if upgradesGui and upgradesGui:IsA("ScreenGui") and upgradesGui.Enabled and upgradesMain and upgradesMain:IsA("GuiObject") and upgradesMain.Visible then
		return true
	end

	if ModalUiState.IsDailyMissionsOpen(playerGui) then
		return true
	end

	if isEnabledScreenGui(playerGui:FindFirstChild("MissionSummary")) then
		return true
	end

	if isEnabledScreenGui(playerGui:FindFirstChild("EKeyMenu")) then
		return true
	end

	if ModalUiState.IsRewardRevealOpen(playerGui) then
		return true
	end

	if ModalUiState.IsChestRewardOpen(playerGui) then
		return true
	end

	return ModalUiState.IsPauseMenuOpen(playerGui)
end

return table.freeze(ModalUiState)
