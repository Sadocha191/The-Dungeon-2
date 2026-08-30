local NpcShared = {}

NpcShared.RemoteName = "NpcBatchEvent"
NpcShared.SyncRequestRemoteName = "NpcSyncRequest"
NpcShared.MotionRemoteName = "NpcMotionEvent"
NpcShared.DebugSnapshotRemoteName = "NpcLifecycleDebugSnapshot"
NpcShared.ProtocolVersion = 2
NpcShared.BatchRate = 0.1
NpcShared.MotionRate = 1 / 12
NpcShared.PoolTargetCapacity = 160

NpcShared.MotionLod = table.freeze({
	NearDistance = 70,
	MidDistance = 140,
	NearHz = 12,
	MidHz = 6,
	FarHz = 3,
	ImportantHz = 12,
})

NpcShared.PresentationLod = table.freeze({
	CriticalDistance = 35,
	NearDistance = 70,
	MidDistance = 140,
	NearHz = 60,
	MidHz = 24,
	FarHz = 10,
	CulledHz = 4,
	ClassificationInterval = 0.25,
})

NpcShared.States = table.freeze({
	Spawn = "Spawn",
	Idle = "Idle",
	Chasing = "Chasing",
	Attacking = "Attacking",
	Dead = "Dead",
	Despawned = "Despawned",
})

NpcShared.Attributes = table.freeze({
	Id = "NpcId",
	Type = "NpcType",
	MobType = "MobType",
	EnemyId = "EnemyId",
	EnemyRank = "EnemyRank",
	State = "NpcState",
	LegacyState = "State",
	AiState = "AIState",
	Health = "NpcHealth",
	LegacyHealth = "Health",
	MaxHealth = "NpcMaxHealth",
	LegacyMaxHealth = "MaxHealth",
	Speed = "NpcSpeed",
	Dead = "NpcDead",
	LegacyDead = "IsDead",
	LegacyAttacking = "IsAttacking",
	Alive = "Alive",
	Direction = "NpcDirection",
	Velocity = "NpcVelocity",
	IsElite = "IsElite",
	IsMiniBoss = "IsMiniBoss",
	IsBoss = "IsBoss",
	IsRanged = "IsRanged",
	Damage = "Damage",
	AttackRange = "AttackRange",
	AttackCooldown = "AttackCooldown",
	MovementMode = "MovementMode",
	MovementProfile = "MovementProfile",
})

NpcShared.AnimationStateByNpcState = table.freeze({
	[NpcShared.States.Spawn] = "idle",
	[NpcShared.States.Idle] = "idle",
	[NpcShared.States.Chasing] = "run",
	[NpcShared.States.Attacking] = "attack",
	[NpcShared.States.Dead] = "death",
	[NpcShared.States.Despawned] = "death",
})

function NpcShared.IsDeadState(state: string?): boolean
	return state == NpcShared.States.Dead or state == NpcShared.States.Despawned
end

return table.freeze(NpcShared)
