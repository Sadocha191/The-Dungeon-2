-- SCRIPT: LobbyAoEAttack.server.lua
-- GDZIE: ServerScriptService/LobbyAoEAttack.server.lua
-- ZMIANA: wizualizacja kuli AoE (krótko, przezroczysta) + DMG tylko dla Puppetów

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local AttackRequest = remotes:WaitForChild("AttackRequest")

local RADIUS = 8
local BASE_DAMAGE = 10
local COOLDOWN = 0.45

local lastAtk: {[number]: number} = {}

local function getHRP(player: Player): BasePart?
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getToolDamage(player: Player): number
	local char = player.Character
	if not char then return BASE_DAMAGE end
	for _, inst in ipairs(char:GetChildren()) do
		if inst:IsA("Tool") then
			local bd = inst:GetAttribute("BaseDamage")
			if typeof(bd) == "number" then
				return bd
			end
			break
		end
	end
	return BASE_DAMAGE
end

local function spawnAoESphere(pos: Vector3, radius: number)
	local p = Instance.new("Part")
	p.Name = "AoEVisual"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 0.75
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(120, 200, 255)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	Debris:AddItem(p, 0.15)
end

AttackRequest.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	local last = lastAtk[player.UserId] or 0
	if (now - last) < COOLDOWN then return end
	lastAtk[player.UserId] = now

	local hrp = getHRP(player)
	if not hrp then return end

	-- VFX (wszyscy widzą, bo to Part z serwera)
	spawnAoESphere(hrp.Position, RADIUS)

	-- DMG
	local dmg = getToolDamage(player)

	local parts = workspace:GetPartBoundsInRadius(hrp.Position, RADIUS)
	local hit: {[Humanoid]: boolean} = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not hit[hum] then
				-- NIE bij graczy
				if Players:GetPlayerFromCharacter(model) == nil then
					-- tylko Puppety
					if CollectionService:HasTag(model, "Puppet") then
						hit[hum] = true
						hum:TakeDamage(dmg)
					end
				end
			end
		end
	end
end)

print("[LobbyAoEAttack] Ready + VFX")
