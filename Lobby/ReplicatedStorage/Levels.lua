-- MODULE: Levels.lua
-- GDZIE: ReplicatedStorage/Levels.lua (ModuleScript)
-- CO: Lista poziomów do teleportu z lobby (rozszerzalna).

local Levels = {}

Levels.List = {
	{
		key = "Level1",
		name = "Level 1",
		placeId = 82864046258949,
	},
}

function Levels.GetAll(): {any}
	local out = table.create(#Levels.List)
	for i, entry in ipairs(Levels.List) do
		out[i] = entry
	end
	return out
end

function Levels.GetByKey(key: string): any
	for _, entry in ipairs(Levels.List) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

return Levels
