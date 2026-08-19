-- EventsConfig.lua
-- Shared event schedule for lobby rewards and dungeon progress.

return {
	{
		Id = "blood_moon_001",
		DisplayName = "Blood Moon",
		Description = "The Blood Moon rises over the dungeon. Complete event objectives to earn tickets and WP.",
		StartUnix = 0, -- Studio/dev active fallback. Set real UTC Unix dates before enabling live rewards.
		EndUnix = 0,
		Icon = "",
		BannerImage = "",
		EventType = "Milestone",
		SortOrder = 1,
		IsEnabled = true,

		Tasks = {
			{
				Id = "defeat_enemies",
				DisplayName = "Defeat Enemies",
				Description = "Defeat 500 enemies during the event.",
				ProgressKey = "EnemiesDefeated",
				RequiredAmount = 500,
				Rewards = { { Type = "WP", Amount = 300 } },
			},
			{
				Id = "open_chests",
				DisplayName = "Open Chests",
				Description = "Open 20 chests during the event.",
				ProgressKey = "ChestsOpened",
				RequiredAmount = 20,
				Rewards = { { Type = "Ticket", Amount = 2 } },
			},
			{
				Id = "defeat_elites",
				DisplayName = "Defeat Elites",
				Description = "Defeat 10 elite enemies during the event.",
				ProgressKey = "ElitesDefeated",
				RequiredAmount = 10,
				Rewards = { { Type = "WP", Amount = 500 } },
			},
			{
				Id = "complete_runs",
				DisplayName = "Complete Dungeon Runs",
				Description = "Complete 5 dungeon runs during the event.",
				ProgressKey = "DungeonRunsCompleted",
				RequiredAmount = 5,
				Rewards = { { Type = "Ticket", Amount = 3 } },
			},
		},

		Milestones = {
			{
				Id = "blood_moon_milestone_1",
				DisplayName = "Blood Moon Progress I",
				RequiredCompletedTasks = 2,
				Rewards = { { Type = "Ticket", Amount = 2 } },
			},
			{
				Id = "blood_moon_milestone_2",
				DisplayName = "Blood Moon Progress II",
				RequiredCompletedTasks = 4,
				Rewards = {
					{ Type = "Ticket", Amount = 5 },
				},
			},
		},

		FinalRewards = {
			{ Type = "Ticket", Amount = 5 },
		},
	},
}
