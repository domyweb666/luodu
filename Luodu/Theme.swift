import SwiftUI
import UIKit

// 顏色對應 index.html:13-23
extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let v = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((v >> 16) & 0xFF) / 255,
                green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    static let pageBG = Color(light: 0xF2F2F7, dark: 0x000000)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let mainGreen = Color(light: 0x34C759, dark: 0x30D158)
    static let soil = Color(light: 0x9A6B45, dark: 0x6F4B30)
    static let soil2 = Color(light: 0x7E5535, dark: 0x573923)
    static let leaf = Color(light: 0x4FBF67, dark: 0x43B35C)
    static let leaf2 = Color(light: 0x2FA04C, dark: 0x2A8F43)
    static let radish = Color(light: 0xFBF7EC, dark: 0xEFE9DA)
    static let radishLine = Color(light: 0xE4DCC8, dark: 0xCFC6AF)
    static let fillGray = Color(.tertiarySystemFill)
}

/// 綠色大按鈕（index.html:70）
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 58
    var fontSize: CGFloat = 20
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.mainGreen, in: Capsule())
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// 封面小方塊：有圖顯示圖，沒圖顯示書名第一個字（index.html:52）
struct CoverView: View {
    let book: Book
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let img = CoverImage.image(from: book.cover) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(String(book.name.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.fillGray)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

enum CoverImage {
    /// 裁成正方形、縮到 160×160、轉成 data URL（index.html:312-320）
    static func dataURL(from image: UIImage) -> String? {
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let target: CGFloat = 160
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
        let out = renderer.image { _ in
            let scale = target / side
            let w = image.size.width * scale
            let h = image.size.height * scale
            image.draw(in: CGRect(x: (target - w) / 2, y: (target - h) / 2, width: w, height: h))
        }
        guard let jpg = out.jpegData(compressionQuality: 0.8) else { return nil }
        return "data:image/jpeg;base64," + jpg.base64EncodedString()
    }

    static func image(from dataURL: String?) -> UIImage? {
        guard let s = dataURL, let comma = s.firstIndex(of: ",") else { return nil }
        guard let raw = Data(base64Encoded: String(s[s.index(after: comma)...])) else { return nil }
        return UIImage(data: raw)
    }
}

/// 會自動換行的一排按鈕（訊號用）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
