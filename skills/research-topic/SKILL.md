---
name: research-topic
description: Deep Exa research on any topic — 8-search pattern (foundational + recent + surveys + YouTube + blogs + courses + theses + books), coverage gap-fill, deduplication, refs.bib for academic papers, and a structured summary.md. Use when the user wants to research a topic, find papers, gather sources, or says "/research-topic", "find sources on X", "research X for me", "gather papers on X", "Exa search for X", "find me articles on X". Also invoked by the slides-with-research orchestrator.
---

# Research Topic

Produce **curated sources** and a **summary.md** for any topic. Output lands in an output directory (defaulting to `slides/<topic-slug>/` in CWD).

**Explicit:** `/research-topic`

---

## Phase 0 — Inputs

If any of the following are unknown, grill the user (one question at a time, provide a recommended answer for each):

1. **Topic** — specific enough to write targeted Exa queries
2. **Audience** — who will read / watch this? (e.g. graduate students, industry practitioners, general public)
3. **Depth** — overview or deep academic coverage?
4. **Output directory** — where to write refs.bib and summary.md (default: `slides/<topic-slug>/` in CWD)
5. **Existing context** — any papers or links already in scope?

Derive `<topic-slug>` as lowercase-hyphenated from the topic name (e.g. "RAG Systems" → `rag-systems`).

After all answers are confirmed, proceed.

---

## Phase 1 — Output directory + topic reference

```bash
mkdir -p <output-dir>
cat <output-dir>/topic-reference.md 2>/dev/null
```

If `topic-reference.md` exists in the output dir, use its keywords, key authors, and high-value sites to sharpen Phase 2 queries. Otherwise **derive** all 8 query sets dynamically from the topic.

---

## Phase 2 — Source discovery (Exa)

Use Exa MCP (`mcp__plugin_exa_exa__web_search_exa`) with `livecrawl: "always"`. Run **all 8** searches; collect and dedupe URLs across all runs. **Skip any `*.wikipedia.org` result.**

### Search 1 — Foundational papers
```
[topic] foundational seminal paper site:arxiv.org OR site:aclanthology.org OR site:papers.nips.cc OR site:proceedings.mlr.press
```
*numResults: 5*

### Search 2 — Latest papers (2022–2025)
```
[topic] 2023 2024 paper research arxiv
```
*numResults: 5*

### Search 3 — Survey / reviews
```
[topic] survey comprehensive review overview 2021 2022 2023 2024
```
*numResults: 4*

### Search 4 — YouTube lectures
```
[topic] lecture tutorial site:youtube.com
[topic] explained youtube Karpathy OR "Yannic Kilcher" OR "3Blue1Brown" OR stanford OR "MIT OpenCourseWare" OR "Hugging Face"
```
*numResults: 5 each, dedupe*

### Search 5 — Reputed blogs
```
[topic] site:lilianweng.github.io OR site:distill.pub OR site:jalammar.github.io OR site:huggingface.co/blog OR site:openai.com/blog OR site:ai.google/research
```
*numResults: 5*

### Search 6 — University course materials
```
[topic] lecture notes slides course site:stanford.edu OR site:mit.edu OR site:cs.cmu.edu OR site:oxford.ac.uk
```
*numResults: 4*

### Search 7 — Theses
```
[topic] thesis dissertation PhD 2019 2020 2021 2022 2023
```
*numResults: 4*

### Search 8 — Books / free chapters
```
[topic] textbook book chapter site:d2l.ai OR site:deeplearningbook.org OR site:jmlr.org
```
*numResults: 4*

### Coverage review and gap-fill (required)

1. **Dedupe** URLs; apply `references/source_priority_rules.md` (block list + tier order).
2. **Tier check:** seminal papers, surveys, recent papers, theses, courses, video, blogs/docs.
   - **Thin** = fewer than 2 confirmed URLs from that tier after dedup.
   - For each thin tier: run up to 2 targeted gap-fill Exa queries. Stop when ≥ 2 sources or total URL count hits 50.
3. **Volume:** aim for 15–50 distinct high-value URLs.

---

## Phase 3 — Build refs.bib

For each academic paper URL (arXiv, ACL Anthology, DOI-bearing URL):

```bash
python3 <skill-dir>/scripts/update_refs_bib.py \
  --output-dir <output-dir> \
  --url <paper_url>
```

Where `<skill-dir>` is the absolute path to this skill's directory (resolved from this SKILL.md's location — do not assume a fixed install path).

Do **not** add BibTeX for YouTube, blogs, or course pages. See `references/bibtex_templates.md`.

Log `⚠ Failed: [url]` on error and continue.

---

## Phase 4 — Write summary.md

Write `<output-dir>/summary.md`:

```markdown
# Research Summary: [Topic]

## Audience
[audience]

## Depth
[surface overview | deep academic]

## Key Concepts
- [concept]
...

## Primary Papers
- [Title (Author, Year)] — [one-line description]
...

## Survey / Review Sources
- [Title or URL] — [one-line description]
...

## Video / Course Resources
- [Title / channel (URL)] — [one-line description]
...

## Blog / Documentation
- [Title (URL)] — [one-line description]
...

## Suggested Slide Outline
1. [Section title]
2. [Section title]
...

## All Curated Sources
[flat list of all URLs, one per line]
```

---

## Scripts and references

| Path | Purpose |
|------|---------|
| `scripts/update_refs_bib.py` | Append BibTeX from arXiv / ACL / DOI URLs |
| `references/source_priority_rules.md` | Allow/block list + tier order |
| `references/bibtex_templates.md` | BibTeX entry conventions |

---

## Completion criterion

Done when:
- `<output-dir>/refs.bib` exists with ≥ 1 entry (or no academic papers were found — state that explicitly)
- `<output-dir>/summary.md` exists with all sections populated
- Source count and refs.bib entry count reported to user
