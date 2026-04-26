# Superaudit methodology

Authoritative rules for producing a cycle file. The skill (`SKILL.md`) wires the workflow; this file defines the substance.

## Scope

- Time window: commits since `sinceDate` (from prepare JSON) through HEAD (`headSha`).
- Include both committed and uncommitted state (staged, unstaged, untracked).
- Exclude lockfiles and binary asset bumps from per-line review; count them in totals only.
- Path scope is **already enforced** by the `gitContext` block in the prepare JSON. It reflects `pathExcludes`/`pathIncludes` from the per-repo config. **Do not read or audit files outside that scope.** If you believe you need a file not visible there, stop and ask the user.
- For each entry in `reports`, mine real issues. Skip the entry if its `output` starts with `(skipped: ...)` or `(no output, ...)`.

## Method

1. Enumerate commits and diff stats from `gitContext.log` + `gitContext.diffHead`. Group by feature/domain, not chronology.
2. For non-trivial files, read the diff with the same pathspec (`git show <sha> -- <pathspec>` or `git diff HEAD -- <pathspec>`); skim trivial ones.
3. Cross-check architecture, layering, naming, folder conventions. **Always consult repo `CLAUDE.md` / `AGENTS.md` if present** — they encode the rules this audit measures against. Also look for: `tokens.*` / design-system imports (drift = hardcoded values), `eslint`/`biome` config (suppressions or rule-disables in the diff), `tsconfig.json` paths (alias misuse).
4. Detect:
   - **Convention drift (primary focus)**: design-token bypass (hardcoded colors/spacing/typography), folder-structure violations (file in wrong layer/feature dir), naming-convention drift (file casing, component naming, prop naming), import alias misuse, lint/format suppressions added in diff.
   - **Architecture / layering**: cross-layer imports, package boundary leaks, top-level dir misuse, downward deps (e.g. `components/` importing from `features/`).
   - **Dead code / duplicates**: renamed-but-old-kept, orphan exports, unused files.
   - **Security**: committed secrets or `.env*.local`, weakened auth defaults, CORS/cookie/CSRF regressions, PII in logs, disabled checks.
   - **Performance**: N+1 queries, unmemoized heavy renders, bundle adds, sync I/O on hot paths, re-entrancy, unstable list keys.
   - **Tech debt**: `TODO`/`FIXME`/`HACK`, commented-out code, magic numbers, `any`, suppressed errors, `@ts-ignore`/`@ts-expect-error`.
   - **Scope creep**: commits mixing unrelated concerns.
   - **Test gaps**: new logic without tests, snapshot-only coverage for behavior.
   - **API/contract drift**: public exports changed without version bump, breaking prop changes.
5. **State-driven sweep (every cycle, not just diff)**. The window-and-grep loop misses repo-wide drift: empty dirs, stub-only features, orphan files, dead exports, doc↔reality drift. Always also walk current HEAD for:
   - **Empty directories** (`find -type d -empty`) — abandoned scaffolds violate the "closed list" contract.
   - **Closed-list drift** — `ls <src>` vs the bible's enumerated top-level dirs. Missing dirs the bible promises (e.g. `assets/`) and extra dirs not on the list both qualify.
   - **Stub-only features** — feature dirs whose total source byte-count is below ~2 KB are placeholder shells masquerading as real features.
   - **Orphan files** — files with zero inbound imports (`rg "from .*<basename>"` returns 0). Special attention to `*-screen.tsx` / `*-component.tsx` in shared dirs.
   - **Cross-feature import graph** — for each `features/<X>`, grep `@/features/(?!X)` inside it; flag any hits unless annotated.
   - **Dead exports** — exported symbols in feature `types.ts` / `constants.ts` / `index.ts` whose grep returns 0 inbound consumers.
   - **Bible drift** — for every "MUST DO" / "DO" rule that names a path or file pattern, grep current HEAD to verify reality matches.

## Dedup against prior cycles

Before writing a finding, consult `knownFindings` from the prepare JSON:

- **`status: "open"`** — re-evaluate against current HEAD. If the issue still applies, list under **Still open (carried)** and **preserve the existing `<!-- fp: ... -->` marker verbatim**. If it no longer applies, omit it (finalize will mark it `stale`). Do not re-fingerprint a carried finding under any circumstances.
- **`status: "closed"`** — never re-add. The user explicitly closed it (or finalize marked it closed via a `[x]` check-off).
- **`status: "stale"`** — only re-add if you have direct evidence the issue has actually returned (regression). Treat re-add as a **New this cycle** entry; finalize will reopen it in state automatically.

## Output

Write `cyclePath` (Write tool) using exactly this structure. Every finding MUST be a GitHub markdown task list item with `[P0|P1|P2]` so users can check it off:

`- [ ] [P0|P1|P2] <concrete finding>. Evidence: <file:line or SHA or report:rule>. Fix: <one-line hint>. <!-- fp: <hex> -->`

The `<!-- fp: ... -->` marker is **required** for carried-over findings (copy from `knownFindings`). For new findings you may omit it — `finalize.mjs` injects one.

Template:

```markdown
# Superaudit Cycle <N> — <branch> — <date>

## Summary

- Commits since cycle-<N-1>: M
- Files touched: K (+added / ~modified / -deleted)
- LOC: +X / -Y
- New findings: A
- Still open (carried): B
- Closed since last cycle: C
- Stale (no longer applicable): D
- Top risks: 3–5 bullets

## Priority Legend

- P0 — ship-blocker / security / data-loss risk
- P1 — correctness, arch violation, or near-term debt
- P2 — cleanup / polish / nice-to-have

## Findings by Feature

### <Feature name>

**Files**

- path/to/file.ts (+X/-Y) <role: component|module|config|...>

**What changed**

- 1–3 bullets, plain language.

**New this cycle**

- [ ] [P0] ... Evidence: ... Fix: ...
- [ ] [P1] ... Evidence: ... Fix: ...

**Still open (carried)**

- [ ] [P1] ... Evidence: ... Fix: ... <!-- fp: abc123def456 -->
  <!-- carried from cycle-005 -->

**Closed since last cycle**

- [x] [P0] ... Evidence: ... Fix: ... <!-- fp: 789ghi012jkl -->
  <!-- closed in cycle-006 by user check-off -->

## Cross-cutting Issues

- Convention drift, repeated patterns, systemic gaps. Same `- [ ] [Px] ...` format applies — these get fingerprinted too.

## Action Plan (ranked)

Ordered list pulling from the priority queue across all features. Reference findings by their fp marker so the user can navigate.

1. P0 — <short title> — `fp: abc123...`
2. P1 — <short title> — `fp: def456...`

## Open Questions

- Things needing human decision before fix. Not findings, no fingerprint, no checkbox.
```

## Applying findings (the plan→approve→apply seam)

The skill writes findings; it does **not** apply them. Cycle files are the proposal layer. Skipping straight from "finding" to "edit the file" loses the bible-vs-finding sanity check and is the failure mode that produces "the audit damaged the repo." Treat application as its own pipeline:

1. **Group findings into a plan.** From the cycle file, bucket each fp by:
   - **Mechanical** — single-file rename, lint annotation, dead-import strip. Risk: low.
   - **Structural** — directory move, file lift, dep boundary change. Risk: medium.
   - **Cross-cutting** — pattern sweeps across many files (logger adoption, store splits, route gating). Risk: high.

2. **Re-read the bible per finding.** Before each edit, walk `CLAUDE.md` / `AGENTS.md` rules that name the same path or pattern. If the proposed fix would create a new violation (downward dep, store split, cross-feature import), **skip** the finding and surface the conflict in the plan: "fp X rejected — `Fix:` text would violate §N.M (<reason>). Suggest alternative: <…>." Do not apply silently.

3. **Pause for approval before structural and cross-cutting changes.** Mechanical changes can run unattended. Structural and cross-cutting changes need explicit user "go" — show the grouped plan first, list the rejected-with-reason items, and wait. The user check-off on a finding line is not the same as approval to apply; it's a "decided not to act" signal.

4. **Apply, verify, check off.** After each edit, run the same lint/tsc gates the skill ran during prepare. On clean, flip `[ ]` → `[x]` on the finding line in the cycle file (this is the only legitimate edit to a prior cycle, per `## Rules` below). On regression, revert and surface in the plan.

5. **Carry rejected findings forward.** Items rejected for bible conflict are not "stale" — they are open and unfixable in the proposed shape. Document the rejection in the next cycle's `## Open Questions`, not as a closure.

This pipeline is what the skill *recommends* operators (human or agent) follow. The skill does not enforce it; it only ships the proposal artifact.

## Rules

- Every finding needs evidence: file path + line range, or commit SHA, or `<report-label>:<rule>`. No evidence = don't write the finding.
- No vague verdicts. Concrete smell + concrete one-line fix.
- Do not modify source files. Only Write `cyclePath`. (Finalize will edit the cycle file in place to inject fp markers — that's expected.)
- **Carried findings**: preserve the existing `<!-- fp: ... -->` marker verbatim. A new fp on a re-detected finding will double-count it in state.
- **Closed findings (`status: "closed"` in `knownFindings`)**: never re-add, even if the underlying drift still exists. The user's check-off is the authoritative signal that they've decided not to act on it.
- **Stale findings**: only re-add if you have direct evidence the regression returned.
- New findings go under **New this cycle** as `- [ ]` (no fp needed; finalize injects one).
- If `gitContext` shows zero in-scope changes, write a Summary note saying no in-scope changes were detected, plus the **Still open (carried)** section if any open findings remain. Don't fabricate filler.
- Do not include any author or per-person attribution. The cycle is project-wide.
- Do not edit prior `cycle-NNN.md` files. They are immutable history. Closures propagate via the user editing prior cycles' `[ ]` → `[x]`; that's the only legitimate edit.
