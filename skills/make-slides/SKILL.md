---
name: make-slides
description: Write and compile Beamer (LaTeX PDF) slides from a topic summary or outline. Use when the user wants slides compiled or written, says "/make-slides", "write the slides", "compile slides", "make a Beamer deck", "build a PDF presentation", or has finished research and needs a PDF. Also invoked by the slides-with-research orchestrator after research-topic completes.
---

# Make Slides

Write **Beamer slides** (metropolis theme, pdflatex) from a `summary.md` + `refs.bib` in the output directory. Sections become separate files in `sections/`; the root `main.tex` inputs them.

**Explicit:** `/make-slides`

---

## Phase 0 — Inputs

Determine the output directory. Check for `summary.md` and `refs.bib`:

```bash
ls <output-dir>/
cat <output-dir>/summary.md 2>/dev/null
```

- If `summary.md` is missing: ask the user for the topic, audience, and a rough outline before proceeding. You'll write the slides from their description instead.
- If `refs.bib` is missing: slides compile without a bibliography — proceed, note this to the user.

If audience and slide count (or talk length) are not known, ask before writing (one question at a time):

1. **Audience** — who are the slides for?
2. **Talk length** — 15 / 30 / 45 / 60 min? (determines frame density, see `references/beamer_template.md`)
3. **Author name and affiliation** — for the title frame (or "skip" to leave blank)

---

## Phase 1 — Scaffold

Create the output-dir structure:

```bash
mkdir -p <output-dir>/sections
```

Write `<output-dir>/main.tex` using the template in `references/beamer_template.md`. Fill in title, author, affiliation from Phase 0. The `\input{sections/...}` lines will be added as you write sections in Phase 2.

If `refs.bib` exists, it is already in `<output-dir>/` — `\addbibresource{refs.bib}` in main.tex picks it up automatically.

---

## Phase 2 — Write section content

Derive sections from the **Suggested Slide Outline** in `summary.md`, or from the user's rough outline if summary.md was missing.

For each section:
1. Create `<output-dir>/sections/NN-<slug>.tex`
2. Open with `\section{Section Title}`
3. Write 3–8 frames depending on talk length (see slide density guide in `references/beamer_template.md`)
4. Frame writing rules:
   - Max 5 bullet points per frame, ≤ 10 words per bullet
   - Equations get their own frame
   - Cite papers inline: `\parencite{AuthorYYYY}` (keys come from refs.bib)
   - Read the key concepts and primary papers from `summary.md` for this section
5. Add `\input{sections/NN-<slug>}` to main.tex after the previous section's input line

Completion criterion: every section has ≥ 3 frames and its `\input{...}` line is in main.tex.

---

## Phase 3 — Compile

```bash
cd <output-dir>
latexmk -pdf -interaction=nonstopmode -bibtex main.tex
```

On error: read the last 50 lines of `main.log` to identify the LaTeX error, fix it, and retry once. If it fails again, show the user the error message.

Verify:
```bash
ls -lh <output-dir>/main.pdf
```

---

## References

| Path | Purpose |
|------|---------|
| `references/beamer_template.md` | Full preamble, frame patterns, compilation commands, slide density guide |

---

## Completion criterion

Done when `<output-dir>/main.pdf` exists and is non-empty. Report its path to the user.
