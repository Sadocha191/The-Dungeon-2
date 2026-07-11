local MobConfig = {}

-- Main mob tuning table.
-- visualScale controls the spawned model size.
-- facingYawDegrees rotates the visual model around the vertical axis.
-- groundOffset is the animated root-center height above terrain used for final grounding.
MobConfig.Mobs = {
	Slime = {
		hp = 22,
		speed = 8.5,
		attackRange = 3,
		attackCooldown = 1.9,
		damage = 5,
		xp = 5,
		coins = 1,
		visualScale = 1,
		groundOffset = 2.55,
	},

	Zombie = {
		hp = 74,
		speed = 7.0,
		attackRange = 4,
		attackCooldown = 2.3,
		damage = 9,
		xp = 9,
		coins = 2,
		visualScale = 1,
	},

	Skeleton = {
		hp = 44,
		speed = 13.5,
		attackRange = 4,
		attackCooldown = 1.45,
		damage = 10,
		xp = 11,
		coins = 2,
		visualScale = 1,
	},

	Goblin = {
		hp = 56,
		speed = 15.5,
		attackRange = 3,
		attackCooldown = 1.18,
		damage = 8,
		xp = 13,
		coins = 2,
		visualScale = 1,
		facingYawDegrees = -90,
	},

	Grzyb = {
		hp = 48,
		speed = 8.0,
		attackRange = 4,
		attackCooldown = 2.15,
		damage = 9,
		xp = 10,
		coins = 2,
		visualScale = 1,
		facingYawDegrees = -90,
		movementProfile = "GroundLarge",
	},

	Warewolf = {
		hp = 112,
		speed = 17.0,
		attackRange = 5,
		attackCooldown = 1.18,
		damage = 13,
		xp = 20,
		coins = 3,
		visualScale = 1,
	},

	Harp = {
		hp = 88,
		speed = 13.5,
		attackRange = 25,
		attackCooldown = 2.1,
		damage = 11,
		xp = 19,
		coins = 3,
		visualScale = 1,
		isRanged = true,
	},

	Demon = {
		hp = 128,
		speed = 11.5,
		attackRange = 18,
		attackCooldown = 1.85,
		damage = 13,
		xp = 23,
		coins = 4,
		visualScale = 1,
		isRanged = true,
		hasFireball = true,
	},

	LandShark = {
		hp = 108,
		speed = 18.5,
		attackRange = 7,
		attackCooldown = 2.7,
		damage = 15,
		xp = 22,
		coins = 4,
		visualScale = 1,
		isBurrow = true,
	},

	Golem = {
		hp = 210,
		speed = 6.5,
		attackRange = 6,
		attackCooldown = 2.6,
		damage = 18,
		xp = 30,
		coins = 5,
		visualScale = 3,
		movementProfile = "GroundLarge",
	},

	Knight = {
		hp = 150,
		speed = 11.8,
		attackRange = 5,
		attackCooldown = 1.35,
		damage = 14,
		xp = 27,
		coins = 4,
		visualScale = 3,
		movementProfile = "GroundLarge",
	},

	Ent = {
		hp = 260,
		speed = 5.5,
		attackRange = 8,
		attackCooldown = 2.9,
		damage = 17,
		xp = 34,
		coins = 6,
		visualScale = 3.3,
		facingYawDegrees = -90,
		movementProfile = "GroundLarge",
	},
}

for _, config in pairs(MobConfig.Mobs) do
	config.range = config.attackRange
	config.cd = config.attackCooldown
	config.dmg = config.damage
end

return MobConfig
