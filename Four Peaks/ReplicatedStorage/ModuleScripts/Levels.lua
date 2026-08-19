-- MODULE: Levels.lua
-- Used by the lobby portal UI and teleport flow.

local Levels = {}

Levels.List = {
	{
		key = "AshenWastes",
		instanceName = "AshenWastes",
		aliases = { "Level", "Level1" },
		name = "Ashen Wastes",
		placeId = 113361902471683,
		description = "A burned wasteland covered in gray ash, dead trees, and the ruins of a long-fallen civilization. Fits an open map with low visibility and enemy waves emerging from clouds of ash.",
		highscore = 0,
		speedrun = "00:00.00",
	},
	{
		key = "HollowMarsh",
		instanceName = "HollowMarsh",
		aliases = { "Level2" },
		name = "Hollow Marsh",
		placeId = 86815986698401,
		description = "A dark swamp filled with black water, twisted branches, and rotting vegetation. Heavy and oppressive atmosphere, great for swamp monsters, poison effects, and slower but more dangerous elite enemies.",
		highscore = 0,
		speedrun = "00:00.00",
	},
	{
		key = "Blightmoor",
		instanceName = "Blightmoor",
		name = "Blightmoor",
		description = "A cursed moor corrupted by strange energy. The land is dead, the air feels sick, and the plants have grown into warped, unnatural shapes. Good for plague-themed enemies, corruption, and decay effects.",
		highscore = 0,
		speedrun = "00:00.00",
	},
	{
		key = "ShatteredHighlands",
		instanceName = "ShatteredHighlands",
		name = "Shattered Highlands",
		description = "Broken highlands with cliffs, rocky paths, and the remains of ruined strongholds. The whole area feels like the aftermath of an ancient war. Works well for a harsher biome with fallen warriors and stronger armored enemies.",
		highscore = 0,
		speedrun = "00:00.00",
	},
	{
		key = "Dreadwood",
		instanceName = "Dreadwood",
		name = "Dreadwood",
		description = "A grim forest where the trees look twisted and almost alive. It feels like something is always watching from the darkness. Perfect for beasts, spirits, and cursed forest creatures.",
		highscore = 0,
		speedrun = "00:00.00",
	},
}

function Levels.GetAll(): { any }
	local out = table.create(#Levels.List)
	for i, entry in ipairs(Levels.List) do
		out[i] = entry
	end
	return out
end

function Levels.GetByKey(key: string): any
	for _, entry in ipairs(Levels.List) do
		if entry.key == key then
			return entry
		end

		local aliases = entry.aliases
		if typeof(aliases) == "table" then
			for _, alias in ipairs(aliases) do
				if alias == key then
					return entry
				end
			end
		end
	end

	return nil
end

return Levels
