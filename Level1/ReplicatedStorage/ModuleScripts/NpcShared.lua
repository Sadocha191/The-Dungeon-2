local NpcShared = {}

NpcShared.RemoteName = "NpcBatchEvent"
NpcShared.SyncRequestRemoteName = "NpcSyncRequest"
NpcShared.BatchRate = 0.1

NpcShared.PositionScale = 4
NpcShared.VelocityScale = 10
NpcShared.YawScale = 1000
NpcShared.PacketStride = 22

NpcShared.RenderThrottleMinCount = 120
NpcShared.RenderBatchSize = 80

NpcShared.States = table.freeze({
	Spawn = "Spawn",
	Idle = "Idle",
	Chasing = "Chasing",
	Attacking = "Attacking",
	Dead = "Dead",
	Despawned = "Despawned",
})

NpcShared.StateIds = table.freeze({
	[NpcShared.States.Spawn] = 0,
	[NpcShared.States.Idle] = 1,
	[NpcShared.States.Chasing] = 2,
	[NpcShared.States.Attacking] = 3,
	[NpcShared.States.Dead] = 4,
	[NpcShared.States.Despawned] = 5,
})

NpcShared.StateNames = table.freeze({
	[0] = NpcShared.States.Spawn,
	[1] = NpcShared.States.Idle,
	[2] = NpcShared.States.Chasing,
	[3] = NpcShared.States.Attacking,
	[4] = NpcShared.States.Dead,
	[5] = NpcShared.States.Despawned,
})

NpcShared.PacketFlags = table.freeze({
	HasModel = 1,
	Dead = 2,
	Despawned = 4,
})

NpcShared.Attributes = table.freeze({
	Id = "NpcId",
	Type = "NpcType",
	MobType = "MobType",
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
	IsRanged = "IsRanged",
	Damage = "Damage",
	AttackRange = "AttackRange",
	AttackCooldown = "AttackCooldown",
})

NpcShared.AnimationStateByNpcState = table.freeze({
	[NpcShared.States.Spawn] = "idle",
	[NpcShared.States.Idle] = "idle",
	[NpcShared.States.Chasing] = "run",
	[NpcShared.States.Attacking] = "attack",
	[NpcShared.States.Dead] = "death",
	[NpcShared.States.Despawned] = "death",
})

local function roundSigned(value: number): number
	if value >= 0 then
		return math.floor(value + 0.5)
	end
	return math.ceil(value - 0.5)
end

local function clampI16(value: number): number
	return math.clamp(roundSigned(tonumber(value) or 0), -32768, 32767)
end

local function clampU16(value: number): number
	return math.clamp(math.floor((tonumber(value) or 0) + 0.5), 0, 65535)
end

local function flatDir(v: Vector3?): Vector3
	if typeof(v) ~= "Vector3" then
		return Vector3.new(0, 0, -1)
	end

	local xz = Vector3.new(v.X, 0, v.Z)
	if xz.Magnitude <= 1e-4 then
		return Vector3.new(0, 0, -1)
	end

	return xz.Unit
end

function NpcShared.EncodeState(state: string?): number
	return NpcShared.StateIds[state or ""] or NpcShared.StateIds[NpcShared.States.Idle]
end

function NpcShared.DecodeState(stateId: number): string
	return NpcShared.StateNames[math.floor(tonumber(stateId) or 0)] or NpcShared.States.Idle
end

function NpcShared.EncodeYaw(dir: Vector3?): number
	local flat = flatDir(dir)
	local yaw = math.atan2(flat.X, -flat.Z)
	return clampI16(yaw * NpcShared.YawScale)
end

function NpcShared.DecodeYaw(encodedYaw: number): Vector3
	local yaw = (tonumber(encodedYaw) or 0) / NpcShared.YawScale
	return Vector3.new(math.sin(yaw), 0, -math.cos(yaw))
end

function NpcShared.EncodeVector3(value: Vector3?, scale: number): (number, number, number)
	if typeof(value) ~= "Vector3" then
		return 0, 0, 0
	end

	return clampI16(value.X * scale), clampI16(value.Y * scale), clampI16(value.Z * scale)
end

function NpcShared.DecodeVector3(x: number, y: number, z: number, scale: number): Vector3
	local safeScale = if scale == 0 then 1 else scale
	return Vector3.new(
		(tonumber(x) or 0) / safeScale,
		(tonumber(y) or 0) / safeScale,
		(tonumber(z) or 0) / safeScale
	)
end

function NpcShared.BuildPacketEntry(data)
	local px, py, pz = NpcShared.EncodeVector3(data.pos, NpcShared.PositionScale)
	local vx, vy, vz = NpcShared.EncodeVector3(data.vel, NpcShared.VelocityScale)

	local flags = 0
	if data.hasModel == true then
		flags += NpcShared.PacketFlags.HasModel
	end
	if data.dead == true then
		flags += NpcShared.PacketFlags.Dead
	end
	if data.despawned == true then
		flags += NpcShared.PacketFlags.Despawned
	end

	return {
		numericId = clampU16(data.numericId or data.id),
		flags = flags,
		stateId = NpcShared.EncodeState(data.state),
		hp = clampU16(data.hp),
		maxHp = clampU16(data.maxHp),
		px = px,
		py = py,
		pz = pz,
		vx = vx,
		vy = vy,
		vz = vz,
		yaw = NpcShared.EncodeYaw(data.dir),
	}
end

function NpcShared.ClonePacketEntry(entry)
	return {
		numericId = entry.numericId,
		flags = entry.flags,
		stateId = entry.stateId,
		hp = entry.hp,
		maxHp = entry.maxHp,
		px = entry.px,
		py = entry.py,
		pz = entry.pz,
		vx = entry.vx,
		vy = entry.vy,
		vz = entry.vz,
		yaw = entry.yaw,
	}
end

function NpcShared.PacketEntryEquals(a, b): boolean
	if a == b then
		return true
	end
	if not a or not b then
		return false
	end

	return a.numericId == b.numericId
		and a.flags == b.flags
		and a.stateId == b.stateId
		and a.hp == b.hp
		and a.maxHp == b.maxHp
		and a.px == b.px
		and a.py == b.py
		and a.pz == b.pz
		and a.vx == b.vx
		and a.vy == b.vy
		and a.vz == b.vz
		and a.yaw == b.yaw
end

function NpcShared.EncodePacket(entries): buffer
	local count = #entries
	local packet = buffer.create(count * NpcShared.PacketStride)

	for index, entry in ipairs(entries) do
		local offset = (index - 1) * NpcShared.PacketStride
		buffer.writeu16(packet, offset, clampU16(entry.numericId))
		offset += 2
		buffer.writeu8(packet, offset, math.clamp(entry.flags or 0, 0, 255))
		offset += 1
		buffer.writeu8(packet, offset, math.clamp(entry.stateId or 0, 0, 255))
		offset += 1
		buffer.writeu16(packet, offset, clampU16(entry.hp))
		offset += 2
		buffer.writeu16(packet, offset, clampU16(entry.maxHp))
		offset += 2
		buffer.writei16(packet, offset, clampI16(entry.px))
		offset += 2
		buffer.writei16(packet, offset, clampI16(entry.py))
		offset += 2
		buffer.writei16(packet, offset, clampI16(entry.pz))
		offset += 2
		buffer.writei16(packet, offset, clampI16(entry.vx))
		offset += 2
		buffer.writei16(packet, offset, clampI16(entry.vy))
		offset += 2
		buffer.writei16(packet, offset, clampI16(entry.vz))
		offset += 2
		buffer.writei16(packet, offset, clampI16(entry.yaw))
	end

	return packet
end

function NpcShared.DecodePacket(packet): { [number]: { [string]: any } }
	if typeof(packet) ~= "buffer" then
		return {}
	end

	local packetLength = buffer.len(packet)
	if packetLength == 0 or packetLength % NpcShared.PacketStride ~= 0 then
		return {}
	end

	local count = packetLength / NpcShared.PacketStride
	local items = table.create(count)

	for index = 1, count do
		local offset = (index - 1) * NpcShared.PacketStride
		local numericId = buffer.readu16(packet, offset)
		offset += 2
		local flags = buffer.readu8(packet, offset)
		offset += 1
		local stateId = buffer.readu8(packet, offset)
		offset += 1
		local hp = buffer.readu16(packet, offset)
		offset += 2
		local maxHp = buffer.readu16(packet, offset)
		offset += 2
		local px = buffer.readi16(packet, offset)
		offset += 2
		local py = buffer.readi16(packet, offset)
		offset += 2
		local pz = buffer.readi16(packet, offset)
		offset += 2
		local vx = buffer.readi16(packet, offset)
		offset += 2
		local vy = buffer.readi16(packet, offset)
		offset += 2
		local vz = buffer.readi16(packet, offset)
		offset += 2
		local yaw = buffer.readi16(packet, offset)

		items[index] = {
			id = tostring(numericId),
			numericId = numericId,
			hasModel = bit32.band(flags, NpcShared.PacketFlags.HasModel) ~= 0,
			dead = bit32.band(flags, NpcShared.PacketFlags.Dead) ~= 0,
			despawned = bit32.band(flags, NpcShared.PacketFlags.Despawned) ~= 0,
			state = NpcShared.DecodeState(stateId),
			hp = hp,
			maxHp = maxHp,
			pos = NpcShared.DecodeVector3(px, py, pz, NpcShared.PositionScale),
			vel = NpcShared.DecodeVector3(vx, vy, vz, NpcShared.VelocityScale),
			dir = NpcShared.DecodeYaw(yaw),
		}
	end

	return items
end

function NpcShared.IsDeadState(state: string?): boolean
	return state == NpcShared.States.Dead or state == NpcShared.States.Despawned
end

return table.freeze(NpcShared)
