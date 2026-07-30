import SwiftUI

/// 日記アプリ専用の、丸い手描き風線画アイコン。
/// SF Symbolsや絵文字のOSごとの見た目に依存せず、MacとiPadで同じ印象を保つ。
enum DiaryLineIconKind {
    case journal
    case rainCloud
    case cloud
    case cloudSun
    case halfMoon
    case smallSun
    case sun
    case sparkle
    case mood(Int)

    static func forMoodScore(_ score: Int) -> DiaryLineIconKind {
        switch max(1, min(score, 7)) {
        case 1: return .rainCloud
        case 2: return .cloud
        case 3: return .cloudSun
        case 4: return .halfMoon
        case 5: return .smallSun
        case 6: return .sun
        default: return .sparkle
        }
    }
}

struct DiaryLineIcon: View {
    let kind: DiaryLineIconKind
    let color: Color
    let size: CGFloat

    init(kind: DiaryLineIconKind, color: Color = DiaryTheme.ink, size: CGFloat = 36) {
        self.kind = kind
        self.color = color
        self.size = size
    }

    var body: some View {
        Canvas { context, canvasSize in
            let lineWidth = max(1.5, canvasSize.width * 0.065)
            let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

            switch resolvedKind {
            case .journal:
                drawJournal(in: &context, size: canvasSize, stroke: stroke)
            case .rainCloud:
                drawCloud(in: &context, size: canvasSize, stroke: stroke, rain: true)
            case .cloud:
                drawCloud(in: &context, size: canvasSize, stroke: stroke, rain: false)
            case .cloudSun:
                drawSun(in: &context, size: canvasSize, stroke: stroke, rays: false)
                drawCloud(in: &context, size: canvasSize, stroke: stroke, rain: false)
            case .halfMoon:
                drawHalfMoon(in: &context, size: canvasSize, stroke: stroke)
            case .smallSun:
                drawSun(in: &context, size: canvasSize, stroke: stroke, rays: false)
            case .sun:
                drawSun(in: &context, size: canvasSize, stroke: stroke, rays: true)
            case .sparkle:
                drawSparkle(in: &context, size: canvasSize, stroke: stroke)
            case .mood:
                break
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var resolvedKind: DiaryLineIconKind {
        if case .mood(let score) = kind {
            return DiaryLineIconKind.forMoodScore(score)
        }
        return kind
    }

    private func drawJournal(
        in context: inout GraphicsContext,
        size: CGSize,
        stroke: StrokeStyle
    ) {
        let rect = CGRect(x: size.width * 0.18, y: size.height * 0.12, width: size.width * 0.64, height: size.height * 0.76)
        context.stroke(Path(roundedRect: rect, cornerRadius: size.width * 0.12), with: .color(color), style: stroke)

        var heart = Path()
        heart.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.58))
        heart.addCurve(
            to: CGPoint(x: size.width * 0.35, y: size.height * 0.40),
            control1: CGPoint(x: size.width * 0.34, y: size.height * 0.54),
            control2: CGPoint(x: size.width * 0.35, y: size.height * 0.40)
        )
        heart.addCurve(
            to: CGPoint(x: size.width * 0.50, y: size.height * 0.48),
            control1: CGPoint(x: size.width * 0.43, y: size.height * 0.32),
            control2: CGPoint(x: size.width * 0.50, y: size.height * 0.40)
        )
        heart.addCurve(
            to: CGPoint(x: size.width * 0.65, y: size.height * 0.40),
            control1: CGPoint(x: size.width * 0.50, y: size.height * 0.40),
            control2: CGPoint(x: size.width * 0.57, y: size.height * 0.32)
        )
        heart.addCurve(
            to: CGPoint(x: size.width * 0.50, y: size.height * 0.58),
            control1: CGPoint(x: size.width * 0.65, y: size.height * 0.54),
            control2: CGPoint(x: size.width * 0.66, y: size.height * 0.40)
        )
        context.stroke(heart, with: .color(color), style: stroke)

        var note = Path()
        note.move(to: CGPoint(x: size.width * 0.32, y: size.height * 0.70))
        note.addLine(to: CGPoint(x: size.width * 0.68, y: size.height * 0.70))
        context.stroke(note, with: .color(color), style: stroke)
    }

    private func drawCloud(
        in context: inout GraphicsContext,
        size: CGSize,
        stroke: StrokeStyle,
        rain: Bool
    ) {
        let cloud = cloudPath(in: CGRect(x: size.width * 0.14, y: size.height * 0.25, width: size.width * 0.72, height: size.height * 0.42))
        context.stroke(cloud, with: .color(color), style: stroke)

        guard rain else { return }
        for index in 0..<3 {
            let x = size.width * (0.34 + CGFloat(index) * 0.16)
            var drop = Path()
            drop.move(to: CGPoint(x: x, y: size.height * 0.76))
            drop.addLine(to: CGPoint(x: x - size.width * 0.035, y: size.height * 0.87))
            context.stroke(drop, with: .color(color), style: stroke)
        }
    }

    private func cloudPath(in rect: CGRect) -> Path {
        var path = Path()
        let bottom = rect.maxY
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: bottom))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.43 + rect.minX, y: rect.minY + rect.height * 0.40),
            control1: CGPoint(x: rect.minX + rect.width * 0.04, y: bottom),
            control2: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.43)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.30),
            control1: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.04),
            control2: CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.03)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.10, y: bottom),
            control1: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.20),
            control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.47)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: bottom))
        return path
    }

    private func drawSun(
        in context: inout GraphicsContext,
        size: CGSize,
        stroke: StrokeStyle,
        rays: Bool
    ) {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.50)
        let radius = size.width * 0.18
        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(color), style: stroke)

        guard rays else { return }
        for index in 0..<8 {
            let angle = Double(index) * Double.pi / 4
            let inner = radius * 1.55
            let outer = radius * 2.15
            var ray = Path()
            ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            context.stroke(ray, with: .color(color), style: stroke)
        }
    }

    private func drawHalfMoon(
        in context: inout GraphicsContext,
        size: CGSize,
        stroke: StrokeStyle
    ) {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.50)
        let radius = size.width * 0.27
        var moon = Path()
        moon.addArc(center: center, radius: radius, startAngle: .degrees(-70), endAngle: .degrees(70), clockwise: false)
        moon.addArc(center: CGPoint(x: center.x + size.width * 0.12, y: center.y), radius: radius * 0.88, startAngle: .degrees(70), endAngle: .degrees(-70), clockwise: true)
        context.stroke(moon, with: .color(color), style: stroke)
    }

    private func drawSparkle(
        in context: inout GraphicsContext,
        size: CGSize,
        stroke: StrokeStyle
    ) {
        drawSparkleShape(in: &context, center: CGPoint(x: size.width * 0.50, y: size.height * 0.48), radius: size.width * 0.28, stroke: stroke)
        drawSparkleShape(in: &context, center: CGPoint(x: size.width * 0.76, y: size.height * 0.25), radius: size.width * 0.10, stroke: stroke)
    }

    private func drawSparkleShape(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        stroke: StrokeStyle
    ) {
        var sparkle = Path()
        sparkle.move(to: CGPoint(x: center.x, y: center.y - radius))
        sparkle.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        sparkle.move(to: CGPoint(x: center.x - radius, y: center.y))
        sparkle.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        context.stroke(sparkle, with: .color(color), style: stroke)
    }
}
