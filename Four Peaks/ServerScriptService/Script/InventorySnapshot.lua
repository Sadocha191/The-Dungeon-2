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
				table.insert(entries, {
					id = id,
					amount = count,
				})
			end
		end
	end

	table.sort(entries, function(a, b)
		if a.amount == b.amount then
			return a.id < b.id
		end
		return a.amount > b.amount
	end)

	return entries
end

local function buildUnlockedProductList(unlockedMap)
	local out = {}
	if typeof(unlockedMap) ~= "table" then
		return out
	end
	for id, value in pairs(unlockedMap) do
		if value == true and typeof(id) == "string" and id ~= "" and SpellDefs.GetProduct(id) then
			table.insert(out, id)
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

local function buildSpellEntries(unlockedMap, equippedSet)
	local entries = {}
	for _, productId in ipairs(SpellDefs.GetShopList()) do
		local product = SpellDefs.GetProduct(productId)
		local def = product and SpellDefs.GetSpell(product.familyId) or nil
		if product and def then
			local presentation = product.presentation or SpellDefs.GetPresentation(product)
			table.insert(entries, {
				id = product.id,
				productId = product.id,
				familyId = product.familyId,
				displayName = product.displayName,
				name = product.name,
				element = product.element,
				attackType = product.attackType,
				spellType = product.spellType,
				baseQuality = product.baseQuality,
				rarity = product.cardQuality or product.baseQuality or "Common",
				unlocked = unlockedMap[product.id] == true,
				equipped = equippedSet[product.id] == true,
				costSouls = product.costSouls or product.costCoins or 0,
				description = SpellDefs.DescribeShopProduct(product),
				iconGlyph = product.iconGlyph or def.iconGlyph,
				artMotif = product.artMotif or def.artMotif,
				loreDescription = product.loreDescription or def.loreDescription,
				gameplayDescription = product.gameplayDescription or def.gameplayDescription,
				visualDirection = product.visualDirection or def.visualDirection,
				frameStyle = product.frameStyle or def.frameStyle,
				codexCategory = product.codexCategory or def.codexCategory,
				witchbookAccent = product.witchbookAccent or def.witchbookAccent,
				presentation = presentation,
				visualProfile = product.visualProfile or SpellDefs.GetVisualProfile(product),
				statLines = SpellDefs.GetSpellStatLines(def, {
					level = 1,
					baseMultiplier = product.baseMultiplier,
					basePower = product.basePower,
				}),
				upgradeLevels = SpellDefs.GetSpellUpgradeLevels(product.familyId),
				combinations = SpellDefs.GetSynergiesFor(product.familyId),
			})
		end
	end
	return entries
end

local function buildCodexPayload(player)
	if not CodexDefinitions or not PlayerData.GetCodexSnapshot then
		return {
			categories = {},
			entries = {},
			counts = {},
		}
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
		if discovered then
			counts[entry.category].discovered += 1
		end
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
	if fn and fn:IsA("RemoteFunction") then
		return fn
	end
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
	local data = PlayerData.Get(player)
	local currencies = CurrencyService.GetBalances(player)
	local crafting = (typeof(data.crafting) == "table") and data.crafting or {}
	local spellLoadout = PlayerData.GetSpellLoadout and PlayerData.GetSpellLoadout(player) or {}
	local resolvedSpellLoadout = (#spellLoadout > 0 and spellLoadout)
		or (PlayerData.ResolveSpellLoadout and PlayerData.ResolveSpellLoadout(player))
		or {}
	local unlockedProducts = buildUnlockedProductList(data.spellsUnlocked)
	local equippedSpellSet = {}
	for _, productId in ipairs(resolvedSpellLoadout) do
		equippedSpellSet[productId] = true
	end
	local codexPayload = buildCodexPayload(player)

	local weapons = {}
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)

	local favoriteSet = {}
	for _, name in ipairs(state.FavoriteWeapons or {}) do
		if typeof(name) == "string" then
			favoriteSet[name] = true
		end
	end

	for _, inst in ipairs(state.WeaponInstances or {}) do
		if typeof(inst) == "table" then
			local weaponId = inst.weaponId
			if typeof(weaponId) == "string" and weaponId ~= "" then
				local def = WeaponConfigs.Get(weaponId)
				if def then
					table.insert(weapons, {
						InstanceId = inst.instanceId,
						WeaponId = weaponId,
						Prefix = inst.prefix or "Standard",
						Level = tonumber(inst.level) or 1,
						MaxLevel = def.maxLevel or 1,
						Rarity = (inst.rarity ~= "" and inst.rarity) or def.rarity or "Common",
						Stats = computeInstanceStats(def, inst),
						Favorite = favoriteSet[weaponId] == true,
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
			loadout = resolvedSpellLoadout,
			savedLoadout = spellLoadout,
			maxSlots = SpellDefs.GetLoadoutLimit(),
			entries = buildSpellEntries(data.spellsUnlocked or {}, equippedSpellSet),
			damageSummary = SpellDefs.SummarizeDamageByElement(resolvedSpellLoadout),
			combinations = buildCombinationPayload(codexPayload),
		},
		codex = codexPayload,
		equippedId = state.EquippedWeaponInstanceId,
		weapons = weapons,
	}
end

print("[InventorySnapshot] Ready")
