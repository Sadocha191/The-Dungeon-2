-- RemotesInit.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name: string)
	local ev = folder:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	if ev then ev:Destroy() end

	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = folder
	return ev
end

-- Multi shared XP/level + upgrades
ensureRemoteEvent("PartyLevelUp")        -- server -> all clients
ensureRemoteEvent("PartyUpgradePicked")  -- client -> server (wybrano upgrade)
ensureRemoteEvent("PartyXPUpdate")       -- server -> all clients (xp/level update opcjonalnie)

-- Floating damage numbers
ensureRemoteEvent("DamageIndicatorEvent")  -- server -> all clients (pos, amount, crit)
ensureRemoteEvent("PickupIndicatorEvent")  -- server -> client (kind, amount)
ensureRemoteEvent("PickupToastEvent")      -- server -> client (bottom-left item toasts)
ensureRemoteEvent("DropVisualEvent")       -- server -> all clients (drop spawn/update/remove sync)
ensureRemoteEvent("DropSyncRequest")       -- client -> server (late join / respawn sync)
-- Loading gate (client preload handshake)
ensureRemoteEvent("ClientReady")          -- client -> server (loaded/preloaded)
ensureRemoteEvent("ClientWorldLoaded")    -- client -> server (world streamed + textures preloaded)
-- Pause menu
ensureRemoteEvent("PauseMenuEvent")       -- client -> server (pause/resume toggle)
ensureRemoteEvent("TeleportStatus")       -- server -> client (teleport overlay state)

-- Weapon VFX swing (server -> client)
ensureRemoteEvent("WeaponSwingVFX")
ensureRemoteEvent("SpellVFXEvent")        -- orbit + transient spell visuals
-- WeaponEvent (client -> server) [legacy/manual]
ensureRemoteEvent("WeaponEvent")
-- NPC presentation batches (server -> client)
ensureRemoteEvent("NpcBatchEvent")
ensureRemoteEvent("NpcSyncRequest")
