local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local remote = remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local CraftingConfig = require(moduleFolder:WaitForChild("CraftingConfig"))

local pickupToastEvent = ensureRemote("PickupToastEvent")

local PickupToastService = {}
local materialDefsById = {}

for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS or {}) do
	if typeof(def) == "table" and typeof(def.id) == "string" and def.id ~= "" then
		materialDefsById[def.id] = {
			name = def.id,
			bucket = "mineResources",
			rarity = def.rarity,
		}
	end
end

for _, def in ipairs(CraftingConfig.MOB_MATERIAL_DEFS or {}) do
	if typeof(def) == "table" and typeof(def.id) == "string" and def.id ~= "" then
		materialDefsById[def.id] = {
			name = def.id,
			bucket = "mobMaterials",
			rarity = def.rarity,
		}
	end
end

if typeof(CraftingConfig.UPGRADE_CRYSTAL_ID) == "string" and CraftingConfig.UPGRADE_CRYSTAL_ID ~= "" then
	materialDefsById[CraftingConfig.UPGRADE_CRYSTAL_ID] = {
		name = CraftingConfig.UPGRADE_CRYSTAL_ID,
		bucket = "upgradeMaterials",
		rarity = "Rare",
	}
end

if typeof(CraftingConfig.ELITE_SPECIAL_ID) == "string" and CraftingConfig.ELITE_SPECIAL_ID ~= "" then
	materialDefsById[CraftingConfig.ELITE_SPECIAL_ID] = {
		name = CraftingConfig.ELITE_SPECIAL_ID,
		bucket = "upgradeMaterials",
		rarity = "Epic",
	}
end

if typeof(CraftingConfig.BOSS_SPECIAL_ID) == "string" and CraftingConfig.BOSS_SPECIAL_ID ~= "" then
	materialDefsById[CraftingConfig.BOSS_SPECIAL_ID] = {
		name = CraftingConfig.BOSS_SPECIAL_ID,
		bucket = "upgradeMaterials",
		rarity = "Legendary",
	}
end

local function sanitizeAmount(amount)
	return math.max(1, math.floor(tonumber(amount) or 1))
end

local function sanitizeNote(note)
	note = tostring(note or "")
	if note == "" then
		return nil
	end
	return note
end

local function sanitizeRarity(rarity)
	rarity = tostring(rarity or "")
	if rarity == "" then
		return nil
	end
	return rarity
end

function PickupToastService.Push(player, payload)
	if not player or player.Parent ~= Players then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end

	local label = tostring(payload.label or "")
	if label == "" then
		return
	end

	local variant = tostring(payload.variant or "material")
	if variant == "" then
		variant = "material"
	end

	local note = sanitizeNote(payload.note)
	local key = tostring(payload.key or (variant .. "|" .. label .. "|" .. tostring(note or "")))

	pickupToastEvent:FireClient(player, {
		key = key,
		variant = variant,
		label = label,
		amount = sanitizeAmount(payload.amount),
		note = note,
		rarity = sanitizeRarity(payload.rarity),
		duration = tonumber(payload.duration),
	})
end

local function resolveMaterialInfo(materialId, bucketOverride)
	local def = nil
	if typeof(CraftingConfig.GetMaterialDef) == "function" then
		local ok, result = pcall(CraftingConfig.GetMaterialDef, materialId)
		if ok and typeof(result) == "table" then
			def = result
		end
	end
	if not def then
		def = materialDefsById[materialId]
	end
	local label = materialId
	local bucket = bucketOverride
	local rarity = nil

	if def then
		label = def.name or def.id or materialId
		bucket = bucket or def.bucket
		rarity = def.rarity
	end

	if materialId == CraftingConfig.UPGRADE_CRYSTAL_ID
		or materialId == CraftingConfig.ELITE_SPECIAL_ID
		or materialId == CraftingConfig.BOSS_SPECIAL_ID then
		bucket = "upgradeMaterials"
	end

	local variant = "material"
	if bucket == "mineResources" then
		variant = "mineResource"
	elseif bucket == "mobMaterials" then
		variant = "mobMaterial"
	elseif bucket == "upgradeMaterials" then
		variant = "upgradeMaterial"
	end

	return label, variant, rarity
end

function PickupToastService.PushMaterial(player, materialId, amount, note, bucketOverride)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return
	end

	local label, variant, rarity = resolveMaterialInfo(materialId, bucketOverride)
	PickupToastService.Push(player, {
		variant = variant,
		label = label,
		amount = amount,
		note = note,
		rarity = rarity,
	})
end

function PickupToastService.PushRecipe(player, recipeId, note, amount)
	local recipe = CraftingConfig.GetRecipe(recipeId)
	local label = (recipe and recipe.weaponId) or tostring(recipeId or "")
	if label == "" then
		return
	end

	PickupToastService.Push(player, {
		variant = "recipe",
		label = label,
		amount = sanitizeAmount(amount),
		note = note,
		rarity = recipe and recipe.rarity or nil,
	})
end

return PickupToastService
