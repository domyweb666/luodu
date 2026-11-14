import Foundation
import Observation
import UniformTypeIdentifiers

extension UTType {
    /// 書檔的類型，在 Info.plist 裡宣告
    static let luoduBook = UTType(exportedAs: "app.luodu.book")
}

/// 接住從 app 外面來的書檔：先檢查，再請使用者確認，確認了才裝。
@Observable
final class BookImporter {
    var pending: BookPackage?
    var showConfirm = false
    var errorMessage = ""
    var showError = false

    /// delay：從書架那張底部卡片叫出來的時候，要等卡片收完再跳確認框
    func open(_ url: URL, delay: TimeInterval) {
        open(url, present: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            if pending != nil {
                showConfirm = true
            } else if !errorMessage.isEmpty {
                showError = true
            }
        }
    }

    func open(_ url: URL, present: Bool = true) {
        errorMessage = ""
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= BookPackage.maxBytes else {
            fail(BookPackage.ParseError.tooBig.message, present: present)
            return
        }
        guard let raw = try? Data(contentsOf: url) else {
            fail("這個檔案打不開。", present: present)
            return
        }
        do {
            pending = try BookPackage.parse(raw)
            showConfirm = present
        } catch let error as BookPackage.ParseError {
            fail(error.message, present: present)
        } catch {
            fail(BookPackage.ParseError.notABook.message, present: present)
        }
    }

    private func fail(_ message: String, present: Bool) {
        pending = nil
        errorMessage = message
        showError = present
    }
}

#if DEBUG
/// 只給雲端模擬器截圖用的啟動參數，正式版（Release）不會編進去。
enum DebugLaunch {
    private static func string(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    /// `-startPage 0`：開在哪一頁
    static var startPage: Int? { string("startPage").flatMap { Int($0) } }
    /// `-readerPage 0`：直接打開翻書畫面的第幾頁
    static var readerPage: Int? { string("readerPage").flatMap { Int($0) } }
    /// `-importBook /path/x.luodubook`：啟動時直接裝一本書
    static func importBookIfAsked(into store: Store) {
        guard let path = string("importBook"),
              let raw = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let package = try? BookPackage.parse(raw) else { return }
        _ = try? store.install(package)
    }
}
#endif
