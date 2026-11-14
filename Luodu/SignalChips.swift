import SwiftUI

/// 八顆訊號按鈕（index.html:251-256）。主畫面和翻書的最後一頁共用。
struct SignalChips: View {
    @Binding var selected: Set<String>
    var child: String

    /// 照固定順序排好選到的訊號
    static func ordered(_ selected: Set<String>) -> [String] {
        (Rules.good + Rules.bad).map(\.key).filter { selected.contains($0) }
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Rules.good, id: \.key) { s in
                chip(s, isBad: false)
            }
            ForEach(Rules.bad, id: \.key) { s in
                chip(s, isBad: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ s: Rules.Signal, isBad: Bool) -> some View {
        let on = selected.contains(s.key)
        let background: Color = on ? (isBad ? Color.secondary : Color.mainGreen) : Color.card
        let foreground: Color = on ? (isBad ? Color.card : Color.white) : (isBad ? Color.secondary : Color.primary)
        return Button {
            if on {
                selected.remove(s.key)
            } else {
                selected.insert(s.key)
            }
        } label: {
            Text(Rules.named(s.label, child: child))
                .font(.system(size: 15, weight: on && !isBad ? .semibold : .regular))
                .foregroundStyle(foreground)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(background, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
