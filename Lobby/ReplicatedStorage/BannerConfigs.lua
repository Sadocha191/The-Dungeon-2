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
			{ WeaponId = "Sword", Rarity = "Common", Weight = 50 },
			{ WeaponId = "Bow", Rarity = "Common", Weight = 50 },
			{ WeaponId = "Pistol", Rarity = "Rare", Weight = 40 },
			{ WeaponId = "Halberd", Rarity = "Rare", Weight = 60 },
			{ WeaponId = "Scythe", Rarity = "Epic", Weight = 70 },
			{ WeaponId = "Staff", Rarity = "Legendary", Weight = 100 },
		},
		FeaturedWeaponIds = { "Staff" },
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
