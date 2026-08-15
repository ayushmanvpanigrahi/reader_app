from __future__ import annotations

import io
import re
from dataclasses import dataclass, field

import fitz  # PyMuPDF
from bs4 import BeautifulSoup
from ebooklib import ITEM_DOCUMENT, epub
from langchain_text_splitters import RecursiveCharacterTextSplitter


@dataclass
class ChapterSpan:
    title: str
    start_page: int
    end_page: int


@dataclass
class ExtractedText:
    pages: list[str] = field(default_factory=list)
    chapters: list[ChapterSpan] = field(default_factory=list)

    @property
    def total_pages(self) -> int:
        return len(self.pages)

    @property
    def chapter_count(self) -> int:
        return len(self.chapters)


def extract_pdf(content: bytes, book_title: str) -> ExtractedText:
    doc = fitz.open(stream=content, filetype="pdf")
    pages = [page.get_text("text") for page in doc]
    chapters = _build_chapters_from_toc(doc, pages)

    if not chapters:
        chapters = _fallback_chapters_from_heading_heuristics(pages)

    doc.close()
    return ExtractedText(pages=pages, chapters=chapters)


def extract_epub(content: bytes, book_title: str) -> ExtractedText:
    book = epub.read_epub(io.BytesIO(content))

    raw_items: list[tuple[str, str]] = []
    for item in book.get_items_of_type(ITEM_DOCUMENT):
        html = item.get_content().decode("utf-8", errors="ignore")
        soup = BeautifulSoup(html, "lxml")
        for tag in soup(["script", "style"]):
            tag.decompose()
        text = soup.get_text(" ", strip=True)
        text = re.sub(r"\s+", " ", text).strip()
        if text:
            raw_items.append((item.get_name(), text))

    page_size = 1500
    pages: list[str] = []
    for _, text in raw_items:
        for i in range(0, len(text), page_size):
            pages.append(text[i : i + page_size])

    chapters = _chapters_from_epub_headings(raw_items, pages, page_size)
    return ExtractedText(pages=pages, chapters=chapters)


def semantic_chunk(
    extracted: ExtractedText,
    *,
    book_id: str,
    user_id: str,
    title: str,
    author: str,
    chunk_size: int,
    chunk_overlap: int,
) -> list[dict]:
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        separators=["\n\n", "\n", ". ", " ", ""],
    )

    chunks: list[dict] = []
    chunk_index = 0
    pages = extracted.pages
    spans = extracted.chapters or [ChapterSpan(title="Front Matter", start_page=0, end_page=max(len(pages) - 1, 0))]

    for span in spans:
        span_pages = pages[span.start_page : span.end_page + 1]
        full_text = "\n\n".join(f"[[PAGE {start + span.start_page + 1}]]\n{text}" for start, text in enumerate(span_pages))
        if not full_text.strip():
            continue

        page_anchors = _parse_page_anchors(full_text)
        for piece in splitter.split_text(full_text):
            page_number = _dominant_page(piece, page_anchors)
            chunks.append(
                {
                    "user_id": user_id,
                    "book_id": book_id,
                    "title": title,
                    "author": author,
                    "chapter": span.title,
                    "page_number": page_number,
                    "chunk_index": chunk_index,
                    "text": piece,
                }
            )
            chunk_index += 1

    return chunks


def _build_chapters_from_toc(doc: fitz.Document, pages: list[str]) -> list[ChapterSpan]:
    toc = doc.get_toc()
    spans: list[ChapterSpan] = []
    for level, title, page_no in toc:
        if level != 1:
            continue
        clean = re.sub(r"^\d+[.)]\s*", "", str(title)).strip()
        spans.append(ChapterSpan(title=clean, start_page=page_no - 1, end_page=page_no - 1))

    if not spans:
        return spans

    for i in range(len(spans)):
        start = spans[i].start_page
        end = spans[i + 1].start_page - 1 if i + 1 < len(spans) else len(pages) - 1
        spans[i].end_page = max(end, start)
    return spans


_HEADING_RE = re.compile(r"^(?:chapter|lesson|unit|part|book)\s+[0-9IVXLC]+[.:-]?\s+(.+)$", re.IGNORECASE)


def _fallback_chapters_from_heading_heuristics(pages: list[str]) -> list[ChapterSpan]:
    spans: list[ChapterSpan] = []
    for idx, page_text in enumerate(pages):
        lines = [ln.strip() for ln in page_text.splitlines() if ln.strip()]
        if not lines:
            continue
        first = lines[0]
        if len(first) <= 60 and _HEADING_RE.match(first):
            spans.append(ChapterSpan(title=first[:60], start_page=idx, end_page=idx))
        elif len(first) <= 40 and first == first.upper() and idx < len(pages) - 1:
            spans.append(ChapterSpan(title=first, start_page=idx, end_page=idx))

    for i in range(len(spans)):
        start = spans[i].start_page
        end = spans[i + 1].start_page - 1 if i + 1 < len(spans) else len(pages) - 1
        spans[i].end_page = max(end, start)
    return spans


def _chapters_from_epub_headings(raw_items: list[tuple[str, str]], pages: list[str], page_size: int) -> list[ChapterSpan]:
    spans: list[ChapterSpan] = []
    running_page = 0
    for _, text in raw_items:
        first = text[:80]
        if _HEADING_RE.match(first):
            title = re.split(r"[.:-]\s*", first, maxsplit=1)[-1][:60] or first[:60]
            spans.append(ChapterSpan(title=title.strip(), start_page=running_page, end_page=running_page))
        running_page += max(1, len(text) // page_size)

    for i in range(len(spans)):
        start = spans[i].start_page
        end = spans[i + 1].start_page - 1 if i + 1 < len(spans) else max(len(pages) - 1, start)
        spans[i].end_page = max(end, start)
    return spans


def _parse_page_anchors(full_text: str) -> dict[int, int]:
    anchors: dict[int, int] = {}
    for idx, line in enumerate(full_text.splitlines()):
        m = re.fullmatch(r"\[\[PAGE (\d+)\]\]", line.strip())
        if m:
            anchors[idx] = int(m.group(1))
    return anchors


def _dominant_page(piece: str, anchors: dict[int, int]) -> int:
    line_offset = piece.count("\n") + 1
    best = 0
    best_dist = float("inf")
    for anchor_line, page in anchors.items():
        if anchor_line <= line_offset:
            dist = line_offset - anchor_line
            if dist < best_dist:
                best, best_dist = page, dist
    return best if best else 1
