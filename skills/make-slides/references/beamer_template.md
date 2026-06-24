# Beamer Template Reference

Self-contained template for `make-slides` skill. All slides use pdflatex + biblatex + biber.

---

## main.tex

```latex
\documentclass[10pt, aspectratio=169]{beamer}

% ── Theme ─────────────────────────────────────────────────────────────────────
\usetheme{metropolis}
\usepackage{appendixnumberbeamer}

% ── Core packages ─────────────────────────────────────────────────────────────
\usepackage{booktabs}
\usepackage{amsmath, amssymb, amsthm}
\usepackage{mathtools}
\usepackage{bm}
\usepackage{xcolor}
\usepackage{graphicx}
\usepackage{tikz}
\usepackage{pgfplots}
\pgfplotsset{compat=1.18}
\usetikzlibrary{arrows.meta, positioning, shapes.geometric, fit, backgrounds}
\usepackage{hyperref}

% ── Bibliography (biblatex + biber) ──────────────────────────────────────────
\usepackage[
  style=authoryear-comp,
  backend=biber,
  maxcitenames=2,
  maxbibnames=6,
  url=false,
  doi=false,
  isbn=false,
]{biblatex}
\addbibresource{refs.bib}

% ── Colour palette ───────────────────────────────────────────────────────────
\definecolor{accentBlue}{HTML}{2E86AB}
\definecolor{accentRed}{HTML}{C0392B}
\definecolor{darkBg}{HTML}{1C1C1C}
\setbeamercolor{frametitle}{bg=darkBg}
\setbeamercolor{progress bar}{fg=accentRed}
\setbeamercolor{alerted text}{fg=accentRed}

% ── Metadata ─────────────────────────────────────────────────────────────────
\title{[TALK TITLE]}
\subtitle{[SUBTITLE — optional]}
\author{[AUTHOR NAME]}
\institute{[INSTITUTION — optional]}
\date{\today}

\begin{document}

\maketitle

\begin{frame}{Outline}
  \tableofcontents
\end{frame}

% ── Sections — one \input per section file ────────────────────────────────────
\input{sections/01-introduction}
% \input{sections/02-...}
% ...

\begin{frame}[allowframebreaks]{References}
  \printbibliography[heading=none]
\end{frame}

\end{document}
```

---

## Section file structure (`sections/NN-slug.tex`)

Each section is a separate file in `sections/`. The skill creates one file per section from the outline.

```latex
% sections/01-introduction.tex

\section{Introduction}

\begin{frame}{[Frame title]}
  [Content — keep to 4–5 bullet points or one block/equation per frame]
\end{frame}

\begin{frame}{[Frame title 2]}
  \begin{itemize}
    \item Point one (cite if sourced: \parencite{AuthorYYYY})
    \item Point two
    \item Point three
  \end{itemize}
\end{frame}
```

---

## Frame patterns

### Bullet list frame
```latex
\begin{frame}{Title}
  \begin{itemize}
    \item First point
    \item Second point \parencite{Author2023}
  \end{itemize}
\end{frame}
```

### Two-column frame
```latex
\begin{frame}{Title}
  \begin{columns}[T]
    \begin{column}{0.5\textwidth}
      [Left content]
    \end{column}
    \begin{column}{0.5\textwidth}
      [Right content]
    \end{column}
  \end{columns}
\end{frame}
```

### Block frame (definition / insight)
```latex
\begin{frame}{Title}
  \begin{block}{Block Heading}
    Key insight or definition.
  \end{block}
\end{frame}
```

### Equation frame
```latex
\begin{frame}{Title}
  \begin{equation}
    P(W \mid O) = \frac{P(O \mid W) \cdot P(W)}{P(O)}
  \end{equation}
  \begin{itemize}
    \item $P(O \mid W)$: acoustic model
    \item $P(W)$: language model
  \end{itemize}
\end{frame}
```

---

## Compilation commands

```bash
# Full build (recommended — handles biber automatically)
cd <output-dir>
latexmk -pdf -interaction=nonstopmode -bibtex main.tex

# Clean auxiliary files
latexmk -C

# If biber isn't auto-triggered:
pdflatex main.tex
biber main
pdflatex main.tex
pdflatex main.tex
```

---

## Makefile (optional, drop in output-dir)

```makefile
.PHONY: slides clean

slides:
	latexmk -pdf -interaction=nonstopmode -bibtex main.tex

clean:
	latexmk -C
	rm -f *.nav *.snm *.vrb
```

---

## Slide density guide

| Talk length | Total frames | Frames per section |
|---|---|---|
| 15 min | 12–15 | 3–4 |
| 30 min | 20–25 | 4–6 |
| 45 min | 30–35 | 5–7 |
| 60 min | 40–50 | 6–8 |

Never put more than 5 bullet points on a single frame. Equations get their own frame.
