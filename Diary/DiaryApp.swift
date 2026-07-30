import SwiftUI
import SwiftData
import UIKit

/// 日記アプリ全体で共有する「静かな記録帳」テーマ。
/// 画面ごとに色を決めないことで、選択状態と重要な操作の意味を統一する。
enum DiaryTheme {
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.105, blue: 0.12, alpha: 1)
            : UIColor(red: 0.965, green: 0.95, blue: 0.925, alpha: 1)
    })

    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.155, blue: 0.17, alpha: 1)
            : UIColor(red: 0.995, green: 0.985, blue: 0.965, alpha: 1)
    })

    static let elevatedSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.19, green: 0.195, blue: 0.21, alpha: 1)
            : UIColor.white
    })

    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let line = Color(uiColor: .separator).opacity(0.55)

    // 主操作は1色に揃え、ボタンの意味を迷わせない。
    static let accent = Color(red: 0.80, green: 0.29, blue: 0.30)
    static let accentSoft = accent.opacity(0.13)

    static let blue = Color(red: 0.29, green: 0.40, blue: 0.68)
    static let green = Color(red: 0.29, green: 0.49, blue: 0.38)
    static let orange = Color(red: 0.70, green: 0.43, blue: 0.19)
    static let purple = Color(red: 0.49, green: 0.35, blue: 0.61)

    static let moodColors: [Color] = [
        Color(red: 0.35, green: 0.39, blue: 0.62),
        Color(red: 0.46, green: 0.48, blue: 0.62),
        Color(red: 0.66, green: 0.53, blue: 0.35),
        Color(red: 0.47, green: 0.48, blue: 0.48),
        Color(red: 0.36, green: 0.56, blue: 0.48),
        Color(red: 0.30, green: 0.55, blue: 0.41),
        accent
    ]

    static func moodColor(for score: Int) -> Color {
        moodColors[max(0, min(score - 1, moodColors.count - 1))]
    }
}

enum DiaryRuntime {
    static var isMacWindow: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        ProcessInfo.processInfo.isiOSAppOnMac
#endif
    }
}

private struct DiarySurfaceModifier: ViewModifier {
    let padding: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DiaryTheme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DiaryTheme.line, lineWidth: 1)
            }
    }
}

extension View {
    func diarySurface(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        modifier(DiarySurfaceModifier(padding: padding, radius: radius))
    }
}

@main
struct ScienceClubDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            MoodJournalView()
                .tint(DiaryTheme.accent)
#if canImport(UIKit)
                .background(MacWindowConfigurator())
#endif
        }
        .modelContainer(for: [MoodEntry.self, MentalHealthAssessment.self])
#if targetEnvironment(macCatalyst)
        // Macでは縦長のiPhone画面にならないよう、横長の初期ウィンドウを指定する。
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
#endif
    }
}

#if canImport(UIKit)
/// 保存済みの縦長ウィンドウが残っていても、Macの2カラムUIを表示できる幅へ戻す。
private struct MacWindowConfigurator: UIViewRepresentable {
    private let minimumSize = CGSize(width: 1024, height: 700)

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            configure(uiView.window)
        }
    }

    private func configure(_ window: UIWindow?) {
        guard DiaryRuntime.isMacWindow,
              let window,
              let windowScene = window.windowScene else { return }

        windowScene.sizeRestrictions?.minimumSize = minimumSize

        var frame = window.frame
        if frame.width < minimumSize.width || frame.height < minimumSize.height {
            frame.size.width = max(frame.width, minimumSize.width)
            frame.size.height = max(frame.height, minimumSize.height)
            window.frame = frame
        }
    }
}
#endif
