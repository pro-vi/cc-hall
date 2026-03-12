#!/usr/bin/env bun

import { mkdir, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import os from "node:os";

const DAY_MS = 24 * 60 * 60 * 1000;
const STATE_DIR = process.env.HALL_STATE_DIR || "";
const HOME_DIR = process.env.HOME || os.homedir();
const CACHE_DIR = path.join(STATE_DIR, "usage");

function resolveProjectDirs() {
    if (process.env.HALL_USAGE_PROJECTS_DIR) {
        return [process.env.HALL_USAGE_PROJECTS_DIR];
    }
    const roots = [];
    if (process.env.CLAUDE_CONFIG_DIR) {
        for (const dir of process.env.CLAUDE_CONFIG_DIR.split(",")) {
            const trimmed = dir.trim();
            if (trimmed) roots.push(path.join(trimmed, "projects"));
        }
    }
    roots.push(path.join(HOME_DIR, ".config", "claude", "projects"));
    roots.push(path.join(HOME_DIR, ".claude", "projects"));
    return [...new Set(roots.map((r) => path.resolve(r)))];
}
const PREVIEW_DIR = path.join(CACHE_DIR, "previews");
const NOW_MS = Number.isFinite(Date.parse(process.env.HALL_USAGE_NOW || ""))
    ? Date.parse(process.env.HALL_USAGE_NOW)
    : Date.now();
const LOCAL_DAY_FORMATTER = new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
});

// Order matters: specific patterns before broad ones.
const MODEL_RATES = [
    {
        match: /claude-opus-4-[56]/i,
        family: "Claude Opus 4.5/4.6",
        input: 5.0,
        output: 25.0,
        cacheRead: 0.5,
        cacheWrite5m: 6.25,
        cacheWrite1h: 10.0,
        longInput: 10.0,
        longOutput: 37.5,
        fastMultiplier: 6,
    },
    {
        match: /claude-opus-4/i,
        family: "Claude Opus 4/4.1",
        input: 15.0,
        output: 75.0,
        cacheRead: 1.5,
        cacheWrite5m: 18.75,
        cacheWrite1h: 30.0,
    },
    {
        match: /claude-sonnet-4/i,
        family: "Claude Sonnet 4/4.5/4.6",
        input: 3.0,
        output: 15.0,
        cacheRead: 0.3,
        cacheWrite5m: 3.75,
        cacheWrite1h: 6.0,
        longInput: 6.0,
        longOutput: 22.5,
    },
    {
        match: /claude-sonnet-3[.-]?7/i,
        family: "Claude Sonnet 3.7",
        input: 3.0,
        output: 15.0,
        cacheRead: 0.3,
        cacheWrite5m: 3.75,
        cacheWrite1h: 6.0,
    },
    {
        match: /claude-haiku-4[.-]?5/i,
        family: "Claude Haiku 4.5",
        input: 1.0,
        output: 5.0,
        cacheRead: 0.1,
        cacheWrite5m: 1.25,
        cacheWrite1h: 2.0,
    },
    {
        match: /claude-haiku-3[.-]?5/i,
        family: "Claude Haiku 3.5",
        input: 0.8,
        output: 4.0,
        cacheRead: 0.08,
        cacheWrite5m: 1.0,
        cacheWrite1h: 1.6,
    },
    {
        match: /claude-opus-3/i,
        family: "Claude Opus 3",
        input: 15.0,
        output: 75.0,
        cacheRead: 1.5,
        cacheWrite5m: 18.75,
        cacheWrite1h: 30.0,
    },
    {
        match: /claude-haiku-3(?!\.5|[.-]5)/i,
        family: "Claude Haiku 3",
        input: 0.25,
        output: 1.25,
        cacheRead: 0.03,
        cacheWrite5m: 0.3,
        cacheWrite1h: 0.5,
    },
];

function money(amount) {
    return new Intl.NumberFormat("en-US", {
        style: "currency",
        currency: "USD",
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
    }).format(amount);
}

function integer(amount) {
    return new Intl.NumberFormat("en-US", {
        maximumFractionDigits: 0,
    }).format(amount);
}

function shortTokens(amount) {
    if (amount >= 1_000_000_000) return `${(amount / 1_000_000_000).toFixed(2)}B`;
    if (amount >= 1_000_000) return `${(amount / 1_000_000).toFixed(2)}M`;
    if (amount >= 1_000) return `${(amount / 1_000).toFixed(1)}k`;
    return `${Math.round(amount)}`;
}

function shortMoney(amount, partial, unavailable) {
    if (unavailable) return "n/a";
    if (partial) return `~${money(amount)}`;
    return money(amount);
}

function formatUtilization(pct) {
    if (!Number.isFinite(pct)) return "n/a";
    return Number.isInteger(pct) ? `${pct}%` : `${pct.toFixed(1)}%`;
}

function escapeLabel(value) {
    return String(value).replace(/\t/g, " ").replace(/\x1f/g, " ");
}

function projectLabel(projectPath) {
    if (!projectPath) return "(unknown project)";
    const base = path.basename(projectPath);
    return base || projectPath;
}

function localDayKey(timestampMs) {
    const parts = LOCAL_DAY_FORMATTER.formatToParts(new Date(timestampMs));
    const values = {};
    for (const part of parts) {
        if (part.type === "year" || part.type === "month" || part.type === "day") {
            values[part.type] = part.value;
        }
    }
    return `${values.year}-${values.month}-${values.day}`;
}

function displayDate(timestampMs) {
    return new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "2-digit",
        year: "numeric",
    }).format(new Date(timestampMs));
}

function displayDateTime(timestampMs) {
    return new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "2-digit",
        year: "numeric",
        hour: "numeric",
        minute: "2-digit",
    }).format(new Date(timestampMs));
}

function formatResetTime(isoString) {
    const timestampMs = Date.parse(isoString || "");
    if (!Number.isFinite(timestampMs)) return "(unknown)";

    const deltaMs = timestampMs - NOW_MS;
    if (deltaMs <= 0) return displayDateTime(timestampMs);
    if (deltaMs > DAY_MS) return displayDate(timestampMs);

    const totalMinutes = Math.floor(deltaMs / 60000);
    if (totalMinutes <= 0) return "in <1m";

    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours <= 0) return `in ${minutes}m`;
    if (minutes <= 0) return `in ${hours}h`;
    return `in ${hours}h ${minutes}m`;
}

function daysAgo(days) {
    return NOW_MS - days * DAY_MS;
}

function rateForModel(model) {
    return MODEL_RATES.find((entry) => entry.match.test(model)) || null;
}

function numeric(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function estimateRecordCost(record) {
    const rates = rateForModel(record.model);
    if (!rates) {
        return {
            family: null,
            estimatedCost: 0,
            unavailable: record.totalTokens > 0,
            partial: false,
        };
    }

    const isFast = record.speed === "fast" && rates.fastMultiplier != null;
    const totalInput = record.inputTokens + record.cacheReadTokens + record.cacheWriteTokens;
    const isLong = !isFast && totalInput > 200_000 && rates.longInput != null;

    let inputRate = rates.input;
    let outputRate = rates.output;
    let cacheReadRate = rates.cacheRead;
    let cacheWrite5mRate = rates.cacheWrite5m;
    let cacheWrite1hRate = rates.cacheWrite1h;

    if (isFast) {
        const m = rates.fastMultiplier;
        inputRate *= m;
        outputRate *= m;
        cacheReadRate *= m;
        cacheWrite5mRate *= m;
        cacheWrite1hRate *= m;
    } else if (isLong) {
        const scale = rates.longInput / rates.input;
        inputRate = rates.longInput;
        outputRate = rates.longOutput;
        cacheReadRate *= scale;
        cacheWrite5mRate *= scale;
        cacheWrite1hRate *= scale;
    }

    let estimatedCost = 0;
    let partial = false;

    estimatedCost += (record.inputTokens / 1_000_000) * inputRate;
    estimatedCost += (record.outputTokens / 1_000_000) * outputRate;
    estimatedCost += (record.cacheReadTokens / 1_000_000) * cacheReadRate;

    const splitTotal = record.cacheWrite5mTokens + record.cacheWrite1hTokens;
    if (splitTotal > 0) {
        estimatedCost += (record.cacheWrite5mTokens / 1_000_000) * cacheWrite5mRate;
        estimatedCost += (record.cacheWrite1hTokens / 1_000_000) * cacheWrite1hRate;
        if (splitTotal < record.cacheWriteTokens) {
            partial = true;
        }
    } else if (record.cacheWriteTokens > 0) {
        partial = true;
    }

    return {
        family: rates.family,
        estimatedCost,
        unavailable: false,
        partial,
    };
}

function makeAccumulator(meta = {}) {
    return {
        ...meta,
        inputTokens: 0,
        outputTokens: 0,
        cacheWriteTokens: 0,
        cacheReadTokens: 0,
        cacheWrite5mTokens: 0,
        cacheWrite1hTokens: 0,
        totalTokens: 0,
        estimatedCost: 0,
        messageCount: 0,
        sessionIds: new Set(),
        subagentMessages: 0,
        latestTimestampMs: 0,
        latestModel: "",
        latestProjectPath: "",
        pricingFamilies: new Set(),
        costSources: new Set(),
        unavailableCost: false,
        partialCost: false,
    };
}

function accumulate(acc, record) {
    acc.inputTokens += record.inputTokens;
    acc.outputTokens += record.outputTokens;
    acc.cacheWriteTokens += record.cacheWriteTokens;
    acc.cacheReadTokens += record.cacheReadTokens;
    acc.cacheWrite5mTokens += record.cacheWrite5mTokens;
    acc.cacheWrite1hTokens += record.cacheWrite1hTokens;
    acc.totalTokens += record.totalTokens;
    acc.estimatedCost += record.estimatedCost;
    acc.messageCount += 1;
    acc.sessionIds.add(record.sessionId);
    if (record.isSubagent) acc.subagentMessages += 1;
    if (record.costUnavailable) acc.unavailableCost = true;
    if (record.costPartial) acc.partialCost = true;
    if (record.pricingFamily) acc.pricingFamilies.add(record.pricingFamily);
    if (record.costSource) acc.costSources.add(record.costSource);
    if (record.timestampMs >= acc.latestTimestampMs) {
        acc.latestTimestampMs = record.timestampMs;
        acc.latestModel = record.model;
        acc.latestProjectPath = record.projectPath;
    }
}

function finalizeAccumulator(acc) {
    return {
        ...acc,
        sessionCount: acc.sessionIds.size,
        pricingFamilies: [...acc.pricingFamilies].sort(),
        costSources: [...acc.costSources].sort(),
        partialCost: acc.partialCost || acc.unavailableCost,
        costUnavailable: acc.unavailableCost,
    };
}

function metricTable(summary) {
    return [
        "| Metric | Value |",
        "|-------|------:|",
        `| Total tokens | ${integer(summary.totalTokens)} |`,
        `| Input | ${integer(summary.inputTokens)} |`,
        `| Output | ${integer(summary.outputTokens)} |`,
        `| Cache write | ${integer(summary.cacheWriteTokens)} |`,
        `| Cache read | ${integer(summary.cacheReadTokens)} |`,
        `| Messages | ${integer(summary.messageCount)} |`,
        `| Sessions | ${integer(summary.sessionCount)} |`,
        `| Est. cost | ${summary.costUnavailable ? "Unavailable" : shortMoney(summary.estimatedCost, summary.partialCost, false)} |`,
    ].join("\n");
}

function costNotes(summary) {
    if (summary.costUnavailable) {
        return [
            "",
            "Cost is unavailable for at least one model family in this bucket.",
            "Hall keeps the token totals exact and avoids guessing the missing price.",
        ].join("\n");
    }

    const hasCostUSD = summary.costSources.includes("costUSD");
    const hasCalculated = summary.costSources.includes("calculated");
    const lines = [""];

    if (hasCostUSD && !hasCalculated) {
        lines.push("Cost sourced from transcript `costUSD` fields (higher accuracy).");
    } else if (hasCostUSD && hasCalculated) {
        lines.push("Cost is a mix of transcript `costUSD` (where available) and rate-estimated values.");
    } else {
        lines.push("Cost is estimated from local transcript usage and the current Claude prompt-caching pricing model.");
    }
    if (summary.partialCost) {
        lines.push("This bucket is partial because some cache-write records lacked a durable 5m/1h split.");
    }
    if (summary.pricingFamilies.length > 0) {
        lines.push(`Priced families: ${summary.pricingFamilies.join(", ")}.`);
    }
    return lines.join("\n");
}

function renderAggregatePreview(title, subtitle, summary, extras = []) {
    if (summary.messageCount === 0) {
        return [
            `**${title}**`,
            "",
            subtitle,
            "",
            "No usage-bearing assistant messages were found for this slice.",
        ].join("\n");
    }

    return [
        `**${title}**`,
        "",
        subtitle,
        "",
        metricTable(summary),
        "",
        `Latest activity: ${displayDateTime(summary.latestTimestampMs)}`,
        `Latest model: ${summary.latestModel || "(unknown)"}`,
        `Latest project: \`${summary.latestProjectPath || "(unknown)"}\``,
        `Subagent messages included: ${integer(summary.subagentMessages)}`,
        ...extras,
        costNotes(summary),
    ].join("\n");
}

function relativeWindow(records, predicate) {
    const acc = makeAccumulator();
    for (const record of records) {
        if (predicate(record)) accumulate(acc, record);
    }
    return finalizeAccumulator(acc);
}

async function collectJsonlFiles(rootDir) {
    const files = [];

    async function walk(currentDir) {
        let entries = [];
        try {
            entries = await readdir(currentDir, { withFileTypes: true });
        } catch {
            return;
        }

        for (const entry of entries) {
            if (entry.name === "tool-results") continue;
            const fullPath = path.join(currentDir, entry.name);
            if (entry.isDirectory()) {
                await walk(fullPath);
            } else if (entry.isFile() && entry.name.endsWith(".jsonl")) {
                files.push(fullPath);
            }
        }
    }

    await walk(rootDir);
    files.sort();
    return files;
}

async function loadRecords(rootDirs) {
    const fileSets = await Promise.all(rootDirs.map((dir) => collectJsonlFiles(dir)));
    const files = [...new Set(fileSets.flat())];
    const records = [];
    const rateLimitEvents = [];

    for (const filePath of files) {
        const text = await Bun.file(filePath).text().catch(() => "");
        if (!text) continue;

        for (const rawLine of text.split("\n")) {
            const line = rawLine.trim();
            if (!line) continue;

            let parsed;
            try {
                parsed = JSON.parse(line);
            } catch {
                continue;
            }

            const timestampMs = Date.parse(parsed?.timestamp || "");
            if (!Number.isFinite(timestampMs)) continue;

            // Rate limit event detection
            if (parsed?.isApiErrorMessage === true) {
                const texts = (parsed?.message?.content || [])
                    .filter((c) => c.type === "text")
                    .map((c) => c.text);
                const text = texts.join(" ");
                const match = text.match(/out of.*usage.*resets\s+(.+)/i);
                if (match) {
                    rateLimitEvents.push({ timestampMs, resetText: match[1].trim() });
                }
                continue;
            }

            const usage = parsed?.message?.usage;
            const role = parsed?.message?.role;
            if (!usage || role !== "assistant") continue;

            const inputTokens = numeric(usage?.input_tokens);
            const outputTokens = numeric(usage?.output_tokens);
            const cacheWriteTokens = numeric(usage?.cache_creation_input_tokens);
            const cacheReadTokens = numeric(usage?.cache_read_input_tokens);
            const cacheWrite5mTokens = numeric(usage?.cache_creation?.ephemeral_5m_input_tokens);
            const cacheWrite1hTokens = numeric(usage?.cache_creation?.ephemeral_1h_input_tokens);

            const record = {
                filePath,
                timestampMs,
                dayKey: localDayKey(timestampMs),
                sessionId: String(parsed?.sessionId || path.basename(filePath, ".jsonl")),
                projectPath: String(parsed?.cwd || ""),
                model: String(parsed?.message?.model || "<unknown>"),
                isSubagent: filePath.includes(`${path.sep}subagents${path.sep}`) || parsed?.isSidechain === true,
                speed: String(usage?.speed || "standard"),
                messageId: String(parsed?.message?.id || ""),
                requestId: String(parsed?.requestId || ""),
                inputTokens,
                outputTokens,
                cacheWriteTokens,
                cacheReadTokens,
                cacheWrite5mTokens,
                cacheWrite1hTokens,
            };
            record.totalTokens = record.inputTokens + record.outputTokens + record.cacheWriteTokens + record.cacheReadTokens;

            const reportedCost = numeric(parsed?.costUSD);
            if (record.totalTokens <= 0 && reportedCost <= 0) {
                continue;
            }
            if (reportedCost > 0) {
                record.estimatedCost = reportedCost;
                record.costSource = "costUSD";
                record.pricingFamily = rateForModel(record.model)?.family || null;
                record.costUnavailable = false;
                record.costPartial = false;
            } else {
                const priced = estimateRecordCost(record);
                record.estimatedCost = priced.estimatedCost;
                record.costSource = "calculated";
                record.pricingFamily = priced.family;
                record.costUnavailable = priced.unavailable;
                record.costPartial = priced.partial;
            }

            records.push(record);
        }
    }

    // Deduplicate by messageId:requestId composite key
    const seen = new Set();
    const deduped = [];
    for (const record of records) {
        if (record.messageId && record.requestId) {
            const key = `${record.messageId}:${record.requestId}`;
            if (seen.has(key)) continue;
            seen.add(key);
        }
        deduped.push(record);
    }

    deduped.sort((a, b) => a.timestampMs - b.timestampMs);
    rateLimitEvents.sort((a, b) => a.timestampMs - b.timestampMs);
    return { records: deduped, rateLimitEvents };
}

function latestSessionSummary(records) {
    const sessions = new Map();
    for (const record of records) {
        const key = record.sessionId;
        if (!sessions.has(key)) {
            sessions.set(key, makeAccumulator({ sessionId: key, projectPath: record.projectPath }));
        }
        accumulate(sessions.get(key), record);
    }

    const summaries = [...sessions.values()].map(finalizeAccumulator);
    summaries.sort((a, b) => b.latestTimestampMs - a.latestTimestampMs);
    return summaries[0] || finalizeAccumulator(makeAccumulator({ sessionId: "" }));
}

function aggregateBy(records, keyFn, metaFn) {
    const groups = new Map();
    for (const record of records) {
        const key = keyFn(record);
        if (!groups.has(key)) groups.set(key, makeAccumulator(metaFn(record, key)));
        accumulate(groups.get(key), record);
    }
    return [...groups.values()].map(finalizeAccumulator);
}

function entryLine(label, command) {
    return `${escapeLabel(label)}\t${command}`;
}

function extractOAuthAccessToken(value) {
    if (!value) return null;

    if (typeof value === "string") {
        const trimmed = value.trim();
        if (!trimmed) return null;

        if (trimmed.startsWith("{")) {
            try {
                return extractOAuthAccessToken(JSON.parse(trimmed));
            } catch {
                return null;
            }
        }

        return trimmed;
    }

    if (typeof value !== "object") return null;

    const direct = value.accessToken;
    if (typeof direct === "string" && direct.trim()) return direct.trim();

    const nested = value?.claudeAiOauth?.accessToken;
    if (typeof nested === "string" && nested.trim()) return nested.trim();

    return null;
}

async function getOAuthToken() {
    if (Object.prototype.hasOwnProperty.call(process.env, "HALL_USAGE_OAUTH_RESPONSE")) {
        return null;
    }

    try {
        if (process.platform === "darwin") {
            const account = process.env.USER || os.userInfo().username;
            if (!account) return null;

            const result = Bun.spawnSync([
                "security",
                "find-generic-password",
                "-s",
                "Claude Code-credentials",
                "-a",
                account,
                "-w",
            ]);
            if (result.exitCode !== 0) return null;

            const secret = Buffer.from(result.stdout).toString("utf8");
            return extractOAuthAccessToken(secret);
        }

        const credentialsPath = path.join(HOME_DIR, ".claude", ".credentials.json");
        const raw = await Bun.file(credentialsPath).text().catch(() => "");
        if (!raw.trim()) return null;

        const parsed = JSON.parse(raw);
        return extractOAuthAccessToken(parsed);
    } catch {
        return null;
    }
}

function normalizeRateLimitUsage(payload) {
    if (!payload || typeof payload !== "object") return null;

    const normalizeWindow = (value) => {
        if (!value || typeof value !== "object") return null;
        const utilization = Number(value.utilization);
        const resetsAt = typeof value.resets_at === "string" ? value.resets_at : "";
        if (!Number.isFinite(utilization) || !resetsAt) return null;
        return { utilization, resetsAt };
    };

    const fiveHour = normalizeWindow(payload.five_hour);
    const sevenDay = normalizeWindow(payload.seven_day);
    if (!fiveHour && !sevenDay) return null;

    let extraUsage = null;
    if (payload.extra_usage && typeof payload.extra_usage === "object") {
        const utilization = Number(payload.extra_usage.utilization);
        const monthlyLimit = Number(payload.extra_usage.monthly_limit);
        const usedCredits = Number(payload.extra_usage.used_credits);
        extraUsage = {
            isEnabled: payload.extra_usage.is_enabled === true,
            utilization: Number.isFinite(utilization) ? utilization : null,
            monthlyLimit: Number.isFinite(monthlyLimit) ? monthlyLimit : null,
            usedCredits: Number.isFinite(usedCredits) ? usedCredits : null,
        };
    }

    return { fiveHour, sevenDay, extraUsage };
}

async function fetchRateLimitUsage() {
    if (Object.prototype.hasOwnProperty.call(process.env, "HALL_USAGE_OAUTH_RESPONSE")) {
        try {
            const injected = process.env.HALL_USAGE_OAUTH_RESPONSE || "";
            if (!injected.trim()) return null;
            return normalizeRateLimitUsage(JSON.parse(injected));
        } catch {
            return null;
        }
    }

    const token = await getOAuthToken();
    if (!token) return null;

    try {
        const response = await fetch("https://api.anthropic.com/api/oauth/usage", {
            method: "GET",
            headers: {
                Authorization: `Bearer ${token}`,
                "anthropic-beta": "oauth-2025-04-20",
            },
            signal: AbortSignal.timeout(5000),
        });

        if (!response.ok) return null;
        return normalizeRateLimitUsage(await response.json());
    } catch {
        return null;
    }
}

async function buildSnapshot() {
    if (!STATE_DIR) {
        throw new Error("HALL_STATE_DIR is required");
    }

    await mkdir(PREVIEW_DIR, { recursive: true });
    const projectDirs = resolveProjectDirs();
    const [{ records, rateLimitEvents }, liveUsage] = await Promise.all([
        loadRecords(projectDirs),
        fetchRateLimitUsage(),
    ]);
    const currentProjectPath = process.cwd();
    const todayKey = localDayKey(NOW_MS);

    const today = relativeWindow(records, (record) => record.dayKey === todayKey);
    const last7 = relativeWindow(records, (record) => record.timestampMs >= daysAgo(7));
    const last30 = relativeWindow(records, (record) => record.timestampMs >= daysAgo(30));
    const currentProject30 = relativeWindow(
        records,
        (record) => record.projectPath === currentProjectPath && record.timestampMs >= daysAgo(30),
    );
    const latestSession = latestSessionSummary(records);

    const daily = aggregateBy(
        records.filter((record) => record.timestampMs >= daysAgo(14)),
        (record) => record.dayKey,
        (record, key) => ({ dayKey: key }),
    ).sort((a, b) => b.latestTimestampMs - a.latestTimestampMs);

    const projects = aggregateBy(
        records.filter((record) => record.timestampMs >= daysAgo(30)),
        (record) => record.projectPath || "(unknown project)",
        (record, key) => ({ projectPath: key }),
    )
        .sort((a, b) => b.totalTokens - a.totalTokens)
        .slice(0, 12);

    const models = aggregateBy(
        records.filter((record) => record.timestampMs >= daysAgo(30)),
        (record) => record.model,
        (record, key) => ({ model: key }),
    )
        .sort((a, b) => b.totalTokens - a.totalTokens)
        .slice(0, 12);

    const overviewEntries = [];
    const dailyEntries = [];
    const projectEntries = [];
    const modelEntries = [];
    const previewWrites = [];

    const overviewMetrics = [
        {
            id: "ov-today",
            label: "Today",
            summary: today,
            subtitle: "Usage-bearing assistant messages from the current calendar day.",
        },
        {
            id: "ov-7d",
            label: "Last 7 days",
            summary: last7,
            subtitle: "Rolling 7 day usage across all projects, including subagents.",
        },
        {
            id: "ov-30d",
            label: "Last 30 days",
            summary: last30,
            subtitle: "Rolling 30 day usage across all projects, including subagents.",
        },
        {
            id: "ov-current-project",
            label: "This project (30d)",
            summary: currentProject30,
            subtitle: `Rolling 30 day usage for \`${currentProjectPath}\`.`,
        },
    ];

    for (const metric of overviewMetrics) {
        const label = `${metric.label.padEnd(18)} ${shortTokens(metric.summary.totalTokens).padStart(8)} tok  ${shortMoney(metric.summary.estimatedCost, metric.summary.partialCost, metric.summary.costUnavailable)}`;
        overviewEntries.push(entryLine(label, `usage-show ${metric.id}`));
        previewWrites.push(
            writeFile(
                path.join(PREVIEW_DIR, `${metric.id}.md`),
                renderAggregatePreview(metric.label, metric.subtitle, metric.summary),
            ),
        );
    }

    const latestSessionLabel = `${"Latest session".padEnd(18)} ${shortTokens(latestSession.totalTokens).padStart(8)} tok  ${shortMoney(latestSession.estimatedCost, latestSession.partialCost, latestSession.costUnavailable)}`;
    overviewEntries.push(entryLine(latestSessionLabel, "usage-show ov-latest-session"));
    previewWrites.push(
        writeFile(
            path.join(PREVIEW_DIR, "ov-latest-session.md"),
            renderAggregatePreview(
                "Latest Session",
                latestSession.sessionId
                    ? `Most recent session observed in local transcripts: \`${latestSession.sessionId}\`.`
                    : "No session transcript data found.",
                latestSession,
            ),
        ),
    );

    const latestRateLimit = rateLimitEvents.length > 0 ? rateLimitEvents[rateLimitEvents.length - 1] : null;
    let rateLimitLabel = `${"Rate limit".padEnd(18)} ${"no events".padStart(8)}`;
    if (liveUsage) {
        const segments = [];
        if (liveUsage.fiveHour) segments.push(`5h: ${formatUtilization(liveUsage.fiveHour.utilization)}`);
        if (liveUsage.sevenDay) segments.push(`7d: ${formatUtilization(liveUsage.sevenDay.utilization)}`);
        rateLimitLabel = `${"Rate limit".padEnd(18)} ${segments.join("  ")}`;
    } else if (latestRateLimit) {
        rateLimitLabel = `${"Rate limit".padEnd(18)} ${latestRateLimit.resetText.padStart(8)}`;
    }
    overviewEntries.push(entryLine(rateLimitLabel, "usage-show ov-rate-limit"));

    const costTable = [
        "| Period | Tokens | Est. Cost |",
        "|--------|-------:|----------:|",
        `| Today | ${shortTokens(today.totalTokens)} | ${shortMoney(today.estimatedCost, today.partialCost, today.costUnavailable)} |`,
        `| Last 7 days | ${shortTokens(last7.totalTokens)} | ${shortMoney(last7.estimatedCost, last7.partialCost, last7.costUnavailable)} |`,
        `| Last 30 days | ${shortTokens(last30.totalTokens)} | ${shortMoney(last30.estimatedCost, last30.partialCost, last30.costUnavailable)} |`,
    ].join("\n");

    previewWrites.push(
        writeFile(
            path.join(PREVIEW_DIR, "ov-rate-limit.md"),
            liveUsage
                ? [
                      "**Rate Limit**",
                      "",
                      "| Window | Used | Resets |",
                      "|--------|-----:|--------|",
                      ...(liveUsage.fiveHour
                          ? [
                                `| 5 hour | ${formatUtilization(liveUsage.fiveHour.utilization)} | ${formatResetTime(liveUsage.fiveHour.resetsAt)} |`,
                            ]
                          : []),
                      ...(liveUsage.sevenDay
                          ? [
                                `| 7 day | ${formatUtilization(liveUsage.sevenDay.utilization)} | ${formatResetTime(liveUsage.sevenDay.resetsAt)} |`,
                            ]
                          : []),
                      ...(liveUsage.extraUsage?.isEnabled &&
                      liveUsage.extraUsage.utilization != null &&
                      liveUsage.extraUsage.usedCredits != null &&
                      liveUsage.extraUsage.monthlyLimit != null
                          ? [
                                "",
                                `Extra usage: ${formatUtilization(liveUsage.extraUsage.utilization)} (${money(liveUsage.extraUsage.usedCredits)} / ${money(liveUsage.extraUsage.monthlyLimit)} monthly limit)`,
                            ]
                          : []),
                      "",
                      costTable,
                      "",
                      "Source: Anthropic OAuth API (live)",
                  ].join("\n")
                : latestRateLimit
                ? [
                      "**Rate Limit**",
                      "",
                      `Resets ${latestRateLimit.resetText}`,
                      `Detected: ${displayDateTime(latestRateLimit.timestampMs)}`,
                      `Events observed: ${rateLimitEvents.length}`,
                      "",
                      costTable,
                  ].join("\n")
                : [
                      "**Rate Limit**",
                      "",
                      "No rate limit events detected in local transcripts.",
                      "",
                      costTable,
                      "",
                      "Hall scans for `isApiErrorMessage` entries that mention usage resets.",
                      "If you hit a rate limit during a session, it will appear here after a snapshot refresh.",
                  ].join("\n"),
        ),
    );

    if (daily.length === 0) {
        dailyEntries.push(entryLine("No transcript data", "usage-show daily-empty"));
        previewWrites.push(
            writeFile(
                path.join(PREVIEW_DIR, "daily-empty.md"),
                [
                    "**Daily Usage**",
                    "",
                    "No usage-bearing assistant messages were found in the last 14 days.",
                ].join("\n"),
            ),
        );
    } else {
        for (const day of daily) {
            const id = `day-${day.dayKey}`;
            const label = `${day.dayKey.padEnd(18)} ${shortTokens(day.totalTokens).padStart(8)} tok  ${shortMoney(day.estimatedCost, day.partialCost, day.costUnavailable)}`;
            dailyEntries.push(entryLine(label, `usage-show ${id}`));
            previewWrites.push(
                writeFile(
                    path.join(PREVIEW_DIR, `${id}.md`),
                    renderAggregatePreview(day.dayKey, `Daily rollup for ${day.dayKey}.`, day),
                ),
            );
        }
    }

    if (projects.length === 0) {
        projectEntries.push(entryLine("No transcript data", "usage-show projects-empty"));
        previewWrites.push(
            writeFile(
                path.join(PREVIEW_DIR, "projects-empty.md"),
                [
                    "**Projects**",
                    "",
                    "No usage-bearing assistant messages were found in the last 30 days.",
                ].join("\n"),
            ),
        );
    } else {
        for (const [index, project] of projects.entries()) {
            const id = `project-${index + 1}`;
            const label = `${projectLabel(project.projectPath).padEnd(18)} ${shortTokens(project.totalTokens).padStart(8)} tok  ${shortMoney(project.estimatedCost, project.partialCost, project.costUnavailable)}`;
            projectEntries.push(entryLine(label, `usage-show ${id}`));
            previewWrites.push(
                writeFile(
                    path.join(PREVIEW_DIR, `${id}.md`),
                    renderAggregatePreview(
                        projectLabel(project.projectPath),
                        `Top project in the rolling 30 day window.\n\nPath: \`${project.projectPath}\``,
                        project,
                    ),
                ),
            );
        }
    }

    if (models.length === 0) {
        modelEntries.push(entryLine("No transcript data", "usage-show models-empty"));
        previewWrites.push(
            writeFile(
                path.join(PREVIEW_DIR, "models-empty.md"),
                [
                    "**Models**",
                    "",
                    "No usage-bearing assistant messages were found in the last 30 days.",
                ].join("\n"),
            ),
        );
    } else {
        for (const [index, model] of models.entries()) {
            const id = `model-${index + 1}`;
            const label = `${model.model.padEnd(24)} ${shortTokens(model.totalTokens).padStart(8)} tok  ${shortMoney(model.estimatedCost, model.partialCost, model.costUnavailable)}`;
            modelEntries.push(entryLine(label, `usage-show ${id}`));
            previewWrites.push(
                writeFile(
                    path.join(PREVIEW_DIR, `${id}.md`),
                    renderAggregatePreview(
                        model.model,
                        "Rolling 30 day usage grouped by exact model string.",
                        model,
                    ),
                ),
            );
        }
    }

    await Promise.all([
        writeFile(path.join(CACHE_DIR, "overview.entries"), overviewEntries.join("\n")),
        writeFile(path.join(CACHE_DIR, "daily.entries"), dailyEntries.join("\n")),
        writeFile(path.join(CACHE_DIR, "projects.entries"), projectEntries.join("\n")),
        writeFile(path.join(CACHE_DIR, "models.entries"), modelEntries.join("\n")),
        ...previewWrites,
    ]);

    await writeFile(
        path.join(CACHE_DIR, "manifest.json"),
        JSON.stringify(
            {
                builtAt: new Date().toISOString(),
                now: new Date(NOW_MS).toISOString(),
                projectsDirs: projectDirs,
                recordCount: records.length,
                currentProjectPath,
            },
            null,
            2,
        ),
    );
}

async function main() {
    const command = process.argv[2] || "build";
    if (command !== "build") {
        console.error("Usage: hall-usage.js build");
        process.exit(1);
    }
    await buildSnapshot();
}

main().catch((error) => {
    console.error(error?.message || String(error));
    process.exit(1);
});
