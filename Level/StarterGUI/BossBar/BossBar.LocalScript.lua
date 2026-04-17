local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local gui = script.Parent

local function findNamedChildOfClass(parent: Instance, name: string, className: string)
	local direct = parent:FindFirstChild(name)
	if direct and direct:IsA(className) then
		return direct
	end

	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name and child:IsA(className) then
			return child
		end
	end

	return nil
end

local function findOptionalText(root: Instance, names: { string })
	for _, name in ipairs(names) do
		local candidate = root:FindFirstChild(name, true)
		if candidate and (candidate:IsA("TextLabel") or candidate:IsA("TextButton") or candidate:IsA("TextBox")) then
			return candidate
		end
	end

	return nil
end

local bossBar = findNamedChildOfClass(gui, "BossBar", "Frame")
assert(bossBar, "BossBar frame was not found")

local fill = bossBar:WaitForChild("Fill")
local crop = fill:WaitForChild("Crop")
assert(crop:IsA("Frame"), "BossBar Crop must be a Frame")

local nameLabel = findOptionalText(bossBar, { "BossName", "Name", "Title", "EnemyName" })
local hpLabel = findOptionalText(bossBar, { "HP", "Hp", "HPText", "HpText", "Health", "HealthText" })

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local batchEvent = remotes:WaitForChild("NpcBatchEvent")
local syncRequestEvent = remotes:WaitForChild("NpcSyncRequest")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local NpcShared = require(moduleFolder:WaitForChild("NpcShared"))
local ATTR = NpcShared.Attributes

local BOSSBAR_VISIBLE_POSITION = UDim2.new(0.5, 0, 0.103, 0)
local BOSSBAR_HIDDEN_POSITION = UDim2.new(0.5, 0, -0.12, 0)
local BOSSBAR_TWEEN_INFO = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BOSSBAR_MIN_CROP_SCALE = 0.052
local BOSSBAR_MAX_CROP_SCALE = 1
local BOSSBAR_CROP_SMOOTH_SPEED = 14
local TARGET_TIMEOUT = math.max(0.5, (NpcShared.BatchRate or 0.1) * 8)

local trackedTargets = {}
local activeTargetId = nil
local activeTween = nil
local activeTweenToken = 0
local desiredVisible = false
local currentCropScale = BOSSBAR_MIN_CROP_SCALE
local targetCropScale = BOSSBAR_MIN_CROP_SCALE

local function formatDisplayName(rawName: any): string
	local text = tostring(rawName or "Enemy")
	text = string.gsub(text, "_", " ")
	text = string.gsub(text, "(%l)(%u)", "%1 %2")
	return text
end

local function resolveDisplayName(target): string
	local model = target and target.model
	if not model then
		return "Enemy"
	end

	local rawName = model:GetAttribute("DisplayName")
		or model:GetAttribute(ATTR.MobType)
		or model:GetAttribute(ATTR.Type)
		or model.Name
	return formatDisplayName(rawName)
end

local function resolveHealth(target): (number, number)
	local hp = tonumber(target and target.hp)
	local maxHp = tonumber(target and target.maxHp)

	hp = math.max(0, hp or 0)
	maxHp = math.max(1, maxHp or 1)
	return hp, maxHp
end

local function computeCropScale(target): number
	local hp, maxHp = resolveHealth(target)
	local hpPercent = math.clamp(hp / maxHp, 0, 1)
	return BOSSBAR_MIN_CROP_SCALE + ((BOSSBAR_MAX_CROP_SCALE - BOSSBAR_MIN_CROP_SCALE) * hpPercent)
end

local function getTargetPriority(target): number
	if target and target.isBoss then
		return 2
	end
	if target and target.isElite then
		return 1
	end
	return 0
end

local function setCropScale(scaleX: number)
	local clamped = math.clamp(scaleX, BOSSBAR_MIN_CROP_SCALE, BOSSBAR_MAX_CROP_SCALE)
	crop.Size = UDim2.new(clamped, 0, 1, 0)
end

local function setText(target)
	if nameLabel then
		nameLabel.Text = target and resolveDisplayName(target) or ""
	end

	if hpLabel then
		if target then
			local hp, maxHp = resolveHealth(target)
			hpLabel.Text = ("%d / %d"):format(math.floor(hp + 0.5), math.floor(maxHp + 0.5))
		else
			hpLabel.Text = ""
		end
	end
end

local function cancelActiveTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function playVisibilityTween(shouldShow: boolean)
	local goalPosition = shouldShow and BOSSBAR_VISIBLE_POSITION or BOSSBAR_HIDDEN_POSITION

	if desiredVisible == shouldShow and activeTween == nil and bossBar.Position == goalPosition then
		return
	end

	if desiredVisible == shouldShow and activeTween ~= nil then
		return
	end

	desiredVisible = shouldShow
	activeTweenToken += 1
	local tweenToken = activeTweenToken

	cancelActiveTween()

	if bossBar.Position == goalPosition then
		return
	end

	local tween = TweenService:Create(bossBar, BOSSBAR_TWEEN_INFO, {
		Position = goalPosition,
	})
	activeTween = tween

	tween.Completed:Connect(function(playbackState)
		if activeTween ~= tween or activeTweenToken ~= tweenToken then
			return
		end

		activeTween = nil
		if playbackState == Enum.PlaybackState.Completed then
			bossBar.Position = goalPosition
		end
	end)

	tween:Play()
end

local function resolveFlags(model: Model?, existing)
	local isBoss = false
	local isElite = false

	if model then
		isBoss = model:GetAttribute(ATTR.IsBoss) == true or string.sub(model.Name, 1, 5) == "Boss_"
		isElite = model:GetAttribute(ATTR.IsElite) == true
	end

	if existing then
		if not isBoss then
			isBoss = existing.isBoss == true
		end
		if not isElite then
			isElite = existing.isElite == true
		end
	end

	return isElite, isBoss
end

local function isValidTarget(target, now: number): boolean
	if not target then
		return false
	end

	local model = target.model
	if not model or not model.Parent then
		return false
	end

	if not target.isElite and not target.isBoss then
		return false
	end

	if target.dead == true or target.despawned == true then
		return false
	end

	if NpcShared.IsDeadState(target.state) then
		return false
	end

	if (now - (target.lastSeen or 0)) > TARGET_TIMEOUT then
		return false
	end

	local hp, maxHp = resolveHealth(target)
	return maxHp > 0 and hp > 0
end

local function resolveActiveTarget(now: number)
	local current = activeTargetId and trackedTargets[activeTargetId] or nil
	local best = isValidTarget(current, now) and current or nil
	local bestPriority = getTargetPriority(best)

	for id, target in pairs(trackedTargets) do
		if not isValidTarget(target, now) then
			if (now - (target.lastSeen or 0)) > TARGET_TIMEOUT or target.dead == true or target.despawned == true then
				trackedTargets[id] = nil
			end
			continue
		end

		local priority = getTargetPriority(target)
		if not best or priority > bestPriority then
			best = target
			bestPriority = priority
		elseif not current and priority == bestPriority and (target.lastSeen or 0) > (best.lastSeen or 0) then
			best = target
		end
	end

	return best
end

local function updateActiveTarget(now: number)
	local target = resolveActiveTarget(now)
	local nextTargetId = target and target.id or nil
	local switchedTarget = activeTargetId ~= nextTargetId

	activeTargetId = nextTargetId

	if target then
		targetCropScale = computeCropScale(target)
		if switchedTarget then
			currentCropScale = targetCropScale
		end
		setText(target)
		playVisibilityTween(true)
		return
	end

	targetCropScale = BOSSBAR_MIN_CROP_SCALE
	if switchedTarget then
		setText(nil)
	end
	playVisibilityTween(false)
end

bossBar.Position = BOSSBAR_HIDDEN_POSITION
setCropScale(BOSSBAR_MIN_CROP_SCALE)
setText(nil)
gui.ResetOnSpawn = false

batchEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local items = payload.items
	if typeof(items) ~= "table" then
		return
	end

	local fullSnapshot = payload.full == true
	local seen = fullSnapshot and {} or nil
	local now = os.clock()

	for _, item in ipairs(items) do
		if typeof(item) ~= "table" or item.id == nil then
			continue
		end

		local id = tostring(item.id)
		local existing = trackedTargets[id]
		local model = existing and existing.model or nil

		if typeof(item.model) == "Instance" and item.model:IsA("Model") then
			model = item.model
		end

		local isElite, isBoss = resolveFlags(model, existing)
		if seen then
			seen[id] = true
		end

		if not isElite and not isBoss then
			trackedTargets[id] = nil
			continue
		end

		local target = existing or {
			id = id,
		}

		target.model = model
		target.isElite = isElite
		target.isBoss = isBoss
		target.state = typeof(item.state) == "string" and item.state or target.state
		target.hp = typeof(item.hp) == "number" and item.hp or target.hp
		target.maxHp = typeof(item.maxHp) == "number" and item.maxHp or target.maxHp
		target.dead = item.dead == true
		target.despawned = item.despawned == true
		target.lastSeen = now

		if target.dead or target.despawned or NpcShared.IsDeadState(target.state) then
			trackedTargets[id] = nil
		else
			trackedTargets[id] = target
		end
	end

	if seen then
		for id in pairs(trackedTargets) do
			if not seen[id] then
				trackedTargets[id] = nil
			end
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	updateActiveTarget(os.clock())

	local alpha = 1 - math.exp(-dt * BOSSBAR_CROP_SMOOTH_SPEED)
	currentCropScale += (targetCropScale - currentCropScale) * alpha
	if math.abs(currentCropScale - targetCropScale) <= 0.001 then
		currentCropScale = targetCropScale
	end

	setCropScale(currentCropScale)
end)

task.defer(function()
	syncRequestEvent:FireServer()
end)
