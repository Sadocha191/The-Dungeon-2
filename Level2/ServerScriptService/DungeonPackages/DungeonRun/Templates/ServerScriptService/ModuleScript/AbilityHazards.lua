local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript")
assert(moduleFolder and moduleFolder:IsA("Folder"), "[AbilityHazards] ServerScriptService.ModuleScript folder is required")

local function requireModule(name: string)
	local module = moduleFolder:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "[AbilityHazards] " .. name .. " ModuleScript is required")
	return require(module)
end

local AbilityGeometry = requireModule("AbilityGeometry")
local DamageService = requireModule("DamageService")

local AbilityHazards = {}

local DEFAULT_COLOR = Color3.fromRGB(255, 132, 82)
local activeZones = {}

local function anyPlayersAlive(): boolean
	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and plr:GetAttribute("RunEnded") ~= true then
			return true
		end
	end
	return false
end

local function getAliveCombatPlayers()
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Parent and plr:GetAttribute("RunEnded") ~= true then
			local character = plr.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and hrp and humanoid.Health > 0 then
				out[#out + 1] = {
					player = plr,
					humanoid = humanoid,
					hrp = hrp,
				}
			end
		end
	end
	return out
end

local function makeHazardPart(parent: Instance, center: Vector3, radius: number, duration: number, color: Color3?)
	local disk = Instance.new("Part")
	disk.Name = "TelegraphCircle"
	disk.Anchored = true
	disk.CanCollide = false
	disk.CanTouch = false
	disk.CanQuery = false
	disk.Material = Enum.Material.Neon
	disk.CastShadow = false
	disk.Color = color or DEFAULT_COLOR
	disk.Transparency = 0.30
	disk.Shape = Enum.PartType.Cylinder
	disk.Size = Vector3.new(radius * 2, 0.12, radius * 2)
	disk.CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disk.Parent = parent
	TweenService:Create(disk, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Transparency = 0.75,
		Size = Vector3.new(radius * 2.18, 0.12, radius * 2.18),
	}):Play()
	Debris:AddItem(disk, duration + 0.2)
	return disk
end

local function applyHazardDamage(player: Player, amount: number, context)
	amount = math.max(1, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return
	end

	local damageContext = nil
	if typeof(context) == "table" then
		damageContext = {
			sourceType = context.sourceType,
		}
		if context.abilityId ~= nil then
			damageContext.abilityId = context.abilityId
		end
	end

	DamageService.Apply(player, amount, damageContext)
end

local function damagePlayersInRadius(center: Vector3, radius: number, damage: number, context)
	for _, info in ipairs(getAliveCombatPlayers()) do
		if AbilityGeometry.IsPointInRadius(info.hrp.Position, center, radius) then
			applyHazardDamage(info.player, damage, context)
		end
	end
end

local function cleanupRecord(record, destroyPart: boolean)
	activeZones[record] = nil
	record.cancelled = true
	if destroyPart and record.part and record.part.Parent then
		record.part:Destroy()
	end
end

function AbilityHazards.CreateZone(options)
	assert(type(options) == "table", "[AbilityHazards] CreateZone expects options")
	local center = options.center
	assert(typeof(center) == "Vector3", "[AbilityHazards] center must be a Vector3")

	local radius = math.max(0, tonumber(options.radius) or 0)
	local duration = tonumber(options.duration) or 0
	local tickRate = tonumber(options.tickRate) or 0.5
	local damage = options.damage
	local parent = options.parent or workspace

	local record = {
		cancelled = false,
		part = makeHazardPart(parent, center, radius, duration, options.color),
	}
	record.part.Transparency = 0.48
	activeZones[record] = true

	task.spawn(function()
		local remaining = math.max(0.05, duration)
		while remaining > 0 do
			if record.cancelled then
				return
			end
			local runStarted = options.runStarted
			if runStarted and runStarted.Value ~= true then
				cleanupRecord(record, true)
				return
			end
			if not anyPlayersAlive() then
				cleanupRecord(record, false)
				return
			end
			local pauseState = options.pauseState
			if pauseState and pauseState.Value then
				task.wait(0.1)
			else
				damagePlayersInRadius(center, radius, damage, options.context)
				local step = math.min(math.max(0.05, tickRate), remaining)
				task.wait(step)
				remaining -= step
			end
		end
		cleanupRecord(record, false)
	end)

	return record
end

function AbilityHazards.Cancel(record)
	if record and activeZones[record] then
		cleanupRecord(record, true)
	end
end

function AbilityHazards.CancelAll()
	for record in pairs(activeZones) do
		cleanupRecord(record, true)
	end
end

function AbilityHazards.GetActiveCount(): number
	local count = 0
	for _ in pairs(activeZones) do
		count += 1
	end
	return count
end

return AbilityHazards
