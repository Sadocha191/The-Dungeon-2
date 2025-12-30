-- SCRIPT: StarterWeaponOnSpawn.server.lua
-- GDZIE: ServerScriptService/StarterWeaponOnSpawn.server.lua
-- CO: daje/odtwarza broń startową bez nadpisywania.
--     Jeśli gracz ma już broń (WeaponType) -> nic nie robi.
--     Jeśli gracz nie ma broni -> daje tę z DS (StarterWeaponName) albo Rusty Sword.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStateStore = require(ServerScriptService:WaitForChild("PlayerStateStore"))

local templates = ServerStorage:WaitForChild("WeaponTemplates")
local START_WEAPON_NAME = "Rusty Sword"

local function isWeaponTool(inst: Instance): boolean
	return inst:IsA("Tool") and typeof(inst:GetAttribute("WeaponType")) == "string"
end

local function hasAnyWeapon(player: Player): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, inst in ipairs(backpack:GetChildren()) do
			if isWeaponTool(inst) then return true end
		end
	end
	local char = player.Character
	if char then
		for _, inst in ipairs(char:GetChildren()) do
			if isWeaponTool(inst) then return true end
		end
	end
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, inst in ipairs(starterGear:GetChildren()) do
			if isWeaponTool(inst) then return true end
		end
	end
	return false
end

local function containerHasTool(container: Instance?, toolName: string): boolean
	if not container then return false end
	local t = container:FindFirstChild(toolName)
	return t ~= nil and t:IsA("Tool")
end

local function giveTool(player: Player, toolName: string): boolean
	local template = templates:FindFirstChild(toolName)
	if not template or not template:IsA("Tool") then
		warn("[StarterWeapon] Missing template:", toolName)
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then
		warn("[StarterWeapon] No Backpack for", player.Name)
		return false
	end

	if not containerHasTool(backpack, toolName) then
		template:Clone().Parent = backpack
	end

	local starterGear = player:FindFirstChild("StarterGear") or player:WaitForChild("StarterGear", 10)
	if starterGear and not containerHasTool(starterGear, toolName) then
		template:Clone().Parent = starterGear
	end

	return true
end

local function ensureWeapon(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)

	-- ✅ jeśli ma już jakąkolwiek broń (np. gacha) -> nic nie rób
	if hasAnyWeapon(player) then
		return
	end

	-- ✅ jeśli w DS jest zapisana broń (nawet gdy StarterWeaponClaimed=true) -> odtwórz ją
	local preferred = START_WEAPON_NAME
	if typeof(state.StarterWeaponName) == "string" and state.StarterWeaponName ~= "" then
		preferred = state.StarterWeaponName
	end

	if giveTool(player, preferred) then
		-- jeśli nie było flagi, ustaw ją (na przyszłość)
		if not state.StarterWeaponClaimed then
			PlayerStateStore.SetStarterWeaponClaimed(player, preferred)
		end
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	task.defer(function()
		ensureWeapon(player)
	end)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			ensureWeapon(player)
		end)
	end)
end)

print("[StarterWeaponOnSpawn] Ready ->", START_WEAPON_NAME)
