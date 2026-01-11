-- SCRIPT: StarterWeaponOnSpawn.server.lua
-- CO TERAZ ROBI:
-- 1) Jeśli gracz MA broń (Tool) -> tylko synchronizuje stan (EnsureOwnedWeapon + equip name).
-- 2) Jeśli gracz NIE ma broni:
--    - jeśli ma zapisaną broń w PlayerStateStore (StarterWeaponName) -> odtwarza ją
--    - jeśli nie ma zapisu -> NIE daje nic (zero darmowych mieczy).

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))

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
	warn("[StarterWeaponOnSpawn] Missing WeaponCatalog module; disabled.")
	return
end

local WeaponCatalog = require(weaponCatalogModule)

local WeaponTemplates = ServerStorage:WaitForChild("WeaponTemplates", 10)

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
		warn("[StarterWeaponOnSpawn] Missing template:", toolName)
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then
		warn("[StarterWeaponOnSpawn] No Backpack for", player.Name)
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

	-- 1) jeśli gracz ma broń w plecaku/na postaci -> synchronizacja tylko
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

	-- 2) jeśli NIE ma broni -> odtwarzamy TYLKO jeśli jest zapisana w DS
	local preferred: string? = nil
	if typeof(state.StarterWeaponName) == "string" and state.StarterWeaponName ~= "" then
		preferred = state.StarterWeaponName
	end

	-- brak zapisanej broni = nowy gracz = NIE DAJEMY NIC
	if not preferred then
		return
	end

	-- odtwórz broń z DS
	if giveTool(player, preferred) then
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

print("[StarterWeaponOnSpawn] Ready (no free starter weapon)")
