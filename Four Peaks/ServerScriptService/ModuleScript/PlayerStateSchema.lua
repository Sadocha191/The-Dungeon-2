-- PlayerStateSchema.lua
-- Sanitization for weapon inventory and lobby profile state embedded in GlobalPlayerProgress_v1.

local Schema = {}

local function clone(value)
	if typeof(value) ~= "table" then return value end
	local copy = {}
	for key, nested in pairs(value) do
		copy[clone(key)] = clone(nested)
	end
	return copy
end
Schema.Clone = clone

local function clampInt(value, minimum)
	local number = math.floor(tonumber(value) or 0)
	if minimum ~= nil and number < minimum then return minimum end
	return number
end
Schema.ClampInt = clampInt

local function sanitizeStringList(raw)
	local out, seen = {}, {}
	if typeof(raw) ~= "table" then return out end
	for _, value in ipairs(raw) do
		if typeof(value) == "string" and value ~= "" and not seen[value] then
			seen[value] = true
			table.insert(out, value)
		end
	end
	return out
end

local function sanitizeCountMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then return out end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = clampInt(value, 0)
			if amount > 0 then out[key] = amount end
		end
	end
	return out
end

function Schema.Default()
	return {
		CreatedOnce = false,
		Profile = nil,
		StarterWeaponClaimed = false,
		StarterWeaponName = nil,
		OwnedWeapons = {},
		FavoriteWeapons = {},
		OwnedSpells = {},
		SpellLoadout = {},
		Codex = {
			Discovered = {},
			Seen = {},
		},
		WeaponInstances = {},
		EquippedWeaponInstanceId = nil,
		Missions = {
			DailyKey = 0,
			WeeklyKey = 0,
			SelectedDaily = {},
			SelectedWeekly = {},
			ClaimCounts = {},
			CountersDaily = {},
			CountersWeekly = {},
			WeeklyWeaponRuns = {},
		},
		Tutorial = {
			Active = true,
			Step = 1,
			Complete = false,
		},
	}
end

function Schema.EnsureUniqueOwnedWeapons(instances)
	local out, seen = {}, {}
	for _, instance in ipairs(instances or {}) do
		local weaponId = instance and instance.weaponId
		if typeof(weaponId) == "string" and weaponId ~= "" and not seen[weaponId] then
			seen[weaponId] = true
			table.insert(out, weaponId)
		end
	end
	return out
end

local function sanitizeWeaponInstance(raw, generateInstanceId)
	if typeof(raw) ~= "table" then return nil end
	local instance = clone(raw)
	instance.instanceId = typeof(instance.instanceId) == "string" and instance.instanceId ~= ""
		and instance.instanceId or generateInstanceId()
	instance.weaponId = tostring(instance.weaponId or "")
	if instance.weaponId == "" then return nil end
	instance.rarity = tostring(instance.rarity or "")
	instance.level = math.max(1, clampInt(instance.level, 1))
	instance.prefix = tostring(instance.prefix or "Standard")
	instance.rollStats = typeof(instance.rollStats) == "table" and clone(instance.rollStats) or {}
	instance.createdAt = math.max(0, math.floor(tonumber(instance.createdAt) or os.time()))
	instance.upgradeSilverSpent = math.max(0, clampInt(instance.upgradeSilverSpent, 0))
	instance.upgradeMaterialsSpent = sanitizeCountMap(instance.upgradeMaterialsSpent)
	if typeof(instance.craftCosts) == "table" then
		instance.craftCosts = clone(instance.craftCosts)
		instance.craftCosts.silver = math.max(0, clampInt(instance.craftCosts.silver, 0))
		instance.craftCosts.mineResources = sanitizeCountMap(instance.craftCosts.mineResources)
		instance.craftCosts.mobMaterials = sanitizeCountMap(instance.craftCosts.mobMaterials)
	end
	return instance
end

function Schema.Sanitize(raw, generateInstanceId)
	generateInstanceId = generateInstanceId or function()
		error("PlayerStateSchema.Sanitize requires an instance ID generator", 2)
	end

	local data = Schema.Default()
	if typeof(raw) == "table" then
		for key, value in pairs(raw) do data[key] = clone(value) end
	end
	data._profileMeta = nil

	data.CreatedOnce = data.CreatedOnce == true
	if data.Profile ~= nil and typeof(data.Profile) ~= "table" then data.Profile = nil end
	data.StarterWeaponClaimed = data.StarterWeaponClaimed == true
	if data.StarterWeaponName ~= nil then data.StarterWeaponName = tostring(data.StarterWeaponName) end
	data.FavoriteWeapons = sanitizeStringList(data.FavoriteWeapons)
	data.OwnedSpells = sanitizeStringList(data.OwnedSpells)
	data.SpellLoadout = sanitizeStringList(data.SpellLoadout)

	if typeof(data.Codex) ~= "table" then data.Codex = {} end
	data.Codex.Discovered = typeof(data.Codex.Discovered) == "table" and clone(data.Codex.Discovered) or {}
	data.Codex.Seen = typeof(data.Codex.Seen) == "table" and clone(data.Codex.Seen) or {}

	local instances = {}
	for _, rawInstance in ipairs(typeof(data.WeaponInstances) == "table" and data.WeaponInstances or {}) do
		local instance = sanitizeWeaponInstance(rawInstance, generateInstanceId)
		if instance then table.insert(instances, instance) end
	end

	if #instances == 0 and typeof(data.OwnedWeapons) == "table" then
		for _, weaponId in ipairs(data.OwnedWeapons) do
			if typeof(weaponId) == "string" and weaponId ~= "" then
				table.insert(instances, {
					instanceId = generateInstanceId(),
					weaponId = weaponId,
					rarity = "",
					level = 1,
					prefix = "Standard",
					rollStats = {},
					createdAt = os.time(),
					upgradeSilverSpent = 0,
					upgradeMaterialsSpent = {},
				})
			end
		end
	end
	data.WeaponInstances = instances
	data.OwnedWeapons = Schema.EnsureUniqueOwnedWeapons(instances)

	if typeof(data.Missions) ~= "table" then data.Missions = {} end
	local missions = data.Missions
	missions.DailyKey = tonumber(missions.DailyKey) or 0
	missions.WeeklyKey = tonumber(missions.WeeklyKey) or 0
	missions.SelectedDaily = sanitizeStringList(missions.SelectedDaily)
	missions.SelectedWeekly = sanitizeStringList(missions.SelectedWeekly)
	missions.ClaimCounts = sanitizeCountMap(missions.ClaimCounts)
	missions.CountersDaily = sanitizeCountMap(missions.CountersDaily)
	missions.CountersWeekly = sanitizeCountMap(missions.CountersWeekly)
	missions.WeeklyWeaponRuns = sanitizeCountMap(missions.WeeklyWeaponRuns)

	if typeof(data.Tutorial) ~= "table" then data.Tutorial = {} end
	data.Tutorial.Active = data.Tutorial.Active ~= false
	data.Tutorial.Step = math.max(1, clampInt(data.Tutorial.Step, 1))
	data.Tutorial.Complete = data.Tutorial.Complete == true

	local equippedOk = false
	if typeof(data.EquippedWeaponInstanceId) == "string" and data.EquippedWeaponInstanceId ~= "" then
		for _, instance in ipairs(instances) do
			if instance.instanceId == data.EquippedWeaponInstanceId then
				equippedOk = true
				break
			end
		end
	end
	if not equippedOk then
		local selected = nil
		if typeof(data.StarterWeaponName) == "string" and data.StarterWeaponName ~= "" then
			for _, instance in ipairs(instances) do
				if instance.weaponId == data.StarterWeaponName then
					selected = instance.instanceId
					break
				end
			end
		end
		if not selected and instances[1] then selected = instances[1].instanceId end
		data.EquippedWeaponInstanceId = selected
	end

	return data
end

return Schema
