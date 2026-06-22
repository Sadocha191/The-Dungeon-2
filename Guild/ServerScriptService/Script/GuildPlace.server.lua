local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local GuildConfig = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("GuildConfig"))

local playerProfileStore = DataStoreService:GetDataStore("GlobalPlayerProgress_v1")
local guildStore = DataStoreService:GetDataStore("GuildRecords_v1")
local returnInFlight = {}
local TREASURY_KEYS = GuildConfig.TREASURY_KEYS or {
	"Silver",
	"Souls",
	"Tickets",
	"WeaponPoints",
}
local TREASURY_HISTORY_LIMIT = tonumber(GuildConfig.TREASURY_HISTORY_LIMIT) or 25
local LOCATION_STATUS = "Coming soon"
local GUILD_LOCATION_DEFINITIONS = {
	{
		Id = "Dojo",
		Name = "Dojo",
		Description = "Przyszłe ulepszenia bojowe gildii.",
		Hint = "zachodni dziedziniec",
		Position = Vector3.new(-70, 0, 0),
		BaseSize = Vector3.new(24, 1, 18),
		BuildingSize = Vector3.new(15, 8, 11),
		Color = Color3.fromRGB(142, 64, 51),
		AccentColor = Color3.fromRGB(230, 204, 152),
		Accents = {
			{ Name = "TrainingMat", Offset = Vector3.new(0, 1.08, 0), Size = Vector3.new(10, 0.25, 7), Color = Color3.fromRGB(96, 45, 38), Material = Enum.Material.Fabric },
		},
	},
	{
		Id = "Treasury",
		Name = "Skarbiec",
		Description = "Przyszłe zarządzanie zasobami gildii.",
		Hint = "wschodnie skrzydło zamku",
		Position = Vector3.new(70, 0, 0),
		BaseSize = Vector3.new(24, 1, 18),
		BuildingSize = Vector3.new(16, 9, 12),
		Color = Color3.fromRGB(85, 91, 105),
		AccentColor = Color3.fromRGB(218, 172, 75),
		Accents = {
			{ Name = "VaultDoor", Offset = Vector3.new(0, 4.2, -5.9), Size = Vector3.new(6, 6, 0.6), Color = Color3.fromRGB(218, 172, 75), Material = Enum.Material.Metal },
		},
	},
	{
		Id = "HallOfFame",
		Name = "Sala chwały",
		Description = "Przyszłe rankingi i contribution członków.",
		Hint = "północna aleja",
		Position = Vector3.new(0, 0, -70),
		BaseSize = Vector3.new(26, 1, 18),
		BuildingSize = Vector3.new(18, 9, 11),
		Color = Color3.fromRGB(102, 88, 123),
		AccentColor = Color3.fromRGB(228, 215, 164),
		Accents = {
			{ Name = "HonorPlinth", Offset = Vector3.new(0, 2.2, 0), Size = Vector3.new(5, 3, 5), Color = Color3.fromRGB(228, 215, 164), Material = Enum.Material.Marble },
		},
	},
	{
		Id = "Farms",
		Name = "Farmy",
		Description = "Przyszła produkcja zasobów gildii.",
		Hint = "południowo-zachodnie pola",
		Position = Vector3.new(-55, 0, 55),
		BaseSize = Vector3.new(28, 1, 22),
		BuildingSize = Vector3.new(12, 6, 9),
		Color = Color3.fromRGB(92, 124, 72),
		AccentColor = Color3.fromRGB(152, 108, 62),
		Accents = {
			{ Name = "CropRowA", Offset = Vector3.new(-6, 1.12, 2), Size = Vector3.new(4, 0.35, 12), Color = Color3.fromRGB(64, 128, 57), Material = Enum.Material.Grass },
			{ Name = "CropRowB", Offset = Vector3.new(0, 1.12, 2), Size = Vector3.new(4, 0.35, 12), Color = Color3.fromRGB(73, 145, 60), Material = Enum.Material.Grass },
			{ Name = "CropRowC", Offset = Vector3.new(6, 1.12, 2), Size = Vector3.new(4, 0.35, 12), Color = Color3.fromRGB(64, 128, 57), Material = Enum.Material.Grass },
		},
	},
	{
		Id = "Mine",
		Name = "Kopalnia",
		Description = "Przyszła produkcja materiałów gildii.",
		Hint = "południowo-wschodnie skały",
		Position = Vector3.new(55, 0, 55),
		BaseSize = Vector3.new(26, 1, 20),
		BuildingSize = Vector3.new(14, 8, 10),
		Color = Color3.fromRGB(82, 78, 72),
		AccentColor = Color3.fromRGB(144, 126, 92),
		Accents = {
			{ Name = "OreRockA", Offset = Vector3.new(-7, 2.2, 4), Size = Vector3.new(5, 4, 5), Color = Color3.fromRGB(106, 101, 94), Material = Enum.Material.Rock },
			{ Name = "OreRockB", Offset = Vector3.new(7, 1.8, 3), Size = Vector3.new(4, 3, 4), Color = Color3.fromRGB(125, 112, 88), Material = Enum.Material.Slate },
		},
	},
	{
		Id = "Fishing",
		Name = "Łowiska",
		Description = "Przyszła produkcja specjalnych zasobów.",
		Hint = "północno-zachodni staw",
		Position = Vector3.new(-55, 0, -55),
		BaseSize = Vector3.new(28, 1, 22),
		BuildingSize = Vector3.new(11, 5, 8),
		Color = Color3.fromRGB(63, 105, 126),
		AccentColor = Color3.fromRGB(151, 112, 71),
		Accents = {
			{ Name = "FishingPond", Offset = Vector3.new(4, 1.06, 2), Size = Vector3.new(13, 0.2, 10), Color = Color3.fromRGB(58, 131, 159), Material = Enum.Material.SmoothPlastic, Transparency = 0.15 },
			{ Name = "Dock", Offset = Vector3.new(-6, 1.25, 2), Size = Vector3.new(5, 0.5, 12), Color = Color3.fromRGB(130, 91, 55), Material = Enum.Material.WoodPlanks },
		},
	},
	{
		Id = "BossRaid",
		Name = "Boss Raid",
		Description = "Przyszłe raidy gildyjne.",
		Hint = "północno-wschodni plac bojowy",
		Position = Vector3.new(55, 0, -55),
		BaseSize = Vector3.new(28, 1, 22),
		BuildingSize = Vector3.new(16, 8, 10),
		Color = Color3.fromRGB(102, 49, 70),
		AccentColor = Color3.fromRGB(197, 74, 89),
		Accents = {
			{ Name = "RaidPortal", Offset = Vector3.new(0, 4, 0), Size = Vector3.new(7, 7, 1), Color = Color3.fromRGB(197, 74, 89), Material = Enum.Material.Neon },
		},
	},
}
local GUILD_LOCATION_BY_ID = {}
for _, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
	GUILD_LOCATION_BY_ID[definition.Id] = definition
end

local function getRemoteEventsFolder()
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = ReplicatedStorage
	end
	return remoteEvents
end

local function ensureRemoteEvent(name)
	local remoteEvents = getRemoteEventsFolder()
	local event = remoteEvents:FindFirstChild(name)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	if event then
		event:Destroy()
	end

	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remoteEvents
	return event
end

local function getRemoteFunctionsFolder()
	local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
	if not remoteFunctions then
		remoteFunctions = Instance.new("Folder")
		remoteFunctions.Name = "RemoteFunctions"
		remoteFunctions.Parent = ReplicatedStorage
	end
	return remoteFunctions
end

local function ensureRemoteFunction(name)
	local remoteFunctions = getRemoteFunctionsFolder()
	local fn = remoteFunctions:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then
		return fn
	end
	if fn then
		fn:Destroy()
	end

	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remoteFunctions
	return fn
end

local requestLobbyReturn = ensureRemoteEvent("RequestLobbyReturn")
local lobbyReturnStatus = ensureRemoteEvent("LobbyReturnStatus")
local guildLocationOpened = ensureRemoteEvent("GuildLocationOpened")
local guildTreasuryUpdated = ensureRemoteEvent("GuildTreasuryUpdated")
local getGuildCastleState = ensureRemoteFunction("GetGuildCastleState")
local getTreasury = ensureRemoteFunction("GetTreasury")
local depositToTreasury = ensureRemoteFunction("DepositToTreasury")
local spendFromTreasury = ensureRemoteFunction("SpendFromTreasury")

local function clampInt(value, minValue)
	local n = math.floor(tonumber(value) or 0)
	if minValue ~= nil and n < minValue then
		return minValue
	end
	if n < 0 then
		return 0
	end
	return n
end

local function copyMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" then
			if typeof(value) == "table" then
				out[key] = copyMap(value)
			else
				out[key] = value
			end
		end
	end
	return out
end

local function sanitizeCountMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = clampInt(value)
			if amount > 0 then
				out[key] = amount
			end
		end
	end
	return out
end

local function sanitizeTreasuryHistory(raw)
	local history = {}
	if typeof(raw) ~= "table" then
		return history
	end
	local startIndex = math.max(1, #raw - TREASURY_HISTORY_LIMIT + 1)
	for index = startIndex, #raw do
		local entry = raw[index]
		if typeof(entry) == "table" then
			table.insert(history, {
				userId = clampInt(entry.userId or entry.UserId),
				username = tostring(entry.username or entry.Username or "Player"),
				resourceId = tostring(entry.resourceId or entry.ResourceId or ""),
				amount = clampInt(entry.amount or entry.Amount),
				createdAt = clampInt(entry.createdAt or entry.CreatedAt),
				action = tostring(entry.action or entry.Action or "Deposit"),
				reason = tostring(entry.reason or entry.Reason or ""),
			})
		end
	end
	return history
end

local function memberKey(userId)
	return tostring(math.floor(tonumber(userId) or 0))
end

local function getTeleportGuildId(player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if typeof(teleportData) ~= "table" then
		return nil
	end
	local guildId = teleportData.guildId or teleportData.GuildId
	if typeof(guildId) == "string" and guildId ~= "" then
		return guildId
	end
	return nil
end

local function getPlayerGuildId(player)
	local attributeGuildId = player:GetAttribute("GuildId")
	if typeof(attributeGuildId) == "string" and attributeGuildId ~= "" then
		return attributeGuildId
	end
	return getTeleportGuildId(player)
end

local function loadPlayerProfile(userId)
	local ok, profile = pcall(function()
		return playerProfileStore:GetAsync(tostring(userId))
	end)
	if ok and typeof(profile) == "table" then
		return profile
	end
	if not ok then
		warn("[GuildPlace] Failed to load player profile:", userId, profile)
	end
	return nil
end

local function loadGuild(guildId)
	local ok, guild = pcall(function()
		return guildStore:GetAsync(guildId)
	end)
	if ok and typeof(guild) == "table" then
		return guild
	end
	if not ok then
		warn("[GuildPlace] Failed to load guild:", guildId, guild)
	end
	return nil
end

local function getCurrencyResourceDef(resourceId)
	if typeof(GuildConfig.GetTreasuryCurrencyResource) == "function" then
		local resource = GuildConfig.GetTreasuryCurrencyResource(resourceId)
		if resource then
			return {
				id = resource.id,
				displayName = resource.displayName,
				kind = "Currency",
				profileKey = resource.profileKey,
				minAmount = clampInt(resource.minAmount, 1),
				xpPerUnit = tonumber(resource.xpPerUnit) or 0,
				contributionPerUnit = tonumber(resource.contributionPerUnit) or 1,
			}
		end
	end
	for _, resource in ipairs(GuildConfig.TREASURY_CURRENCY_RESOURCES or {}) do
		if resource.id == resourceId then
			return {
				id = resource.id,
				displayName = resource.displayName,
				kind = "Currency",
				profileKey = resource.profileKey,
				minAmount = clampInt(resource.minAmount, 1),
				xpPerUnit = tonumber(resource.xpPerUnit) or 0,
				contributionPerUnit = tonumber(resource.contributionPerUnit) or 1,
			}
		end
	end
	return nil
end

local function getMaterialResourceDef(resourceId)
	if typeof(GuildConfig.GetTreasuryMaterialResource) == "function" then
		local mapping, materialId = GuildConfig.GetTreasuryMaterialResource(resourceId)
		if mapping then
			return {
				id = resourceId,
				displayName = tostring(mapping.displayPrefix or "Material") .. ": " .. materialId,
				kind = "Material",
				craftingKey = mapping.craftingKey,
				materialId = materialId,
				minAmount = 1,
				xpPerUnit = tonumber(mapping.xpPerUnit) or 0,
				contributionPerUnit = tonumber(mapping.contributionPerUnit) or 1,
			}
		end
	end
	for _, mapping in pairs(GuildConfig.TREASURY_MATERIAL_PREFIXES or {}) do
		local prefix = tostring(mapping.prefix or "")
		if prefix ~= "" and string.sub(resourceId, 1, #prefix) == prefix then
			local materialId = string.sub(resourceId, #prefix + 1)
			if materialId ~= "" then
				return {
					id = resourceId,
					displayName = tostring(mapping.displayPrefix or "Material") .. ": " .. materialId,
					kind = "Material",
					craftingKey = mapping.craftingKey,
					materialId = materialId,
					minAmount = 1,
					xpPerUnit = tonumber(mapping.xpPerUnit) or 0,
					contributionPerUnit = tonumber(mapping.contributionPerUnit) or 1,
				}
			end
		end
	end
	return nil
end

local function getTreasuryResourceDef(resourceId)
	local id = tostring(resourceId or "")
	if id == "" then
		return nil
	end
	return getCurrencyResourceDef(id) or getMaterialResourceDef(id)
end

local function ensureProfileCrafting(profile)
	if typeof(profile.crafting) ~= "table" then
		profile.crafting = {}
	end
	for _, key in ipairs({ "mobMaterials", "upgradeMaterials", "mineResources" }) do
		if typeof(profile.crafting[key]) ~= "table" then
			profile.crafting[key] = {}
		else
			profile.crafting[key] = sanitizeCountMap(profile.crafting[key])
		end
	end
	return profile.crafting
end

local function getProfileResourceAmount(profile, resource)
	if resource.kind == "Currency" then
		return clampInt(profile[resource.profileKey])
	end
	local crafting = ensureProfileCrafting(profile)
	return clampInt(crafting[resource.craftingKey] and crafting[resource.craftingKey][resource.materialId])
end

local function addProfileResource(profile, resource, delta)
	if resource.kind == "Currency" then
		profile[resource.profileKey] = math.max(0, clampInt(profile[resource.profileKey]) + delta)
		return
	end
	local crafting = ensureProfileCrafting(profile)
	local bucket = crafting[resource.craftingKey]
	bucket[resource.materialId] = math.max(0, clampInt(bucket[resource.materialId]) + delta)
	if bucket[resource.materialId] <= 0 then
		bucket[resource.materialId] = nil
	end
end

local function ensureGuildTreasury(guild)
	if typeof(guild.treasury) ~= "table" and typeof(guild.Treasury) == "table" then
		guild.treasury = guild.Treasury
	end
	if typeof(guild.treasury) ~= "table" then
		guild.treasury = {}
	end
	for _, key in ipairs(TREASURY_KEYS) do
		guild.treasury[key] = clampInt(guild.treasury[key])
	end
	guild.treasury.resources = sanitizeCountMap(guild.treasury.resources or guild.treasury.Resources)
	guild.memberContributions = sanitizeCountMap(guild.memberContributions or guild.MemberContributions)
	guild.totalContribution = clampInt(guild.totalContribution or guild.TotalContribution)
	guild.treasuryHistory = sanitizeTreasuryHistory(guild.treasuryHistory or guild.TreasuryHistory)
end

local function getGuildResourceAmount(guild, resource)
	ensureGuildTreasury(guild)
	if resource.kind == "Currency" then
		return clampInt(guild.treasury[resource.id])
	end
	return clampInt(guild.treasury.resources[resource.id])
end

local function setGuildResourceAmount(guild, resource, amount)
	ensureGuildTreasury(guild)
	local nextAmount = math.max(0, clampInt(amount))
	if resource.kind == "Currency" then
		guild.treasury[resource.id] = nextAmount
	end
	guild.treasury.resources[resource.id] = nextAmount
	if nextAmount <= 0 and resource.kind ~= "Currency" then
		guild.treasury.resources[resource.id] = nil
	end
end

local function addGuildResource(guild, resource, amount)
	setGuildResourceAmount(guild, resource, getGuildResourceAmount(guild, resource) + clampInt(amount))
end

local function addTreasuryHistory(guild, player, resourceId, amount, action, reason)
	ensureGuildTreasury(guild)
	table.insert(guild.treasuryHistory, {
		userId = player.UserId,
		username = player.Name,
		resourceId = tostring(resourceId or ""),
		amount = clampInt(amount),
		createdAt = os.time(),
		action = tostring(action or "Deposit"),
		reason = tostring(reason or ""),
	})
	while #guild.treasuryHistory > TREASURY_HISTORY_LIMIT do
		table.remove(guild.treasuryHistory, 1)
	end
end

local function getContributionGain(resource, amount)
	return math.max(1, math.floor((tonumber(amount) or 0) * (resource.contributionPerUnit or 1) + 0.5))
end

local function getXpGain(resource, amount)
	return math.max(1, math.floor((tonumber(amount) or 0) * (resource.xpPerUnit or 0) + 0.5))
end

local function getGuildLevelFromXp(xp)
	if typeof(GuildConfig.GetLevelFromXp) == "function" then
		return GuildConfig.GetLevelFromXp(xp)
	end
	return math.max(1, clampInt(xp, 1))
end

local function rejectPlayer(player, reason)
	local lobbyPlaceId = tonumber(GuildConfig.LOBBY_PLACE_ID) or 0
	if lobbyPlaceId > 0 then
		local guildId = getPlayerGuildId(player)
		local teleportData = {
			sourcePlace = "Guild",
			reason = reason,
		}
		if guildId then
			teleportData.guildId = guildId
			teleportData.GuildId = guildId
		end
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(teleportData)
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(lobbyPlaceId, { player }, options)
		end)
		if ok then
			return
		end
		warn("[GuildPlace] Lobby teleport failed:", err)
	end
	player:Kick(reason)
end

local function getProfileGuildId(profile)
	local membership = profile and profile.Guild
	local guildId = typeof(membership) == "table" and membership.GuildId or nil
	if typeof(guildId) == "string" and guildId ~= "" then
		return guildId
	end
	return nil
end

local function profileHasGuild(profile, guildId)
	return getProfileGuildId(profile) == guildId
end

local function getGuildMembers(guild)
	local members = guild and (guild.members or guild.Members)
	if typeof(members) == "table" then
		return members
	end
	return {}
end

local function getGuildMember(guild, player)
	local member = getGuildMembers(guild)[memberKey(player.UserId)]
	if typeof(member) == "table" then
		return member
	end
	return nil
end

local function guildHasPlayer(guild, player)
	return getGuildMember(guild, player) ~= nil
end

local function countMembers(guild)
	local count = 0
	for _, member in pairs(getGuildMembers(guild)) do
		if typeof(member) == "table" then
			count += 1
		end
	end
	return count
end

local function countOnlineMembers(guild)
	local count = 0
	for _, member in pairs(getGuildMembers(guild)) do
		if typeof(member) == "table" then
			local userId = math.floor(tonumber(member.userId or member.UserId) or 0)
			if userId > 0 and Players:GetPlayerByUserId(userId) then
				count += 1
			end
		end
	end
	return count
end

local function copyTreasury(guild)
	local raw = guild and (guild.treasury or guild.Treasury)
	local treasury = {}
	for _, key in ipairs(TREASURY_KEYS) do
		treasury[key] = clampInt(typeof(raw) == "table" and raw[key] or 0)
	end
	treasury.resources = sanitizeCountMap(typeof(raw) == "table" and (raw.resources or raw.Resources) or nil)
	if typeof(raw) == "table" then
		for key, value in pairs(raw) do
			if typeof(key) == "string" and key ~= "resources" and key ~= "Resources" and treasury[key] == nil then
				treasury[key] = clampInt(value)
			end
		end
	end
	return treasury
end

local function getMemberRole(member)
	local role = member and (member.role or member.Role)
	if typeof(role) == "string" and role ~= "" then
		return role
	end
	return "Member"
end

local function hasTreasuryManagerRole(member)
	local role = getMemberRole(member)
	return role == "Owner" or role == "Officer"
end

local function getGuildPrivacy(guild)
	return tostring(guild and (guild.privacy or guild.Privacy) or "Public") == "Private" and "Private" or "Public"
end

local function getLocationStatus(definition)
	return definition.Id == "Treasury" and "Open" or LOCATION_STATUS
end

local function buildGuildLocationState()
	local locations = {}
	for index, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
		locations[index] = {
			Id = definition.Id,
			Name = definition.Name,
			Description = definition.Description,
			Status = getLocationStatus(definition),
			Hint = definition.Hint,
		}
	end
	return locations
end

local function getFlatDirectionToCenter(position)
	local direction = Vector3.new(-position.X, 0, -position.Z)
	if direction.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return direction.Unit
end

local function ensurePart(parent, name, props)
	local part = parent:FindFirstChild(name)
	if part and not part:IsA("BasePart") then
		part:Destroy()
		part = nil
	end
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function ensureLocationBillboard(sign, definition)
	local billboard = sign:FindFirstChild("LocationBillboard")
	if billboard and not billboard:IsA("BillboardGui") then
		billboard:Destroy()
		billboard = nil
	end
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "LocationBillboard"
		billboard.Parent = sign
	end
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Size = UDim2.fromOffset(230, 72)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)

	local label = billboard:FindFirstChild("NameLabel")
	if label and not label:IsA("TextLabel") then
		label:Destroy()
		label = nil
	end
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "NameLabel"
		label.Parent = billboard
	end
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 23)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = definition.Name
	label.TextColor3 = Color3.fromRGB(255, 239, 201)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.45
	label.TextWrapped = true
end

local function ensureLocationPrompt(model, entrance, definition)
	local prompt = nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			if not prompt and descendant.Name == "GuildLocationPrompt" then
				prompt = descendant
			else
				descendant:Destroy()
			end
		end
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GuildLocationPrompt"
	end
	prompt.ActionText = "Open"
	prompt.ObjectText = definition.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("GuildLocationId", definition.Id)
	prompt.Parent = entrance
	return prompt
end

local function ensureGuildLocations()
	local folder = Workspace:FindFirstChild("GuildLocations")
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GuildLocations"
		folder.Parent = Workspace
	end

	for _, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
		local model = folder:FindFirstChild(definition.Id)
		if model and not model:IsA("Model") then
			model:Destroy()
			model = nil
		end
		if not model then
			model = Instance.new("Model")
			model.Name = definition.Id
			model.Parent = folder
		end
		model:SetAttribute("GuildLocationId", definition.Id)
		model:SetAttribute("DisplayName", definition.Name)
		model:SetAttribute("Status", getLocationStatus(definition))

		local center = definition.Position
		local front = getFlatDirectionToCenter(center)
		local baseSize = definition.BaseSize
		local buildingSize = definition.BuildingSize
		local frontDistance = math.max(baseSize.X, baseSize.Z) * 0.5 - 2

		ensurePart(model, "Ground", {
			Anchored = true,
			BottomSurface = Enum.SurfaceType.Smooth,
			BrickColor = BrickColor.new("Dark stone grey"),
			CanCollide = true,
			Color = Color3.fromRGB(47, 54, 48),
			Material = Enum.Material.Cobblestone,
			Position = center + Vector3.new(0, baseSize.Y * 0.5, 0),
			Size = baseSize,
			TopSurface = Enum.SurfaceType.Smooth,
		})
		ensurePart(model, "Building", {
			Anchored = true,
			BottomSurface = Enum.SurfaceType.Smooth,
			CanCollide = true,
			Color = definition.Color,
			Material = Enum.Material.WoodPlanks,
			Position = center + Vector3.new(0, baseSize.Y + buildingSize.Y * 0.5, 0),
			Size = buildingSize,
			TopSurface = Enum.SurfaceType.Smooth,
		})
		local entrance = ensurePart(model, "Entrance", {
			Anchored = true,
			BottomSurface = Enum.SurfaceType.Smooth,
			CanCollide = false,
			Color = Color3.fromRGB(28, 24, 22),
			Material = Enum.Material.Wood,
			Position = center + front * frontDistance + Vector3.new(0, baseSize.Y + 3, 0),
			Size = Vector3.new(6, 6, 1.25),
			TopSurface = Enum.SurfaceType.Smooth,
			Transparency = 0.08,
		})
		local sign = ensurePart(model, "Sign", {
			Anchored = true,
			BottomSurface = Enum.SurfaceType.Smooth,
			CanCollide = false,
			Color = definition.AccentColor,
			Material = Enum.Material.Wood,
			Position = center + front * (frontDistance + 1.4) + Vector3.new(0, baseSize.Y + 7.3, 0),
			Size = Vector3.new(10, 2.25, 0.5),
			TopSurface = Enum.SurfaceType.Smooth,
		})
		ensureLocationBillboard(sign, definition)

		for _, accent in ipairs(definition.Accents or {}) do
			ensurePart(model, accent.Name, {
				Anchored = true,
				BottomSurface = Enum.SurfaceType.Smooth,
				CanCollide = accent.CanCollide ~= false,
				Color = accent.Color or definition.AccentColor,
				Material = accent.Material or Enum.Material.SmoothPlastic,
				Position = center + accent.Offset,
				Size = accent.Size,
				TopSurface = Enum.SurfaceType.Smooth,
				Transparency = accent.Transparency or 0,
			})
		end

		model.PrimaryPart = entrance
	end

	return folder
end

local function fireLobbyReturnStatus(player, success, message, code)
	if player and player.Parent then
		lobbyReturnStatus:FireClient(player, {
			Success = success == true,
			Message = message or "",
			Code = code or (success and "Teleporting" or "Failed"),
			LobbyPlaceId = tonumber(GuildConfig.LOBBY_PLACE_ID) or 0,
		})
	end
end

local function getAuthorizedGuild(player)
	if player:GetAttribute("GuildCastleReady") ~= true then
		return nil, "Guild authorization is not ready yet."
	end

	local guildId = getPlayerGuildId(player)
	if not guildId then
		return nil, "Guild authorization is missing."
	end

	local profile = loadPlayerProfile(player.UserId)
	if not profileHasGuild(profile, guildId) then
		return nil, "You are not a member of this guild."
	end

	local guild = loadGuild(guildId)
	if not guild or guild.disbanded == true or not guildHasPlayer(guild, player) then
		return nil, "Guild not found or membership expired."
	end

	return guild, nil
end

local function buildPlayerResourceList(profile)
	local resources = {}
	for _, configResource in ipairs(GuildConfig.TREASURY_CURRENCY_RESOURCES or {}) do
		local resource = getTreasuryResourceDef(configResource.id)
		if resource then
			table.insert(resources, {
				Id = resource.id,
				DisplayName = tostring(resource.displayName or resource.id),
				Kind = resource.kind,
				Amount = getProfileResourceAmount(profile, resource),
				CanDeposit = true,
			})
		end
	end

	local crafting = ensureProfileCrafting(profile)
	for _, mapping in pairs(GuildConfig.TREASURY_MATERIAL_PREFIXES or {}) do
		local bucket = crafting[mapping.craftingKey]
		if typeof(bucket) == "table" then
			local materialIds = {}
			for materialId, amount in pairs(bucket) do
				if typeof(materialId) == "string" and clampInt(amount) > 0 then
					table.insert(materialIds, materialId)
				end
			end
			table.sort(materialIds)
			for _, materialId in ipairs(materialIds) do
				local resourceId = tostring(mapping.prefix or "") .. materialId
				local resource = getTreasuryResourceDef(resourceId)
				if resource then
					table.insert(resources, {
						Id = resource.id,
						DisplayName = tostring(resource.displayName or resource.id),
						Kind = resource.kind,
						Amount = getProfileResourceAmount(profile, resource),
						CanDeposit = true,
					})
				end
			end
		end
	end

	return resources
end

local function buildGuildResourceList(guild)
	ensureGuildTreasury(guild)
	local resources = {}
	local seen = {}
	for _, key in ipairs(TREASURY_KEYS) do
		local resource = getTreasuryResourceDef(key)
		if resource then
			seen[resource.id] = true
			table.insert(resources, {
				Id = resource.id,
				DisplayName = tostring(resource.displayName or resource.id),
				Kind = resource.kind,
				Amount = getGuildResourceAmount(guild, resource),
			})
		end
	end
	local materialIds = {}
	for resourceId, amount in pairs(guild.treasury.resources or {}) do
		if not seen[resourceId] and clampInt(amount) > 0 then
			table.insert(materialIds, resourceId)
		end
	end
	table.sort(materialIds)
	for _, resourceId in ipairs(materialIds) do
		local resource = getTreasuryResourceDef(resourceId)
		if resource then
			table.insert(resources, {
				Id = resource.id,
				DisplayName = tostring(resource.displayName or resource.id),
				Kind = resource.kind,
				Amount = getGuildResourceAmount(guild, resource),
			})
		end
	end
	return resources
end

local function getTotalContribution(guild)
	local total = clampInt(guild and (guild.totalContribution or guild.TotalContribution))
	local memberTotal = 0
	for _, member in pairs(getGuildMembers(guild)) do
		if typeof(member) == "table" then
			memberTotal += clampInt(member.contribution or member.Contribution)
		end
	end
	local contributionMap = guild and (guild.memberContributions or guild.MemberContributions)
	if typeof(contributionMap) == "table" then
		local mapTotal = 0
		for _, amount in pairs(contributionMap) do
			mapTotal += clampInt(amount)
		end
		memberTotal = math.max(memberTotal, mapTotal)
	end
	if memberTotal > 0 then
		return memberTotal
	end
	return total
end

local function buildTreasuryState(player, message, success)
	local guild, authError = getAuthorizedGuild(player)
	if not guild then
		return {
			Success = false,
			Message = authError or "Guild data is not available.",
		}
	end
	local profile = loadPlayerProfile(player.UserId)
	if not profileHasGuild(profile, tostring(guild.guildId or guild.GuildId or "")) then
		return {
			Success = false,
			Message = "You are not a member of this guild.",
		}
	end

	ensureGuildTreasury(guild)
	local member = getGuildMember(guild, player)
	local memberContribution = clampInt(member and (member.contribution or member.Contribution) or 0)
	local memberContributionMap = guild.memberContributions and guild.memberContributions[memberKey(player.UserId)]
	if clampInt(memberContributionMap) > memberContribution then
		memberContribution = clampInt(memberContributionMap)
	end

	return {
		Success = success ~= false,
		Message = message or "",
		ServerNowUnix = os.time(),
		GuildId = tostring(guild.guildId or guild.GuildId or ""),
		Role = getMemberRole(member),
		CanSpend = hasTreasuryManagerRole(member),
		Contribution = memberContribution,
		TotalContribution = getTotalContribution(guild),
		GuildResources = buildGuildResourceList(guild),
		PlayerResources = buildPlayerResourceList(profile),
		History = sanitizeTreasuryHistory(guild.treasuryHistory),
	}
end

local function updatePlayerProfile(userId, transform)
	local transformResult = nil
	local ok, result = pcall(function()
		return playerProfileStore:UpdateAsync(tostring(userId), function(profile)
			if typeof(profile) ~= "table" then
				transformResult = {
					Success = false,
					Message = "Player profile is not available.",
				}
				return profile
			end
			local nextProfile, nextResult = transform(profile)
			transformResult = nextResult
			return nextProfile or profile
		end)
	end)
	if not ok then
		return false, {
			Success = false,
			Message = "Player profile save failed.",
			Error = tostring(result),
		}
	end
	return transformResult ~= nil and transformResult.Success == true, transformResult or {
		Success = true,
		Profile = result,
	}
end

local function updateGuildRecord(guildId, transform)
	local transformResult = nil
	local ok, result = pcall(function()
		return guildStore:UpdateAsync(guildId, function(guild)
			if typeof(guild) ~= "table" then
				transformResult = {
					Success = false,
					Message = "Guild record is not available.",
				}
				return guild
			end
			local nextGuild, nextResult = transform(guild)
			transformResult = nextResult
			return nextGuild or guild
		end)
	end)
	if not ok then
		return false, {
			Success = false,
			Message = "Guild treasury save failed.",
			Error = tostring(result),
		}
	end
	return transformResult ~= nil and transformResult.Success == true, transformResult or {
		Success = true,
		Guild = result,
	}
end

local function broadcastTreasuryUpdated(guildId, reason)
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if getPlayerGuildId(otherPlayer) == guildId then
			guildTreasuryUpdated:FireClient(otherPlayer, {
				GuildId = guildId,
				Reason = reason or "TreasuryChanged",
				ServerNowUnix = os.time(),
			})
		end
	end
end

local function refundProfileResource(userId, resource, amount)
	updatePlayerProfile(userId, function(profile)
		addProfileResource(profile, resource, clampInt(amount))
		return profile, {
			Success = true,
		}
	end)
end

local function getTreasuryForPlayer(player, requestedGuildId)
	local guildId = getPlayerGuildId(player)
	if typeof(requestedGuildId) == "string" and requestedGuildId ~= "" and requestedGuildId ~= guildId then
		return {
			Success = false,
			Message = "You can only inspect your current guild treasury.",
		}
	end
	return buildTreasuryState(player, "Treasury loaded.", true)
end

local function depositTreasuryForPlayer(player, resourceId, amount)
	local resource = getTreasuryResourceDef(resourceId)
	if not resource then
		return buildTreasuryState(player, "Unknown treasury resource.", false)
	end
	local donation = clampInt(amount)
	if donation < clampInt(resource.minAmount, 1) then
		return buildTreasuryState(player, "Amount must be positive.", false)
	end
	local contributionGain = getContributionGain(resource, donation)
	local xpGain = getXpGain(resource, donation)

	local guild, authError = getAuthorizedGuild(player)
	if not guild then
		return {
			Success = false,
			Message = authError or "Guild authorization failed.",
		}
	end
	local guildId = tostring(guild.guildId or guild.GuildId or "")

	local profileOk, profileResult = updatePlayerProfile(player.UserId, function(profile)
		if not profileHasGuild(profile, guildId) then
			return profile, {
				Success = false,
				Message = "You are not a member of this guild.",
			}
		end
		local owned = getProfileResourceAmount(profile, resource)
		if owned < donation then
			return profile, {
				Success = false,
				Message = "Not enough " .. tostring(resource.displayName or resource.id) .. ".",
			}
		end
		addProfileResource(profile, resource, -donation)
		return profile, {
			Success = true,
		}
	end)
	if not profileOk then
		return buildTreasuryState(player, profileResult and profileResult.Message or "Deposit failed.", false)
	end

	local guildOk, guildResult = updateGuildRecord(guildId, function(nextGuild)
		if nextGuild.disbanded == true then
			return nextGuild, {
				Success = false,
				Message = "Guild not found or membership expired.",
			}
		end
		local member = getGuildMember(nextGuild, player)
		if not member then
			return nextGuild, {
				Success = false,
				Message = "Guild membership expired.",
			}
		end
		ensureGuildTreasury(nextGuild)
		addGuildResource(nextGuild, resource, donation)

		local totalContributionBase = getTotalContribution(nextGuild)
		nextGuild.xp = clampInt(nextGuild.xp or nextGuild.XP) + xpGain
		nextGuild.level = getGuildLevelFromXp(nextGuild.xp)
		member.contribution = clampInt(member.contribution or member.Contribution) + contributionGain
		nextGuild.memberContributions[memberKey(player.UserId)] = clampInt(nextGuild.memberContributions[memberKey(player.UserId)]) + contributionGain
		nextGuild.totalContribution = totalContributionBase + contributionGain
		addTreasuryHistory(nextGuild, player, resource.id, donation, "Deposit", "Guild treasury deposit")
		return nextGuild, {
			Success = true,
		}
	end)
	if not guildOk then
		refundProfileResource(player.UserId, resource, donation)
		return buildTreasuryState(player, guildResult and guildResult.Message or "Deposit failed; resources were refunded.", false)
	end

	updatePlayerProfile(player.UserId, function(profile)
		if profileHasGuild(profile, guildId) then
			if typeof(profile.Guild) ~= "table" then
				profile.Guild = {}
			end
			profile.Guild.Contribution = clampInt(profile.Guild.Contribution or profile.Guild.contribution) + contributionGain
		end
		return profile, {
			Success = true,
		}
	end)

	broadcastTreasuryUpdated(guildId, "Deposit")
	return buildTreasuryState(player, "Donation accepted.", true)
end

local function spendTreasuryForPlayer(player, resourceId, amount, reason)
	local resource = getTreasuryResourceDef(resourceId)
	if not resource then
		return buildTreasuryState(player, "Unknown treasury resource.", false)
	end
	local spendAmount = clampInt(amount)
	if spendAmount <= 0 then
		return buildTreasuryState(player, "Amount must be positive.", false)
	end
	local spendReason = tostring(reason or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if spendReason == "" then
		spendReason = "Manual treasury spend"
	end
	if #spendReason > 80 then
		spendReason = spendReason:sub(1, 80)
	end

	local guild, authError = getAuthorizedGuild(player)
	if not guild then
		return {
			Success = false,
			Message = authError or "Guild authorization failed.",
		}
	end
	local guildId = tostring(guild.guildId or guild.GuildId or "")

	local guildOk, guildResult = updateGuildRecord(guildId, function(nextGuild)
		if nextGuild.disbanded == true then
			return nextGuild, {
				Success = false,
				Message = "Guild not found or membership expired.",
			}
		end
		local member = getGuildMember(nextGuild, player)
		if not member then
			return nextGuild, {
				Success = false,
				Message = "Guild membership expired.",
			}
		end
		if not hasTreasuryManagerRole(member) then
			return nextGuild, {
				Success = false,
				Message = "Only Owner or Officer can spend guild resources.",
			}
		end
		local currentAmount = getGuildResourceAmount(nextGuild, resource)
		if currentAmount < spendAmount then
			return nextGuild, {
				Success = false,
				Message = "Not enough guild " .. tostring(resource.displayName or resource.id) .. ".",
			}
		end
		setGuildResourceAmount(nextGuild, resource, currentAmount - spendAmount)
		addTreasuryHistory(nextGuild, player, resource.id, spendAmount, "Spend", spendReason)
		return nextGuild, {
			Success = true,
		}
	end)
	if not guildOk then
		return buildTreasuryState(player, guildResult and guildResult.Message or "Spend failed.", false)
	end

	broadcastTreasuryUpdated(guildId, "Spend")
	return buildTreasuryState(player, "Treasury resources spent.", true)
end

local function buildGuildCastleState(player)
	local guild, authError = getAuthorizedGuild(player)
	if not guild then
		return {
			Success = false,
			Message = authError or "Guild data is not available.",
		}
	end

	local member = getGuildMember(guild, player)
	return {
		Success = true,
		Message = "",
		ServerNowUnix = os.time(),
		Guild = {
			GuildId = tostring(guild.guildId or guild.GuildId or ""),
			Name = tostring(guild.name or guild.Name or "Guild"),
			Description = tostring(guild.description or guild.Description or ""),
			Privacy = getGuildPrivacy(guild),
			Level = math.max(1, clampInt(guild.level or guild.Level, 1)),
			XP = clampInt(guild.xp or guild.Xp or guild.XP),
			Treasury = copyTreasury(guild),
			TreasuryKeys = table.clone(TREASURY_KEYS),
			TotalContribution = getTotalContribution(guild),
			MemberCount = countMembers(guild),
			OnlineMemberCount = countOnlineMembers(guild),
		},
		Membership = {
			GuildId = tostring(guild.guildId or guild.GuildId or ""),
			Role = getMemberRole(member),
			Contribution = clampInt(member and (member.contribution or member.Contribution) or 0),
		},
		Locations = buildGuildLocationState(),
	}
end

local function openGuildLocation(player, locationId)
	local definition = GUILD_LOCATION_BY_ID[locationId]
	if not definition then
		return
	end

	local guild, authError = getAuthorizedGuild(player)
	if not guild then
		guildLocationOpened:FireClient(player, {
			Success = false,
			LocationId = definition.Id,
			Name = definition.Name,
			Message = authError or "You must be a guild member to use this location.",
			Status = "Locked",
		})
		return
	end

	local payload = {
		Success = true,
		Location = {
			Id = definition.Id,
			Name = definition.Name,
			Description = definition.Description,
			Status = getLocationStatus(definition),
			Hint = definition.Hint,
			GuildId = tostring(guild.guildId or guild.GuildId or ""),
		},
	}
	if definition.Id == "Treasury" then
		payload.Location.Panel = "Treasury"
		payload.Treasury = buildTreasuryState(player, "Treasury loaded.", true)
	end
	guildLocationOpened:FireClient(player, payload)
end

local function bindGuildLocationPrompts()
	local folder = ensureGuildLocations()
	for _, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
		local model = folder:FindFirstChild(definition.Id)
		local entrance = model and model:FindFirstChild("Entrance")
		if model and entrance and entrance:IsA("BasePart") then
			local prompt = ensureLocationPrompt(model, entrance, definition)
			prompt.Triggered:Connect(function(player)
				openGuildLocation(player, definition.Id)
			end)
		else
			warn("[GuildPlace] Failed to bind guild location prompt:", definition.Id)
		end
	end
end

local function returnPlayerToLobby(player)
	if returnInFlight[player] then
		return
	end

	local lobbyPlaceId = tonumber(GuildConfig.LOBBY_PLACE_ID) or 0
	if lobbyPlaceId <= 0 then
		fireLobbyReturnStatus(player, false, "Lobby place is not configured yet.", "LobbyPlaceMissing")
		return
	end

	local guild, authError = getAuthorizedGuild(player)
	if not guild then
		fireLobbyReturnStatus(player, false, authError or "Guild authorization failed.", "Unauthorized")
		return
	end

	returnInFlight[player] = true
	fireLobbyReturnStatus(player, true, "Returning to Four Peaks...", "Teleporting")

	local options = Instance.new("TeleportOptions")
	local guildId = tostring(guild.guildId or guild.GuildId or "")
	options:SetTeleportData({
		guildId = guildId,
		GuildId = guildId,
		sourcePlace = "Guild",
		returnToLobby = true,
	})

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(lobbyPlaceId, { player }, options)
	end)
	if not ok then
		returnInFlight[player] = nil
		warn("[GuildPlace] Return to lobby failed:", err)
		fireLobbyReturnStatus(player, false, "Return to lobby failed. Try again.", "TeleportFailed")
	end
end

bindGuildLocationPrompts()

Players.PlayerAdded:Connect(function(player)
	local guildId = getTeleportGuildId(player)
	local profile = nil
	-- Direct Play in Studio has no teleport data, so use saved server-side membership for local testing only.
	if not guildId and RunService:IsStudio() then
		profile = loadPlayerProfile(player.UserId)
		guildId = getProfileGuildId(profile)
	end

	if not guildId then
		rejectPlayer(player, "Guild teleport data missing.")
		return
	end

	profile = profile or loadPlayerProfile(player.UserId)
	if not profileHasGuild(profile, guildId) then
		rejectPlayer(player, "You are not a member of this guild.")
		return
	end

	local guild = loadGuild(guildId)
	if not guild or guild.disbanded == true or not guildHasPlayer(guild, player) then
		rejectPlayer(player, "Guild not found or membership expired.")
		return
	end

	player:SetAttribute("GuildId", tostring(guild.guildId or guild.GuildId or guildId))
	player:SetAttribute("GuildName", tostring(guild.name or guild.Name or "Guild"))
	player:SetAttribute("GuildLevel", math.max(1, math.floor(tonumber(guild.level or guild.Level) or 1)))
	player:SetAttribute("GuildCastleReady", true)
end)

requestLobbyReturn.OnServerEvent:Connect(function(player)
	returnPlayerToLobby(player)
end)

getGuildCastleState.OnServerInvoke = function(player)
	return buildGuildCastleState(player)
end

getTreasury.OnServerInvoke = function(player, guildId)
	return getTreasuryForPlayer(player, guildId)
end

depositToTreasury.OnServerInvoke = function(player, resourceId, amount)
	return depositTreasuryForPlayer(player, resourceId, amount)
end

spendFromTreasury.OnServerInvoke = function(player, resourceId, amount, reason)
	return spendTreasuryForPlayer(player, resourceId, amount, reason)
end

Players.PlayerRemoving:Connect(function(player)
	returnInFlight[player] = nil
end)

print("[GuildPlace] Ready")
