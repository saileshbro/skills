#!/usr/bin/env node
// superaudit skill: prepare.
//
// Manually-triggered. Gathers everything the audit needs and prints a single
// JSON object on stdout. On error/blocked state, prints { error, code } to
// stderr and exits 1.
//
// Usage:
//   node prepare.mjs
//
// Layout in consuming repo (under repo root):
//   superaudit/
//     .config.json   (optional, see SKILL.md)
//     _state.json    (auto-managed: findings registry, fingerprint-keyed)
//     .lock.d/       (mkdir lock, 5-min stale window)
//     cycle-001.md   (append-only cycle reports, zero-padded sequential)
//     cycle-002.md
//     ...

import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";

function fail(code, message) {
  process.stderr.write(`${JSON.stringify({ error: message, code })}\n`);
  process.exit(1);
}

function git(argv) {
  const r = spawnSync("git", argv, { encoding: "utf8" });
  return r.status === 0 ? r.stdout.replace(/\n$/, "") : "";
}

function gitOut(argv) {
  const r = spawnSync("git", argv, {
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
  });
  return r.status === 0 ? r.stdout || "" : "";
}

const repoRoot = git(["rev-parse", "--show-toplevel"]);
if (!repoRoot) fail("NOT_A_REPO", "Not inside a git repository.");
process.chdir(repoRoot);

const dir = join(repoRoot, "superaudit");
if (!existsSync(dir)) {
  fail(
    "NO_SUPERAUDIT_DIR",
    `No 'superaudit/' directory at ${repoRoot}. Create it (mkdir superaudit) to opt this repo into superaudit.`
  );
}

const configPath = join(dir, ".config.json");
let config = {};
if (existsSync(configPath)) {
  try {
    config = JSON.parse(readFileSync(configPath, "utf8"));
  } catch (e) {
    fail("BAD_CONFIG", `Invalid JSON in ${configPath}: ${e.message}`);
  }
}

const pathExcludes = Array.isArray(config.pathExcludes)
  ? config.pathExcludes.filter((s) => typeof s === "string" && s.length > 0)
  : [];
const pathIncludes = Array.isArray(config.pathIncludes)
  ? config.pathIncludes.filter((s) => typeof s === "string" && s.length > 0)
  : [];
const sinceHours = Number.isFinite(Number(config.sinceHours))
  ? Number(config.sinceHours)
  : 24;
const reportsCfg = Array.isArray(config.reports) ? config.reports : [];

function pad(n) {
  return String(n).padStart(2, "0");
}
function fmtLocal(d) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours()
  )}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}
function dateOnly(d) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

const lockDir = join(dir, ".lock.d");
const LOCK_TIMEOUT_MS = 5 * 60 * 1000;
function acquireLock() {
  try {
    mkdirSync(lockDir);
    return;
  } catch (e) {
    if (e.code !== "EEXIST") fail("LOCK_ERR", e.message);
  }
  let stale = false;
  try {
    stale = Date.now() - statSync(lockDir).mtimeMs > LOCK_TIMEOUT_MS;
  } catch {}
  if (stale) {
    rmSync(lockDir, { recursive: true, force: true });
    try {
      mkdirSync(lockDir);
      return;
    } catch (e) {
      fail("LOCK_ERR", e.message);
    }
  }
  fail(
    "LOCKED",
    `Superaudit lock held at ${lockDir} (<5min). Wait or remove the directory if known stale.`
  );
}
acquireLock();

function releaseLockAndFail(code, msg) {
  try {
    rmSync(lockDir, { recursive: true, force: true });
  } catch {}
  fail(code, msg);
}

const statePath = join(dir, "_state.json");
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
    releaseLockAndFail(
      "BAD_STATE",
      `Invalid JSON in ${statePath}: ${e.message}`
    );
  }
}

const cycleRe = /^cycle-(\d+)\.md$/;
let existingCycles;
try {
  existingCycles = readdirSync(dir)
    .map((f) => {
      const m = f.match(cycleRe);
      return m ? { file: f, n: Number(m[1]) } : null;
    })
    .filter(Boolean)
    .sort((a, b) => a.n - b.n);
} catch (e) {
  releaseLockAndFail("PREP_ERR", e.message);
}

const maxCycleOnDisk = existingCycles.length
  ? existingCycles[existingCycles.length - 1].n
  : 0;
const lastCycleN = Math.max(state.lastCycle, maxCycleOnDisk);
const cycleN = lastCycleN + 1;
const cycleFile = `cycle-${String(cycleN).padStart(3, "0")}.md`;
const cyclePath = join(dir, cycleFile);
const cycleRel = `superaudit/${cycleFile}`;

// Scrape `- [x] ... <!-- fp: abc --> ` lines from prior cycle files. Any
// fingerprint marked closed by the user becomes status=closed in state.
// This is how user check-offs propagate without round-tripping a UI.
const fpInLine = /<!--\s*fp:\s*([0-9a-f]{6,32})\s*-->/i;
const checkedRe = /^\s*-\s*\[x\]\s/i;
const todayIso = new Date().toISOString();

let stateMutated = false;
for (const c of existingCycles) {
  let txt;
  try {
    txt = readFileSync(join(dir, c.file), "utf8");
  } catch {
    continue;
  }
  for (const line of txt.split(/\r?\n/)) {
    if (!checkedRe.test(line)) continue;
    const m = line.match(fpInLine);
    if (!m) continue;
    const fp = m[1].toLowerCase();
    const f = state.findings[fp];
    if (f && f.status !== "closed") {
      f.status = "closed";
      f.closedAt = todayIso;
      f.closedInCycle = c.n;
      stateMutated = true;
    }
  }
}

// Persist closures back to disk before finalize loads state. Without this,
// finalize would read the pre-closure state and (correctly per its own
// logic) demote the never-re-listed-but-now-closed finding to "stale".
if (stateMutated) {
  try {
    writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`);
  } catch (e) {
    releaseLockAndFail(
      "STATE_WRITE",
      `Failed to persist state closures: ${e.message}`
    );
  }
}

const branch = git(["rev-parse", "--abbrev-ref", "HEAD"]) || "(detached)";
const headSha = git(["rev-parse", "HEAD"]) || "(none)";
const now = new Date();
const dateStr = dateOnly(now);
const sinceDate = fmtLocal(new Date(Date.now() - sinceHours * 3600 * 1000));

const pathspecExcludes = pathExcludes.map((p) => `:(exclude)${p}`);
const pathspec = ["--", ...pathIncludes, ...pathspecExcludes];

const gitContext = {
  log: gitOut(["log", `--since=${sinceDate}`, "--stat", ...pathspec]),
  status: gitOut(["status", "--short", ...pathspec]),
  diffHead: gitOut(["diff", "HEAD", "--stat", ...pathspec]),
  excludes: pathExcludes,
  includes: pathIncludes,
  pathspec,
};

let pkgJsonCache;
function readRepoPkg() {
  if (pkgJsonCache !== undefined) return pkgJsonCache;
  const p = join(repoRoot, "package.json");
  if (!existsSync(p)) return (pkgJsonCache = null);
  try {
    pkgJsonCache = JSON.parse(readFileSync(p, "utf8"));
  } catch {
    pkgJsonCache = null;
  }
  return pkgJsonCache;
}

function hasPackageDep(name) {
  const pkg = readRepoPkg();
  if (!pkg) return false;
  return Boolean(
    (pkg.dependencies && pkg.dependencies[name]) ||
      (pkg.devDependencies && pkg.devDependencies[name]) ||
      (pkg.peerDependencies && pkg.peerDependencies[name]) ||
      (pkg.optionalDependencies && pkg.optionalDependencies[name])
  );
}

// Catches transitive deps (e.g. `babel-plugin-react-compiler` shipped via
// `expo` SDK rather than declared at the top level).
function hasNodeModule(name) {
  return existsSync(join(repoRoot, "node_modules", name, "package.json"));
}

// `path` is repo-relative, `pattern` is a JS regex source string. Used for
// build-flag style detection where a feature is opt-in via config rather
// than a top-level dep — e.g. Expo `experiments.reactCompiler: true`,
// Next.js `experimental.reactCompiler`, babel.config referencing a plugin.
function fileMatches(path, pattern) {
  const abs = join(repoRoot, path);
  if (!existsSync(abs)) return false;
  let txt;
  try {
    txt = readFileSync(abs, "utf8");
  } catch {
    return false;
  }
  let re;
  try {
    re = new RegExp(pattern);
  } catch {
    return false;
  }
  return re.test(txt);
}

// Evaluate a `when` clause. All top-level keys AND together. `anyOf` is
// itself an array of nested clauses, OR-ed. Supported keys:
//   packageDep / packageDeps  — declared in package.json
//   nodeModulesDep / nodeModulesDeps — present under node_modules/ (transitive ok)
//   fileExists / filesExist   — repo-relative paths must exist
//   fileContains              — { path, pattern } regex match against file contents
//   filesContain              — array of the above (all must match)
//   anyOf                     — [whenClause, ...]; passes if ANY nested passes
function evalWhen(when) {
  if (!when || typeof when !== "object") return { ok: true };
  const deps = []
    .concat(typeof when.packageDep === "string" ? [when.packageDep] : [])
    .concat(Array.isArray(when.packageDeps) ? when.packageDeps : []);
  for (const d of deps) {
    if (!hasPackageDep(d)) {
      return { ok: false, reason: `missing package dep '${d}'` };
    }
  }
  const nmDeps = []
    .concat(
      typeof when.nodeModulesDep === "string" ? [when.nodeModulesDep] : []
    )
    .concat(Array.isArray(when.nodeModulesDeps) ? when.nodeModulesDeps : []);
  for (const d of nmDeps) {
    if (!hasNodeModule(d)) {
      return { ok: false, reason: `missing node_modules/${d}` };
    }
  }
  const files = []
    .concat(typeof when.fileExists === "string" ? [when.fileExists] : [])
    .concat(Array.isArray(when.filesExist) ? when.filesExist : []);
  for (const f of files) {
    if (!existsSync(join(repoRoot, f))) {
      return { ok: false, reason: `missing file '${f}'` };
    }
  }
  const contains = []
    .concat(when.fileContains ? [when.fileContains] : [])
    .concat(Array.isArray(when.filesContain) ? when.filesContain : []);
  for (const c of contains) {
    if (!c || typeof c.path !== "string" || typeof c.pattern !== "string") {
      return { ok: false, reason: `bad fileContains clause` };
    }
    if (!fileMatches(c.path, c.pattern)) {
      return {
        ok: false,
        reason: `file '${c.path}' does not match /${c.pattern}/`,
      };
    }
  }
  if (Array.isArray(when.anyOf) && when.anyOf.length > 0) {
    const reasons = [];
    let matched = false;
    for (const sub of when.anyOf) {
      const r = evalWhen(sub);
      if (r.ok) {
        matched = true;
        break;
      }
      reasons.push(r.reason);
    }
    if (!matched) {
      return { ok: false, reason: `none of anyOf matched (${reasons.join("; ")})` };
    }
  }
  return { ok: true };
}

function runReport(label, cmd, when) {
  const w = evalWhen(when);
  if (!w.ok) {
    return { label, output: `(skipped: ${w.reason})`, status: -1 };
  }
  if (!Array.isArray(cmd) || cmd.length === 0) {
    return { label, output: "(skipped: empty cmd)", status: -1 };
  }
  const [exe, ...rest] = cmd;
  let r;
  try {
    r = spawnSync(exe, rest, {
      cwd: repoRoot,
      encoding: "utf8",
      timeout: 5 * 60 * 1000,
      maxBuffer: 32 * 1024 * 1024,
      env: { ...process.env, CI: "1", FORCE_COLOR: "0", NO_COLOR: "1" },
    });
  } catch (e) {
    return { label, output: `(skipped: ${e.message})`, status: -1 };
  }
  if (r.error) {
    return {
      label,
      output: `(skipped: ${r.error.code || r.error.message})`,
      status: -1,
    };
  }
  let out = `${r.stdout || ""}${r.stderr || ""}`.trim();
  if (!out) out = `(no output, exit=${r.status})`;
  const CAP = 16 * 1024;
  if (out.length > CAP) {
    const half = Math.floor(CAP / 2);
    out = `${out.slice(0, half)}\n... [truncated ${
      out.length - CAP
    } chars] ...\n${out.slice(-half)}`;
  }
  return { label, output: out, status: r.status ?? -1 };
}

const reports = reportsCfg.map((r) =>
  runReport(
    typeof r?.label === "string" ? r.label : "report",
    r?.cmd,
    r?.when
  )
);

// Surface known findings to Claude so it can dedup at write time. "open" =
// carryover candidates, "closed" = hands-off, "stale" = do-not-resurrect.
const knownFindings = Object.entries(state.findings).map(([fp, f]) => ({
  fingerprint: fp,
  priority: f.priority,
  evidence: f.evidence,
  text: f.text,
  fix: f.fix,
  feature: f.feature || null,
  status: f.status,
  firstSeenCycle: f.firstSeenCycle,
  lastSeenCycle: f.lastSeenCycle,
  closedInCycle: f.closedInCycle || null,
}));

const result = {
  repoRoot,
  superauditDir: dir,
  cyclePath,
  cycleRel,
  cycleNumber: cycleN,
  previousCycleNumber: lastCycleN || null,
  previousCycleFile: existingCycles.length
    ? existingCycles[existingCycles.length - 1].file
    : null,
  dateStr,
  sinceDate,
  branch,
  headSha,
  lockPath: lockDir,
  statePath,
  state,
  knownFindings,
  config,
  gitContext,
  reports,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
