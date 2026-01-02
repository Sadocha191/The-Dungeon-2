-- SCRIPT: StarterWeaponOnSpawn.server.lua
-- GDZIE: ServerScriptService/StarterWeaponOnSpawn.server.lua
-- CO: daje/odtwarza broń startową bez nadpisywania.
--     Jeśli gracz ma już broń (WeaponType) -> nic nie robi.
--     Jeśli gracz nie ma broni -> daje tę z DS (StarterWeaponName) albo Knight's Oath.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStateStore = require(ServerScriptService:WaitForChild("PlayerStateStore"))

local function findWeaponCatalog(): ModuleScript?
	local direct = ServerScriptService:FindFirstChild("WeaponCatalog", true)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	local folder = ServerScriptService:FindFirstChild("ModuleScript")
		or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild("WeaponCatalog")
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end
	return nil
end

local weaponCatalogModule = findWeaponCatalog()
if not weaponCatalogModule then
	warn("[StarterWeapon] Missing WeaponCatalog module; starter weapon disabled.")
	return
end

local WeaponCatalog = require(weaponCatalogModule)

local START_WEAPON_NAME = "Sword"

local WeaponTemplates = ServerStorage:FindFirstChild("WeaponTemplates")

local function isWeaponTool(inst: Instance): boolean
	if not inst:IsA("Tool") then
		return false
	end
	if typeof(inst:GetAttribute("WeaponType")) == "string" then
		return true
	end
	return WeaponTemplates and WeaponTemplates:FindFirstChild(inst.Name, true) ~= nil
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

local function findWeaponName(player: Player): string?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, inst in ipairs(backpack:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	local char = player.Character
	if char then
		for _, inst in ipairs(char:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, inst in ipairs(starterGear:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	return nil
end

local function containerHasTool(container: Instance?, toolName: string): boolean
	if not container then return false end
	local t = container:FindFirstChild(toolName)
	return t ~= nil and t:IsA("Tool")
end

local function giveTool(player: Player, toolName: string): boolean
	local template = WeaponCatalog.FindTemplate(toolName)
	if not template then
		warn("[StarterWeapon] Missing template:", toolName)
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then
		warn("[StarterWeapon] No Backpack for", player.Name)
		return false
	end

	if not containerHasTool(backpack, toolName) then
		local clone = template:Clone()
		WeaponCatalog.PrepareTool(clone, toolName)
		clone.Parent = backpack
	end

	return true
end

local function ensureWeapon(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)

	-- ✅ jeśli ma już jakąkolwiek broń (np. gacha) -> nic nie rób
	if hasAnyWeapon(player) then
		local currentName = findWeaponName(player)
		if typeof(currentName) == "string" and currentName ~= "" then
			PlayerStateStore.EnsureOwnedWeapon(player, currentName)
			if state.StarterWeaponName ~= currentName then
				PlayerStateStore.SetEquippedWeaponName(player, currentName)
			end
		end
		return
	end

	-- ✅ jeśli w DS jest zapisana broń (nawet gdy StarterWeaponClaimed=true) -> odtwórz ją
	local preferred = START_WEAPON_NAME
	if typeof(state.StarterWeaponName) == "string" and state.StarterWeaponName ~= "" then
		preferred = state.StarterWeaponName
	end

	if not giveTool(player, preferred) and preferred ~= START_WEAPON_NAME then
		preferred = START_WEAPON_NAME
		giveTool(player, preferred)
	end

	if preferred == START_WEAPON_NAME or WeaponCatalog.FindTemplate(preferred) then
		PlayerStateStore.EnsureOwnedWeapon(player, preferred)
		PlayerStateStore.SetEquippedWeaponName(player, preferred)
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
