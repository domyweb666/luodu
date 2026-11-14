import SwiftUI

/// 三頁左右滑：蘿蔔田／主畫面／設定（index.html:127-132, 377-386）
struct RootView: View {
    @State private var page = 1

    private let names = ["蘿蔔田", "主畫面", "設定"]

    var body: some View {
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
    }

    private func goMain() {
        withAnimation {
            page = 1
        }
    }
}
