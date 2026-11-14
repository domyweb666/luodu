"""產生截圖用的假資料，內容照原型的示範資料（index.html:368-375）。
用法：python3 ci/seed.py <現在選的書 id> [孩子名字]
"""
import json
import sys
import time

now = int(time.time() * 1000)
day = 86400000
books_spec = [
    ("小芽的鞋子", 47, True),
    ("擠擠床", 31, True),
    ("好餓的毛毛蟲", 22, False),
    ("小芽洗澎澎", 12, False),
    ("這是什麼？", 5, False),
    ("球掉了", 2, False),
]
books, logs = [], []
for i, (name, count, pulled) in enumerate(books_spec):
    bid = "d%d" % i
    book = {"id": bid, "name": name, "pulled": pulled}
    if pulled:
        book["pulledAt"] = now - (40 - i * 20) * day
    books.append(book)
    for k in range(count):
        sg = []
        if k > 3 and k % 2:
            sg.append("jie")
        if k > 5 and k % 3 == 0:
            sg.append("zhi")
        if k > 8 and k % 4 == 0:
            sg.append("zai")
        if count > 20 and k > count - 4:
            sg.append("bei")
        if i == 3 and k in (6, 9):
            sg.append("skip")
        gap = 3.5 if i < 2 else 1.3
        logs.append({
            "id": "%s-%d" % (bid, k),
            "bookId": bid,
            "ts": now - round((count - k) * gap * day) - i * 3600000,
            "signals": sg,
        })

print(json.dumps({
    "books": books,
    "logs": logs,
    "current": sys.argv[1] if len(sys.argv) > 1 else "d3",
    "child": sys.argv[2] if len(sys.argv) > 2 else "",
}, ensure_ascii=False))
