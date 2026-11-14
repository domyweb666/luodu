import SwiftUI

/// 主畫面（index.html:224-286）
struct MainView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var newName = ""
    @State private var showShelf = false
    @State private var showReader = false

    /// 這次選的訊號
    @State private var selected: Set<String> = []
    /// 剛按完的完成語
    @State private var justDone: String?
    /// 剛記下的那一筆，用來收回
    @State private var lastLogId: String?

    @State private var pull: CGFloat = 0
    @State private var leafScale: CGFloat = 1
    @State private var tilt: CGFloat = 0
    @State private var dragging = false

    var body: some View {
        Group {
            if let book = store.currentBook {
                bookView(book)
            } else {
                firstBookView
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 44)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showShelf) {
            ShelfSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showReader) {
            if let book = store.currentBook, let content = store.content(of: book.id) {
                ReaderView(
                    book: book,
                    content: content,
                    showChips: store.count(of: book.id) >= 3,
                    startPage: MainView.readerStartPage
                ) { signals in
                    logRead(book, signals: signals)
                }
            }
        }
        .onChange(of: store.currentBook?.id) { _, _ in
            resetTransient()
        }
        .onAppear {
            #if DEBUG
            if DebugLaunch.readerPage != nil, let book = store.currentBook, store.hasPages(book) {
                showReader = true
            }
            #endif
        }
    }

    private var child: String { store.data.child }

    /// 翻書一律從第 1 頁開始。雲端截圖時才會用啟動參數指定別頁。
    private static var readerStartPage: Int {
        #if DEBUG
        return DebugLaunch.readerPage ?? 0
        #else
        return 0
        #endif
    }

    private func resetTransient() {
        selected = []
        justDone = nil
        lastLogId = nil
        pull = 0
        leafScale = 1
        dragging = false
    }

    // MARK: 還沒有書

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var firstBookView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今晚念的是哪一本？")
                .font(.system(size: 30, weight: .bold))
                .padding(.horizontal, 4)
            Text("打書名就好，之後再補封面。")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 2)
            TextField("書名", text: $newName)
                .font(.system(size: 22))
                .padding(18)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
                .submitLabel(.done)
                .autocorrectionDisabled()
                .onSubmit(plant)
                .padding(.top, 14)
            Button("種下去", action: plant)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmedName.isEmpty)
                .padding(.top, 14)
            Spacer()
        }
        .padding(.top, 60)
    }

    private func plant() {
        guard !trimmedName.isEmpty else { return }
        store.addBook(name: trimmedName)
        newName = ""
    }

    // MARK: 有書

    private func bookView(_ book: Book) -> some View {
        let n = store.count(of: book.id)
        let canPull = Rules.pullable(book: book, bei: store.sigCount(book.id, "bei"))
        let tip = Rules.tip(n: n, jie: store.sigCount(book.id, "jie"))
        let swaying = canPull && justDone == nil && !dragging && !reduceMotion

        return VStack(spacing: 0) {
            Button {
                showShelf = true
            } label: {
                HStack(spacing: 10) {
                    CoverView(book: book)
                    Text(book.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text("›")
                        .foregroundStyle(Color.secondary)
                }
                .padding(.leading, 6)
                .padding(.trailing, 14)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("換書，現在是\(book.name)")

            stage(book: book, n: n, canPull: canPull)
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
                .onChange(of: swaying, initial: true) { _, on in
                    if on {
                        tilt = -3
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            tilt = 3
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) {
                            tilt = 0
                        }
                    }
                }

            Text(Rules.countText(n: n, pulled: book.pulled))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 10)

            messageCard(canPull: canPull, tip: tip)

            if n >= 3 {
                SignalChips(selected: $selected, child: child)
                    .padding(.top, 12)
            }

            if store.hasPages(book) {
                Button("開始念") {
                    showReader = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 14)
                Button(justDone == nil ? "沒翻書，直接記一次" : "又念了一次") {
                    logRead(book, signals: SignalChips.ordered(selected))
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 8)
            } else {
                Button(justDone == nil ? "念完了" : "又念了一次") {
                    logRead(book, signals: SignalChips.ordered(selected))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 14)
            }

            if justDone != nil, lastLogId != nil {
                Button("按錯了，收回這一次") {
                    undo()
                }
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private func stage(book: Book, n: Int, canPull: Bool) -> some View {
        if book.pulled {
            PulledView(n: n)
                .frame(maxHeight: 300)
                .frame(maxHeight: .infinity, alignment: .bottom)
        } else {
            PlantView(n: n, pull: pull, leafScale: leafScale, tilt: tilt)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !canPull { wiggle() }
                }
                .gesture(canPull ? pullGesture(book: book, n: n) : nil)
                .accessibilityAddTraits(canPull ? .isButton : [])
                .accessibilityLabel(canPull ? "蘿蔔，可以拔了" : "蘿蔔")
                .accessibilityAction {
                    if canPull { finishPull(book: book, n: n) }
                }
        }
    }

    private func messageCard(canPull: Bool, tip: Rules.Tip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if canPull && justDone == nil {
                Text("可以拔了。")
                    .font(.system(size: 22, weight: .bold))
                Text(Rules.named("她搶先念完兩次了", child: child))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                Text("按住蘿蔔往上拖。還想留在土裡也可以。")
                    .font(.system(size: 17))
            } else {
                if let done = justDone {
                    Text(Rules.named(done, child: child))
                        .font(.system(size: 22, weight: .bold))
                        .padding(.bottom, 10)
                }
                Text((justDone == nil ? "今晚試試" : "明晚試試") + (tip.k.isEmpty ? "" : "：" + tip.k))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                Text(Rules.named(tip.t, child: child))
                    .font(.system(size: 17))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
    }

    // MARK: 動作

    private func logRead(_ book: Book, signals: [String]) {
        guard let log = store.logRead(signals: signals) else { return }
        selected = []
        lastLogId = log.id
        let n = store.count(of: book.id)
        justDone = Rules.doneText(n: n, totalLogs: store.data.logs.count)
        if n == 3 {
            Haptics.sprout()
        } else {
            Haptics.leaf()
        }
        guard !reduceMotion else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            leafScale = 0
        }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.45)) {
                leafScale = 1
            }
        }
        wiggle()
    }

    private func undo() {
        guard let id = lastLogId else { return }
        store.undo(id)
        lastLogId = nil
        justDone = nil
        leafScale = 1
    }

    private func wiggle() {
        guard !reduceMotion else { return }
        Task { @MainActor in
            for angle: CGFloat in [-4, 4, 0] {
                withAnimation(.easeInOut(duration: 0.12)) {
                    tilt = angle
                }
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    private func pullGesture(book: Book, n: Int) -> some Gesture {
        let limit = RadishGeometry.bodyLen(n) + 26
        return DragGesture(minimumDistance: 6)
            .onChanged { value in
                dragging = true
                pull = max(0, min(limit, -value.translation.height * 0.9))
            }
            .onEnded { _ in
                dragging = false
                if pull > limit * 0.55 {
                    finishPull(book: book, n: n)
                } else {
                    withAnimation(.easeOut(duration: 0.22)) {
                        pull = 0
                    }
                }
            }
    }

    private func finishPull(book: Book, n: Int) {
        store.pull(book.id)
        Haptics.pulled()
        pull = 0
        lastLogId = nil
        justDone = "拔起來了。\(n) 次。"
    }
}
