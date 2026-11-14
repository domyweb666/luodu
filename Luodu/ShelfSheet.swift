import SwiftUI
import PhotosUI

/// 書架（index.html:288-320），加上改名、換封面、刪書。
struct ShelfSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var newCover: String?
    @State private var newCoverItem: PhotosPickerItem?

    @State private var renameTarget: Book?
    @State private var renameText = ""
    @State private var showRename = false

    @State private var coverTargetId: String?
    @State private var coverItem: PhotosPickerItem?
    @State private var showCoverPicker = false

    @State private var deleteTarget: Book?
    @State private var showDelete = false

    @Environment(BookImporter.self) private var importer
    @State private var showBookImporter = false

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("在念的書")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)

                VStack(spacing: 0) {
                    ForEach(store.data.books) { book in
                        if book.id != store.data.books.first?.id {
                            Divider().padding(.leading, 18)
                        }
                        row(book)
                    }
                }
                .background(Color.card, in: RoundedRectangle(cornerRadius: 26))

                HStack(spacing: 8) {
                    TextField("加一本：書名", text: $newName)
                        .font(.system(size: 20))
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .onSubmit(add)
                    PhotosPicker(selection: $newCoverItem, matching: .images) {
                        Group {
                            if let img = CoverImage.image(from: newCover) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "camera")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 54, height: 54)
                        .background(Color.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .accessibilityLabel("選封面")
                }
                .padding(.top, 14)

                Button("種下去", action: add)
                    .buttonStyle(PrimaryButtonStyle(height: 52, fontSize: 17))
                    .disabled(trimmedName.isEmpty)
                    .padding(.top, 14)

                Button("加一本做好的書檔") {
                    showBookImporter = true
                }
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .background(Color.pageBG)
        .onChange(of: newCoverItem) { _, item in
            loadCover(item) { newCover = $0 }
        }
        .photosPicker(isPresented: $showCoverPicker, selection: $coverItem, matching: .images)
        .onChange(of: coverItem) { _, item in
            guard let id = coverTargetId else { return }
            loadCover(item) { cover in
                if let cover { store.setCover(id, cover: cover) }
                coverItem = nil
            }
        }
        .fileImporter(isPresented: $showBookImporter, allowedContentTypes: [.luoduBook, .json, .data]) { result in
            guard case .success(let url) = result else { return }
            importer.open(url, delay: 0.6)
            dismiss()
        }
        .alert("改書名", isPresented: $showRename) {
            TextField("書名", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("好") {
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let book = renameTarget, !name.isEmpty {
                    store.rename(book.id, to: name)
                }
            }
        }
        .confirmationDialog(
            deleteTarget.map { "刪掉《\($0.name)》？" } ?? "",
            isPresented: $showDelete,
            titleVisibility: .visible
        ) {
            Button("刪掉", role: .destructive) {
                if let book = deleteTarget {
                    store.deleteBook(book.id)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let book = deleteTarget {
                let n = store.count(of: book.id)
                Text(n > 0 ? "念過的 \(n) 次紀錄會一起刪掉，救不回來。" : "這本還沒有紀錄。")
            }
        }
    }

    private func row(_ book: Book) -> some View {
        HStack(spacing: 12) {
            Button {
                store.select(book.id)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    CoverView(book: book)
                    Text(book.name)
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(store.count(of: book.id)) 次" + (book.id == store.currentBook?.id ? " ✓" : ""))
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("改書名") {
                    renameTarget = book
                    renameText = book.name
                    showRename = true
                }
                Button(book.cover == nil ? "補封面" : "換封面") {
                    coverTargetId = book.id
                    showCoverPicker = true
                }
                Button("刪掉這本", role: .destructive) {
                    deleteTarget = book
                    showDelete = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("《\(book.name)》的更多動作")
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .frame(minHeight: 56)
    }

    private func add() {
        guard !trimmedName.isEmpty else { return }
        store.addBook(name: trimmedName, cover: newCover)
        dismiss()
    }

    private func loadCover(_ item: PhotosPickerItem?, done: @escaping (String?) -> Void) {
        guard let item else { return }
        Task { @MainActor in
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: raw) else {
                done(nil)
                return
            }
            done(CoverImage.dataURL(from: image))
        }
    }
}
