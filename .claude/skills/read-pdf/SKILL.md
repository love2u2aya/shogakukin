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
python3 .claude/skills/read-pdf/scripts/read_pdf.py FILE.pdf --pages 1-5

# ページ数だけ確認
python3 .claude/skills/read-pdf/scripts/read_pdf.py FILE.pdf --info

# 全ページ走査してキーワードを含むページだけ抽出
python3 .claude/skills/read-pdf/scripts/read_pdf.py FILE.pdf --grep "資産基準"

# 全文（大きいPDFは出力が膨大になるので注意。通常は --pages か --grep を使う）
python3 .claude/skills/read-pdf/scripts/read_pdf.py FILE.pdf --all
```

## 注意
- 大きいPDF（数十〜百ページ超）は `--all` を避け、`--pages` か `--grep` で絞る。
- 画像のみのスキャンPDF（テキスト層なし）はこの方法では文字が取れない（OCRが要る）。その場合はページ画像化が必要だが poppler が無いため、ユーザーに相談する。
- 検証: `python3 -c "import fitz; print(fitz.__doc__.splitlines()[0])"` で PyMuPDF が出ればOK。
