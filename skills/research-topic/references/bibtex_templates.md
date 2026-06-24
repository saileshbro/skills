# BibTeX Templates

Format templates for refs.bib. Uses `biblatex` + `biber` style (not legacy `bibtex`).

---

## Key Naming Convention

**Format:** `AuthorYYYY`
- Last name of first author + 4-digit year
- CamelCase: capitalise first letter of last name
- Multiple works same author+year: append `a`, `b`, `c`
- Characters: letters + digits only

**Examples:**
```
Radford2022     ← Radford et al., 2022
Hu2021          ← Hu et al., 2021 (LoRA)
Vaswani2017     ← Vaswani et al., 2017 (Attention Is All You Need)
```

The `update_refs_bib.py` script generates keys automatically and handles collisions.

---

## arXiv Preprint (`@misc`)

```bibtex
@misc{AuthorYYYY,
  author        = {Last, First and Last2, First2},
  title         = {{Full Paper Title Exactly As Published}},
  year          = {2024},
  eprint        = {2212.04356},
  archivePrefix = {arXiv},
  primaryClass  = {cs.CL},
  url           = {https://arxiv.org/abs/2212.04356},
}
```

---

## Conference Paper (`@inproceedings`)

```bibtex
@inproceedings{AuthorYYYY,
  author    = {Last, First and Last2, First2},
  title     = {{Full Paper Title}},
  booktitle = {Proceedings of the 40th International Conference on Machine Learning},
  year      = {2023},
  doi       = {10.5555/...},
  url       = {https://arxiv.org/abs/...},
}
```

**Common booktitle strings:**
| Venue | Booktitle |
|---|---|
| ACL | `Proceedings of the Annual Meeting of the Association for Computational Linguistics` |
| NeurIPS | `Advances in Neural Information Processing Systems` |
| ICML | `Proceedings of the International Conference on Machine Learning` |
| ICLR | `Proceedings of the International Conference on Learning Representations` |

---

## Journal Article (`@article`)

```bibtex
@article{AuthorYYYY,
  author  = {Last, First and Last2, First2},
  title   = {{Full Paper Title}},
  journal = {Journal Name},
  year    = {2023},
  volume  = {31},
  pages   = {1000--1012},
  doi     = {10.1109/...},
}
```

---

## Book (`@book`)

```bibtex
@book{AuthorYYYY,
  author    = {Last, First and Last2, First2},
  title     = {{Book Title: Subtitle}},
  year      = {2023},
  publisher = {Publisher Name},
}
```

---

## PhD Thesis (`@phdthesis`)

```bibtex
@phdthesis{AuthorYYYY,
  author = {Last, First},
  title  = {{Thesis Title}},
  school = {University Name},
  year   = {2023},
  url    = {https://...},
}
```

---

## Author Formatting Rules

- Format: `Last, First` joined by ` and ` for multiple authors
- List all authors; do NOT use "et al." in BibTeX
- Name particles: `van den Berg, Jan` — use the form the author uses
