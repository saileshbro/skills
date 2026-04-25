#!/usr/bin/env node
// superaudit skill: finalize.
//
// Re-parses the just-written cycle file, computes a fingerprint per finding,
// updates _state.json (new findings added; recurring findings get
// lastSeenCycle bumped; previously-open findings not seen this cycle become
// 'stale'), injects `<!-- fp: ... -->` markers next to each finding line so
// future runs can match user check-offs back to state, then releases the
// prepare lock.
//
// Usage:
//   node finalize.mjs <statePath> <cyclePath> <cycleNumber> <lockPath>
//
// All four args are produced by prepare.mjs (statePath, cyclePath,
// cycleNumber, lockPath in its JSON output).
//
// On any error the lock is still released, because a stuck lock blocks the
// next run for 5min and that's worse than a half-finalized state file.

import { createHash } from "node:crypto";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";

const [, , statePath, cyclePath, cycleNumStr, lockPath] = process.argv;

if (!statePath || !cyclePath || !cycleNumStr || !lockPath) {
  process.stderr.write(
    "usage: finalize.mjs <statePath> <cyclePath> <cycleNumber> <lockPath>\n"
  );
  process.exit(1);
}

const cycleN = Number(cycleNumStr);
if (!Number.isFinite(cycleN) || cycleN <= 0) {
  releaseLock();
  process.stderr.write(`bad cycleNumber: ${cycleNumStr}\n`);
  process.exit(1);
}

function releaseLock() {
  try {
    rmSync(lockPath, { recursive: true, force: true });
  } catch {}
}

function bail(msg, code = 1) {
  releaseLock();
  process.stderr.write(`${msg}\n`);
  process.exit(code);
}

let state = { version: 1, lastCycle: 0, findings: {} };
if (existsSync(statePath)) {
  try {
    const raw = JSON.parse(readFileSync(statePath, "utf8"));
    if (raw && typeof raw === "object") {
      state = {
        version: raw.version || 1,
        lastCycle: Number.isFinite(raw.lastCycle) ? raw.lastCycle : 0,
        findings:
          raw.findings && typeof raw.findings === "object" ? raw.findings : {},
      };
    }
  } catch (e) {
    bail(`bad state file ${statePath}: ${e.message}`);
  }
}

if (!existsSync(cyclePath)) {
  bail(`cycle file not found: ${cyclePath}`);
}

const raw = readFileSync(cyclePath, "utf8");

// Parse findings: lines like "- [ ] [P1] <text>. Evidence: <e>. Fix: <f>."
// We accept some variation in spacing/punctuation. We also tolerate (and
// preserve) any existing fp marker.
const findingRe =
  /^(\s*-\s*\[(?: |x)\]\s*)\[(P[0-2])\]\s*(.+?)\s*$/i;
const fpInLine = /<!--\s*fp:\s*([0-9a-f]{6,32})\s*-->/i;
// Split a finding body into text + evidence + fix. All optional except text.
function splitFinding(body) {
  const stripped = body.replace(fpInLine, "").trim();
  const evIdx = stripped.search(/\bEvidence:/i);
  const fixIdx = stripped.search(/\bFix:/i);
  const text =
    evIdx >= 0 ? stripped.slice(0, evIdx).trim() : stripped.trim();
  let evidence = "";
  let fix = "";
  if (evIdx >= 0 && fixIdx > evIdx) {
    evidence = stripped.slice(evIdx + "Evidence:".length, fixIdx).trim();
    fix = stripped.slice(fixIdx + "Fix:".length).trim();
  } else if (evIdx >= 0) {
    evidence = stripped.slice(evIdx + "Evidence:".length).trim();
  } else if (fixIdx >= 0) {
    fix = stripped.slice(fixIdx + "Fix:".length).trim();
  }
  return {
    text: text.replace(/[.,;\s]+$/, ""),
    evidence: evidence.replace(/[.,;\s]+$/, ""),
    fix: fix.replace(/[.,;\s]+$/, ""),
  };
}

function normPath(p) {
  // Strip line ranges, surrounding parens, lower-case, normalize slashes.
  return String(p)
    .toLowerCase()
    .replace(/[()`]/g, "")
    .replace(/:\d+(-\d+)?/g, "")
    .replace(/\s+/g, "")
    .trim();
}
function normText(s) {
  return String(s)
    .toLowerCase()
    .replace(/[`*_]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}
function fingerprint(priority, evidence, text) {
  const key = `${priority.toUpperCase()}|${normPath(evidence)}|${normText(
    text
  )}`;
  return createHash("sha1").update(key).digest("hex").slice(0, 12);
}

// Track current section (feature) by walking H3 headers — we use the most
// recent ### as the feature label for findings beneath it.
const lines = raw.split(/\r?\n/);
let currentFeature = null;
const seenFps = new Set();
const newLines = [];

for (const line of lines) {
  const h3 = line.match(/^###\s+(.+?)\s*$/);
  if (h3) {
    currentFeature = h3[1].trim();
  }
  const m = line.match(findingRe);
  if (!m) {
    newLines.push(line);
    continue;
  }
  const [, prefix, priority, body] = m;
  const isClosedNow = /\[x\]/i.test(prefix);
  const { text, evidence, fix } = splitFinding(body);
  if (!text) {
    newLines.push(line);
    continue;
  }
  const existingFpMatch = body.match(fpInLine);
  const fp = existingFpMatch
    ? existingFpMatch[1].toLowerCase()
    : fingerprint(priority, evidence || "", text);
  seenFps.add(fp);

  const prior = state.findings[fp];
  if (!prior) {
    state.findings[fp] = {
      priority: priority.toUpperCase(),
      evidence,
      text,
      fix,
      feature: currentFeature,
      status: isClosedNow ? "closed" : "open",
      firstSeenCycle: cycleN,
      lastSeenCycle: cycleN,
      closedAt: isClosedNow ? new Date().toISOString() : null,
      closedInCycle: isClosedNow ? cycleN : null,
    };
  } else {
    prior.lastSeenCycle = cycleN;
    if (isClosedNow && prior.status !== "closed") {
      prior.status = "closed";
      prior.closedAt = new Date().toISOString();
      prior.closedInCycle = cycleN;
    } else if (!isClosedNow && prior.status === "stale") {
      // Re-detected after going stale — reopen.
      prior.status = "open";
      prior.closedAt = null;
      prior.closedInCycle = null;
    }
    // Refresh metadata in case wording / fix improved.
    prior.priority = priority.toUpperCase();
    if (evidence) prior.evidence = evidence;
    if (fix) prior.fix = fix;
    if (currentFeature) prior.feature = currentFeature;
  }

  // Inject fp marker if missing.
  let outLine = line;
  if (!existingFpMatch) {
    const trimmed = line.replace(/\s+$/, "");
    const sep = trimmed.endsWith(".") ? " " : ". ";
    outLine = `${trimmed}${sep}<!-- fp: ${fp} -->`;
  }
  newLines.push(outLine);
}

// Mark previously-open findings not seen this cycle as stale. Don't touch
// closed ones — closed is closed. Stale findings can come back to "open"
// next cycle if Claude re-detects them.
for (const [fp, f] of Object.entries(state.findings)) {
  if (f.status === "open" && !seenFps.has(fp) && f.lastSeenCycle < cycleN) {
    f.status = "stale";
  }
}

state.lastCycle = Math.max(state.lastCycle, cycleN);

// Write cycle file back (with fp markers) and state.
try {
  writeFileSync(cyclePath, newLines.join("\n"));
  writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`);
} catch (e) {
  bail(`write error: ${e.message}`);
}

releaseLock();

const summary = {
  cycle: cycleN,
  findingsInCycle: seenFps.size,
  totalKnown: Object.keys(state.findings).length,
  open: Object.values(state.findings).filter((f) => f.status === "open").length,
  closed: Object.values(state.findings).filter((f) => f.status === "closed")
    .length,
  stale: Object.values(state.findings).filter((f) => f.status === "stale")
    .length,
};
process.stdout.write(`${JSON.stringify(summary)}\n`);
