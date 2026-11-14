import SwiftUI

/// 蘿蔔的形狀與尺寸，照原型的 SVG 一筆一筆搬（index.html:184-222）。
/// 目前是占位圖形，之後換插圖。
enum RadishGeometry {
    static let angles: [Double] = [0, -24, 24, -44, 44, -12, 12, -34, 34, -56, 56, -6, 18, -18, 40, -40]

    static func bodyLen(_ n: Int) -> CGFloat {
        46 + CGFloat(min(n, 70)) * 1.5
    }

    static func leafPath(len: CGFloat, wid: CGFloat) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addCurve(
            to: CGPoint(x: 0, y: -len),
            control1: CGPoint(x: -wid, y: -len * 0.35),
            control2: CGPoint(x: -wid * 0.9, y: -len * 0.85)
        )
        p.addCurve(
            to: .zero,
            control1: CGPoint(x: wid * 0.9, y: -len * 0.85),
            control2: CGPoint(x: wid, y: -len * 0.35)
        )
        p.closeSubpath()
        return p
    }

    static func bodyPath(_ length: CGFloat) -> Path {
        let w: CGFloat = 24
        var p = Path()
        p.move(to: CGPoint(x: -w, y: 6))
        p.addCurve(
            to: CGPoint(x: 0, y: length),
            control1: CGPoint(x: -w - 4, y: length * 0.5),
            control2: CGPoint(x: -8, y: length * 0.92)
        )
        p.addCurve(
            to: CGPoint(x: w, y: 6),
            control1: CGPoint(x: 8, y: length * 0.92),
            control2: CGPoint(x: w + 4, y: length * 0.5)
        )
        p.addCurve(
            to: CGPoint(x: -w, y: 6),
            control1: CGPoint(x: w, y: -6),
            control2: CGPoint(x: -w, y: -6)
        )
        p.closeSubpath()
        return p
    }

    static func drawBody(_ ctx: GraphicsContext, length: CGFloat) {
        let path = bodyPath(length)
        ctx.fill(path, with: .color(.radish))
        ctx.stroke(path, with: .color(.radishLine), lineWidth: 1.5)
    }

    static func drawFace(_ ctx: GraphicsContext) {
        let ink = Color(red: 0x3A / 255.0, green: 0x2E / 255.0, blue: 0x25 / 255.0)
        let blush = Color(red: 0xF4 / 255.0, green: 0xA6 / 255.0, blue: 0xA6 / 255.0).opacity(0.7)
        ctx.fill(Path(ellipseIn: CGRect(x: -8 - 2.6, y: 20 - 2.6, width: 5.2, height: 5.2)), with: .color(ink))
        ctx.fill(Path(ellipseIn: CGRect(x: 8 - 2.6, y: 20 - 2.6, width: 5.2, height: 5.2)), with: .color(ink))
        ctx.fill(Path(ellipseIn: CGRect(x: -14 - 4.5, y: 27 - 2.8, width: 9, height: 5.6)), with: .color(blush))
        ctx.fill(Path(ellipseIn: CGRect(x: 14 - 4.5, y: 27 - 2.8, width: 9, height: 5.6)), with: .color(blush))
        var mouth = Path()
        mouth.move(to: CGPoint(x: -3, y: 27))
        mouth.addQuadCurve(to: CGPoint(x: 3, y: 27), control: CGPoint(x: 0, y: 30))
        ctx.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    /// count 片葉子。newestScale 有值時，最後一片用這個比例畫（新葉子彈出來的動畫）。
    static func drawLeaves(_ ctx: GraphicsContext, count: Int, newestScale: CGFloat? = nil) {
        let m = min(count, 36)
        guard m > 0 else { return }
        let scale = 1 + CGFloat(min(count, 60)) / 140
        for i in 0..<m {
            let angle = angles[i % 16] + Double((i * 7) % 9 - 4)
            let len = (38 + CGFloat(i % 4) * 9) * scale
            let wid = 9 + CGFloat(i % 3) * 2
            var g = ctx
            g.rotate(by: .degrees(angle))
            if let s = newestScale, i == m - 1 {
                g.scaleBy(x: s, y: s)
            }
            g.fill(leafPath(len: len, wid: wid), with: .color(i % 2 == 1 ? .leaf : .leaf2))
        }
    }

    /// 第 3 次剛冒芽的兩片小葉子
    static func drawSprout(_ ctx: GraphicsContext, scale: CGFloat) {
        for (angle, color) in [(-28.0, Color.leaf), (28.0, Color.leaf2)] {
            var g = ctx
            g.rotate(by: .degrees(angle))
            g.scaleBy(x: scale, y: scale)
            g.fill(leafPath(len: 22, wid: 8), with: .color(color))
        }
    }
}

/// 還在土裡的蘿蔔。畫在給定範圍的底部正中央，原型的 200×200 畫布對到 base 邊長，
/// 葉子和被往上拖的蘿蔔可以畫進上方多出來的空間。
struct PlantView: View, Animatable {
    var n: Int
    /// 往上拔了多少（原型畫布單位）
    var pull: CGFloat = 0
    /// 最新那片葉子的大小，1 是正常
    var leafScale: CGFloat = 1
    /// 蘿蔔左右歪的角度（只歪蘿蔔，土不動）
    var tilt: CGFloat = 0
    var maxBase: CGFloat = 310

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(pull, AnimatablePair(leafScale, tilt)) }
        set {
            pull = newValue.first
            leafScale = newValue.second.first
            tilt = newValue.second.second
        }
    }

    var body: some View {
        Canvas { context, size in
            let base = min(size.width, size.height, maxBase)
            let s = base / 200
            var c = context
            c.translateBy(x: (size.width - base) / 2, y: size.height - base)
            c.scaleBy(x: s, y: s)

            c.fill(Path(ellipseIn: CGRect(x: 14, y: 176, width: 172, height: 20)), with: .color(.black.opacity(0.06)))

            if n >= 3 {
                let length = RadishGeometry.bodyLen(n)
                var g = c
                g.translateBy(x: 100, y: 150 - pull)
                if tilt != 0 {
                    g.translateBy(x: 0, y: length)
                    g.rotate(by: .degrees(Double(tilt)))
                    g.translateBy(x: 0, y: -length)
                }
                RadishGeometry.drawBody(g, length: length)
                RadishGeometry.drawFace(g)
                if n == 3 {
                    RadishGeometry.drawSprout(g, scale: leafScale)
                } else {
                    RadishGeometry.drawLeaves(g, count: n - 3, newestScale: leafScale)
                }
            }

            var soil = Path()
            soil.move(to: CGPoint(x: 10, y: 200))
            soil.addLine(to: CGPoint(x: 10, y: 176))
            soil.addCurve(to: CGPoint(x: 190, y: 176), control1: CGPoint(x: 40, y: 150), control2: CGPoint(x: 160, y: 150))
            soil.addLine(to: CGPoint(x: 190, y: 200))
            soil.closeSubpath()
            c.fill(soil, with: .color(.soil))

            var soilFront = Path()
            soilFront.move(to: CGPoint(x: 10, y: 200))
            soilFront.addLine(to: CGPoint(x: 10, y: 186))
            soilFront.addCurve(to: CGPoint(x: 190, y: 186), control1: CGPoint(x: 50, y: 172), control2: CGPoint(x: 150, y: 172))
            soilFront.addLine(to: CGPoint(x: 190, y: 200))
            soilFront.closeSubpath()
            c.fill(soilFront, with: .color(.soil2.opacity(0.55)))

            if n < 3 {
                let seedFill = Color(red: 0xE9 / 255.0, green: 0xD9 / 255.0, blue: 0xA8 / 255.0)
                let seedLine = Color(red: 0xC9 / 255.0, green: 0xB7 / 255.0, blue: 0x7F / 255.0)
                var g = c
                g.translateBy(x: 100, y: 168)
                if tilt != 0 { g.rotate(by: .degrees(Double(tilt) * 2)) }
                let seed = Path(ellipseIn: CGRect(x: -9, y: -12, width: 18, height: 12))
                g.fill(seed, with: .color(seedFill))
                g.stroke(seed, with: .color(seedLine), lineWidth: 1.2)
                for i in 0..<3 {
                    let dot = Path(ellipseIn: CGRect(x: CGFloat(86 + i * 14) - 3, y: 182 - 3, width: 6, height: 6))
                    c.fill(dot, with: .color(i < n ? seedFill : Color.white.opacity(0.22)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 拔起來的整根蘿蔔（index.html:219-222）
struct PulledView: View {
    var n: Int

    static func boxHeight(_ n: Int) -> CGFloat {
        74 + RadishGeometry.bodyLen(n) + 8
    }

    var body: some View {
        Canvas { context, size in
            let h = PulledView.boxHeight(n)
            let s = min(size.width / 80, size.height / h)
            var g = context
            g.translateBy(x: (size.width - 80 * s) / 2, y: size.height - h * s)
            g.scaleBy(x: s, y: s)
            g.translateBy(x: 40, y: 74)
            g.scaleBy(x: 0.8, y: 0.8)
            RadishGeometry.drawBody(g, length: RadishGeometry.bodyLen(n))
            RadishGeometry.drawFace(g)
            RadishGeometry.drawLeaves(g, count: max(2, min(n - 3, 14)))
        }
        .accessibilityHidden(true)
    }
}
