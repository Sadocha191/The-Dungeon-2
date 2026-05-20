const GITHUB_API_BASE_URL = "https://api.github.com";
const MAX_REQUEST_BYTES = 128 * 1024;
const MAX_MESSAGE_LENGTH = 2000;
const MAX_STACK_TRACE_LENGTH = 12000;
const MAX_CONTEXT_BLOCK_LENGTH = 4000;
const MAX_LABEL_LENGTH = 50;
const META_MARKER = "ROBLOX_ERROR_META";

class HttpError extends Error {
	constructor(status, message, details) {
		super(message);
		this.name = "HttpError";
		this.status = status;
		this.details = details;
	}
}

class GithubRateLimitError extends Error {
	constructor(message, retryAfterSeconds) {
		super(message);
		this.name = "GithubRateLimitError";
		this.retryAfterSeconds = retryAfterSeconds;
	}
}

class GithubApiError extends Error {
	constructor(message, status, details) {
		super(message);
		this.name = "GithubApiError";
		this.status = status;
		this.details = details;
	}
}

function logInfo(event, data = {}) {
	console.log(`[roblox-error-bridge] ${event}`, data);
}

function logWarn(event, data = {}) {
	console.warn(`[roblox-error-bridge] ${event}`, data);
}

function logError(event, data = {}) {
	console.error(`[roblox-error-bridge] ${event}`, data);
}

function jsonResponse(status, payload, headers = {}) {
	return new Response(JSON.stringify(payload, null, 2), {
		status,
		headers: {
			"content-type": "application/json; charset=utf-8",
			"cache-control": "no-store",
			...headers,
		},
	});
}

function collapseWhitespace(value) {
	return String(value ?? "")
		.replace(/\r\n/g, "\n")
		.replace(/\r/g, "\n")
		.replace(/\s+/g, " ")
		.trim();
}

function truncate(value, maxLength) {
	const normalized = collapseWhitespace(value);
	if (!normalized) {
		return "";
	}
	if (normalized.length <= maxLength) {
		return normalized;
	}
	if (maxLength <= 3) {
		return normalized.slice(0, maxLength);
	}
	return `${normalized.slice(0, maxLength - 3)}...`;
}

function truncateMultiline(value, maxLength) {
	const normalized = String(value ?? "")
		.replace(/\r\n/g, "\n")
		.replace(/\r/g, "\n")
		.trim();
	if (!normalized) {
		return "";
	}
	if (normalized.length <= maxLength) {
		return normalized;
	}
	if (maxLength <= 3) {
		return normalized.slice(0, maxLength);
	}
	return `${normalized.slice(0, maxLength - 3)}...`;
}

function sanitizeCodeBlock(value) {
	return String(value ?? "").replace(/```/g, "'''");
}

function toPositiveInteger(value, fallback = 1) {
	const numeric = Number(value);
	if (!Number.isFinite(numeric) || numeric <= 0) {
		return fallback;
	}
	return Math.max(1, Math.floor(numeric));
}

function normalizeTimestamp(value, fallback) {
	const normalized = collapseWhitespace(value);
	if (!normalized) {
		return fallback;
	}
	const parsed = Date.parse(normalized);
	if (Number.isNaN(parsed)) {
		return fallback;
	}
	return new Date(parsed).toISOString();
}

function timingSafeEqual(left, right) {
	if (typeof left !== "string" || typeof right !== "string") {
		return false;
	}

	const encoder = new TextEncoder();
	const leftBytes = encoder.encode(left);
	const rightBytes = encoder.encode(right);

	if (leftBytes.length !== rightBytes.length) {
		return false;
	}

	let result = 0;
	for (let index = 0; index < leftBytes.length; index += 1) {
		result |= leftBytes[index] ^ rightBytes[index];
	}

	return result === 0;
}

function getExpectedEnv(env) {
	return {
		GITHUB_TOKEN: env.GITHUB_TOKEN,
		GITHUB_OWNER: env.GITHUB_OWNER,
		GITHUB_REPO: env.GITHUB_REPO,
		ROBLOX_ERROR_SECRET: env.ROBLOX_ERROR_SECRET,
	};
}

function assertEnv(env) {
	const expectedEnv = getExpectedEnv(env);
	const missing = Object.entries(expectedEnv)
		.filter(([, value]) => !collapseWhitespace(value))
		.map(([key]) => key);

	if (missing.length > 0) {
		throw new HttpError(500, "Bridge environment is incomplete.", { missing });
	}

	return expectedEnv;
}

function getProvidedSecret(request) {
	const headerSecret = collapseWhitespace(request.headers.get("x-roblox-error-secret"));
	if (headerSecret) {
		return headerSecret;
	}

	const authorization = collapseWhitespace(request.headers.get("authorization"));
	if (authorization.toLowerCase().startsWith("bearer ")) {
		return authorization.slice(7).trim();
	}

	return "";
}

async function parseRequestBody(request) {
	const contentLength = Number(request.headers.get("content-length") || "0");
	if (Number.isFinite(contentLength) && contentLength > MAX_REQUEST_BYTES) {
		throw new HttpError(413, "Payload is too large.");
	}

	const rawBody = await request.text();
	if (rawBody.length > MAX_REQUEST_BYTES) {
		throw new HttpError(413, "Payload is too large.");
	}

	try {
		return JSON.parse(rawBody || "{}");
	} catch (error) {
		throw new HttpError(400, "Request body must be valid JSON.", { cause: String(error) });
	}
}

function sanitizeExtraContext(value) {
	if (!value || typeof value !== "object" || Array.isArray(value)) {
		return {};
	}

	const safe = {};
	for (const [key, entryValue] of Object.entries(value)) {
		const safeKey = truncate(key, 80);
		if (!safeKey) {
			continue;
		}

		if (entryValue === null || entryValue === undefined) {
			continue;
		}

		if (typeof entryValue === "object") {
			safe[safeKey] = truncateMultiline(JSON.stringify(entryValue), 400);
		} else {
			safe[safeKey] = truncateMultiline(String(entryValue), 400);
		}
	}

	return safe;
}

function normalizePayload(rawPayload) {
	if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
		throw new HttpError(400, "Payload must be a JSON object.");
	}

	const nowIso = new Date().toISOString();
	const errorCode = truncate(rawPayload.errorCode, 64);
	if (!errorCode) {
		throw new HttpError(400, "Payload is missing errorCode.");
	}

	const source = truncate(rawPayload.source || "roblox", 40).toLowerCase();
	if (source !== "roblox") {
		throw new HttpError(400, "Unsupported payload source.");
	}

	const context = rawPayload.context && typeof rawPayload.context === "object" ? rawPayload.context : {};
	const systemName = truncate(context.system || rawPayload.system || rawPayload.scriptName || "UnknownSystem", 120);
	const scriptName = truncate(rawPayload.scriptName || systemName || "UnknownScript", 120);
	const placeName = truncate(rawPayload.placeName || "Unknown", 120);
	const jobId = truncate(rawPayload.jobId || "N/A", 200);
	const sanitizedMessage = truncate(rawPayload.sanitizedMessage || rawPayload.message || "N/A", 1000);
	const message = truncateMultiline(rawPayload.message || "N/A", MAX_MESSAGE_LENGTH);
	const stackTrace = truncateMultiline(rawPayload.stackTrace || "N/A", MAX_STACK_TRACE_LENGTH);
	const player = rawPayload.player && typeof rawPayload.player === "object" ? rawPayload.player : {};
	const examplePlayerName = truncate(player.name || rawPayload.playerName || "N/A", 120);
	const playerUserId = player.userId != null ? String(player.userId) : rawPayload.playerUserId != null ? String(rawPayload.playerUserId) : "N/A";
	const firstSeen = normalizeTimestamp(rawPayload.firstSeen || rawPayload.serverTime, nowIso);
	const lastSeen = normalizeTimestamp(rawPayload.lastSeen || rawPayload.serverTime || firstSeen, firstSeen);
	const occurrenceCount = toPositiveInteger(rawPayload.occurrenceCount, 1);
	const lineNumber = Number.isFinite(Number(rawPayload.lineNumber)) ? Math.max(0, Math.floor(Number(rawPayload.lineNumber))) : null;
	const phase = truncate(context.phase || rawPayload.phase || "unknown", 60);
	const runMode = truncate(context.runMode || rawPayload.runMode || "N/A", 80);
	const level = truncate(context.level || rawPayload.level || "N/A", 120);
	const wave = truncate(context.wave || rawPayload.wave || "N/A", 80);

	return {
		source,
		game: truncate(rawPayload.game || "The Dungeon 2", 120),
		errorCode,
		errorType: truncate(rawPayload.errorType || "ServerError", 80),
		placeId: String(rawPayload.placeId || "unknown"),
		placeName,
		jobId,
		serverTime: normalizeTimestamp(rawPayload.serverTime, nowIso),
		firstSeen,
		lastSeen,
		scriptName,
		scriptFullName: truncate(rawPayload.scriptFullName || "N/A", 240),
		lineNumber,
		message,
		sanitizedMessage,
		stackTrace,
		occurrenceCount,
		player: {
			name: examplePlayerName,
			userId: truncate(playerUserId, 60),
		},
		context: {
			system: systemName,
			phase,
			runMode,
			level,
			wave,
			extra: sanitizeExtraContext(context.extra),
		},
	};
}

function inferPlaceLabel(payload) {
	const source = `${payload.placeName} ${payload.context.phase}`.toLowerCase();
	if (source.includes("level") || source.includes("poziom") || source.includes("combat")) {
		return "place:level";
	}
	if (source.includes("four peaks") || source.includes("cztery") || source.includes("lobby")) {
		return "place:lobby";
	}
	return truncate(`place:${payload.placeName.toLowerCase().replace(/\s+/g, "-")}`, MAX_LABEL_LENGTH);
}

function inferSystemLabel(payload) {
	return truncate(`system:${payload.context.system || payload.scriptName || "UnknownSystem"}`, MAX_LABEL_LENGTH);
}

function getDesiredLabels(payload) {
	const labels = [
		{
			name: "roblox-error",
			color: "B60205",
			description: "Automated Roblox runtime error reports",
		},
		{
			name: "auto-report",
			color: "1D76DB",
			description: "Created or updated automatically by the Roblox error bridge",
		},
		{
			name: inferPlaceLabel(payload),
			color: payload.placeName.toLowerCase().includes("level") ? "0E8A16" : "5319E7",
			description: `Roblox place label for ${payload.placeName}`,
		},
		{
			name: inferSystemLabel(payload),
			color: "FBCA04",
			description: `Roblox system label for ${payload.context.system || payload.scriptName}`,
		},
	];

	const uniqueByName = new Map();
	for (const label of labels) {
		if (label.name) {
			uniqueByName.set(label.name, label);
		}
	}

	return [...uniqueByName.values()];
}

function buildIssueTitle(payload) {
	return truncate(`[${payload.errorCode}] ${payload.scriptName} error in ${payload.placeName}`, 240);
}

function buildJobKey(payload) {
	return payload.jobId && payload.jobId !== "N/A"
		? `${payload.placeName}:${payload.jobId}`
		: `${payload.placeName}:unknown-job`;
}

function sumObjectValues(value) {
	return Object.values(value || {}).reduce((total, item) => total + toPositiveInteger(item, 0), 0);
}

function buildUpdatedMeta(existingMeta, payload) {
	const previousMeta = existingMeta && typeof existingMeta === "object" ? existingMeta : {};
	const perJobOccurrences = previousMeta.perJobOccurrences && typeof previousMeta.perJobOccurrences === "object"
		? { ...previousMeta.perJobOccurrences }
		: {};

	const jobKey = buildJobKey(payload);
	const previousJobCount = toPositiveInteger(perJobOccurrences[jobKey], 0);
	perJobOccurrences[jobKey] = Math.max(previousJobCount, payload.occurrenceCount);

	const totalOccurrences = sumObjectValues(perJobOccurrences);

	return {
		version: 1,
		errorCode: payload.errorCode,
		firstSeen: normalizeTimestamp(previousMeta.firstSeen || payload.firstSeen, payload.firstSeen),
		lastSeen: normalizeTimestamp(payload.lastSeen || payload.serverTime, payload.serverTime),
		totalOccurrences,
		perJobOccurrences,
		lastJobKey: jobKey,
		lastReportedOccurrenceCount: payload.occurrenceCount,
		lastPlaceName: payload.placeName,
		lastJobId: payload.jobId,
		lastScriptName: payload.scriptName,
	};
}

function escapeMetaComment(meta) {
	return `<!-- ${META_MARKER} ${JSON.stringify(meta)} -->`;
}

function parseMetaComment(issueBody) {
	const match = String(issueBody || "").match(new RegExp(`<!-- ${META_MARKER} ([\\s\\S]*?) -->`));
	if (!match) {
		return null;
	}

	try {
		return JSON.parse(match[1]);
	} catch (error) {
		logWarn("meta-parse-failed", { error: String(error) });
		return null;
	}
}

function buildIssueBody(payload, meta) {
	const contextBlock = truncateMultiline(
		JSON.stringify(
			{
				system: payload.context.system,
				phase: payload.context.phase,
				runMode: payload.context.runMode,
				level: payload.context.level,
				wave: payload.context.wave,
				extra: payload.context.extra,
			},
			null,
			2
		),
		MAX_CONTEXT_BLOCK_LENGTH
	);

	return [
		"# Automated Roblox Error Report",
		"",
		`- Error code: ${payload.errorCode}`,
		`- Error type: ${payload.errorType}`,
		`- Place: ${payload.placeName} (${payload.placeId})`,
		`- Script: ${payload.scriptName}`,
		`- System: ${payload.context.system}`,
		`- Line: ${payload.lineNumber ?? "N/A"}`,
		`- First seen: ${meta.firstSeen}`,
		`- Last seen: ${meta.lastSeen}`,
		`- Total tracked occurrences: ${meta.totalOccurrences}`,
		`- Latest reported occurrenceCount: ${payload.occurrenceCount}`,
		`- Example player: ${payload.player.name} (${payload.player.userId})`,
		`- JobId: ${payload.jobId}`,
		"",
		"## Message",
		"",
		"```text",
		sanitizeCodeBlock(payload.message),
		"```",
		"",
		"## Sanitized Message",
		"",
		"```text",
		sanitizeCodeBlock(payload.sanitizedMessage),
		"```",
		"",
		"## Stack Trace",
		"",
		"```text",
		sanitizeCodeBlock(payload.stackTrace),
		"```",
		"",
		"## Context",
		"",
		"```json",
		sanitizeCodeBlock(contextBlock),
		"```",
		"",
		escapeMetaComment(meta),
	].join("\n");
}

function buildUpdateComment(payload, meta) {
	return [
		"Automated Roblox error update.",
		"",
		`- Error code: ${payload.errorCode}`,
		`- Reported occurrenceCount for this server: ${payload.occurrenceCount}`,
		`- Total tracked occurrences: ${meta.totalOccurrences}`,
		`- Last seen: ${meta.lastSeen}`,
		`- Place: ${payload.placeName}`,
		`- JobId: ${payload.jobId}`,
	].join("\n");
}

function buildGithubHeaders(env, extraHeaders = {}) {
	return {
		authorization: `Bearer ${env.GITHUB_TOKEN}`,
		accept: "application/vnd.github+json",
		"user-agent": "td2-roblox-error-bridge/1.0",
		"x-github-api-version": "2022-11-28",
		...extraHeaders,
	};
}

function getRetryAfterSeconds(response) {
	const retryAfter = Number(response.headers.get("retry-after") || "0");
	if (Number.isFinite(retryAfter) && retryAfter > 0) {
		return retryAfter;
	}

	const resetAt = Number(response.headers.get("x-ratelimit-reset") || "0");
	if (Number.isFinite(resetAt) && resetAt > 0) {
		const deltaSeconds = Math.ceil(resetAt - Date.now() / 1000);
		return Math.max(deltaSeconds, 1);
	}

	return 60;
}

async function githubFetch(env, path, init = {}) {
	const url = `${GITHUB_API_BASE_URL}${path}`;
	const response = await fetch(url, {
		...init,
		headers: buildGithubHeaders(env, init.headers),
	});

	if (response.status === 429 || (response.status === 403 && response.headers.get("x-ratelimit-remaining") === "0")) {
		const retryAfterSeconds = getRetryAfterSeconds(response);
		throw new GithubRateLimitError(`GitHub rate limit hit for ${path}.`, retryAfterSeconds);
	}

	const rawText = await response.text();
	let parsedBody = null;
	if (rawText) {
		try {
			parsedBody = JSON.parse(rawText);
		} catch {
			parsedBody = rawText;
		}
	}

	if (!response.ok) {
		throw new GithubApiError(`GitHub request failed for ${path}.`, response.status, parsedBody);
	}

	return parsedBody;
}

async function ensureLabel(env, label) {
	try {
		await githubFetch(env, `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/labels`, {
			method: "POST",
			headers: {
				"content-type": "application/json; charset=utf-8",
			},
			body: JSON.stringify({
				name: label.name,
				color: label.color,
				description: truncate(label.description, 100),
			}),
		});
		logInfo("label-created", { label: label.name });
	} catch (error) {
		if (error instanceof GithubApiError && error.status === 422) {
			return;
		}

		logWarn("label-create-skipped", {
			label: label.name,
			error: error instanceof Error ? error.message : String(error),
		});
	}
}

async function ensureLabels(env, labels) {
	for (const label of labels) {
		await ensureLabel(env, label);
	}
}

async function findExistingIssue(env, errorCode) {
	const query = new URLSearchParams({
		q: `repo:${env.GITHUB_OWNER}/${env.GITHUB_REPO} is:issue "${errorCode}" in:title`,
		per_page: "1",
	});
	const searchResult = await githubFetch(env, `/search/issues?${query.toString()}`);
	return Array.isArray(searchResult.items) && searchResult.items.length > 0 ? searchResult.items[0] : null;
}

async function createIssue(env, payload, meta, labels) {
	const createdIssue = await githubFetch(env, `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/issues`, {
		method: "POST",
		headers: {
			"content-type": "application/json; charset=utf-8",
		},
		body: JSON.stringify({
			title: buildIssueTitle(payload),
			body: buildIssueBody(payload, meta),
			labels: labels.map((label) => label.name),
		}),
	});

	logInfo("issue-created", {
		errorCode: payload.errorCode,
		issueNumber: createdIssue.number,
	});

	return createdIssue;
}

async function updateIssue(env, issueNumber, payload, meta, labels) {
	const updatedIssue = await githubFetch(env, `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/issues/${issueNumber}`, {
		method: "PATCH",
		headers: {
			"content-type": "application/json; charset=utf-8",
		},
		body: JSON.stringify({
			title: buildIssueTitle(payload),
			body: buildIssueBody(payload, meta),
			labels: labels.map((label) => label.name),
		}),
	});

	await githubFetch(env, `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/issues/${issueNumber}/comments`, {
		method: "POST",
		headers: {
			"content-type": "application/json; charset=utf-8",
		},
		body: JSON.stringify({
			body: buildUpdateComment(payload, meta),
		}),
	});

	logInfo("issue-updated", {
		errorCode: payload.errorCode,
		issueNumber,
		totalOccurrences: meta.totalOccurrences,
	});

	return updatedIssue;
}

async function handleRobloxErrorRequest(request, env) {
	if (request.method === "OPTIONS") {
		return new Response(null, { status: 204 });
	}

	if (request.method !== "POST") {
		throw new HttpError(405, "Method not allowed.");
	}

	const url = new URL(request.url);
	if (url.pathname !== "/roblox-error") {
		throw new HttpError(404, "Not found.");
	}

	const requiredEnv = assertEnv(env);
	const providedSecret = getProvidedSecret(request);
	if (!providedSecret || !timingSafeEqual(providedSecret, requiredEnv.ROBLOX_ERROR_SECRET)) {
		throw new HttpError(401, "Unauthorized.");
	}

	const rawPayload = await parseRequestBody(request);
	const payload = normalizePayload(rawPayload);
	const labels = getDesiredLabels(payload);

	logInfo("payload-accepted", {
		errorCode: payload.errorCode,
		placeName: payload.placeName,
		scriptName: payload.scriptName,
		jobId: payload.jobId,
	});

	await ensureLabels(requiredEnv, labels);

	const existingIssue = await findExistingIssue(requiredEnv, payload.errorCode);
	const existingMeta = existingIssue ? parseMetaComment(existingIssue.body) : null;
	const meta = buildUpdatedMeta(existingMeta, payload);

	if (existingIssue) {
		await updateIssue(requiredEnv, existingIssue.number, payload, meta, labels);
		return jsonResponse(200, {
			ok: true,
			action: "updated",
			errorCode: payload.errorCode,
			issueNumber: existingIssue.number,
			totalOccurrences: meta.totalOccurrences,
		});
	}

	const createdIssue = await createIssue(requiredEnv, payload, meta, labels);
	return jsonResponse(201, {
		ok: true,
		action: "created",
		errorCode: payload.errorCode,
		issueNumber: createdIssue.number,
		totalOccurrences: meta.totalOccurrences,
	});
}

export default {
	async fetch(request, env) {
		try {
			return await handleRobloxErrorRequest(request, env);
		} catch (error) {
			if (error instanceof HttpError) {
				logWarn("request-rejected", {
					status: error.status,
					message: error.message,
					details: error.details || null,
				});
				return jsonResponse(error.status, {
					ok: false,
					error: error.message,
					details: error.details || null,
				});
			}

			if (error instanceof GithubRateLimitError) {
				logWarn("github-rate-limited", {
					message: error.message,
					retryAfterSeconds: error.retryAfterSeconds,
				});
				return jsonResponse(
					503,
					{
						ok: false,
						error: "GitHub API rate limit hit.",
						retryAfterSeconds: error.retryAfterSeconds,
					},
					{
						"retry-after": String(error.retryAfterSeconds),
					}
				);
			}

			if (error instanceof GithubApiError) {
				logError("github-api-error", {
					message: error.message,
					status: error.status,
					details: error.details || null,
				});
				return jsonResponse(502, {
					ok: false,
					error: "GitHub API request failed.",
					status: error.status,
				});
			}

			logError("unhandled-error", {
				message: error instanceof Error ? error.message : String(error),
				stack: error instanceof Error ? error.stack : null,
			});
			return jsonResponse(500, {
				ok: false,
				error: "Internal server error.",
			});
		}
	},
};

export { handleRobloxErrorRequest };
