-- // Scripted by Sothaereos

-- A list of materials, and their requirements to generate.
-- Define with the material's enum item, the slope or slope range,
-- and height requirements, relative to the sea level.

-- Location in the table is important, as it determines priority.
-- Materials lower in the table will override anything above it;
-- meaning the table is iterated from the top down.

-- To add a new material quickly, simply copy and paste an
-- existing one and change the values to whatever you like.

local materials = {
	-- The default material; if no other material can generate due
	-- to their requirements, this material will generate there.
	default = Enum.Material.Grass,
	
	-- Ocean and beach materials
	{
		material = Enum.Material.Sand,
		-- Height range in which the material can generate, in studs, relative to the sea level.
		heightRange = NumberRange.new(-math.huge, 2),
		-- Range of slope values at which the material can generate
		slopeRange = NumberRange.new(0, 49),
		-- Blending between this material and others. X is added to the min height, and Y is subtracted from the max height.
		blendRange = Vector2.new(0, 10)
	},
	{
		material = Enum.Material.Limestone,
		heightRange = NumberRange.new(-math.huge, 0),
		slopeRange = NumberRange.new(48, 65),
		blendRange = Vector2.new(0, 20)
	},
	-- Snow materials
	{
		material = Enum.Material.Snow,
		heightRange = NumberRange.new(390, math.huge),
		slopeRange = NumberRange.new(0, 53),
		blendRange = Vector2.new(40, 0)
	},
	{
		material = Enum.Material.Glacier,
		heightRange = NumberRange.new(390, math.huge),
		slopeRange = NumberRange.new(54, math.huge),
		blendRange = Vector2.new(40, 0)
	},
	-- Rock and rock decoration
	{
		material = Enum.Material.Slate,
		heightRange = NumberRange.new(0, 450),
		slopeRange = NumberRange.new(56, 58),
		blendRange = Vector2.new(15, 15)
	},
	{
		material = Enum.Material.Basalt,
		heightRange = NumberRange.new(0, 450),
		slopeRange = NumberRange.new(60, 61),
		blendRange = Vector2.new(15, 15)
	},
	{
		material = Enum.Material.Rock,
		heightRange = NumberRange.new(-math.huge, 430),
		slopeRange = NumberRange.new(48, math.huge),
		blendRange = Vector2.new(30, 0)
	},
	-- Ground
	{
		material = Enum.Material.Ground,
		heightRange = NumberRange.new(320, 430),
		slopeRange = NumberRange.new(0, 47),
		blendRange = Vector2.new(20, 0)
	},
	-- Grassy decoration
	{
		material = Enum.Material.LeafyGrass,
		heightRange = NumberRange.new(0, 370),
		slopeRange = NumberRange.new(43, 43),
		blendRange = Vector2.new(10, 10)
	},
}

return materials