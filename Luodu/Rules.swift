import Foundation

/// 原型裡所有「算出來」的東西。純計算，不碰畫面、不碰存檔。
/// 行號對應 index.html。
enum Rules {
    struct Signal {
        let key: String
        let label: String
    }

    // index.html:147-148
    static let good: [Signal] = [
        Signal(key: "jie", label: "她接話了"),
        Signal(key: "zhi", label: "她指了"),
        Signal(key: "zai", label: "她說再一次"),
        Signal(key: "na", label: "她自己去拿的"),
        Signal(key: "life", label: "生活裡說了書裡的詞"),
        Signal(key: "bei", label: "她搶先念完"),
    ]
    static let bad: [Signal] = [
        Signal(key: "skip", label: "有一頁被跳過"),
        Signal(key: "run", label: "念到一半跑掉"),
    ]

    // index.html:151
    static let done: [String] = [
        "又一片。", "同一本，再一次。這就對了。", "她認得這本了。", "葉子多一片。", "今天也念了。",
        "念過的書，她會自己走回來。", "再一次，是她在學。", "這一片是今天的。", "好，收工。", "又長了一點。",
        "書沒變，她變了一點。", "一樣的書，不一樣的一天。", "今晚這片，記下了。", "土裡的也在長。",
        "念完了，可以關燈了。", "這片葉子長得不錯。", "這本越來越熟了。", "慢慢來，葉子不會跑。",
        "多念一次，不嫌多。", "記好了。", "今天這一次，算數。", "再念一次也可以。",
    ]

    struct Word {
        let k: String
        let t: [String]
    }

    // index.html:152-158
    static let words: [Word] = [
        Word(k: "等", t: ["念到要她接的地方，停三秒。", "問完先不要自己回答，數到三。"]),
        Word(k: "接", t: ["她說什麼都接住，不說「不對」。", "她說錯了，直接把對的說一次就好。"]),
        Word(k: "加", t: ["把她的話多加一個詞說回去。她說「鞋鞋」，你說「粉紅色的鞋子」。"]),
        Word(k: "誇", t: ["誇具體的事：「你找到了！」"]),
        Word(k: "再", t: ["請她再說一次。她不說也沒關係。"]),
    ]

    // index.html:159
    static let life = "念完問她一題真的：書裡那個東西，家裡的在哪裡？"

    /// 設定頁「念法，五個字」的說明（index.html:358）
    static let five: [(k: String, t: String)] = [
        ("等", "念到要她接的地方，停三秒"),
        ("接", "她說什麼都接住，不說「不對」"),
        ("加", "把她的話多加一個詞說回去"),
        ("誇", "誇具體的事"),
        ("再", "請她再說一次，不說也沒關係"),
    ]

    /// 填了孩子的名字，就把固定文案裡的「她」換成名字。
    /// 只能用在 app 自己的文案上，不要用在書名上。
    static func named(_ text: String, child: String) -> String {
        let name = child.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? text : text.replacingOccurrences(of: "她", with: name)
    }

    struct Tip: Equatable {
        var k: String
        var t: String
    }

    /// index.html:174-182
    static func tip(n: Int, jie: Int) -> Tip {
        if n < 2 { return Tip(k: "", t: "前三次只念不問，她在認識這本書。") }
        if n == 2 { return Tip(k: "", t: "再一次就冒芽。還是只念不問。") }
        if n > 3 && n % 5 == 0 { return Tip(k: "去找真的", t: life) }
        let w = words[min(4, jie / 3)]
        return Tip(k: w.k, t: w.t[n % w.t.count])
    }

    /// index.html:272
    static func doneText(n: Int, totalLogs: Int) -> String {
        switch n {
        case 1: return "種下去了。"
        case 2: return "還在土裡，正常的。"
        case 3: return "第三次，冒芽了。"
        default: return done[(n * 7 + totalLogs) % done.count]
        }
    }

    /// index.html:172
    static func pullable(book: Book, bei: Int) -> Bool {
        !book.pulled && bei >= 2
    }

    /// index.html:243
    static func countText(n: Int, pulled: Bool) -> String {
        let base: String
        if n == 0 {
            base = "還沒念過"
        } else if n < 3 {
            base = "第 \(n) 次 · 還在土裡"
        } else {
            base = "念了 \(n) 次"
        }
        return base + (pulled ? " · 已經拔起來了" : "")
    }

    struct Week {
        var total = 0
        /// 「《書名》3 次」
        var perBook: [String] = []
        /// 「《書名》她接話了」，最多 6 條
        var firsts: [String] = []
        /// 「《書名》有一頁被跳過，出現 2 次」
        var warnings: [String] = []
    }

    /// index.html:337-350
    static func week(data: LuoduData, now: Double, child: String) -> Week {
        let since = now - 7 * 864e5
        var out = Week()
        let recent = data.logs.filter { $0.ts >= since }
        out.total = recent.count
        guard !recent.isEmpty else { return out }

        var order: [String] = []
        var per: [String: Int] = [:]
        for log in recent {
            if per[log.bookId] == nil { order.append(log.bookId) }
            per[log.bookId, default: 0] += 1
        }
        for id in order {
            if let b = data.books.first(where: { $0.id == id }) {
                out.perBook.append("《\(b.name)》\(per[id] ?? 0) 次")
            }
        }

        for b in data.books {
            let logs = data.logs.filter { $0.bookId == b.id }
            for s in good {
                if let first = logs.first(where: { $0.signals.contains(s.key) }), first.ts >= since {
                    out.firsts.append("《\(b.name)》" + named(s.label, child: child))
                }
            }
        }
        out.firsts = Array(out.firsts.prefix(6))

        for b in data.books {
            let logs = data.logs.filter { $0.bookId == b.id }
            for s in bad {
                let c = logs.filter { $0.signals.contains(s.key) }.count
                if c >= 2 {
                    out.warnings.append("《\(b.name)》\(s.label)，出現 \(c) 次")
                }
            }
        }
        return out
    }
}
