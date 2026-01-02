local BannerConfigs = {}

BannerConfigs.Banners = {
	WeaponFocus = {
		DisplayName = "Banner broni: Początkujący",
		Description = "Zwiększona szansa na wybrane bronie.",
		Icon = "",
		Active = true,
		Cost = {
			Currency = "Tickets",
			Amount = 1,
		},
		RarityRates = {
			Common = 0.70,
			Rare = 0.20,
			Epic = 0.08,
			Legendary = 0.02,
			Mythical = 0.00,
		},
		Pool = {
			{ WeaponId = "Knight's Oath", Rarity = "Common", Weight = 50 },
			{ WeaponId = "Hunter's Longbow", Rarity = "Common", Weight = 50 },
			{ WeaponId = "Warden's Halberd", Rarity = "Rare", Weight = 40 },
			{ WeaponId = "Apprentice Arcstaff", Rarity = "Rare", Weight = 40 },
			{ WeaponId = "Blackpowder Flintlock", Rarity = "Rare", Weight = 40 },
			{ WeaponId = "Reaper's Crescent", Rarity = "Epic", Weight = 35 },
			{ WeaponId = "Dragonspear Halberd", Rarity = "Epic", Weight = 35 },
			{ WeaponId = "Stormwind Recurve", Rarity = "Epic", Weight = 35 },
			{ WeaponId = "Excalion, Blade of Kings", Rarity = "Legendary", Weight = 25 },
			{ WeaponId = "Harvest of the End", Rarity = "Legendary", Weight = 25 },
			{ WeaponId = "Kingslayer Handcannon", Rarity = "Legendary", Weight = 25 },
			{ WeaponId = "Archmage's Worldstaff", Rarity = "Mythical", Weight = 10 },
		},
		FeaturedWeaponIds = { "Excalion, Blade of Kings" },
		FeaturedRate = 0.50,
		Pity = {
			TargetRarity = "Legendary",
			SoftPityStart = 60,
			SoftPityStep = 0.015,
			HardPity = 80,
		},
	},
}

return BannerConfigs
