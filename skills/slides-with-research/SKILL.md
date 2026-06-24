---
name: slides-with-research
description: Full pipeline — grill user for topic + audience, research with Exa (research-topic), write and compile Beamer slides (make-slides). Use when the user says "make slides on X", "/slides-with-research", "research and create slides for X", "I need a presentation on X", "build a slide deck on X", "prepare a talk on X", "create slides about X". Prefer this skill over ad-hoc slide creation whenever the user wants sourced, compiled slides on a topic.
---

# Slides with Research

End-to-end pipeline: **grill → research → slides**. Sub-skills own each phase; this orchestrator orders the work and detects where to resume.

**Explicit:** `/slides-with-research`

---

## State detection (run first)

Check the output directory — use `slides/<topic-slug>/` in CWD if not known yet:

```bash
ls <output-dir>/ 2>/dev/null
```

| What exists | Resume at |
|-------------|-----------|
| Nothing / no output dir | Phase 1 — Grill |
| Output dir only | Phase 1 — Grill |
| `summary.md` + `refs.bib` present | Phase 3 — Slides |
| `sections/` + `main.tex` present | Phase 4 — Compile only |
| `main.pdf` newer than `main.tex` | Done — confirm with user |

---

## Phase 1 — Grill

Invoke the `/grilling` skill to establish all of the following (one question at a time, with a recommended answer for each):

1. **Topic** — specific enough to write targeted search queries
2. **Audience** — who will see these slides?
3. **Depth** — surface overview or deep academic coverage?
4. **Output directory** — where to write everything (default: `slides/<topic-slug>/` in CWD)
5. **Rough outline** — optional; will be derived from research if absent
6. **Existing sources** — any papers or links already in scope?
7. **Time budget** — how long is the talk? (e.g. "30 min" → ~20–25 frames)

Do not proceed to Phase 2 until all answers are confirmed.

---

## Phase 2 — Research

Follow the **research-topic** skill. Resolve its SKILL.md path from the skill registry or `<skill-dir>/../research-topic/SKILL.md`.

Pass: topic, audience, depth, output directory from Phase 1.

---

## Phase 3 — Slides

Follow the **make-slides** skill. Resolve its SKILL.md path from the skill registry or `<skill-dir>/../make-slides/SKILL.md`.

Pass: output directory (which now contains `summary.md` + `refs.bib` from Phase 2), audience, talk length from Phase 1.

---

## Completion criterion

Done when `<output-dir>/main.pdf` exists and is non-empty. Report the full path to the user.
