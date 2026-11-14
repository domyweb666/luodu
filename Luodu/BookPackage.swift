import Foundation
import UIKit

/// 書檔（.luodubook）。一個 JSON 檔，圖用 base64 放在裡面。
/// 由 tools/pack_book.py 產生。內容來自 app 外面，進來前全部要檢查。
struct BookPackage: Equatable {
    struct Page: Equatable {
        var text: String
        var hint: String?
        var image: Data
    }

    /// 這本書的代號。同一個代號再匯入一次，是更新內容，不是多一本。
    var id: String
    var title: String
    var cover: Data?
    var pages: [Page]

    static let maxPages = 40
    static let maxBytes = 80_000_000

    enum ParseError: Error, Equatable {
        case tooBig
        case notABook
        case unsupportedVersion
        case noPages
        case tooManyPages
        case badImage(page: Int)

        var message: String {
            switch self {
            case .tooBig: return "這個檔案太大了，不像是一本書。"
            case .notABook: return "這個檔案不是蘿讀的書檔，或是內容壞了。"
            case .unsupportedVersion: return "這個書檔是比較新的格式，這版 app 讀不了。"
            case .noPages: return "這個書檔裡沒有任何一頁。"
            case .tooManyPages: return "這個書檔超過 \(BookPackage.maxPages) 頁，讀不了。"
            case .badImage(let page): return "第 \(page) 頁的圖讀不出來。"
            }
        }
    }

    private struct Raw: Decodable {
        struct RawPage: Decodable {
            var text: String?
            var hint: String?
            var image: Data
        }

        var format: String
        var version: Int
        var id: String
        var title: String
        var cover: Data?
        var pages: [RawPage]
    }

    static func parse(_ raw: Data) throws -> BookPackage {
        guard raw.count <= maxBytes else { throw ParseError.tooBig }
        guard let decoded = try? JSONDecoder().decode(Raw.self, from: raw),
              decoded.format == "luodubook" else {
            throw ParseError.notABook
        }
        guard decoded.version == 1 else { throw ParseError.unsupportedVersion }

        let title = decoded.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let id = String(decoded.id.filter { allowed.contains($0) }.prefix(64))
        guard !title.isEmpty, !id.isEmpty else { throw ParseError.notABook }
        guard !decoded.pages.isEmpty else { throw ParseError.noPages }
        guard decoded.pages.count <= maxPages else { throw ParseError.tooManyPages }

        var pages: [Page] = []
        for (index, page) in decoded.pages.enumerated() {
            guard UIImage(data: page.image) != nil else {
                throw ParseError.badImage(page: index + 1)
            }
            let hint = page.hint?.trimmingCharacters(in: .whitespacesAndNewlines)
            pages.append(Page(
                text: (page.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                hint: (hint?.isEmpty ?? true) ? nil : hint,
                image: page.image
            ))
        }

        var cover = decoded.cover
        if let data = cover, UIImage(data: data) == nil { cover = nil }
        return BookPackage(id: id, title: title, cover: cover, pages: pages)
    }
}

/// 裝進手機後，每本書資料夾裡的 content.json
struct BookContent: Codable, Equatable {
    struct Page: Codable, Equatable {
        var text: String
        var hint: String?
    }

    var title: String
    var pages: [Page]
}
