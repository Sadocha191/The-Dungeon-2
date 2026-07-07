local GuildPlaceLocations = {}

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

function GuildPlaceLocations.GetDefinitions()
	return GUILD_LOCATION_DEFINITIONS
end

function GuildPlaceLocations.GetDefinition(locationId)
	return GUILD_LOCATION_BY_ID[locationId]
end

function GuildPlaceLocations.GetStatus(definition)
	return definition.Id == "Treasury" and "Open" or LOCATION_STATUS
end

function GuildPlaceLocations.BuildState()
	local locations = {}
	for index, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
		locations[index] = {
			Id = definition.Id,
			Name = definition.Name,
			Description = definition.Description,
			Status = GuildPlaceLocations.GetStatus(definition),
			Hint = definition.Hint,
		}
	end
	return locations
end

return GuildPlaceLocations
