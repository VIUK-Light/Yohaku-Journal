import Foundation
import LocalAuthentication
import SwiftUI

struct DeviceOwnerAuthenticationClient {
    var authenticate: (_ reason: String) async throws -> Void

    static let live = DeviceOwnerAuthenticationClient { reason in
        let context = LAContext()
        context.localizedCancelTitle = "キャンセル"

        var evaluationError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &evaluationError
        ) else {
            throw DeviceOwnerAuthenticationError.from(evaluationError)
        }

        do {
            let didAuthenticate = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            guard didAuthenticate else {
                throw DeviceOwnerAuthenticationError.failed
            }
        } catch {
            throw DeviceOwnerAuthenticationError.from(error as NSError)
        }
    }
}

enum DeviceOwnerAuthenticationError: Error, Equatable, LocalizedError {
    case unavailable
    case passcodeNotSet
    case cancelled
    case lockedOut
    case failed

    static func from(_ error: NSError?) -> DeviceOwnerAuthenticationError {
        guard let error,
              error.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: error.code) else {
            return .unavailable
        }

        switch code {
        case .passcodeNotSet:
            return .passcodeNotSet
        case .userCancel, .systemCancel, .appCancel:
            return .cancelled
        case .biometryLockout:
            return .lockedOut
        case .authenticationFailed:
            return .failed
        default:
            return .unavailable
        }
    }

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "この端末では端末認証を利用できません。"
        case .passcodeNotSet:
            return "端末のパスコードを設定すると、アプリロックを利用できます。"
        case .cancelled:
            return "端末認証をキャンセルしました。"
        case .lockedOut:
            return "認証が一時的にロックされています。端末の案内に従ってください。"
        case .failed:
            return "端末認証を確認できませんでした。"
        }
    }
}

@MainActor
final class AppLockController: ObservableObject {
    static let defaultsKey = "isDiaryAppLockEnabled"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked: Bool
    @Published private(set) var isPrivacyShieldVisible: Bool
    @Published private(set) var isAuthenticating = false
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults
    private let authenticationClient: DeviceOwnerAuthenticationClient

    init(
        defaults: UserDefaults = .standard,
        authenticationClient: DeviceOwnerAuthenticationClient = .live
    ) {
        self.defaults = defaults
        self.authenticationClient = authenticationClient
        let enabled = defaults.bool(forKey: Self.defaultsKey)
        isEnabled = enabled
        isLocked = enabled
        isPrivacyShieldVisible = enabled
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive, .background:
            protectForBackground()
        case .active:
            Task { await unlockIfNeeded() }
        @unknown default:
            protectForBackground()
        }
    }

    func protectForBackground() {
        guard isEnabled else { return }
        isPrivacyShieldVisible = true
        isLocked = true
        errorMessage = nil
    }

    @discardableResult
    func enableLock() async -> Bool {
        guard !isEnabled else { return true }
        guard await authenticate(reason: "日記のアプリロックを有効にします。") else {
            isPrivacyShieldVisible = isLocked
            return false
        }

        defaults.set(true, forKey: Self.defaultsKey)
        isEnabled = true
        isLocked = false
        isPrivacyShieldVisible = false
        return true
    }

    @discardableResult
    func disableLock() async -> Bool {
        guard isEnabled else { return true }
        guard await authenticate(reason: "日記のアプリロックを無効にします。") else {
            isPrivacyShieldVisible = isLocked
            return false
        }

        defaults.set(false, forKey: Self.defaultsKey)
        isEnabled = false
        isLocked = false
        isPrivacyShieldVisible = false
        errorMessage = nil
        return true
    }

    func lockNow() {
        guard isEnabled else { return }
        isLocked = true
        isPrivacyShieldVisible = true
        errorMessage = nil
    }

    func unlockIfNeeded() async {
        guard isEnabled, isLocked else {
            isPrivacyShieldVisible = false
            return
        }
        _ = await authenticateForUnlock()
    }

    @discardableResult
    func authenticateForUnlock() async -> Bool {
        guard isEnabled else { return true }
        guard await authenticate(reason: "日記の記録を開きます。") else {
            isPrivacyShieldVisible = false
            isLocked = true
            return false
        }

        isPrivacyShieldVisible = false
        isLocked = false
        return true
    }

    private func authenticate(reason: String) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        isPrivacyShieldVisible = true
        errorMessage = nil
        defer { isAuthenticating = false }

        do {
            try await authenticationClient.authenticate(reason)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "端末認証を確認できませんでした。"
            return false
        }
    }
}

@MainActor
final class DiaryDataProtectionStatus: ObservableObject {
    @Published private(set) var report: DiaryFileProtectionReport

    init(report: DiaryFileProtectionReport) {
        self.report = report
    }

    func refresh() {
        report = DiaryFileProtectionService.refreshProtection(at: report.storeURL)
    }
}

struct PrivacyProtectedRootView<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var lockController: AppLockController
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            content()

            if lockController.isPrivacyShieldVisible || lockController.isLocked {
                DiaryPrivacyCover(lockController: lockController)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onAppear {
            lockController.handleScenePhase(scenePhase)
        }
        .onChange(of: scenePhase) { _, phase in
            lockController.handleScenePhase(phase)
        }
    }
}

private struct DiaryPrivacyCover: View {
    @ObservedObject var lockController: AppLockController

    var body: some View {
        ZStack {
            DiaryTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 18) {
                DiaryLineIcon(kind: .journal, color: DiaryTheme.accent, size: 58)

                Text("心の記録は保護されています")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DiaryTheme.ink)
                    .multilineTextAlignment(.center)

                if lockController.isAuthenticating {
                    ProgressView("端末認証を確認中")
                        .tint(DiaryTheme.accent)
                } else if lockController.isEnabled && lockController.isLocked {
                    Button {
                        Task { await lockController.authenticateForUnlock() }
                    } label: {
                        Label("ロックを解除", systemImage: "lock.open")
                            .frame(minWidth: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(DiaryTheme.accent)
                }

                if let errorMessage = lockController.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(DiaryTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
    }
}
