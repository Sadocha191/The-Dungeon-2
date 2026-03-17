local BannerSchedule = {}

-- Edit this file to plan weapon banner rotation.
-- Keep entries ordered from oldest to newest.
-- StartsAtUtc format: "YYYY-MM-DD HH:MM" in UTC.
-- Add more entries below if you want to plan further rotations.
-- Use weapon IDs exactly as they appear in WeaponConfigs.lua.
BannerSchedule.Rotation = {
	{
		StartsAtUtc = "2026-03-01 00:00",
		FeaturedWeaponId = "Excalion, Blade of Kings",
		DisplayName = "Weapon Banner: Excalion",
		Description = "Increased chance for Excalion, Blade of Kings.",
	},
	{
		-- Edit this entry to schedule the next banner.
		StartsAtUtc = "2026-03-24 18:00",
		FeaturedWeaponId = "Harvest of the End",
		DisplayName = "Weapon Banner: Harvest",
		Description = "Increased chance for Harvest of the End.",
	},
}

return BannerSchedule
