import XCTest
@testable import Luodu

final class StoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    func testStartsEmpty() {
        let store = Store(fileURL: tempURL())
        XCTAssertNil(store.currentBook)
        XCTAssertTrue(store.data.books.isEmpty)
    }

    func testAddBookSelectsIt() {
        let store = Store(fileURL: tempURL())
        store.addBook(name: "小芽的鞋子")
        XCTAssertEqual(store.currentBook?.name, "小芽的鞋子")
        XCTAssertEqual(store.count(of: store.currentBook!.id), 0)
    }

    func testLogReadWithoutBookDoesNothing() {
        let store = Store(fileURL: tempURL())
        XCTAssertNil(store.logRead())
        XCTAssertTrue(store.data.logs.isEmpty)
    }

    func testBookAndCountSurviveReload() {
        let url = tempURL()
        let first = Store(fileURL: url)
        first.addBook(name: "小芽的鞋子")
        first.logRead()
        first.logRead(signals: ["jie", "bei"])
        first.logRead()

        let second = Store(fileURL: url)
        XCTAssertEqual(second.currentBook?.name, "小芽的鞋子")
        XCTAssertEqual(second.count(of: second.currentBook!.id), 3)
        XCTAssertEqual(second.sigCount(second.currentBook!.id, "bei"), 1)
        XCTAssertEqual(second.data, first.data)
    }

    func testUndoRemovesOnlyThatLog() {
        let store = Store(fileURL: tempURL())
        store.addBook(name: "擠擠床")
        let keep = store.logRead()!
        let mistake = store.logRead()!
        store.undo(mistake.id)
        XCTAssertEqual(store.data.logs.map(\.id), [keep.id])
    }

    func testSwitchBookKeepsCountsSeparate() {
        let store = Store(fileURL: tempURL())
        store.addBook(name: "甲")
        let a = store.currentBook!.id
        store.logRead()
        store.addBook(name: "乙")
        let b = store.currentBook!.id
        store.logRead()
        store.logRead()
        XCTAssertEqual(store.count(of: a), 1)
        XCTAssertEqual(store.count(of: b), 2)
        store.select(a)
        XCTAssertEqual(store.currentBook?.id, a)
    }

    func testRenameAndCover() {
        let store = Store(fileURL: tempURL())
        store.addBook(name: "打錯的書名")
        let id = store.currentBook!.id
        store.rename(id, to: "對的書名")
        store.setCover(id, cover: "data:image/jpeg;base64,AAAA")
        XCTAssertEqual(store.book(id)?.name, "對的書名")
        XCTAssertEqual(store.book(id)?.cover, "data:image/jpeg;base64,AAAA")
    }

    func testDeleteBookRemovesItsLogsAndMovesCurrent() {
        let store = Store(fileURL: tempURL())
        store.addBook(name: "甲")
        let a = store.currentBook!.id
        store.logRead()
        store.addBook(name: "乙")
        let b = store.currentBook!.id
        store.logRead()
        store.deleteBook(b)
        XCTAssertNil(store.book(b))
        XCTAssertEqual(store.data.logs.count, 1)
        XCTAssertEqual(store.data.logs.first?.bookId, a)
        XCTAssertEqual(store.currentBook?.id, a)
    }

    func testPullMarksBook() {
        let store = Store(fileURL: tempURL())
        store.addBook(name: "甲")
        let id = store.currentBook!.id
        store.pull(id)
        XCTAssertEqual(store.book(id)?.pulled, true)
        XCTAssertNotNil(store.book(id)?.pulledAt)
    }

    func testWipe() {
        let url = tempURL()
        let store = Store(fileURL: url)
        store.addBook(name: "甲")
        store.logRead()
        store.wipe()
        XCTAssertEqual(Store(fileURL: url).data, LuoduData())
    }

    // 原型匯出的備份檔格式（index.html:361、371-373）
    func testParsesPrototypeBackup() throws {
        let json = """
        {"books":[
          {"id":"b1731600000000","name":"小芽的鞋子","cover":null,"pulled":false},
          {"id":"d0","name":"擠擠床","cover":null,"pulled":true,"pulledAt":1731000000000}
        ],
        "logs":[
          {"id":"1731600000001ab12","bookId":"b1731600000000","ts":1731600000001,"signals":["jie","bei"]},
          {"id":"d0-0","bookId":"d0","ts":1730000000000,"signals":[]}
        ],
        "current":"b1731600000000","child":"小芽"}
        """
        let data = try Store.parseBackup(Data(json.utf8))
        XCTAssertEqual(data.books.count, 2)
        XCTAssertEqual(data.books[0].pulled, false)
        XCTAssertNil(data.books[0].pulledAt)
        XCTAssertEqual(data.books[1].pulledAt, 1731000000000)
        XCTAssertEqual(data.logs[0].signals, ["jie", "bei"])
        XCTAssertEqual(data.current, "b1731600000000")
        XCTAssertEqual(data.child, "小芽")
    }

    func testParsesBackupWithoutOptionalFields() throws {
        let json = """
        {"books":[{"id":"x","name":"甲"}],"logs":[{"id":"l","bookId":"x","ts":5}],"current":null}
        """
        let data = try Store.parseBackup(Data(json.utf8))
        XCTAssertEqual(data.books[0].pulled, false)
        XCTAssertEqual(data.logs[0].signals, [])
        XCTAssertNil(data.current)
        XCTAssertEqual(data.child, "")
    }

    func testBadBackupThrowsAndLeavesDataAlone() {
        let store = Store(fileURL: tempURL())
        store.addBook(name: "甲")
        store.logRead()
        let before = store.data
        XCTAssertThrowsError(try Store.parseBackup(Data("不是備份".utf8)))
        XCTAssertThrowsError(try Store.parseBackup(Data(#"{"books":[]}"#.utf8)))
        XCTAssertEqual(store.data, before)
    }

    func testExportThenImportRoundTrips() throws {
        let store = Store(fileURL: tempURL())
        store.addBook(name: "甲", cover: "data:image/jpeg;base64,AAAA")
        store.logRead(signals: ["zhi"])
        store.setChild("小芽")
        let parsed = try Store.parseBackup(store.exportData())
        XCTAssertEqual(parsed, store.data)

        let other = Store(fileURL: tempURL())
        other.replaceAll(with: parsed)
        XCTAssertEqual(other.data, store.data)
    }
}
