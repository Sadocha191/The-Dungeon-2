local BlacksmithTheme = {}

BlacksmithTheme.RarityColors = {
	Common = Color3.fromRGB(170, 174, 181),
	Uncommon = Color3.fromRGB(92, 156, 98),
	Rare = Color3.fromRGB(82, 133, 199),
	Epic = Color3.fromRGB(142, 91, 191),
	Legendary = Color3.fromRGB(218, 166, 72),
	Mythic = Color3.fromRGB(185, 67, 72),
	Mythical = Color3.fromRGB(185, 67, 72),
}

BlacksmithTheme.ElementColors = {
	Fire = Color3.fromRGB(205, 91, 55),
	Water = Color3.fromRGB(74, 132, 190),
	Air = Color3.fromRGB(126, 193, 204),
	Earth = Color3.fromRGB(82, 139, 86),
	Electric = Color3.fromRGB(214, 185, 72),
	Electricity = Color3.fromRGB(214, 185, 72),
	Void = Color3.fromRGB(132, 87, 178),
	Light = Color3.fromRGB(224, 198, 120),
	Physical = Color3.fromRGB(168, 171, 178),
}

function BlacksmithTheme.GetRarityColor(rarity)
	return BlacksmithTheme.RarityColors[tostring(rarity or "")] or BlacksmithTheme.RarityColors.Common
end

function BlacksmithTheme.GetElementColor(element)
	return BlacksmithTheme.ElementColors[tostring(element or "")] or BlacksmithTheme.ElementColors.Physical
end

return BlacksmithTheme
