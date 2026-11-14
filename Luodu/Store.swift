import Foundation
import Observation

// 欄位名稱與網頁原型的 localStorage 格式一致（index.html:142），
// 之後匯入原型備份檔時可以直接對上。

struct Book: Codable, Identifiable, Equatable {
    var id: String
    var name: String
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

    private static func nowMs() -> Double {
        (Date().timeIntervalSince1970 * 1000).rounded()
    }

    var currentBook: Book? {
        data.books.first { $0.id == data.current } ?? data.books.first
    }

    func count(of bookId: String) -> Int {
        data.logs.filter { $0.bookId == bookId }.count
    }

    func addBook(name: String) {
        let book = Book(id: "b" + UUID().uuidString, name: name, cover: nil, pulled: false, pulledAt: nil)
        data.books.append(book)
        data.current = book.id
        save()
    }

    func logRead() {
        guard let book = currentBook else { return }
        data.logs.append(ReadLog(id: UUID().uuidString, bookId: book.id, ts: Store.nowMs(), signals: []))
        save()
    }
}
