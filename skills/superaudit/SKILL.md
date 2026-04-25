---
name: superaudit
description: 'Generate a manually-triggered, prioritized (P0/P1/P2) **codebase audit** of recent repo changes against the project''s declared conventions — design tokens, folder structure, naming, import/layering rules, lint/format config, and any rules captured in `CLAUDE.md` / `AGENTS.md`. Output is an append-only cycle report at `superaudit/cycle-NNN.md`, with findings deduplicated across cycles via fingerprint state. Use this skill whenever the user types `/superaudit` or `/superaudit override`, or says any of "superaudit", "audit this branch", "audit the diff", "run audit", "generate audit", "review my recent changes", "review the diff against our conventions", "did the recent changes follow our standards", "check the new code against our coding practices / design tokens / folder structure", "what''s risky on this branch", or asks for a structured P0/P1/P2 review of recent commits + working-tree changes. Preserves checked-off items across cycles, flags carryover/closed/stale findings, single project-wide cycle (no per-author split). Prefer this skill over an ad-hoc chat-style review whenever the user wants a written, checkable artifact that grades the diff against repo conventions.'
---

# Superaudit

Manually-triggered, project-agnostic audit of recent repo changes against declared conventions. Cycles are append-only files at `superaudit/cycle-NNN.md`. Dedup across cycles is fingerprint-based: each finding gets a stable `<!-- fp: ... -->` marker, and a state file (`superaudit/_state.json`) tracks which findings are open / closed / stale across the whole history.

The presence of a `superaudit/` directory at the repo root is the opt-in signal — refuse to run if it's missing, because auto-creating it would silently enroll repos the user didn't intend to audit.

## Preconditions

- Inside a git repo. (`prepare.mjs` exits `NOT_A_REPO` otherwise.)
- Repo root contains a `superaudit/` directory.

## Workflow

The skill ships two scripts in `scripts/`. Resolve their absolute path from this SKILL.md's location; don't assume a fixed install location.

### 1. Run prepare

```bash
node <skill-dir>/scripts/prepare.mjs
```

`prepare.mjs` gathers everything needed (git context, configured reports, prior cycles, state, lock) and prints **one JSON object on stdout**. On a blocked or error state it prints `{ "error": "...", "code": "..." }` to stderr and exits non-zero — parse that, don't guess from exit code alone.

What it does internally:
- Loads `superaudit/_state.json` (or initializes empty).
- Computes the next cycle number `N` from the highest existing `cycle-NNN.md` plus 1.
- Scrapes `- [x]` lines from prior cycle files; any with a `<!-- fp: ... -->` marker matching a state finding gets marked `closed` — that's how user check-offs propagate.
- Builds path-scoped git context and runs configured reports.

JSON shape (stdout, success):

```
{
  "repoRoot": "/abs/path",
  "superauditDir": "/abs/path/superaudit",
  "cyclePath": "/abs/path/superaudit/cycle-007.md",
  "cycleRel":  "superaudit/cycle-007.md",
  "cycleNumber": 7,
  "previousCycleNumber": 6,
  "previousCycleFile": "cycle-006.md",
  "dateStr":   "2026-04-25",
  "sinceDate": "2026-04-24T...",
  "branch":    "main",
  "headSha":   "deadbeef...",
  "lockPath":  "/abs/path/superaudit/.lock.d",
  "statePath": "/abs/path/superaudit/_state.json",
  "state":     { "version": 1, "lastCycle": 6, "findings": { ... } },
  "knownFindings": [
    {
      "fingerprint": "abc123...",
      "priority": "P1",
      "evidence": "src/Button.tsx:42",
      "text": "...",
      "fix": "...",
      "feature": "checkout",
      "status": "open",            // open | closed | stale
      "firstSeenCycle": 3,
      "lastSeenCycle": 6,
      "closedInCycle": null
    }
  ],
  "config":    { ...as loaded... },
  "gitContext": {
    "log":    "...git log --since=... --stat -- <pathspec>",
    "status": "...git status --short -- <pathspec>",
    "diffHead": "...git diff HEAD --stat -- <pathspec>",
    "excludes": ["apps/web", ...],
    "includes": [],
    "pathspec": ["--", ":(exclude)apps/web", ...]
  },
  "reports": [
    { "label": "Lint", "output": "...", "status": 0 },
    ...
  ]
}
```

### 2. Handle error codes

| `code` | Meaning | Action |
|--------|---------|--------|
| `NOT_A_REPO` | Not in git | Tell user to cd into a repo. Stop. |
| `NO_SUPERAUDIT_DIR` | Repo missing `superaudit/` | Ask user if they want to opt in (`mkdir superaudit/`). Don't auto-create — the directory is the deliberate opt-in. |
| `BAD_CONFIG` | `superaudit/.config.json` invalid JSON | Show parse error, ask user to fix. Stop. |
| `BAD_STATE` | `superaudit/_state.json` invalid JSON | Show error. Don't auto-repair — the user may want to recover prior closures. Stop. |
| `LOCKED` | Another run holds the lock (<5 min) | Tell user, suggest waiting or removing `superaudit/.lock.d/` if known stale. Stop. |

On any of these `prepare.mjs` releases its own lock before exiting — you don't need to call `finalize.mjs`.

### 3. Read methodology

Read `references/audit-methodology.md` (sibling to this SKILL.md). It defines the SCOPE rules, METHOD, OUTPUT structure, and the substantive RULES for what counts as a finding. Treat it as authoritative — the workflow here is just plumbing.

### 4. Generate the cycle file

Use `gitContext` + `reports` from the JSON as the evidence base. The pathspec already encodes configured includes/excludes — files outside that scope are off-limits, because the per-repo config is the user's contract for what to audit. If you think you need a file outside scope, stop and ask.

Dedup via `knownFindings`:
- For each `knownFindings` entry with `status: "open"`: re-evaluate it against the current HEAD. If it still applies, include it under **Still open (carried)** with its existing fingerprint marker. If it no longer applies, omit it (finalize will mark it `stale`).
- For each `knownFindings` entry with `status: "closed"`: do not re-add it under any circumstances. Closed is closed.
- For each `knownFindings` entry with `status: "stale"`: only re-add if you have direct evidence the finding has actually returned (e.g. someone re-introduced the regression). In that case, list it under **New this cycle**.

For each `report` whose `output` starts with `(skipped: ...)` or `(no output, ...)`, ignore it. For the rest, mine real issues and tag them `Evidence: <label>:<rule-or-line>`.

Write the result to `cyclePath` using the **Write** tool. New findings can be written without a `<!-- fp: ... -->` marker — finalize.mjs will compute and inject one. For carried-over findings, **always** preserve the existing `<!-- fp: ... -->` marker verbatim from `knownFindings` so the same fingerprint is reused (otherwise you'll double-count).

If `gitContext` shows zero in-scope changes, write a near-empty cycle file: a Summary line saying no in-scope changes were detected, and the **Still open (carried)** section if any open findings remain. Don't fabricate filler.

### 5. Run finalize

```bash
node <skill-dir>/scripts/finalize.mjs <statePath> <cyclePath> <cycleNumber> <lockPath>
```

`finalize.mjs`:
- Re-parses the cycle file, extracting findings.
- Computes a fingerprint per finding (`sha1(priority|normPath(evidence)|normText(text)).slice(0,12)`); reuses any existing `<!-- fp: ... -->` marker.
- Updates `_state.json`: new findings added, recurring findings get `lastSeenCycle` bumped, previously-open findings not seen this cycle become `stale`.
- Injects missing `<!-- fp: ... -->` markers into the cycle file in place.
- Releases the lock — even on error, because a stuck lock blocks the next run for 5 min and that's worse than a half-finalized state.

Run finalize after **every** Write attempt — success or failure — for the lock-release reason above.

### 6. Report to user

One sentence: which cycle file was written, the cycle number, finding counts (new / still open / closed / stale), and that it's ready for review/commit. Do not commit yourself — the cycle is a document for the user to act on.

## How dedup actually works

The fingerprint algorithm is `sha1(priority|normPath(evidence)|normText(text)).slice(0,12)` where:
- `normPath` strips line ranges (`:42-50` → ``), backticks, parens, lowercases, removes whitespace.
- `normText` lowercases, strips markdown emphasis chars, collapses whitespace.

This means a re-detection of the same issue on the same file will fingerprint identically even if the line number drifted slightly or wording shifted in case. It does **not** dedup across rewordings — that's intentional: if Claude restates an issue meaningfully differently, treat it as a separate signal worth surfacing.

The user check-off mechanism: when the user edits a `cycle-NNN.md` file and changes `- [ ]` to `- [x]` on a finding line, the next `prepare.mjs` run scans the fp marker on that line and marks the matching state entry as `closed`. From that point on, the finding never resurfaces — even if the underlying code drift is still present, the user's check-off is the authoritative "I've decided not to act on this" signal.

## Config schema (`superaudit/.config.json` at repo root)

All keys optional.

```json
{
  "pathExcludes": ["apps/native-old", "apps/web"],
  "pathIncludes": [],
  "sinceHours": 24,
  "reports": [
    { "label": "Lint", "cmd": ["bun", "run", "lint"] }
  ]
}
```

- `pathExcludes`: git pathspecs added as `:(exclude)<path>` to every git query and surfaced to the auditor as the path-scope contract.
- `pathIncludes`: positive pathspecs (additive). Empty = whole repo (minus excludes).
- `sinceHours`: time window for `git log --since=` (default 24).
- `reports`: array of `{ label, cmd }`. `cmd` is `[exe, ...args]` — runs from repo root, 5-min timeout, output capped at 16 KB (head+tail). Empty/missing = no reports.

A reference example lives at `references/config-example.json`.

## Files in this skill

- `scripts/prepare.mjs` — gathers context, loads state, scrapes prior check-offs, acquires lock, runs reports, prints JSON.
- `scripts/finalize.mjs` — parses cycle file, computes fingerprints, updates state, injects fp markers, releases lock.
- `references/audit-methodology.md` — methodology and cycle file schema (the substance of the audit).
- `references/config-example.json` — reference per-repo config.
