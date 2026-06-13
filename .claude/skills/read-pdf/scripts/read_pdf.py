#!/usr/bin/env python3
"""Extract text from a local PDF using PyMuPDF (fitz).

Workaround for this environment: the built-in Read tool fails on PDFs because
poppler/pdftoppm is missing, and installing it is blocked by the network
allowlist. PyMuPDF is pre-installed, so we extract text directly.

Usage:
    read_pdf.py FILE.pdf --info
    read_pdf.py FILE.pdf --pages 1-5
    read_pdf.py FILE.pdf --pages 3,7,10-12
    read_pdf.py FILE.pdf --grep "資産基準"
    read_pdf.py FILE.pdf --all
"""
import argparse
import re
import sys


def parse_pages(spec, page_count):
    """Parse "1-5,8,11-13" into a sorted list of 1-based page numbers."""
    pages = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            for n in range(int(a), int(b) + 1):
                pages.add(n)
        else:
            pages.add(int(part))
    return sorted(p for p in pages if 1 <= p <= page_count)


def clean(text):
    return re.sub(r"\n{2,}", "\n", text).strip()


def main():
    ap = argparse.ArgumentParser(description="Extract text from a PDF via PyMuPDF (fitz).")
    ap.add_argument("file", help="path to the PDF")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--pages", help='page range, 1-based (e.g. "1-5", "3,7,10-12")')
    g.add_argument("--grep", help="print only pages containing this substring")
    g.add_argument("--all", action="store_true", help="print every page (careful: large output)")
    ap.add_argument("--info", action="store_true", help="print page count and metadata, then exit")
    ap.add_argument("--limit", type=int, default=0,
                    help="truncate each page's text to N chars (0 = no limit)")
    args = ap.parse_args()

    try:
        import fitz  # PyMuPDF
    except ImportError:
        sys.exit("PyMuPDF (fitz) is not available. Verify with: "
                 "python3 -c 'import fitz'")

    try:
        doc = fitz.open(args.file)
    except Exception as e:  # noqa: BLE001
        sys.exit(f"Could not open '{args.file}': {e}")

    print(f"# {args.file}  (pages: {doc.page_count})")
    if args.info:
        for k, v in (doc.metadata or {}).items():
            if v:
                print(f"{k}: {v}")
        doc.close()
        return

    if args.pages:
        targets = parse_pages(args.pages, doc.page_count)
    elif args.all:
        targets = list(range(1, doc.page_count + 1))
    elif args.grep:
        targets = [i + 1 for i in range(doc.page_count)
                   if args.grep in doc[i].get_text()]
        if not targets:
            print(f"(no page contains '{args.grep}')")
            doc.close()
            return
    else:
        # default: just the first 3 pages so the call is never accidentally huge
        targets = list(range(1, min(3, doc.page_count) + 1))
        print("(no mode given; showing first pages — use --pages/--grep/--all)")

    for p in targets:
        text = clean(doc[p - 1].get_text())
        if args.limit and len(text) > args.limit:
            text = text[:args.limit] + "…[truncated]"
        print(f"\n--- page {p} ---")
        print(text)

    doc.close()


if __name__ == "__main__":
    main()
