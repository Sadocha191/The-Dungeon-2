-- ProfileLease.lua
-- Shared DataStore session lease and retry helper.
-- Prevents two Roblox servers from writing the same profile snapshot concurrently.

local HttpService = game:GetService("HttpService")

local ProfileLease = {}
ProfileLease.__index = ProfileLease

local DEFAULT_READ_ATTEMPTS = 5
local DEFAULT_UPDATE_ATTEMPTS = 5
local DEFAULT_ACQUIRE_TIMEOUT_SECONDS = 30
local DEFAULT_LEASE_SECONDS = 180
local DEFAULT_SCHEMA_VERSION = 2

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, nested in pairs(value) do
		copy[deepCopy(key)] = deepCopy(nested)
	end
	return copy
end

local function retryDelay(attempt: number)
	local base = math.min(0.25 * (2 ^ math.max(0, attempt - 1)), 3)
	task.wait(base + (math.random() * 0.15))
end

local function normalizeMeta(profile, schemaVersion)
	local meta = typeof(profile._profileMeta) == "table" and profile._profileMeta or {}
	meta.schemaVersion = math.max(schemaVersion, math.floor(tonumber(meta.schemaVersion) or 0))
	meta.revision = math.max(0, math.floor(tonumber(meta.revision) or 0))
	profile._profileMeta = meta
	return meta
end

function ProfileLease.new(dataStore, options)
	assert(dataStore ~= nil, "[ProfileLease] DataStore is required")
	options = typeof(options) == "table" and options or {}

	local jobId = game.JobId
	if typeof(jobId) ~= "string" or jobId == "" then
		jobId = "studio"
	end

	local self = setmetatable({}, ProfileLease)
	self._store = dataStore
	self._name = tostring(options.name or "Profile")
	self._ownerId = string.format("%s:%d:%s", jobId, game.PlaceId, HttpService:GenerateGUID(false))
	self._readAttempts = math.max(1, math.floor(tonumber(options.readAttempts) or DEFAULT_READ_ATTEMPTS))
	self._updateAttempts = math.max(1, math.floor(tonumber(options.updateAttempts) or DEFAULT_UPDATE_ATTEMPTS))
	self._acquireTimeoutSeconds = math.max(1, tonumber(options.acquireTimeoutSeconds) or DEFAULT_ACQUIRE_TIMEOUT_SECONDS)
	self._leaseSeconds = math.max(30, math.floor(tonumber(options.leaseSeconds) or DEFAULT_LEASE_SECONDS))
	self._schemaVersion = math.max(1, math.floor(tonumber(options.schemaVersion) or DEFAULT_SCHEMA_VERSION))
	return self
end

function ProfileLease:GetOwnerId(): string
	return self._ownerId
end

function ProfileLease:Read(dataStore, key: string)
	local lastError = nil
	for attempt = 1, self._readAttempts do
		local ok, result = pcall(function()
			return dataStore:GetAsync(key)
		end)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < self._readAttempts then
			retryDelay(attempt)
		end
	end
	return false, lastError
end

function ProfileLease:Acquire(key: string, seedProfile)
	local deadline = os.clock() + self._acquireTimeoutSeconds
	local lastError = nil
	local blockedOwner = nil

	repeat
		for attempt = 1, self._updateAttempts do
			local applied = false
			local corrupt = false
			blockedOwner = nil

			local ok, result = pcall(function()
				return self._store:UpdateAsync(key, function(current)
					applied = false
					corrupt = false
					blockedOwner = nil
					if current ~= nil and typeof(current) ~= "table" then
						corrupt = true
						return current
					end

					local profile = current or deepCopy(seedProfile)
					if typeof(profile) ~= "table" then
						profile = {}
					end

					local now = os.time()
					local meta = normalizeMeta(profile, self._schemaVersion)
					local owner = typeof(meta.sessionOwner) == "string" and meta.sessionOwner or nil
					local expiresAt = math.floor(tonumber(meta.leaseExpiresAt) or 0)

					if owner and owner ~= self._ownerId and expiresAt > now then
						blockedOwner = owner
						return current
					end

					meta.sessionOwner = self._ownerId
					meta.leaseExpiresAt = now + self._leaseSeconds
					meta.lastPlaceId = game.PlaceId
					meta.updatedAt = now
					applied = true
					return profile
				end)
			end)

			if ok and applied and typeof(result) == "table" then
				return true, result
			end
			if corrupt then
				return false, "CorruptProfileValue"
			end
			if ok and blockedOwner then
				break
			end

			lastError = result
			if attempt < self._updateAttempts then
				retryDelay(attempt)
			end
		end

		if blockedOwner and os.clock() < deadline then
			task.wait(0.75 + (math.random() * 0.25))
		end
	until not blockedOwner or os.clock() >= deadline

	if blockedOwner then
		return false, "ProfileLocked"
	end
	return false, lastError or "AcquireFailed"
end

function ProfileLease:Save(key: string, snapshot)
	if typeof(snapshot) ~= "table" then
		return false, "InvalidSnapshot"
	end

	local lastError = nil
	for attempt = 1, self._updateAttempts do
		local applied = false
		local lostSession = false
		local missingProfile = false
		local nextRevision = nil

		local ok, result = pcall(function()
			return self._store:UpdateAsync(key, function(current)
				applied = false
				lostSession = false
				missingProfile = false
				if typeof(current) ~= "table" then
					missingProfile = true
					return current
				end

				local currentMeta = normalizeMeta(current, self._schemaVersion)
				if currentMeta.sessionOwner ~= self._ownerId then
					lostSession = true
					return current
				end

				local nextProfile = deepCopy(snapshot)
				local nextMeta = normalizeMeta(nextProfile, self._schemaVersion)
				local now = os.time()
				nextRevision = math.max(
					math.floor(tonumber(currentMeta.revision) or 0),
					math.floor(tonumber(nextMeta.revision) or 0)
				) + 1
				nextMeta.revision = nextRevision
				nextMeta.sessionOwner = self._ownerId
				nextMeta.leaseExpiresAt = now + self._leaseSeconds
				nextMeta.lastPlaceId = game.PlaceId
				nextMeta.updatedAt = now
				applied = true
				return nextProfile
			end)
		end)

		if ok and applied and typeof(result) == "table" then
			return true, result, nextRevision
		end
		if lostSession then
			return false, "SessionLost"
		end
		if missingProfile then
			return false, "ProfileMissing"
		end

		lastError = result
		if attempt < self._updateAttempts then
			retryDelay(attempt)
		end
	end

	return false, lastError or "SaveFailed"
end

function ProfileLease:Renew(key: string)
	local lastError = nil
	for attempt = 1, self._updateAttempts do
		local renewed = false
		local lostSession = false
		local missingProfile = false
		local ok, result = pcall(function()
			return self._store:UpdateAsync(key, function(current)
				renewed = false
				lostSession = false
				missingProfile = false
				if typeof(current) ~= "table" then
					missingProfile = true
					return current
				end
				local meta = normalizeMeta(current, self._schemaVersion)
				if meta.sessionOwner ~= self._ownerId then
					lostSession = true
					return current
				end
				local now = os.time()
				meta.leaseExpiresAt = now + self._leaseSeconds
				meta.lastPlaceId = game.PlaceId
				meta.updatedAt = now
				renewed = true
				return current
			end)
		end)

		if ok and renewed then return true, result end
		if lostSession then return false, "SessionLost" end
		if missingProfile then return false, "ProfileMissing" end
		lastError = result
		if attempt < self._updateAttempts then retryDelay(attempt) end
	end
	return false, lastError or "RenewFailed"
end

function ProfileLease:Release(key: string, snapshot)
	local saved, savedResult = self:Save(key, snapshot)
	if not saved then
		return false, savedResult
	end

	local lastError = nil
	for attempt = 1, self._updateAttempts do
		local released = false
		local lostSession = false
		local ok, result = pcall(function()
			return self._store:UpdateAsync(key, function(current)
				released = false
				lostSession = false
				if typeof(current) ~= "table" then
					released = true
					return current
				end

				local meta = normalizeMeta(current, self._schemaVersion)
				if meta.sessionOwner ~= self._ownerId then
					lostSession = true
					return current
				end

				meta.lastSessionOwner = self._ownerId
				meta.sessionOwner = nil
				meta.leaseExpiresAt = 0
				meta.updatedAt = os.time()
				released = true
				return current
			end)
		end)

		if ok and released then
			return true, result
		end
		if lostSession then
			return false, "SessionLost"
		end
		lastError = result
		if attempt < self._updateAttempts then
			retryDelay(attempt)
		end
	end

	return false, lastError or "ReleaseFailed"
end

return ProfileLease
