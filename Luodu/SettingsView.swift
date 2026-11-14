import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// 設定（index.html:352-367）。正式版沒有「載入示範資料」，匯入會先問。
struct SettingsView: View {
    @Environment(Store.self) private var store
    var goMain: () -> Void

    @State private var exporting = false
    @State private var exportDoc = BackupDocument(data: Data())
    @State private var importing = false
    @State private var pendingImport: LuoduData?
    @State private var showImportConfirm = false
    @State private var showImportError = false
    @State private var wipeArmed = false

    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = Reminder.defaultMinutes
    @State private var showReminderDenied = false

    private func setReminder(_ on: Bool) {
        guard on else {
            reminderOn = false
            Reminder.disable()
            return
        }
        Task { @MainActor in
            if await Reminder.enable(minutes: reminderMinutes) {
                reminderOn = true
            } else {
                reminderOn = false
                showReminderDenied = true
            }
        }
    }

    private var child: String { store.data.child }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("設定")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                Text("資料只存在這支手機")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                    .padding(.bottom, 18)

                HStack {
                    Text("孩子的名字")
                        .font(.system(size: 17))
                    TextField("可以不填", text: Binding(
                        get: { store.data.child },
                        set: { store.setChild($0) }
                    ))
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 56)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
                note("填了之後，畫面上的「她」會換成這個名字。")

                VStack(spacing: 0) {
                    Toggle("睡前提醒", isOn: Binding(
                        get: { reminderOn },
                        set: { setReminder($0) }
                    ))
                    .font(.system(size: 17))
                    .tint(Color.mainGreen)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 56)
                    if reminderOn {
                        Divider().padding(.leading, 18)
                        DatePicker("時間", selection: Binding(
                            get: { Reminder.date(minutes: reminderMinutes) },
                            set: { newValue in
                                reminderMinutes = Reminder.minutes(from: newValue)
                                Reminder.schedule(minutes: reminderMinutes)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .font(.system(size: 17))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 56)
                    }
                }
                .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
                .padding(.top, 18)
                note("每天這個時間提醒一次。沒念也不會怎樣。")

                sectionTitle("念法，五個字")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Rules.five, id: \.k) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.k)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.mainGreen)
                            Text(Rules.named(item.t, child: child))
                                .font(.system(size: 15))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
                note("前三次只念不問。主畫面一次只會給你一個字。")

                sectionTitle("資料")
                VStack(spacing: 0) {
                    dataRow("匯出備份") {
                        exportDoc = BackupDocument(data: store.exportData())
                        exporting = true
                    }
                    Divider().padding(.leading, 18)
                    dataRow("匯入備份") {
                        importing = true
                    }
                    Divider().padding(.leading, 18)
                    Button {
                        if wipeArmed {
                            store.wipe()
                            wipeArmed = false
                            goMain()
                        } else {
                            wipeArmed = true
                        }
                    } label: {
                        Text(wipeArmed ? "再按一次，真的清掉" : "清掉全部資料")
                            .font(.system(size: 17))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .padding(.horizontal, 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.card, in: RoundedRectangle(cornerRadius: 26))
                note("刪掉這個 app，資料會一起不見。要刪之前先匯出。")
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .padding(.bottom, 24)
        }
        .onDisappear {
            wipeArmed = false
        }
        .task {
            // 使用者事後在 iPhone 設定裡關掉通知的話，這裡的開關跟著關
            if reminderOn, await Reminder.isDenied() {
                reminderOn = false
            }
        }
        .alert("通知沒有打開", isPresented: $showReminderDenied) {
            Button("去設定") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("先不用", role: .cancel) {}
        } message: {
            Text("要到 iPhone 的「設定」裡允許蘿讀傳送通知，再回來打開睡前提醒。")
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDoc,
            contentType: .json,
            defaultFilename: "蘿讀備份-" + SettingsView.today()
        ) { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .confirmationDialog("用這份備份蓋掉現在的紀錄？", isPresented: $showImportConfirm, titleVisibility: .visible) {
            Button("蓋掉，換成備份", role: .destructive) {
                if let data = pendingImport {
                    store.replaceAll(with: data)
                    goMain()
                }
                pendingImport = nil
            }
            Button("取消", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            if let data = pendingImport {
                Text("備份裡有 \(data.books.count) 本書、\(data.logs.count) 次紀錄。現在手機裡的 \(store.data.books.count) 本書、\(store.data.logs.count) 次紀錄會被換掉，救不回來。")
            }
        }
        .alert("這個檔案讀不出來", isPresented: $showImportError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("現在的紀錄沒有動。")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        guard let raw = try? Data(contentsOf: url),
              let parsed = try? Store.parseBackup(raw) else {
            showImportError = true
            return
        }
        pendingImport = parsed
        showImportConfirm = true
    }

    private static func today() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.top, 26)
            .padding(.bottom, 10)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.top, 8)
    }

    private func dataRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.primary)
                Spacer()
                Text("›")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
