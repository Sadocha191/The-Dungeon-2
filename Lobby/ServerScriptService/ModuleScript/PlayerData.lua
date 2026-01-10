-- PlayerData.lua
-- Fasada do danych gracza: Get/MarkDirty. Zero DataStoreService tutaj.

local PlayerStateStore = require(script.Parent:WaitForChild("PlayerStateStore"))

local PlayerData = {}

function PlayerData.Get(player: Player)
	return PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
end

function PlayerData.MarkDirty(player: Player, reason: string?)
	PlayerStateStore.MarkDirty(player, reason or "playerdata")
end

return PlayerData
