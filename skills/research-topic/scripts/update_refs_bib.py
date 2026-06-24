#!/usr/bin/env python3
"""update_refs_bib.py — fetch paper metadata and append a BibTeX entry to a refs.bib file.

Supports arXiv URLs/IDs, ACL Anthology URLs, DOIs, and Semantic Scholar paper pages.
Uses only Python stdlib — no extra dependencies required.

Usage:
    python3 update_refs_bib.py --output-dir ./slides/rag-systems --url https://arxiv.org/abs/2212.04356
    python3 update_refs_bib.py --output-dir ./slides/rag-systems --arxiv 2106.09685
    python3 update_refs_bib.py --output-dir ./slides/rag-systems --doi 10.18653/v1/2020.acl-main.561
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


# ── URL / ID parsers ───────────────────────────────────────────────────────────

def extract_arxiv_id(url_or_id: str) -> str | None:
    patterns = [
        r"arxiv\.org/(?:abs|pdf)/(\d{4}\.\d{4,5}(?:v\d+)?)",
        r"arxiv\.org/(?:abs|pdf)/([a-z\-]+/\d{7}(?:v\d+)?)",
        r"^(\d{4}\.\d{4,5}(?:v\d+)?)$",
        r"^([a-z\-]+/\d{7}(?:v\d+)?)$",
    ]
    for pattern in patterns:
        m = re.search(pattern, url_or_id, re.IGNORECASE)
        if m:
            return m.group(1).split("v")[0]
    return None


def extract_acl_id(url: str) -> str | None:
    m = re.search(r"aclanthology\.org/([A-Z0-9\-\.]+)", url, re.IGNORECASE)
    return m.group(1) if m else None


def extract_doi(url_or_doi: str) -> str | None:
    m = re.search(r"(10\.\d{4,}/[^\s\"'<>]+)", url_or_doi)
    return m.group(1).rstrip(".,)") if m else None


# ── Metadata fetchers ──────────────────────────────────────────────────────────

def _http_get(url: str, headers: dict[str, str] | None = None) -> bytes:
    req = urllib.request.Request(url, headers=headers or {"User-Agent": "research-topic-skill/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read()


def fetch_arxiv_metadata(arxiv_id: str) -> dict | None:
    api_url = f"https://export.arxiv.org/api/query?id_list={arxiv_id}&max_results=1"
    try:
        data = _http_get(api_url)
    except urllib.error.URLError as e:
        print(f"  ⚠ arXiv API error for {arxiv_id}: {e}", file=sys.stderr)
        return None

    ns = {
        "atom": "http://www.w3.org/2005/Atom",
        "arxiv": "http://arxiv.org/schemas/atom",
    }
    root = ET.fromstring(data)
    entry = root.find("atom:entry", ns)
    if entry is None:
        return None

    def txt(tag: str) -> str:
        el = entry.find(tag, ns)
        return el.text.strip() if el is not None and el.text else ""

    authors = [
        a.find("atom:name", ns).text.strip()
        for a in entry.findall("atom:author", ns)
        if a.find("atom:name", ns) is not None
    ]
    title = re.sub(r"\s+", " ", txt("atom:title"))
    year_raw = txt("atom:published")
    year = year_raw[:4] if year_raw else ""
    journal_ref = txt("arxiv:journal_ref")
    doi = txt("arxiv:doi")
    categories = [
        c.get("term", "")
        for c in entry.findall("arxiv:primary_category", ns)
    ]
    primary_class = categories[0] if categories else ""

    return {
        "arxiv_id": arxiv_id,
        "title": title,
        "authors": authors,
        "year": year,
        "journal_ref": journal_ref,
        "doi": doi,
        "primary_class": primary_class,
        "url": f"https://arxiv.org/abs/{arxiv_id}",
    }


def fetch_semantic_scholar_metadata(doi: str | None = None, title_hint: str = "") -> dict | None:
    if doi:
        api_url = f"https://api.semanticscholar.org/graph/v1/paper/DOI:{urllib.parse.quote(doi)}"
        api_url += "?fields=title,authors,year,publicationVenue,externalIds,abstract"
    elif title_hint:
        encoded = urllib.parse.quote(title_hint)
        api_url = f"https://api.semanticscholar.org/graph/v1/paper/search?query={encoded}&limit=1"
        api_url += "&fields=title,authors,year,publicationVenue,externalIds"
    else:
        return None

    try:
        data = _http_get(api_url)
        result = json.loads(data)
    except (urllib.error.URLError, json.JSONDecodeError) as e:
        print(f"  ⚠ Semantic Scholar error: {e}", file=sys.stderr)
        return None

    if "data" in result:
        if not result["data"]:
            return None
        result = result["data"][0]

    authors = [a.get("name", "") for a in result.get("authors", [])]
    venue = result.get("publicationVenue") or {}
    year = str(result.get("year", "")) if result.get("year") else ""
    external_ids = result.get("externalIds", {})

    return {
        "title": result.get("title", ""),
        "authors": authors,
        "year": year,
        "venue": venue.get("name", ""),
        "doi": external_ids.get("DOI", ""),
        "arxiv_id": external_ids.get("ArXiv", ""),
    }


# ── BibTeX key generation ──────────────────────────────────────────────────────

def _first_author_last(authors: list[str]) -> str:
    if not authors:
        return "Unknown"
    first = authors[0]
    if "," in first:
        return first.split(",")[0].strip()
    parts = first.split()
    return parts[-1] if parts else first


def make_bibtex_key(authors: list[str], year: str, refs_path: Path) -> str:
    base = f"{_first_author_last(authors)}{year}"
    base = re.sub(r"[^A-Za-z0-9]", "", base)
    existing = refs_path.read_text(encoding="utf-8") if refs_path.exists() else ""
    key = base
    suffix_ord = ord("a")
    while f"{{{key}," in existing or f"{{{key}\n" in existing:
        key = base + chr(suffix_ord)
        suffix_ord += 1
    return key


def key_exists(refs_path: Path, key: str) -> bool:
    if not refs_path.exists():
        return False
    text = refs_path.read_text(encoding="utf-8")
    return bool(re.search(rf"@\w+\{{{re.escape(key)},", text))


# ── BibTeX entry builders ──────────────────────────────────────────────────────

def _format_author_list(authors: list[str]) -> str:
    return " and ".join(authors)


def build_arxiv_entry(key: str, meta: dict) -> str:
    lines = [f"@misc{{{key},"]
    lines.append(f"  author        = {{{_format_author_list(meta['authors'])}}},")
    lines.append(f"  title         = {{{{{meta['title']}}}}},")
    lines.append(f"  year          = {{{meta['year']}}},")
    lines.append(f"  eprint        = {{{meta['arxiv_id']}}},")
    lines.append( "  archivePrefix = {arXiv},")
    if meta.get("primary_class"):
        lines.append(f"  primaryClass  = {{{meta['primary_class']}}},")
    lines.append(f"  url           = {{{meta['url']}}},")
    lines.append("}")
    return "\n".join(lines)


def build_inproceedings_entry(key: str, meta: dict, url: str = "") -> str:
    lines = [f"@inproceedings{{{key},"]
    lines.append(f"  author    = {{{_format_author_list(meta['authors'])}}},")
    lines.append(f"  title     = {{{{{meta['title']}}}}},")
    if meta.get("venue"):
        lines.append(f"  booktitle = {{{meta['venue']}}},")
    lines.append(f"  year      = {{{meta['year']}}},")
    if meta.get("doi"):
        lines.append(f"  doi       = {{{meta['doi']}}},")
    if url:
        lines.append(f"  url       = {{{url}}},")
    lines.append("}")
    return "\n".join(lines)


def build_online_entry(key: str, title: str, author: str, year: str, url: str) -> str:
    lines = [f"@online{{{key},"]
    lines.append(f"  author  = {{{author}}},")
    lines.append(f"  title   = {{{{{title}}}}},")
    lines.append(f"  year    = {{{year}}},")
    lines.append(f"  url     = {{{url}}},")
    lines.append("}")
    return "\n".join(lines)


# ── Main pipeline ──────────────────────────────────────────────────────────────

def append_entry(refs_path: Path, entry: str, key: str) -> None:
    existing = refs_path.read_text(encoding="utf-8") if refs_path.exists() else ""
    separator = "\n" if existing.endswith("\n") else "\n\n"
    if not existing:
        separator = ""
    with refs_path.open("a", encoding="utf-8") as f:
        f.write(separator + entry + "\n")
    print(f"  ✓ Added @{key} to {refs_path}")


def process_url(url: str, refs_path: Path) -> bool:
    # ── arXiv ──────────────────────────────────────────────────────────────────
    arxiv_id = extract_arxiv_id(url)
    if arxiv_id:
        print(f"  Fetching arXiv metadata for {arxiv_id}...")
        meta = fetch_arxiv_metadata(arxiv_id)
        if not meta or not meta["authors"]:
            print(f"  ⚠ Could not fetch metadata for arXiv:{arxiv_id}", file=sys.stderr)
            return False
        key = make_bibtex_key(meta["authors"], meta["year"], refs_path)
        if key_exists(refs_path, key):
            print(f"  ℹ Key {key} already exists in refs.bib — skipping.")
            return True
        entry = build_arxiv_entry(key, meta)
        append_entry(refs_path, entry, key)
        return True

    # ── ACL Anthology ──────────────────────────────────────────────────────────
    acl_id = extract_acl_id(url)
    if acl_id:
        print(f"  Fetching Semantic Scholar metadata for ACL:{acl_id}...")
        doi = f"10.18653/v1/{acl_id}"
        meta = fetch_semantic_scholar_metadata(doi=doi)
        if meta and meta["authors"]:
            key = make_bibtex_key(meta["authors"], meta["year"], refs_path)
            if key_exists(refs_path, key):
                print(f"  ℹ Key {key} already exists — skipping.")
                return True
            entry = build_inproceedings_entry(key, meta, url=url)
            append_entry(refs_path, entry, key)
            return True
        print(f"  ⚠ Could not fetch metadata for ACL:{acl_id}", file=sys.stderr)
        return False

    # ── DOI ────────────────────────────────────────────────────────────────────
    doi = extract_doi(url)
    if doi:
        print(f"  Fetching Semantic Scholar metadata for DOI:{doi}...")
        meta = fetch_semantic_scholar_metadata(doi=doi)
        if meta and meta["authors"]:
            key = make_bibtex_key(meta["authors"], meta["year"], refs_path)
            if key_exists(refs_path, key):
                print(f"  ℹ Key {key} already exists — skipping.")
                return True
            if meta.get("arxiv_id"):
                arxiv_meta = fetch_arxiv_metadata(meta["arxiv_id"]) or meta
                entry = build_arxiv_entry(key, arxiv_meta)
            else:
                entry = build_inproceedings_entry(key, meta, url=url)
            append_entry(refs_path, entry, key)
            return True
        print(f"  ⚠ Could not fetch metadata for DOI:{doi}", file=sys.stderr)
        return False

    print(f"  ⚠ Could not identify paper type for URL: {url}", file=sys.stderr)
    print("    Supported: arXiv, ACL Anthology, DOI-bearing URLs.", file=sys.stderr)
    return False


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Append a BibTeX entry to refs.bib in an output directory."
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Directory containing (or to create) refs.bib, e.g. ./slides/rag-systems",
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--url", help="Paper URL (arXiv, ACL Anthology, DOI URL, etc.)")
    group.add_argument("--arxiv", help="arXiv ID, e.g. 2212.04356")
    group.add_argument("--doi", help="DOI string, e.g. 10.18653/v1/2020.acl-main.561")
    args = parser.parse_args()

    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    refs_path = output_dir / "refs.bib"

    if args.arxiv:
        url = f"https://arxiv.org/abs/{args.arxiv}"
    elif args.doi:
        url = f"https://doi.org/{args.doi}"
    else:
        url = args.url

    success = process_url(url, refs_path)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
