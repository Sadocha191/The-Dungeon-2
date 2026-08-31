-- SCRIPT: InventorySnapshot.server.lua
-- GDZIE: ServerScriptService/InventorySnapshot.server.lua
-- CO: RemoteFunction zwraca snapshot ekwipunku (PlayerData + Currencies + WeaponInstances)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript")
	or ServerScriptService:FindFirstChild("ModuleScripts")

local function requireModule(name: string)
	local mod = ServerScriptService:FindFirstChild(name)
	if not mod and moduleFolder then
		mod = moduleFolder:FindFirstChild(name)
	end
	if not mod or not mod:IsA("ModuleScript") then
		warn(("[InventorySnapshot] Missing module: %s"):format(name))
		return nil
	end
	return require(mod)
end

local PlayerData = requireModule("PlayerData")
local CurrencyService = requireModule("CurrencyService")
local PlayerStateStore = requireModule("PlayerStateStore")

local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local WeaponConfigs = require(replicatedModules:WaitForChild("WeaponConfigs"))
local SpellDefs = require(replicatedModules:WaitForChild("SpellDefinitions"))
local CodexDefinitions = nil
do
	local codexModule = replicatedModules:FindFirstChild("CodexDefinitions")
	if codexModule and codexModule:IsA("ModuleScript") then
		local ok, result = pcall(require, codexModule)
		if ok then
			CodexDefinitions = result
		end
	end
end

local function toPct(x: number): number
	return math.floor((tonumber(x) or 0) * 100 + 0.5)
end

local function computeInstanceStats(def: any, inst: any)
	local combat = def.combat or {}
	local roll = (typeof(inst.rollStats) == "table") and inst.rollStats or {}
	local lvl = math.max(1, math.floor(tonumber(inst.level) or 1))
	local baseAtk = (combat.baseAtk or def.baseDamage or 0) + (roll.BaseATK or 0)
	local atkPerLevel = (combat.atkPerLevel or 0) + (roll.ATKPerLevel or 0)
	local atk = baseAtk + (lvl - 1) * atkPerLevel
	local hp = (combat.bonusHP or 0) + (roll.BonusHP or 0)
	local defv = (combat.bonusDefense or 0) + (roll.BonusDefense or 0)
	local spd = (combat.bonusSpeed or 0) + (roll.BonusSpeed or 0)
	local critRate = (combat.bonusCritRate or 0) + (roll.BonusCritRate or 0)
	local critDmg = (combat.bonusCritDmg or 0) + (roll.BonusCritDmg or 0)
	local lifesteal = (combat.bonusLifesteal or 0) + (roll.BonusLifesteal or 0)
	return {
		ATK = math.floor(atk + 0.5),
		HP = math.floor(hp + 0.5),
		DEF = math.floor(defv + 0.5),
		SPD = toPct(spd),
		CRIT_RATE = toPct(critRate),
		CRIT_DMG = toPct(critDmg),
		LIFESTEAL = toPct(lifesteal),
	}
end

local function buildCountEntries(rawMap)
	local entries = {}
	if typeof(rawMap) ~= "table" then
		return entries
	end
	for id, amount in pairs(rawMap) do
		if typeof(id) == "string" and id ~= "" then
			local count = math.max(0, math.floor(tonumber(amount) or 0))
			if count > 0 then
				table.insert(entries, { id = id, amount = count })
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.amount == b.amount then return a.id < b.id end
		return a.amount > b.amount
	end)
	return entries
end

local function buildUnlockedProductList(unlockedMap)
	local out = {}
	local seen = {}
	if typeof(unlockedMap) ~= "table" then
		return out
	end
	for rawId, value in pairs(unlockedMap) do
		if value == true and typeof(rawId) == "string" and rawId ~= "" then
			local normalizedId = SpellDefs.NormalizeProductId and SpellDefs.NormalizeProductId(rawId) or rawId
			local product = SpellDefs.GetProduct(normalizedId)
			if product and not seen[product.id] then
				seen[product.id] = true
				table.insert(out, product.id)
			end
		end
	end
	table.sort(out)
	return out
end

local function buildCombinationPayload(codexSnapshot)
	local discovered = codexSnapshot
		and codexSnapshot.Discovered
		and codexSnapshot.Discovered.Combinations
		or {}
	local out = {}
	for _, combo in ipairs(SpellDefs.GetCombinationList()) do
		local result = SpellDefs.GetSpell(combo.resultId)
		local presentation = result and SpellDefs.GetPresentation(result) or {}
		table.insert(out, {
			id = combo.id,
			resultId = combo.resultId,
			name = result and result.name or combo.resultId,
			element = result and result.element or nil,
			ingredients = combo.ingredients,
			description = SpellDefs.DescribeCombination(combo),
			iconGlyph = result and result.iconGlyph or presentation.iconGlyph,
			artMotif = result and result.artMotif or presentation.artMotif,
			loreDescription = result and result.loreDescription or presentation.loreDescription,
			gameplayDescription = result and result.gameplayDescription or presentation.gameplayDescription,
			visualDirection = result and result.visualDirection or presentation.visualDirection,
			frameStyle = result and result.frameStyle or presentation.frameStyle,
			presentation = presentation,
			discovered = discovered[combo.id] == true,
			replaceBaseSpells = combo.ReplaceBaseSpells ~= false,
		})
	end
	return out
end

local function buildSpellEntries(unlockedMap)
	local entries = {}
	local unlockedIds = {}
	if typeof(unlockedMap) == "table" then
		for id, value in pairs(unlockedMap) do
			if value == true and typeof(id) == "string" then
				table.insert(unlockedIds, id)
			end
		end
	end
	local strongestUnlocked = SpellDefs.ResolveUnlockedProducts(unlockedIds)

	for _, familyId in ipairs(SpellDefs.GetSpellIds()) do
		local def = SpellDefs.GetSpell(familyId)
		if def and not def.isCombo and def.shopAvailable ~= false then
			local product = strongestUnlocked[familyId]
				or SpellDefs.GetProduct(("%s_Standard"):format(familyId))
			if product then
				local presentation = product.presentation or SpellDefs.GetPresentation(def)
				local unlocked = strongestUnlocked[familyId] ~= nil
					or (typeof(unlockedMap) == "table" and unlockedMap[familyId] == true)
				table.insert(entries, {
					id = familyId,
					productId = product.id,
					familyId = familyId,
					displayName = def.name,
					name = def.name,
					element = def.element,
					attackType = def.attackType,
					spellType = def.spellType,
					baseQuality = product.baseQuality or "Standard",
					rarity = product.cardQuality or "Common",
					unlocked = unlocked,
					costSouls = product.costSouls or product.costCoins or 0,
					description = def.gameplayDescription or def.description or "",
					iconGlyph = def.iconGlyph,
					artMotif = def.artMotif,
					loreDescription = def.loreDescription,
					gameplayDescription = def.gameplayDescription,
					visualDirection = def.visualDirection,
					frameStyle = def.frameStyle,
					codexCategory = def.codexCategory,
					witchbookAccent = def.witchbookAccent,
					presentation = presentation,
					visualProfile = product.visualProfile or SpellDefs.GetVisualProfile(def),
					statLines = SpellDefs.GetSpellStatLines(def, {
						level = 1,
						baseMultiplier = product.baseMultiplier,
						basePower = product.basePower,
					}),
					upgradeLevels = SpellDefs.GetSpellUpgradeLevels(familyId),
					combinations = SpellDefs.GetSynergiesFor(familyId),
				})
			end
		end
	end
	return entries
end

local function buildCodexPayload(player)
	if not CodexDefinitions or not PlayerData.GetCodexSnapshot then
		return { categories = {}, entries = {}, counts = {} }
	end
	local snapshot = PlayerData.GetCodexSnapshot(player)
	local entries = {}
	local counts = {}
	local categories = CodexDefinitions.GetCategoryOrder()
	for _, entry in ipairs(CodexDefinitions.GetEntries()) do
		local discovered = snapshot.Discovered[entry.category] and snapshot.Discovered[entry.category][entry.id] == true
		local seen = snapshot.Seen[entry.category] and snapshot.Seen[entry.category][entry.id] == true
		local clean = entry
		clean.discovered = discovered
		clean.seen = seen
		if clean.hiddenDetailsUntilDiscovered and not discovered then
			clean.displayName = "???"
			clean.description = "Undiscovered combination."
			clean.tags = {}
			clean.iconText = "?"
			clean.artMotif = nil
			clean.loreDescription = nil
			clean.gameplayDescription = nil
			clean.visualDirection = nil
			clean.frameStyle = nil
			clean.witchbookAccent = nil
			clean.presentation = nil
		end
		table.insert(entries, clean)
		counts[entry.category] = counts[entry.category] or { discovered = 0, total = 0 }
		counts[entry.category].total += 1
		if discovered then counts[entry.category].discovered += 1 end
	end
	return {
		categories = categories,
		entries = entries,
		counts = counts,
		discovered = snapshot.Discovered,
		seen = snapshot.Seen,
	}
end

local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctions then
	remoteFunctions = Instance.new("Folder")
	remoteFunctions.Name = "RemoteFunctions"
	remoteFunctions.Parent = ReplicatedStorage
end

local function ensureRemoteFunction(name)
	local fn = remoteFunctions:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then return fn end
	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remoteFunctions
	return fn
end

local GetInventorySnapshot = ensureRemoteFunction("RF_GetInventorySnapshot")

GetInventorySnapshot.OnServerInvoke = function(player)
	if not PlayerData or not CurrencyService or not PlayerStateStore then
		return {
			playerInfo = {},
			currencies = {},
			resources = {},
			weapons = {},
		}
	end

	if _G.Spells_SanitizeUnlocked then
		pcall(function()
			_G.Spells_SanitizeUnlocked(player)
		end)
	end

	local data = PlayerData.Get(player)
	local currencies = CurrencyService.GetBalances(player)
	local crafting = (typeof(data.crafting) == "table") and data.crafting or {}
	local unlockedProducts = buildUnlockedProductList(data.spellsUnlocked)
	local codexPayload = buildCodexPayload(player)

	local weapons = {}
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	local favoriteSet = {}
	for _, name in ipairs(state.FavoriteWeapons or {}) do
		if typeof(name) == "string" then favoriteSet[name] = true end
	end

	for _, inst in ipairs(state.WeaponInstances or {}) do
		if typeof(inst) == "table" then
			local weaponId = inst.weaponId
			if typeof(weaponId) == "string" and weaponId ~= "" then
				local def = WeaponConfigs.Get(weaponId)
				if def then
					local rarity = (inst.rarity ~= "" and inst.rarity) or def.rarity or "Common"
					local rarityMultiplier = ({
						Common = 1, Uncommon = 1.2, Rare = 1.4, Epic = 1.8,
						Legendary = 2.4, Mythic = 3, Mythical = 3,
					})[rarity] or 1
					table.insert(weapons, {
						InstanceId = inst.instanceId,
						WeaponId = weaponId,
						Prefix = inst.prefix or "Standard",
						Level = tonumber(inst.level) or 1,
						MaxLevel = def.maxLevel or 1,
						Rarity = rarity,
						Stats = computeInstanceStats(def, inst),
						Favorite = favoriteSet[weaponId] == true,
						WeaponType = def.weaponType,
						Element = def.element,
						Description = def.description,
						SellValue = def.sellValue or math.max(1, math.floor((def.baseDamage or 0) * 3 * rarityMultiplier)),
					})
				end
			end
		end
	end

	return {
		playerInfo = {
			level = data.level,
			xp = data.xp,
			nextXp = data.nextXp,
			race = player:GetAttribute("Race"),
		},
		currencies = {
			Silver = currencies.Silver,
			Coins = currencies.Coins,
			Souls = math.max(0, math.floor(tonumber(data.souls) or 0)),
			WeaponPoints = currencies.WeaponPoints,
			Tickets = currencies.Tickets,
		},
		resources = {
			mineResources = buildCountEntries(crafting.mineResources),
			mobMaterials = buildCountEntries(crafting.mobMaterials),
			upgradeMaterials = buildCountEntries(crafting.upgradeMaterials),
		},
		spells = {
			unlockedProducts = unlockedProducts,
			entries = buildSpellEntries(data.spellsUnlocked or {}),
			combinations = buildCombinationPayload(codexPayload),
		},
		codex = codexPayload,
		equippedId = state.EquippedWeaponInstanceId,
		weapons = weapons,
	}
end

print("[InventorySnapshot] Ready")
