# Source Priority Rules

Rules for the `research-topic` skill — what to include, what to block, and how to rank sources.

---

## Hard Block List (NEVER Add)

| Domain / Pattern | Reason |
|---|---|
| `*.wikipedia.org` | Not peer-reviewed; changes constantly; cannot be cited academically |
| Anonymous Medium posts (no author, no citations) | No academic credibility |
| `quora.com`, `reddit.com`, `stackoverflow.com` | Q&A forums, not primary sources |
| Paywalled articles with no open-access version | Cannot be read or ingested |
| Raw GitHub `README.md` files (unless it's the only authoritative doc) | Use official docs instead |

---

## Priority Tiers (Highest → Lowest)

### Tier 1 — Foundational / Seminal Papers
Peer-reviewed, high-citation. The field cannot be understood without them.

Sources: arXiv, ACL Anthology, NeurIPS, ICML, ICLR, IEEE Xplore (open-access PDFs only).

### Tier 2 — Survey / Comprehensive Review Papers
Identify by: "survey", "review", "overview", "comprehensive" in title.

### Tier 3 — Recent Papers (2022–2025)
State-of-the-art, directly relevant. Prefer those citing foundational works.

### Tier 4 — PhD Theses from Recognised Groups
CMU, Stanford, MIT, ETH Zurich, Oxford, Edinburgh, Johns Hopkins, etc.

### Tier 5 — University Course Materials
Lecture notes, slides, and course pages from top programmes.
Preferred: Stanford, MIT, CMU, Oxford.

### Tier 6 — YouTube (Reputable Educators)
Only substantive lectures or deep-dive explanations, not 5-minute overviews.

**Priority creators/channels:**
| Creator | Strengths |
|---|---|
| Andrej Karpathy | Neural nets, transformers, training intuition |
| Yannic Kilcher | Paper-by-paper deep dives |
| 3Blue1Brown | Mathematical intuition |
| Stanford CS (official) | Lecture recordings |
| MIT OpenCourseWare | Signal processing, NLP lectures |
| Hugging Face | Practical Transformers, PEFT, audio |
| Sebastian Raschka | Deep learning, LLMs, LoRA |

### Tier 7 — Distill / Lilian Weng / Jay Alammar
High-quality interactive or illustrated blog posts. Treat almost as Tier 2.

| Site | Notes |
|---|---|
| `distill.pub` | Peer-reviewed interactive visualisations |
| `lilianweng.github.io` | Deep, well-cited posts |
| `jalammar.github.io` | Illustrated attention, embeddings, BERT |

### Tier 8 — Official Library / Tool Documentation
Only when directly relevant to the topic's implementation areas.

### Tier 9 — Other Reputable ML Blogs
Must have: named author, citations or references, demonstrable technical depth.

---

## BibTeX Type Mapping

| Source type | BibTeX type |
|---|---|
| arXiv preprint | `@misc` with `eprint` + `archivePrefix = {arXiv}` |
| ACL / EMNLP / NAACL / Interspeech / ICASSP | `@inproceedings` |
| NeurIPS / ICML / ICLR | `@inproceedings` |
| Journal (JMLR, IEEE, etc.) | `@article` |
| PhD / ME thesis | `@phdthesis` |
| Book / monograph | `@book` |
| Blog post / web resource | `@online` (biblatex) |

---

## What Goes in refs.bib

**Add:**
- arXiv papers (Tier 1–3)
- ACL / NeurIPS / ICML / ICLR conference papers
- Journal articles
- PhD theses with a citable URL or handle

**Do NOT add:**
- YouTube videos
- Blog posts (including Lil'Log, Distill, Jalammar)
- Course slides / lecture notes
- Official library documentation

The `update_refs_bib.py` script enforces this by only accepting arXiv, ACL Anthology, and DOI-bearing URLs.

---

## Source Count Guidelines

| Topic type | Floor |
|---|---|
| Focused topic (single concept) | 15–20 sources |
| Broad topic (full domain survey) | 20–30 sources |
| Ad-hoc / narrow topic | 10–15 sources |

Never pad with low-quality results to hit numbers.
