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
        store.logRead()
        XCTAssertTrue(store.data.logs.isEmpty)
    }

    func testBookAndCountSurviveReload() {
        let url = tempURL()
        let first = Store(fileURL: url)
        first.addBook(name: "小芽的鞋子")
        first.logRead()
        first.logRead()
        first.logRead()

        let second = Store(fileURL: url)
        XCTAssertEqual(second.currentBook?.name, "小芽的鞋子")
        XCTAssertEqual(second.count(of: second.currentBook!.id), 3)
        XCTAssertEqual(second.data, first.data)
    }
}
