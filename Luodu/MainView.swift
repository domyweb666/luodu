import SwiftUI

struct MainView: View {
    @Environment(Store.self) private var store
    @State private var newName = ""

    var body: some View {
        if let book = store.currentBook {
            bookView(book)
        } else {
            firstBookView
        }
    }

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var firstBookView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("今晚念的是哪一本？")
                .font(.system(size: 30, weight: .bold))
            Text("打書名就好，之後再補封面。")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
            TextField("書名", text: $newName)
                .font(.system(size: 22))
                .padding(18)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26))
                .submitLabel(.done)
                .onSubmit(plant)
            Button(action: plant) {
                Text("種下去")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.green)
            .disabled(trimmedName.isEmpty)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func bookView(_ book: Book) -> some View {
        let n = store.count(of: book.id)
        return VStack(spacing: 12) {
            Text(book.name)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Text(countText(n))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Button {
                store.logRead()
            } label: {
                Text("念完了")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func plant() {
        guard !trimmedName.isEmpty else { return }
        store.addBook(name: trimmedName)
        newName = ""
    }

    /// 對應原型 index.html:243
    private func countText(_ n: Int) -> String {
        if n == 0 { return "還沒念過" }
        if n < 3 { return "第 \(n) 次 · 還在土裡" }
        return "念了 \(n) 次"
    }
}
