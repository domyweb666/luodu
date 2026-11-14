import Foundation
import Observation

// 欄位名稱與網頁原型的 localStorage 格式一致（index.html:142），
// 原型匯出的備份檔可以直接讀進來。

struct Book: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    /// data URL（160×160 JPEG），跟原型一樣
    var cover: String?
    var pulled: Bool
    var pulledAt: Double?
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

    /// 連這本書的所有紀錄一起刪
    func deleteBook(_ bookId: String) {
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
        data = LuoduData()
        save()
    }
}
