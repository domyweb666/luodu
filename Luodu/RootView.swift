import SwiftUI

/// 三頁左右滑：蘿蔔田／主畫面／設定（index.html:127-132, 377-386）
struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(BookImporter.self) private var importer
    @State private var page = RootView.initialPage

    private let names = ["蘿蔔田", "主畫面", "設定"]

    private static var initialPage: Int {
        #if DEBUG
        return DebugLaunch.startPage ?? 1
        #else
        return 1
        #endif
    }

    var body: some View {
        @Bindable var importer = importer

        ZStack(alignment: .top) {
            Color.pageBG.ignoresSafeArea()

            TabView(selection: $page) {
                FieldView(goMain: goMain).tag(0)
                MainView().tag(1)
                SettingsView(goMain: goMain).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    Button {
                        withAnimation {
                            page = i
                        }
                    } label: {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 7, height: 7)
                            .opacity(page == i ? 1 : 0.35)
                            .scaleEffect(page == i ? 1.25 : 1)
                            .frame(width: 22, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(names[i])
                    .accessibilityAddTraits(page == i ? .isSelected : [])
                }
            }
            .padding(.top, 4)
        }
        .onOpenURL { url in
            importer.open(url)
        }
        .alert(confirmTitle, isPresented: $importer.showConfirm) {
            Button(isUpdate ? "換成新的" : "加進書架") {
                installPending()
            }
            Button("取消", role: .cancel) {
                importer.pending = nil
            }
        } message: {
            Text(confirmMessage)
        }
        .alert("加不進來", isPresented: $importer.showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importer.errorMessage)
        }
    }

    private var existing: Book? {
        importer.pending.flatMap { store.existingBook(forPackage: $0.id) }
    }

    private var isUpdate: Bool { existing != nil }

    private var confirmTitle: String {
        guard let package = importer.pending else { return "" }
        return isUpdate ? "換掉《\(package.title)》的內容？" : "把《\(package.title)》加進書架？"
    }

    private var confirmMessage: String {
        guard let package = importer.pending else { return "" }
        if let book = existing {
            return "書架上已經有這本。新的內容共 \(package.pages.count) 頁，念過的 \(store.count(of: book.id)) 次紀錄會留著。"
        }
        return "共 \(package.pages.count) 頁。"
    }

    private func installPending() {
        guard let package = importer.pending else { return }
        importer.pending = nil
        do {
            try store.install(package)
            goMain()
        } catch {
            importer.errorMessage = "存不進手機，可能是空間不夠。"
            importer.showError = true
        }
    }

    private func goMain() {
        withAnimation {
            page = 1
        }
    }
}
