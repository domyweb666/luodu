import Foundation
import Observation
import UIKit

// 欄位名稱與網頁原型的 localStorage 格式一致（index.html:142），
// 原型匯出的備份檔可以直接讀進來。

struct Book: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    /// data URL（160×160 JPEG），跟原型一樣
    var cover: String?
    var pulled: Bool
    var pulledAt: Double?
    /// 從書檔匯入的書才有：書檔的代號、頁數。只打書名的書是 nil。
    var packageId: String? = nil
    var pageCount: Int? = nil
}

struct ReadLog: Codable, Identifiable, Equatable {
    var id: String
    var bookId: String
    /// 1970 起算的毫秒數，跟原型的 Date.now() 一樣
    var ts: Double
    var signals: [String]
}

struct LuoduData: Codable, Equatable {
    var books: [Book] = []
    var logs: [ReadLog] = []
    var current: String?
    var child: String = ""
}

// 寬鬆解碼：原型的備份檔裡 pulledAt、cover、child 可能不存在。
// 寫在 extension 裡，保留自動產生的逐欄位初始化。
extension Book {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        cover = try c.decodeIfPresent(String.self, forKey: .cover)
        pulled = try c.decodeIfPresent(Bool.self, forKey: .pulled) ?? false
        pulledAt = try c.decodeIfPresent(Double.self, forKey: .pulledAt)
        packageId = try c.decodeIfPresent(String.self, forKey: .packageId)
        pageCount = try c.decodeIfPresent(Int.self, forKey: .pageCount)
    }
}

extension ReadLog {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        bookId = try c.decode(String.self, forKey: .bookId)
        ts = try c.decode(Double.self, forKey: .ts)
        signals = try c.decodeIfPresent([String].self, forKey: .signals) ?? []
    }
}

extension LuoduData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        books = try c.decode([Book].self, forKey: .books)
        logs = try c.decode([ReadLog].self, forKey: .logs)
        current = try c.decodeIfPresent(String.self, forKey: .current)
        child = try c.decodeIfPresent(String.self, forKey: .child) ?? ""
    }
}

@Observable
final class Store {
    private(set) var data = LuoduData()
    private let fileURL: URL

    static var defaultFileURL: URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("luodu.v1.json")
    }

    init(fileURL: URL = Store.defaultFileURL) {
        self.fileURL = fileURL
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(LuoduData.self, from: raw) {
            data = decoded
        }
    }

    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }

    static func nowMs() -> Double {
        (Date().timeIntervalSince1970 * 1000).rounded()
    }

    // MARK: 讀

    var currentBook: Book? {
        data.books.first { $0.id == data.current } ?? data.books.first
    }

    func book(_ id: String) -> Book? {
        data.books.first { $0.id == id }
    }

    func logs(of bookId: String) -> [ReadLog] {
        data.logs.filter { $0.bookId == bookId }
    }

    func count(of bookId: String) -> Int {
        logs(of: bookId).count
    }

    func sigCount(_ bookId: String, _ key: String) -> Int {
        logs(of: bookId).filter { $0.signals.contains(key) }.count
    }

    // MARK: 書

    func addBook(name: String, cover: String? = nil) {
        let book = Book(id: "b" + UUID().uuidString, name: name, cover: cover, pulled: false, pulledAt: nil)
        data.books.append(book)
        data.current = book.id
        save()
    }

    func select(_ bookId: String) {
        guard book(bookId) != nil else { return }
        data.current = bookId
        save()
    }

    func rename(_ bookId: String, to name: String) {
        guard let i = data.books.firstIndex(where: { $0.id == bookId }) else { return }
        data.books[i].name = name
        save()
    }

    func setCover(_ bookId: String, cover: String?) {
        guard let i = data.books.firstIndex(where: { $0.id == bookId }) else { return }
        data.books[i].cover = cover
        save()
    }

    // MARK: 書頁（從書檔匯入的書）

    /// 書頁存在資料檔旁邊的資料夾，一本書一個子資料夾
    var booksDir: URL {
        let name = fileURL.deletingPathExtension().lastPathComponent + "-books"
        return fileURL.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
    }

    private func bookDir(_ bookId: String) -> URL {
        booksDir.appendingPathComponent(bookId, isDirectory: true)
    }

    func pageImageURL(_ bookId: String, index: Int) -> URL {
        bookDir(bookId).appendingPathComponent("p\(index + 1).img")
    }

    func content(of bookId: String) -> BookContent? {
        let url = bookDir(bookId).appendingPathComponent("content.json")
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BookContent.self, from: raw)
    }

    /// 這本書現在翻得開嗎。從備份還原的書只有紀錄、沒有書頁，會是 false。
    func hasPages(_ book: Book) -> Bool {
        (book.pageCount ?? 0) > 0 && content(of: book.id) != nil
    }

    func existingBook(forPackage packageId: String) -> Book? {
        data.books.first { $0.packageId == packageId }
    }

    /// 把檢查過的書檔裝進來。書架上已經有同一個代號的書，就換掉書頁、紀錄留著。
    @discardableResult
    func install(_ package: BookPackage) throws -> Book {
        let existing = existingBook(forPackage: package.id)
        let bookId = existing?.id ?? "b" + UUID().uuidString
        let dir = bookDir(bookId)
        let fm = FileManager.default
        try? fm.removeItem(at: dir)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            for (index, page) in package.pages.enumerated() {
                try page.image.write(to: pageImageURL(bookId, index: index), options: .atomic)
            }
            let content = BookContent(
                title: package.title,
                pages: package.pages.map { BookContent.Page(text: $0.text, hint: $0.hint) }
            )
            try JSONEncoder().encode(content).write(to: dir.appendingPathComponent("content.json"), options: .atomic)
        } catch {
            try? fm.removeItem(at: dir)
            throw error
        }

        let coverSource = package.cover ?? package.pages[0].image
        let cover = UIImage(data: coverSource).flatMap { CoverImage.dataURL(from: $0) }

        if let i = data.books.firstIndex(where: { $0.id == bookId }) {
            data.books[i].name = package.title
            data.books[i].pageCount = package.pages.count
            data.books[i].cover = cover ?? data.books[i].cover
        } else {
            data.books.append(Book(
                id: bookId, name: package.title, cover: cover, pulled: false, pulledAt: nil,
                packageId: package.id, pageCount: package.pages.count
            ))
        }
        data.current = bookId
        save()
        return data.books.first { $0.id == bookId }!
    }

    /// 連這本書的所有紀錄和書頁一起刪
    func deleteBook(_ bookId: String) {
        try? FileManager.default.removeItem(at: bookDir(bookId))
        data.books.removeAll { $0.id == bookId }
        data.logs.removeAll { $0.bookId == bookId }
        if data.current == bookId { data.current = data.books.first?.id }
        save()
    }

    func pull(_ bookId: String) {
        guard let i = data.books.firstIndex(where: { $0.id == bookId }) else { return }
        data.books[i].pulled = true
        data.books[i].pulledAt = Store.nowMs()
        save()
    }

    // MARK: 紀錄

    @discardableResult
    func logRead(signals: [String] = []) -> ReadLog? {
        guard let book = currentBook else { return nil }
        let log = ReadLog(id: UUID().uuidString, bookId: book.id, ts: Store.nowMs(), signals: signals)
        data.logs.append(log)
        save()
        return log
    }

    func undo(_ logId: String) {
        data.logs.removeAll { $0.id == logId }
        save()
    }

    // MARK: 設定與備份

    func setChild(_ name: String) {
        data.child = name
        save()
    }

    func exportData() -> Data {
        (try? JSONEncoder().encode(data)) ?? Data()
    }

    /// 只解析、不寫入。讀不出來就丟錯，現有資料不動。
    static func parseBackup(_ raw: Data) throws -> LuoduData {
        try JSONDecoder().decode(LuoduData.self, from: raw)
    }

    func replaceAll(with newData: LuoduData) {
        data = newData
        save()
    }

    func wipe() {
        try? FileManager.default.removeItem(at: booksDir)
        data = LuoduData()
        save()
    }
}
