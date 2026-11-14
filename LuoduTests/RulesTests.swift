import XCTest
@testable import Luodu

final class RulesTests: XCTestCase {
    func testTipFirstThreeReads() {
        XCTAssertEqual(Rules.tip(n: 0, jie: 0), Rules.Tip(k: "", t: "前三次只念不問，她在認識這本書。"))
        XCTAssertEqual(Rules.tip(n: 1, jie: 0).t, "前三次只念不問，她在認識這本書。")
        XCTAssertEqual(Rules.tip(n: 2, jie: 0).t, "再一次就冒芽。還是只念不問。")
    }

    func testTipWordFollowsJieCount() {
        XCTAssertEqual(Rules.tip(n: 3, jie: 0).k, "等")
        XCTAssertEqual(Rules.tip(n: 4, jie: 2).k, "等")
        XCTAssertEqual(Rules.tip(n: 4, jie: 3).k, "接")
        XCTAssertEqual(Rules.tip(n: 6, jie: 6).k, "加")
        XCTAssertEqual(Rules.tip(n: 6, jie: 9).k, "誇")
        XCTAssertEqual(Rules.tip(n: 6, jie: 12).k, "再")
        XCTAssertEqual(Rules.tip(n: 6, jie: 99).k, "再")
    }

    func testTipAlternatesWithinWord() {
        XCTAssertEqual(Rules.tip(n: 3, jie: 0).t, "問完先不要自己回答，數到三。")
        XCTAssertEqual(Rules.tip(n: 4, jie: 0).t, "念到要她接的地方，停三秒。")
    }

    func testTipEveryFifthIsLife() {
        XCTAssertEqual(Rules.tip(n: 5, jie: 0), Rules.Tip(k: "去找真的", t: Rules.life))
        XCTAssertEqual(Rules.tip(n: 10, jie: 12).k, "去找真的")
        XCTAssertNotEqual(Rules.tip(n: 6, jie: 0).k, "去找真的")
    }

    func testDoneText() {
        XCTAssertEqual(Rules.doneText(n: 1, totalLogs: 1), "種下去了。")
        XCTAssertEqual(Rules.doneText(n: 2, totalLogs: 2), "還在土裡，正常的。")
        XCTAssertEqual(Rules.doneText(n: 3, totalLogs: 3), "第三次，冒芽了。")
        // (4*7+4) % 22 = 10
        XCTAssertEqual(Rules.doneText(n: 4, totalLogs: 4), Rules.done[10])
        XCTAssertEqual(Rules.done.count, 22)
    }

    func testPullable() {
        let inSoil = Book(id: "a", name: "甲", cover: nil, pulled: false, pulledAt: nil)
        let out = Book(id: "b", name: "乙", cover: nil, pulled: true, pulledAt: 1)
        XCTAssertFalse(Rules.pullable(book: inSoil, bei: 1))
        XCTAssertTrue(Rules.pullable(book: inSoil, bei: 2))
        XCTAssertFalse(Rules.pullable(book: out, bei: 5))
    }

    func testCountText() {
        XCTAssertEqual(Rules.countText(n: 0, pulled: false), "還沒念過")
        XCTAssertEqual(Rules.countText(n: 2, pulled: false), "第 2 次 · 還在土裡")
        XCTAssertEqual(Rules.countText(n: 3, pulled: false), "念了 3 次")
        XCTAssertEqual(Rules.countText(n: 47, pulled: true), "念了 47 次 · 已經拔起來了")
    }

    func testNamedReplacesOnlyWhenFilled() {
        XCTAssertEqual(Rules.named("她接話了", child: ""), "她接話了")
        XCTAssertEqual(Rules.named("她接話了", child: "  "), "她接話了")
        XCTAssertEqual(Rules.named("她接話了", child: "小芽"), "小芽接話了")
        XCTAssertEqual(Rules.named("請她再說一次。她不說也沒關係。", child: "阿寶"), "請阿寶再說一次。阿寶不說也沒關係。")
    }

    func testWeek() {
        let day = 864e5
        let now = 100 * day
        let a = Book(id: "a", name: "甲", cover: nil, pulled: false, pulledAt: nil)
        let b = Book(id: "b", name: "她的書", cover: nil, pulled: false, pulledAt: nil)
        let logs = [
            // 八天前：不算這週，但讓「jie」在甲不是這週第一次
            ReadLog(id: "1", bookId: "a", ts: now - 8 * day, signals: ["jie", "skip"]),
            ReadLog(id: "2", bookId: "a", ts: now - 2 * day, signals: ["jie", "zhi", "skip"]),
            ReadLog(id: "3", bookId: "b", ts: now - 1 * day, signals: ["jie"]),
            ReadLog(id: "4", bookId: "b", ts: now - 1 * day + 5, signals: []),
        ]
        let data = LuoduData(books: [a, b], logs: logs, current: "a", child: "小芽")
        let week = Rules.week(data: data, now: now, child: "小芽")

        XCTAssertEqual(week.total, 3)
        XCTAssertEqual(week.perBook, ["《甲》1 次", "《她的書》2 次"])
        // 書名裡的「她」不能被換掉
        XCTAssertEqual(week.firsts, ["《甲》小芽指了", "《她的書》小芽接話了"])
        // 不好的訊號是從頭累積
        XCTAssertEqual(week.warnings, ["《甲》有一頁被跳過，出現 2 次"])
    }

    func testWeekEmpty() {
        let week = Rules.week(data: LuoduData(), now: 1000, child: "")
        XCTAssertEqual(week.total, 0)
        XCTAssertTrue(week.perBook.isEmpty)
    }

    func testBodyAndLeavesStopGrowing() {
        XCTAssertEqual(RadishGeometry.bodyLen(0), 46)
        XCTAssertEqual(RadishGeometry.bodyLen(70), 151)
        XCTAssertEqual(RadishGeometry.bodyLen(200), 151)
    }
}
