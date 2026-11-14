import SwiftUI

/// 蘿蔔田＋這週（index.html:322-350）
struct FieldView: View {
    @Environment(Store.self) private var store
    var goMain: () -> Void

    private var child: String { store.data.child }

    var body: some View {
        let books = store.data.books
        let inSoil = books.filter { !$0.pulled }
        let pulled = books.filter { $0.pulled }.sorted { ($0.pulledAt ?? 0) < ($1.pulledAt ?? 0) }
        let total = store.data.logs.count

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("蘿蔔田")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                Text(total > 0 ? "\(books.count) 本書，一共念了 \(total) 次" : "念完第一次，這裡就會有東西")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)

                sectionTitle("還在土裡")
                if inSoil.isEmpty {
                    emptyCard("現在沒有在土裡的書。")
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(inSoil) { book in
                            plot(book)
                        }
                    }
                }

                sectionTitle("拔起來的")
                if pulled.isEmpty {
                    emptyCard(Rules.named("她能搶先把整本念完的那天，就可以拔第一根。", child: child))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(pulled) { book in
                                pulledItem(book)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    }
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
                }

                sectionTitle("這週")
                weekCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .padding(.bottom, 24)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.top, 26)
            .padding(.bottom, 10)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
    }

    private func plot(_ book: Book) -> some View {
        let n = store.count(of: book.id)
        return Button {
            store.select(book.id)
            goMain()
        } label: {
            VStack(spacing: 0) {
                PlantView(n: n)
                    .frame(height: 92)
                    .clipped()
                Text(book.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                Text("\(n) 次")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.horizontal, 6)
            .padding(.bottom, 10)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(book.name)，念了 \(n) 次")
    }

    private func pulledItem(_ book: Book) -> some View {
        let n = store.count(of: book.id)
        return VStack(spacing: 0) {
            PulledView(n: n)
                .frame(width: 74, height: PulledView.boxHeight(n) * 0.9)
            Text(book.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Text("\(n) 次")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(width: 74)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var weekCard: some View {
        let week = Rules.week(data: store.data, now: Store.nowMs(), child: child)
        if week.total == 0 {
            emptyCard("這週還沒有紀錄。")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                weekRow(title: "念了 \(week.total) 次", notes: [week.perBook.joined(separator: "、")])
                if !week.firsts.isEmpty {
                    Divider()
                    weekRow(title: "第一次出現", notes: [week.firsts.joined(separator: "、")])
                }
                ForEach(week.warnings, id: \.self) { warning in
                    Divider()
                    weekRow(title: warning, notes: [
                        Rules.named("先看念法：念到要她接的地方，有停下來等嗎？是不是她累了的時段？", child: child),
                        "都不是的話，再看是整本都這樣，還是只有某一頁。",
                    ])
                }
            }
            .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
        }
    }

    private func weekRow(title: String, notes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            ForEach(notes, id: \.self) { note in
                Text(note)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
