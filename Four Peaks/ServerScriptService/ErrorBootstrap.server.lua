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
