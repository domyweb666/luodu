import SwiftUI

/// 翻書畫面。一頁一張圖一句字，左右滑翻頁，最後多一頁給大人按「念完了」。
/// 這是大人手上的畫面：沒有動畫、沒有聲音、沒有按了會動的東西。
struct ReaderView: View {
    let book: Book
    let content: BookContent
    /// 念過 3 次以後，最後一頁才出現訊號按鈕（跟主畫面一樣）
    let showChips: Bool
    var onDone: ([String]) -> Void

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var page: Int
    @State private var selected: Set<String> = []

    init(book: Book, content: BookContent, showChips: Bool, startPage: Int = 0, onDone: @escaping ([String]) -> Void) {
        self.book = book
        self.content = content
        self.showChips = showChips
        self.onDone = onDone
        _page = State(initialValue: max(0, min(startPage, content.pages.count)))
    }

    private var pageCount: Int { content.pages.count }

    var body: some View {
        ZStack(alignment: .top) {
            Color.pageBG.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(0..<pageCount, id: \.self) { index in
                    pageView(index).tag(index)
                }
                endPage.tag(pageCount)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("不念了，回主畫面")
                Spacer()
                if page < pageCount {
                    Text("\(page + 1) / \(pageCount)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 16)
                }
            }
            .padding(.leading, 6)
        }
    }

    private func pageView(_ index: Int) -> some View {
        let item = content.pages[index]
        return VStack(spacing: 0) {
            Group {
                if let image = UIImage(contentsOfFile: store.pageImageURL(book.id, index: index).path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityHidden(true)
                } else {
                    Text("這一頁的圖不見了")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !item.text.isEmpty {
                Text(item.text)
                    .font(.system(size: 28, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }

            if let hint = item.hint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .accessibilityLabel("給大人的提示：\(hint)")
            }
        }
        .padding(.top, 48)
        .padding(.bottom, 28)
    }

    private var endPage: some View {
        VStack(spacing: 0) {
            Spacer()
            CoverView(book: book, size: 72)
            Text(book.name)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 14)
            if showChips {
                SignalChips(selected: $selected, child: store.data.child)
                    .padding(.top, 24)
            }
            Button("念完了") {
                onDone(SignalChips.ordered(selected))
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 20)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 48)
        .padding(.bottom, 28)
    }
}
