# CLAUDE.md — このリポジトリでの作業メモ

## 📄 PDFの読み込み方法（重要・既知の落とし穴）

このリモート実行環境では、**標準の Read ツールで PDF を開こうとすると失敗する**。
代わりに **Python の PyMuPDF (`import fitz`) を Bash 経由で使う**と読める。

### 症状（実際に出たエラー）
1. `Read` ツールで PDF を開く →
   ```
   pdftoppm is not installed. Install poppler-utils
   (e.g. `brew install poppler` or `apt-get install poppler-utils`)
   to enable PDF page rendering.
   ```
   （Read の PDF レンダリングは poppler の `pdftoppm` に依存しているが未インストール）

2. インストールしようとしても**ネットワーク許可リスト**で弾かれる：
   - `apt-get install -y poppler-utils` → 失敗（`apt failed`）
   - `pip install pypdf` → `pyo3_runtime.PanicException: Python API call failed`
   - `curl https://...` → `Host not in allowlist` / `HTTP 403`
   - `WebFetch` で外部URL（例: jasso.go.jp, waseda.jp）→ `HTTP 403 Forbidden`

### 直し方（これが効く・インストール不要）
環境には **PyMuPDF 1.27 系 (`fitz`) が最初から入っている**。`pdftoppm` も `pdftotext`
も無いが、fitz でテキスト抽出すればよい。Bash のヒアドキュメントで実行する：

```bash
python3 - <<'PY'
import fitz, re
d = fitz.open("/path/to/file.pdf")
print("pages:", d.page_count)
for p in [1, 2, 3]:                     # 読みたいページ番号(1始まり)
    t = d[p-1].get_text()
    print(f"\n--- page {p} ---")
    print(re.sub(r'\n{2,}', '\n', t).strip())
d.close()
PY
```

- 大きい PDF（数十〜百ページ超）でも fitz なら全ページ走査できる。
- 特定キーワードを含むページだけ抽出する場合：
  ```python
  for i in range(d.page_count):
      if "探したい語" in d[i].get_text():
          print(i+1, d[i].get_text()[:1500])
  ```

### 検証コマンド（環境確認用）
```bash
which pdftoppm pdftotext          # → none（poppler 無し）
python3 -c "import fitz; print(fitz.__doc__.splitlines()[0])"   # → PyMuPDF ... と出ればOK
```

### まとめ
- ❌ Read ツールで PDF を直接開く（poppler 依存で失敗）
- ❌ apt-get / pip / curl / WebFetch で外部から取得（ネットワーク許可リストで 403）
- ✅ **`python3` + `import fitz` (PyMuPDF) でローカル PDF をテキスト抽出** ← これで解決
