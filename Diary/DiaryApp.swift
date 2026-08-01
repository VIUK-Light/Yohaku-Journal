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

    // 通常操作は温かいオレンジに揃える。赤は緊急案内・削除だけに使う。
    static let primary = Color(red: 0.76, green: 0.42, blue: 0.15)
    static let accent = primary
    static let accentSoft = primary.opacity(0.13)
    static let emergency = Color(red: 0.69, green: 0.22, blue: 0.22)

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
    static let macWindowDefaultSize = CGSize(width: 1100, height: 700)
    static let macWindowMinimumSize = CGSize(width: 900, height: 600)

    static var isMacWindow: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        // Designed for iPad on Macの経路は使わず、MacはMac Catalyst版だけを使用する。
        false
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
    @StateObject private var lockController: AppLockController
    @StateObject private var protectionStatus: DiaryDataProtectionStatus

    private let modelContainer: ModelContainer?
    private let storeStartupError: String?

    init() {
        _lockController = StateObject(wrappedValue: AppLockController())

        let startup = Self.prepareStore()
        modelContainer = startup.container
        storeStartupError = startup.errorMessage
        _protectionStatus = StateObject(
            wrappedValue: DiaryDataProtectionStatus(report: startup.protectionReport)
        )
    }

    private struct StoreStartup {
        let container: ModelContainer?
        let errorMessage: String?
        let protectionReport: DiaryFileProtectionReport
    }

    private static func prepareStore() -> StoreStartup {
        let schema = Schema([
            MoodEntry.self,
            MentalHealthAssessment.self,
            LightSafetyCheckRecord.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )
        let initialProtection = DiaryFileProtectionService.prepareStore(
            at: configuration.url
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            return StoreStartup(
                container: container,
                errorMessage: nil,
                protectionReport: DiaryFileProtectionService.refreshProtection(
                    at: initialProtection.storeURL
                )
            )
        } catch {
            return StoreStartup(
                container: nil,
                errorMessage: error.localizedDescription,
                protectionReport: initialProtection
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            PrivacyProtectedRootView(lockController: lockController) {
                if let modelContainer {
                    Group {
                        MoodJournalView()
                            .tint(DiaryTheme.accent)
#if targetEnvironment(macCatalyst)
                            .background(MacWindowConfigurator())
#endif
                    }
                    .environmentObject(lockController)
                    .environmentObject(protectionStatus)
                    .modelContainer(modelContainer)
                } else {
                    DiaryStoreUnavailableView(
                        detail: storeStartupError
                            ?? "端末内の保存領域を開けませんでした。"
                    )
                }
            }
            .environmentObject(lockController)
        }
#if targetEnvironment(macCatalyst)
        // Macでは縦長のiPhone画面にならないよう、横長の初期ウィンドウを指定する。
        .defaultSize(
            width: DiaryRuntime.macWindowDefaultSize.width,
            height: DiaryRuntime.macWindowDefaultSize.height
        )
        .windowResizability(.contentMinSize)
#endif
    }
}

private struct DiaryStoreUnavailableView: View {
    let detail: String

    var body: some View {
        ZStack {
            DiaryTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(DiaryTheme.emergency)

                Text("端末内の記録を開けません")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DiaryTheme.ink)

                Text("データを消したり、一時的な空の保存先へ切り替えたりせず停止しています。アプリを終了してもう一度開いてください。続く場合は、この表示内容を添えて開発者へ連絡してください。")
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: 480)
            .padding(28)
        }
    }
}

#if targetEnvironment(macCatalyst)
/// 保存済みの縦長ウィンドウが残っていても、Macの2カラムUIを表示できる幅へ戻す。
private struct MacWindowConfigurator: UIViewRepresentable {
    private let minimumSize = DiaryRuntime.macWindowMinimumSize

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
