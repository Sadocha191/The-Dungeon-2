local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local ServerScriptService = game:GetService("ServerScriptService")

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemoteEvent(parent, name)
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local servicesFolder = ensureFolder(ServerScriptService, "Services")
local ErrorReportService = require(servicesFolder:WaitForChild("ErrorReportService"))

local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
local reportClientErrorRemote = ensureRemoteEvent(remotesFolder, "ReportClientError")

local SERVER_TEST_ATTRIBUTE = "ErrorWebhookServerTestToken"
local CLIENT_TEST_ATTRIBUTE = "ErrorWebhookClientTestToken"
local CLIENT_TEST_TARGET_ATTRIBUTE = "ErrorWebhookClientTestUserId"

local function sanitizeClientPayload(payload)
	if typeof(payload) ~= "table" then
		return nil
	end

	return {
		message = payload.message,
		stack = payload.stack,
		system = payload.system,
		runMode = payload.runMode,
		level = payload.level,
		wave = payload.wave,
		extraContext = typeof(payload.extraContext) == "table" and payload.extraContext or nil,
	}
end

local function normalizeTriggerToken(value)
	local valueType = typeof(value)
	if valueType == "string" then
		local text = value:gsub("^%s+", ""):gsub("%s+$", "")
		return text ~= "" and text or nil
	end
	if valueType == "number" or valueType == "boolean" then
		return tostring(value)
	end
	return nil
end

local function buildTestToken(prefix)
	return string.format("%s-%d", prefix, math.floor(os.clock() * 1000 + 0.5))
end

local lastServerTestToken = nil

local function triggerServerTest(rawToken)
	local token = normalizeTriggerToken(rawToken)
	if not token or token == lastServerTestToken then
		return
	end

	lastServerTestToken = token

	task.defer(function()
		error(
			string.format(
				"[ErrorWebhookTest][Server][%s][PlaceId=%d][JobId=%s] token=%s",
				game.Name,
				game.PlaceId,
				game.JobId,
				token
			),
			0
		)
	end)
end

local function findPlayerForClientTest(target)
	if typeof(target) == "Instance" and target:IsA("Player") then
		return target
	end

	if typeof(target) == "number" then
		return Players:GetPlayerByUserId(target)
	end

	if typeof(target) == "string" then
		local maybeUserId = tonumber(target)
		if maybeUserId then
			return Players:GetPlayerByUserId(maybeUserId)
		end

		local wantedName = string.lower(target)
		for _, player in ipairs(Players:GetPlayers()) do
			if string.lower(player.Name) == wantedName then
				return player
			end
		end
	end

	return Players:GetPlayers()[1]
end

local function triggerClientTest(target, rawToken)
	local testPlayer = findPlayerForClientTest(target)
	local token = normalizeTriggerToken(rawToken) or buildTestToken("client")

	if testPlayer then
		ReplicatedStorage:SetAttribute(CLIENT_TEST_TARGET_ATTRIBUTE, testPlayer.UserId)
	else
		ReplicatedStorage:SetAttribute(CLIENT_TEST_TARGET_ATTRIBUTE, nil)
	end

	ReplicatedStorage:SetAttribute(CLIENT_TEST_ATTRIBUTE, token)
	return testPlayer
end

ReplicatedStorage:GetAttributeChangedSignal(SERVER_TEST_ATTRIBUTE):Connect(function()
	triggerServerTest(ReplicatedStorage:GetAttribute(SERVER_TEST_ATTRIBUTE))
end)

triggerServerTest(ReplicatedStorage:GetAttribute(SERVER_TEST_ATTRIBUTE))

_G.ErrorWebhookTest = _G.ErrorWebhookTest or {}

function _G.ErrorWebhookTest.TriggerServer(rawToken)
	local token = normalizeTriggerToken(rawToken) or buildTestToken("server")
	ReplicatedStorage:SetAttribute(SERVER_TEST_ATTRIBUTE, token)
	return token
end

function _G.ErrorWebhookTest.TriggerClient(target, rawToken)
	local testPlayer = triggerClientTest(target, rawToken)
	return testPlayer and testPlayer.Name or nil
end

reportClientErrorRemote.OnServerEvent:Connect(function(player, payload)
	local sanitizedPayload = sanitizeClientPayload(payload)
	if not sanitizedPayload then
		return
	end

	local ok, err = pcall(function()
		ErrorReportService.ReportClientError(player, sanitizedPayload)
	end)

	if not ok then
		warn("[ErrorBootstrap] Failed to process client error report:", err)
	end
end)

ScriptContext.Error:Connect(function(message, stackTrace, scriptInstance)
	local system = "N/A"
	local extraContext = {}

	if typeof(scriptInstance) == "Instance" then
		system = scriptInstance:GetFullName()
		extraContext.ScriptName = scriptInstance.Name
		extraContext.ClassName = scriptInstance.ClassName
	end

	local ok, err = pcall(function()
		ErrorReportService.ReportServerError(message, stackTrace, system, extraContext)
	end)

	if not ok then
		warn("[ErrorBootstrap] Failed to process server error report:", err)
	end
end)
