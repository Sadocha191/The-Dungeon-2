local NpcAssetSanitizer = {}

NpcAssetSanitizer.SANITIZED_ATTRIBUTE = "NpcAssetSanitized"
NpcAssetSanitizer.REMOVED_ATTRIBUTE = "NpcAssetSanitizerRemoved"

local EDITOR_ARTIFACT_CONTAINER_NAMES = {
	animsaves = true,
	animationsaves = true,
	savedanimations = true,
	animationeditordata = true,
	moonanimator = true,
	moonanimator2 = true,
	moonanimatorfiles = true,
	keyframeeditor = true,
	keyframesequences = true,
	posedata = true,
}

local HEAVY_PROFILE_LIMITS = {
	descendants = 600,
	baseParts = 120,
	meshParts = 80,
	bones = 220,
	cframeValues = 100,
}

local function normalizeName(value: any): string
	return string.lower(tostring(value or "")):gsub("[%s_%-%.%/]", "")
end

local function isEditorArtifactContainer(instance: Instance): boolean
	if not (instance:IsA("Folder") or instance:IsA("Model") or instance:IsA("Configuration")) then
		return false
	end
	return EDITOR_ARTIFACT_CONTAINER_NAMES[normalizeName(instance.Name)] == true
end

function NpcAssetSanitizer.GetTypeName(model: Model): string
	local rawName = model:GetAttribute("MobType")
		or model:GetAttribute("NpcType")
		or model:GetAttribute("Type")
		or model.Name
	return tostring(rawName or "Unknown")
end

function NpcAssetSanitizer.SanitizeModel(model: Model): ({[string]: number}?, boolean)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return nil, false
	end
	if model:GetAttribute(NpcAssetSanitizer.SANITIZED_ATTRIBUTE) == true then
		return nil, false
	end

	local descendants = model:GetDescendants()
	local artifactRoots = {}
	for _, descendant in ipairs(descendants) do
		if isEditorArtifactContainer(descendant) then
			artifactRoots[#artifactRoots + 1] = descendant
		end
	end

	local removedContainers = 0
	for _, artifactRoot in ipairs(artifactRoots) do
		if artifactRoot.Parent then
			removedContainers += 1
			artifactRoot:Destroy()
		end
	end

	local removedClips = 0
	for _, descendant in ipairs(descendants) do
		if descendant.Parent and (descendant:IsA("KeyframeSequence") or descendant:IsA("Pose")) then
			removedClips += 1
			descendant:Destroy()
		end
	end

	local removedTotal = removedContainers + removedClips
	model:SetAttribute(NpcAssetSanitizer.SANITIZED_ATTRIBUTE, true)
	model:SetAttribute(NpcAssetSanitizer.REMOVED_ATTRIBUTE, removedTotal)

	return {
		containers = removedContainers,
		clips = removedClips,
		total = removedTotal,
	}, removedTotal > 0
end

function NpcAssetSanitizer.ProfileModel(model: Model): {[string]: number}
	local profile = {
		descendants = 0,
		baseParts = 0,
		meshParts = 0,
		bones = 0,
		cframeValues = 0,
		animations = 0,
		motor6Ds = 0,
	}

	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return profile
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		profile.descendants += 1
		if descendant:IsA("BasePart") then
			profile.baseParts += 1
		end
		if descendant:IsA("MeshPart") then
			profile.meshParts += 1
		elseif descendant:IsA("Bone") then
			profile.bones += 1
		elseif descendant:IsA("CFrameValue") then
			profile.cframeValues += 1
		elseif descendant:IsA("Animation") then
			profile.animations += 1
		elseif descendant:IsA("Motor6D") then
			profile.motor6Ds += 1
		end
	end

	return profile
end

function NpcAssetSanitizer.IsHeavyProfile(profile: {[string]: number}): (boolean, {string})
	local reasons = {}
	for metric, limit in pairs(HEAVY_PROFILE_LIMITS) do
		local value = tonumber(profile[metric]) or 0
		if value >= limit then
			reasons[#reasons + 1] = string.format("%s=%d", metric, value)
		end
	end
	table.sort(reasons)
	return #reasons > 0, reasons
end

function NpcAssetSanitizer.DescribeProfile(profile: {[string]: number}): string
	return string.format(
		"descendants=%d baseParts=%d meshParts=%d bones=%d cframeValues=%d animations=%d motor6Ds=%d",
		profile.descendants or 0,
		profile.baseParts or 0,
		profile.meshParts or 0,
		profile.bones or 0,
		profile.cframeValues or 0,
		profile.animations or 0,
		profile.motor6Ds or 0
	)
end

return NpcAssetSanitizer
