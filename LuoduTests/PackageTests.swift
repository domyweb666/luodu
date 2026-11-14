import XCTest
import UIKit
@testable import Luodu

final class PackageTests: XCTestCase {
    private func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    private func png(_ color: UIColor = .red) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).pngData { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    private func packageJSON(
        format: String = "luodubook",
        version: Int = 1,
        id: String = "red-ball",
        title: String = "紅球球在哪裡",
        pages: [[String: Any]]? = nil
    ) -> Data {
        let image = png().base64EncodedString()
        let defaultPages: [[String: Any]] = [
            ["text": "紅球球，不見了。", "hint": "停三秒。", "image": image],
            ["text": "在這裡！", "image": image],
        ]
        let object: [String: Any] = [
            "format": format, "version": version, "id": id, "title": title,
            "pages": pages ?? defaultPages,
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    // MARK: 檢查

    func testParsesValidPackage() throws {
        let package = try BookPackage.parse(packageJSON())
        XCTAssertEqual(package.id, "red-ball")
        XCTAssertEqual(package.title, "紅球球在哪裡")
        XCTAssertEqual(package.pages.count, 2)
        XCTAssertEqual(package.pages[0].hint, "停三秒。")
        XCTAssertNil(package.pages[1].hint)
    }

    func testRejectsNonBook() {
        XCTAssertThrowsError(try BookPackage.parse(Data("哈囉".utf8))) {
            XCTAssertEqual($0 as? BookPackage.ParseError, .notABook)
        }
        XCTAssertThrowsError(try BookPackage.parse(packageJSON(format: "something"))) {
            XCTAssertEqual($0 as? BookPackage.ParseError, .notABook)
        }
        // 備份檔不是書檔
        XCTAssertThrowsError(try BookPackage.parse(Data(#"{"books":[],"logs":[]}"#.utf8))) {
            XCTAssertEqual($0 as? BookPackage.ParseError, .notABook)
        }
        XCTAssertThrowsError(try BookPackage.parse(packageJSON(title: "   "))) {
            XCTAssertEqual($0 as? BookPackage.ParseError, .notABook)
        }
    }

    func testRejectsNewerVersion() {
        XCTAssertThrowsError(try BookPackage.parse(packageJSON(version: 2))) {
            XCTAssertEqual($0 as? BookPackage.ParseError, .unsupportedVersion)
        }
    }

    func testRejectsEmptyAndTooManyPages() {
        XCTAssertThrowsError(try BookPackage.parse(packageJSON(pages: []))) {
            XCTAssertEqual($0 as? BookPackage.ParseError, .noPages)
        }
        let image = png().base64EncodedString()
        let many = Array(repeating: ["text": "字", "image": image] as [String: Any], count: 41)
        XCTAssertThrowsError(try BookPackage.parse(packageJSON(pages: many))) {
            XCTAssertEqual($0 as? BookPackage.ParseError, .tooManyPages)
        }
    }

    func testRejectsBadImage() {
        let good = png().base64EncodedString()
        let notImage = Data("這不是圖".utf8).base64EncodedString()
        let pages: [[String: Any]] = [["text": "一", "image": good], ["text": "二", "image": notImage]]
        XCTAssertThrowsError(try BookPackage.parse(packageJSON(pages: pages))) {
            XCTAssertEqual($0 as? BookPackage.ParseError, .badImage(page: 2))
        }
    }

    func testIdIsSanitized() throws {
        let package = try BookPackage.parse(packageJSON(id: "../../etc/red ball"))
        XCTAssertEqual(package.id, "etcredball")
    }

    // MARK: 安裝

    func testInstallCreatesReadableBook() throws {
        let store = Store(fileURL: tempStoreURL())
        let book = try store.install(BookPackage.parse(packageJSON()))
        XCTAssertEqual(book.name, "紅球球在哪裡")
        XCTAssertEqual(book.pageCount, 2)
        XCTAssertNotNil(book.cover)
        XCTAssertEqual(store.currentBook?.id, book.id)
        XCTAssertTrue(store.hasPages(book))
        XCTAssertEqual(store.content(of: book.id)?.pages.map(\.text), ["紅球球，不見了。", "在這裡！"])
        XCTAssertNotNil(UIImage(contentsOfFile: store.pageImageURL(book.id, index: 1).path))
    }

    func testReinstallSamePackageKeepsLogs() throws {
        let store = Store(fileURL: tempStoreURL())
        let first = try store.install(BookPackage.parse(packageJSON()))
        store.logRead()
        store.logRead()

        let image = png(.blue).base64EncodedString()
        let updated = packageJSON(title: "紅球球在哪裡（新版）", pages: [
            ["text": "一", "image": image], ["text": "二", "image": image], ["text": "三", "image": image],
        ])
        let second = try store.install(BookPackage.parse(updated))

        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(store.data.books.count, 1)
        XCTAssertEqual(store.count(of: first.id), 2)
        XCTAssertEqual(second.name, "紅球球在哪裡（新版）")
        XCTAssertEqual(second.pageCount, 3)
        XCTAssertEqual(store.content(of: first.id)?.pages.count, 3)
    }

    func testDifferentPackageIdIsANewBook() throws {
        let store = Store(fileURL: tempStoreURL())
        try store.install(BookPackage.parse(packageJSON(id: "a")))
        try store.install(BookPackage.parse(packageJSON(id: "b")))
        XCTAssertEqual(store.data.books.count, 2)
    }

    func testDeleteRemovesPages() throws {
        let store = Store(fileURL: tempStoreURL())
        let book = try store.install(BookPackage.parse(packageJSON()))
        let imagePath = store.pageImageURL(book.id, index: 0).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagePath))
        store.deleteBook(book.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imagePath))
        XCTAssertNil(store.content(of: book.id))
    }

    func testBookRestoredFromBackupHasNoPages() throws {
        let source = Store(fileURL: tempStoreURL())
        try source.install(BookPackage.parse(packageJSON()))
        source.logRead()
        let backup = try Store.parseBackup(source.exportData())

        let other = Store(fileURL: tempStoreURL())
        other.replaceAll(with: backup)
        let book = other.currentBook!
        XCTAssertEqual(book.pageCount, 2)
        XCTAssertFalse(other.hasPages(book))
        XCTAssertEqual(other.count(of: book.id), 1)
    }

    func testNameOnlyBookHasNoPages() {
        let store = Store(fileURL: tempStoreURL())
        store.addBook(name: "市售繪本")
        XCTAssertFalse(store.hasPages(store.currentBook!))
    }

    func testSamplePackageInRepoIsValid() throws {
        // 範例書檔跟著測試一起打包，確認打包工具產生的檔 app 讀得進去
        guard let url = Bundle(for: PackageTests.self).url(forResource: "red-ball", withExtension: "luodubook") else {
            return XCTFail("測試包裡找不到範例書檔")
        }
        let package = try BookPackage.parse(Data(contentsOf: url))
        XCTAssertEqual(package.id, "red-ball")
        XCTAssertEqual(package.pages.count, 4)
        XCTAssertEqual(package.pages[1].text, "在桌子下面嗎？\n沒有。")
    }
}
