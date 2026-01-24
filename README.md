The Dungeon 2 — Game Rules & Flow
Core Concept

The Dungeon 2 is a session-based dungeon crawler built around short “runs” where you enter a level, fight increasingly dangerous enemies, build your power through drops and upgrades, and try to survive until the end.

Your long-term progression (weapons, currency, quests) happens in the Lobby. Your short-term progression (combat power during the run) happens inside the Dungeon.

Main Loop

Start in the Lobby (Village).

Interact with NPCs (tutorial, quests, blacksmith).

Enter the Portal and select a level.

Play a run: fight, collect rewards, improve your build.

Survive to the end and return to the Lobby with your earnings.

Tutorial Rules

New players start with a guided tutorial in the Lobby.

During the tutorial:

NPC menus (Blacksmith, Missions) are blocked.

Only tutorial dialogues are available.

Once the tutorial is completed:

All NPC systems unlock permanently for that player.

Runs (Dungeon Sessions)
Run Duration and Win Condition

A run lasts up to 20 minutes.

After 20 minutes, the level boss spawns.

Defeating the boss ends the run as a win and returns the player to the Lobby.

Enemy Scaling

Enemies spawn in progressively stronger tiers (weak → strong).

The same base enemy can appear in multiple variants, with scaled stats.

Every 5 minutes, an Elite enemy spawns:

Elites are stronger than standard enemies.

Elites are intended as difficulty spikes and higher-value targets.

Rewards During a Run

While playing a run you earn:

Coins (main free-to-play currency)

Progress toward Daily and Weekly Missions

Any run-based rewards configured for that level

After the run ends, all earned rewards are reflected back in the Lobby.

Weapons and Inventory
Weapon Ownership

Weapons are owned as instances (duplicates are allowed).

Each instance can have:

Rarity (up to Epic via Blacksmith forging)

Level (capped by rarity)

Prefix/Quality modifier that alters stats (e.g., weaker-than-base or stronger-than-base outcomes)

Equipping

You enter a run using your currently equipped weapon instance.

Weapon access during a run is restricted to the equipped weapon (no mid-run weapon swapping unless explicitly implemented later).

Blacksmith System (Forge & Upgrade)

The Blacksmith is the main way to acquire and improve weapons.

Forge

Uses Coins (fixed cost per forge).

Produces:

A random weapon type

A random rarity (limited to Epic)

A random quality prefix that modifies all stats

Forged weapons go directly into the player inventory as a new instance.

Upgrade

Upgrades apply to a selected owned weapon instance.

Upgrading increases weapon level up to its rarity cap.

The UI supports:

Repeated upgrading without re-selecting the weapon

Batch upgrade options (including +10)

Missions (Daily / Weekly)
Where Missions Are Claimed

Missions are handled by the Knight NPC.

Mission Structure

The mission menu displays:

6 Daily missions

12 Weekly missions

Missions progress is tracked automatically based on gameplay actions (kills, time, run completion, etc., depending on the mission definitions).

Reset Rules

Daily missions reset on a daily schedule.

Weekly missions reset on a weekly schedule.

After a reset:

A fresh set of missions is selected for that player.

Claim status and progress are cleared for that cycle.

Rewards

Missions reward currencies (primarily Coins and optionally premium currency depending on configuration).

Claiming is only possible when the mission is marked Claimable (requirements met).

Currency

Coins: core free-to-play currency used for forging and other systems.

Additional currencies may exist and can be used for other systems (e.g., premium/gacha), depending on current implementation.

Saving and Persistence

The game stores player progression persistently:

Tutorial completion state

Owned weapon instances and equipped weapon

Mission selections, progress, and claim history

Currency balances

Progress earned during a run is applied back to the persistent profile when appropriate (end-of-run and periodic saves depending on implementation).

Player Experience Summary

Lobby: preparation, NPC systems, forging/upgrading, missions, portal selection

Dungeon: combat session, scaling enemies, elite spikes every 5 minutes, boss at 20 minutes

Return: rewards and progress feed back into the Lobby systems
