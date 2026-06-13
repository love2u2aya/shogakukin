#!/usr/bin/env bash
# Install the "read-pdf" skill as a PERSONAL skill at ~/.claude/skills/read-pdf
# so it works in EVERY project/repo — both in the Claude Code web environment
# and on a local machine.
#
# This script is self-contained (the skill files are embedded below), so it does
# NOT depend on any particular repository being checked out. That makes it safe
# to run from a Claude Code on the web *environment setup script*, where other
# repos (not this one) may be the working directory.
#
# Usage:
#   bash install-read-pdf-skill.sh
#
# Remote env (all repos, every session): add this script's contents (or a call
#   to it) to your environment's setup script in the Claude Code web settings.
# Local machine (all projects): run it once. Needs PyMuPDF (pip install pymupdf).
set -euo pipefail

DEST="${HOME}/.claude/skills/read-pdf"
mkdir -p "${DEST}/scripts"

cat > "${DEST}/SKILL.md" <<'SKILL_EOF'
---
name: read-pdf
description: Read/extract text from local PDF files in this environment. Use whenever you need to read a PDF here — the built-in Read tool FAILS on PDFs ("pdftoppm is not installed" / poppler missing) and network installs are blocked by the allowlist. This skill uses the pre-installed PyMuPDF (fitz) to extract text directly, with page-range, full-scan, and keyword-search modes. Triggers: "read this PDF", "open the PDF", PDF guides/forms (奨学金案内, てびき, 申込書), any .pdf path.
---

# read-pdf — ローカルPDFのテキスト抽出

## なぜ必要か（この環境の落とし穴）
- 標準の `Read` ツールで PDF を開くと失敗する:
  `pdftoppm is not installed. Install poppler-utils ...`（Read は poppler の画像化に依存、未インストール）。
- `apt-get` / `pip install` / `curl` / `WebFetch` はネットワーク許可リストで弾かれる
  （`apt failed` / `pyo3_runtime.PanicException` / `Host not in allowlist` / `HTTP 403`）。
- 一方 **PyMuPDF (`import fitz`) は最初から入っている** → これでテキスト抽出すれば解決。

## 使い方
スクリプトは `scripts/read_pdf.py`。`python3` で実行する。

```bash
# ページ範囲を読む（1始まり。"1-5" や "3" や "1,4,9-12"）
python3 ~/.claude/skills/read-pdf/scripts/read_pdf.py FILE.pdf --pages 1-5

# ページ数だけ確認
python3 ~/.claude/skills/read-pdf/scripts/read_pdf.py FILE.pdf --info

# 全ページ走査してキーワードを含むページだけ抽出
python3 ~/.claude/skills/read-pdf/scripts/read_pdf.py FILE.pdf --grep "資産基準"

# 全文（大きいPDFは出力が膨大になるので注意。通常は --pages か --grep を使う）
python3 ~/.claude/skills/read-pdf/scripts/read_pdf.py FILE.pdf --all
```

## 注意
- 大きいPDF（数十〜百ページ超）は `--all` を避け、`--pages` か `--grep` で絞る。
- 画像のみのスキャンPDF（テキスト層なし）はこの方法では文字が取れない（OCRが要る）。その場合はページ画像化が必要だが poppler が無いため、ユーザーに相談する。
- 検証: `python3 -c "import fitz; print(fitz.__doc__.splitlines()[0])"` で PyMuPDF が出ればOK。
SKILL_EOF

cat > "${DEST}/scripts/read_pdf.py" <<'PY_EOF'
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
PY_EOF

chmod +x "${DEST}/scripts/read_pdf.py"

# Ensure PyMuPDF is available. No-op if already installed (e.g. the web env).
# Locally (network allowed) this installs it; if it fails, warn the user.
if ! python3 -c "import fitz" >/dev/null 2>&1; then
  pip install --quiet pymupdf >/dev/null 2>&1 \
    && echo "Installed PyMuPDF (pymupdf)." \
    || echo "WARN: could not auto-install PyMuPDF. Run: pip install pymupdf"
fi

echo "Installed read-pdf skill to ${DEST}"
