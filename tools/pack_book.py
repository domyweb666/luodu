"""把一個書的資料夾打包成蘿讀書檔（.luodubook）。

用法：
    python tools/pack_book.py <書的資料夾>

資料夾裡要有：
    書.txt        書名、代號、每一頁的字和提示
    1.jpg 2.jpg … 每頁一張圖（jpg 或 png 都可以），檔名就是頁碼
    封面.jpg      可以沒有，沒有就用第 1 頁當封面

書.txt 的寫法見 docs/做一本書檔.md。
需要 Pillow：pip install pillow
"""
import base64
import io
import json
import re
import sys
from pathlib import Path

from PIL import Image

MAX_SIDE = 1600
MAX_PAGES = 40
IMAGE_EXTS = (".jpg", ".jpeg", ".png")


def fail(message):
    print("打包失敗：" + message)
    sys.exit(1)


def parse_text(raw):
    """回傳 (書名, 代號, [ {text, hint}, ... ])"""
    title = ""
    book_id = ""
    pages = []
    current = None
    for line in raw.splitlines():
        line = line.strip()
        if line.startswith("#"):
            current = {"lines": [], "hint": ""}
            pages.append(current)
            continue
        if current is None:
            m = re.match(r"^書名[：:]\s*(.+)$", line)
            if m:
                title = m.group(1).strip()
                continue
            m = re.match(r"^代號[：:]\s*(.+)$", line)
            if m:
                book_id = m.group(1).strip()
            continue
        if not line:
            continue
        m = re.match(r"^提示[：:]\s*(.*)$", line)
        if m:
            current["hint"] = m.group(1).strip()
        else:
            current["lines"].append(line)
    result = [{"text": "\n".join(p["lines"]), "hint": p["hint"]} for p in pages]
    return title, book_id, result


def find_image(folder, stem):
    for ext in IMAGE_EXTS:
        for candidate in (folder / (stem + ext), folder / (stem + ext.upper())):
            if candidate.exists():
                return candidate
    return None


def encode_image(path):
    try:
        image = Image.open(path)
        image.load()
    except Exception:
        fail("%s 打不開，不是正常的圖檔。" % path.name)
    image = image.convert("RGB")
    longest = max(image.size)
    if longest > MAX_SIDE:
        scale = MAX_SIDE / longest
        image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, "JPEG", quality=85)
    return base64.b64encode(buffer.getvalue()).decode("ascii")


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    folder = Path(sys.argv[1])
    text_file = folder / "書.txt"
    if not text_file.exists():
        fail("找不到 %s" % text_file)

    title, book_id, pages = parse_text(text_file.read_text(encoding="utf-8-sig"))
    if not title:
        fail("書.txt 裡沒有「書名：」那一行。")
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", book_id):
        fail("書.txt 裡的「代號：」只能用英文字母、數字、連字號、底線，例如 xiaoya-shoes。")
    if not pages:
        fail("書.txt 裡沒有任何一頁。每一頁要用「# 第 1 頁」這樣的一行開頭。")
    if len(pages) > MAX_PAGES:
        fail("最多 %d 頁，這本有 %d 頁。" % (MAX_PAGES, len(pages)))

    out_pages = []
    for number, page in enumerate(pages, start=1):
        image_path = find_image(folder, str(number))
        if image_path is None:
            fail("第 %d 頁找不到圖。資料夾裡要有 %d.jpg 或 %d.png。" % (number, number, number))
        item = {"text": page["text"], "image": encode_image(image_path)}
        if page["hint"]:
            item["hint"] = page["hint"]
        out_pages.append(item)

    extra = find_image(folder, str(len(pages) + 1))
    if extra is not None:
        fail("資料夾裡有 %s，可是書.txt 只寫了 %d 頁。" % (extra.name, len(pages)))

    package = {"format": "luodubook", "version": 1, "id": book_id, "title": title, "pages": out_pages}
    cover_path = find_image(folder, "封面")
    if cover_path is not None:
        package["cover"] = encode_image(cover_path)

    out_path = folder.parent / (book_id + ".luodubook")
    out_path.write_text(json.dumps(package, ensure_ascii=False), encoding="utf-8")
    size_mb = out_path.stat().st_size / 1_000_000
    print("好了：%s（%d 頁，%.1f MB）" % (out_path, len(out_pages), size_mb))
    for number, page in enumerate(pages, start=1):
        first = page["text"].splitlines()[0] if page["text"] else "（沒有字）"
        print("  第 %d 頁：%s%s" % (number, first, "　提示：" + page["hint"] if page["hint"] else ""))


if __name__ == "__main__":
    main()
