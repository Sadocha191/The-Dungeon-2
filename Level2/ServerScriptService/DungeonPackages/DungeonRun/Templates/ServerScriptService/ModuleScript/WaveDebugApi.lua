local RunService = game:GetService("RunService")

local WaveDebugApi = {}

local DEBUG_GLOBALS = {
	"DebugAreAutoMobSpawnsEnabled",
	"DebugSetAutoMobSpawnsEnabled",
	"DebugForceSpawnMob",
	"DebugForceEliteSpawn",
	"DebugForceMiniBossSpawn",
	"DebugForceBossSpawn",
	"DebugClearEnemies",
	"DebugDumpNpcLifecycle",
	"DebugRunNpcLifecycleTest",
	"DebugGetNpcLifecycleTestReport",
}

function WaveDebugApi.Register(api)
	assert(RunService:IsStudio(), "[WaveDebugApi] Debug API can only be registered in Studio")
	assert(type(api) == "table", "[WaveDebugApi] api table is required")
	_G.DebugAreAutoMobSpawnsEnabled = api.areAutoMobSpawnsEnabled
	_G.DebugSetAutoMobSpawnsEnabled = api.setAutoMobSpawnsEnabled
	_G.DebugForceSpawnMob = api.forceSpawnMob
	_G.DebugForceEliteSpawn = api.forceEliteSpawn
	_G.DebugForceMiniBossSpawn = api.forceMiniBossSpawn
	_G.DebugForceBossSpawn = api.forceBossSpawn
	_G.DebugClearEnemies = api.clearEnemies
	_G.DebugDumpNpcLifecycle = api.dumpNpcLifecycle
	_G.DebugRunNpcLifecycleTest = api.runNpcLifecycleTest
	_G.DebugGetNpcLifecycleTestReport = api.getNpcLifecycleTestReport
end

function WaveDebugApi.Unregister()
	for _, name in ipairs(DEBUG_GLOBALS) do
		_G[name] = nil
	end
end

return WaveDebugApi
