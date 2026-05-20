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
local ErrorReporter = require(servicesFolder:WaitForChild("ErrorReporter"))

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
		rawMessage = payload.rawMessage,
		message = payload.message,
		stack = payload.stack,
		stackTrace = payload.stackTrace,
		system = payload.system,
		scriptName = payload.scriptName,
		lineNumber = payload.lineNumber,
		runMode = payload.runMode,
		level = payload.level,
		wave = payload.wave,
		phase = payload.phase,
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

local errorReporterTest = _G.ErrorReporterTest or _G.ErrorWebhookTest or {}
_G.ErrorReporterTest = errorReporterTest
_G.ErrorWebhookTest = errorReporterTest

function errorReporterTest.TriggerServer(rawToken)
	local token = normalizeTriggerToken(rawToken) or buildTestToken("server")
	ReplicatedStorage:SetAttribute(SERVER_TEST_ATTRIBUTE, token)
	return token
end

function errorReporterTest.TriggerClient(target, rawToken)
	local testPlayer = triggerClientTest(target, rawToken)
	return testPlayer and testPlayer.Name or nil
end

ErrorReporter.WarnIfHttpDisabled()

reportClientErrorRemote.OnServerEvent:Connect(function(player, payload)
	local sanitizedPayload = sanitizeClientPayload(payload)
	if not sanitizedPayload then
		return
	end

	local ok, err = pcall(function()
		ErrorReporter.ReportClientError(player, sanitizedPayload)
	end)

	if not ok then
		warn("[ErrorBootstrap] Failed to process client error report:", err)
	end
end)

ScriptContext.Error:Connect(function(message, stackTrace, scriptInstance)
	local system = "Server"
	local extraContext = {}

	if typeof(scriptInstance) == "Instance" then
		system = scriptInstance.Name
		extraContext.ScriptPath = scriptInstance:GetFullName()
		extraContext.ClassName = scriptInstance.ClassName
	end

	local ok, err = pcall(function()
		ErrorReporter.ReportError(message, stackTrace, {
			sourceType = "server",
			errorType = "ServerError",
			system = system,
			scriptInstance = scriptInstance,
			scriptName = typeof(scriptInstance) == "Instance" and scriptInstance.Name or nil,
			extra = extraContext,
		})
	end)

	if not ok then
		warn("[ErrorBootstrap] Failed to process server error report:", err)
	end
end)
