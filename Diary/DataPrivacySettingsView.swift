import Foundation
import SwiftData
import SwiftUI

struct DataPrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var lockController: AppLockController
    @EnvironmentObject private var protectionStatus: DiaryDataProtectionStatus

    @State private var counts = DiaryDataCounts.zero
    @State private var isWorking = false
    @State private var pendingBackup: PendingBackup?
    @State private var pendingEncryptedRestore: PendingEncryptedRestore?
    @State private var pendingRestore: PendingRestore?
    @State private var exportDocument: EncryptedDiaryArchiveDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isShowingDeletion = false
    @State private var notice: DataManagementNotice?

    var body: some View {
        List {
            appLockSection
            localStorageSection
            backupSection
            deletionSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("プライバシーとデータ")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isWorking {
                ZStack {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                    ProgressView("処理中…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityLabel("処理中")
            }
        }
        .task {
            refreshCounts()
            protectionStatus.refresh()
        }
        .sheet(item: $pendingBackup) { item in
            BackupPasswordSheet(archive: item.archive) { encryptedData in
                exportDocument = EncryptedDiaryArchiveDocument(encryptedData: encryptedData)
                pendingBackup = nil
                Task {
                    await Task.yield()
                    isExporting = true
                }
            }
        }
        .sheet(item: $pendingEncryptedRestore) { item in
            RestorePasswordSheet(encryptedData: item.encryptedData) { archive in
                pendingEncryptedRestore = nil
                Task {
                    await Task.yield()
                    prepareRestorePreview(for: archive)
                }
            }
        }
        .sheet(item: $pendingRestore) { item in
            RestorePreviewSheet(item: item) { policy in
                performRestore(item.archive, policy: policy)
            }
        }
        .sheet(isPresented: $isShowingDeletion) {
            FullDataDeletionSheet(counts: counts) {
                performFullDeletion()
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .yohakuJournalBackup,
            defaultFilename: backupFilename
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.yohakuJournalBackup],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var appLockSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: lockController.isEnabled ? "lock.fill" : "lock.open")
                    .foregroundStyle(DiaryTheme.accent)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lockController.isEnabled ? "アプリロックは有効です" : "アプリロックは無効です")
                        .font(.subheadline.weight(.semibold))
                    Text("Face ID・Touch ID・端末パスコードのいずれかを使います。独自の暗証番号は保存しません。")
                        .font(.caption)
                        .foregroundStyle(DiaryTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)

            Button(lockController.isEnabled ? "アプリロックを無効にする" : "アプリロックを有効にする") {
                changeAppLockSetting()
            }
            .disabled(lockController.isAuthenticating || isWorking)

            if lockController.isEnabled {
                Button("今すぐロック") {
                    lockController.lockNow()
                }
            }

            if let errorMessage = lockController.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.emergency)
            }
        } header: {
            Text("アプリロック")
        } footer: {
            Text("ロック中は記録内容を表示せず、アプリ切替画面にも保護画面を表示します。端末認証を解除した場合は、端末設定で再び有効にするまで開けません。")
        }
    }

    private var localStorageSection: some View {
        Section("端末内保存") {
            dataCountRow("日記", count: counts.moodEntries)
            dataCountRow("セルフチェック", count: counts.assessments)
            dataCountRow("安全確認日時", count: counts.safetyChecks)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: protectionStatus.report.isProtected ? "checkmark.shield" : "exclamationmark.shield")
                    .foregroundStyle(
                        protectionStatus.report.isProtected
                            ? DiaryTheme.green
                            : DiaryTheme.emergency
                    )
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 4) {
                    Text(protectionStatus.report.isProtected ? "追加ファイル保護を適用" : "追加ファイル保護を未確認")
                        .font(.subheadline.weight(.semibold))
                    Text(
                        protectionStatus.report.warning
                            ?? "記録はアプリ専用領域に保存し、端末がロックされている間は読み書きできない保護を適用します。"
                    )
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                beginBackup()
            } label: {
                Label("暗号化バックアップを作成", systemImage: "lock.doc")
            }
            .disabled(isWorking)

            Button {
                isImporting = true
            } label: {
                Label("バックアップから復元", systemImage: "arrow.clockwise.icloud")
            }
            .disabled(isWorking)
        } header: {
            Text("手動バックアップ")
        } footer: {
            Text("バックアップはパスワードから作った鍵で暗号化します。パスワードは端末にもファイルにも保存されず、忘れた場合は復元できません。復元前には件数と競合を確認できます。")
        }
    }

    private var deletionSection: some View {
        Section {
            Button("端末内の記録をすべて削除", role: .destructive) {
                isShowingDeletion = true
            }
            .disabled(counts.total == 0 || isWorking)
        } header: {
            Text("すべての記録を削除")
        } footer: {
            Text("日記、セルフチェック、安全確認日時をまとめて削除します。アプリロックなどの設定は残ります。失敗した場合は削除前のデータへ戻します。")
        }
    }

    private func dataCountRow(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)件")
                .foregroundStyle(DiaryTheme.muted)
                .monospacedDigit()
        }
    }

    private var backupFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: Date())
        return "Yohaku-Journal-\(date).yohakubackup"
    }

    private func changeAppLockSetting() {
        Task {
            isWorking = true
            defer { isWorking = false }
            if lockController.isEnabled {
                _ = await lockController.disableLock()
            } else {
                _ = await lockController.enableLock()
            }
        }
    }

    private func beginBackup() {
        do {
            let archive = try DiaryArchiveDataService.makeArchive(in: modelContext)
            pendingBackup = PendingBackup(archive: archive)
        } catch {
            showError(title: "バックアップを準備できませんでした", error: error)
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        exportDocument = nil
        switch result {
        case .success(let url):
            do {
                try DiaryFileProtectionService.applyCompleteProtection(to: url)
                notice = DataManagementNotice(
                    title: "バックアップを保存しました",
                    message: "暗号化済みのファイルだけを書き出しました。"
                )
            } catch {
                notice = DataManagementNotice(
                    title: "暗号化バックアップを保存しました",
                    message: "内容は暗号化されていますが、保存先の追加ファイル保護は確認できませんでした: \(error.localizedDescription)"
                )
            }
        case .failure(let error):
            if !isUserCancellation(error) {
                showError(title: "バックアップを保存できませんでした", error: error)
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isWorking = true
            Task {
                defer { isWorking = false }
                do {
                    let encryptedData = try await Task.detached(priority: .userInitiated) {
                        try DiaryArchiveFileReader.readEncryptedData(from: url)
                    }.value
                    _ = try DiaryArchiveCrypto.metadata(from: encryptedData)
                    pendingEncryptedRestore = PendingEncryptedRestore(
                        encryptedData: encryptedData
                    )
                } catch {
                    showError(title: "バックアップを開けませんでした", error: error)
                }
            }
        case .failure(let error):
            if !isUserCancellation(error) {
                showError(title: "バックアップを選べませんでした", error: error)
            }
        }
    }

    private func prepareRestorePreview(for archive: DiaryArchiveV1) {
        do {
            let preview = try DiaryArchiveDataService.preview(
                archive: archive,
                in: modelContext
            )
            pendingRestore = PendingRestore(archive: archive, preview: preview)
        } catch {
            showError(title: "復元内容を確認できませんでした", error: error)
        }
    }

    private func performRestore(
        _ archive: DiaryArchiveV1,
        policy: RestoreConflictPolicy
    ) -> Bool {
        do {
            let result = try DiaryArchiveDataService.restore(
                archive: archive,
                conflictPolicy: policy,
                in: modelContext
            )
            pendingRestore = nil
            refreshCounts()
            notice = DataManagementNotice(
                title: "復元しました",
                message: "追加 \(result.inserted.total)件、置換 \(result.replaced.total)件。"
            )
            return true
        } catch {
            showError(title: "復元できませんでした", error: error)
            return false
        }
    }

    private func performFullDeletion() -> Bool {
        do {
            let deleted = try DiaryArchiveDataService.deleteAll(in: modelContext)
            isShowingDeletion = false
            refreshCounts()
            notice = DataManagementNotice(
                title: "記録を削除しました",
                message: "端末内の記録 \(deleted.total)件を削除しました。"
            )
            return true
        } catch {
            showError(title: "削除できませんでした", error: error)
            return false
        }
    }

    private func refreshCounts() {
        do {
            counts = try DiaryArchiveDataService.counts(in: modelContext)
        } catch {
            showError(title: "記録件数を確認できませんでした", error: error)
        }
    }

    private func showError(title: String, error: Error) {
        notice = DataManagementNotice(
            title: title,
            message: (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        )
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        let cocoaError = error as NSError
        return cocoaError.domain == NSCocoaErrorDomain
            && cocoaError.code == CocoaError.userCancelled.rawValue
    }
}

private struct PendingBackup: Identifiable {
    let id = UUID()
    let archive: DiaryArchiveV1
}

private struct PendingEncryptedRestore: Identifiable {
    let id = UUID()
    let encryptedData: Data
}

private struct PendingRestore: Identifiable {
    let id = UUID()
    let archive: DiaryArchiveV1
    let preview: DiaryArchiveRestorePreview
}

private struct DataManagementNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct BackupPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let archive: DiaryArchiveV1
    let onEncrypted: (Data) -> Void

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("12文字以上", text: $password)
                        .textContentType(.newPassword)
                    SecureField("もう一度入力", text: $confirmation)
                        .textContentType(.newPassword)
                } header: {
                    Text("バックアップ用パスワード")
                } footer: {
                    Text("このパスワードは保存されません。復元時に同じ文字列が必要です。長いフレーズを推奨します。")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(DiaryTheme.emergency)
                    }
                }
            }
            .navigationTitle("バックアップを暗号化")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") { encryptArchive() }
                        .disabled(!canCreate || isWorking)
                }
            }
            .overlay {
                if isWorking {
                    ProgressView("暗号化中…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
        .onDisappear {
            password = ""
            confirmation = ""
        }
    }

    private var canCreate: Bool {
        password.count >= DiaryArchivePasswordPolicy.minimumCharacterCount
            && password == confirmation
    }

    private func encryptArchive() {
        guard password == confirmation else {
            errorMessage = "確認用パスワードが一致しません。"
            return
        }
        let passwordForEncryption = password
        isWorking = true
        errorMessage = nil

        Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try DiaryArchiveCrypto.encrypt(
                        archive: archive,
                        password: passwordForEncryption
                    )
                }.value
                password = ""
                confirmation = ""
                onEncrypted(data)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            isWorking = false
        }
    }
}

private struct RestorePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let encryptedData: Data
    let onDecrypted: (DiaryArchiveV1) -> Void

    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("バックアップ用パスワード", text: $password)
                        .textContentType(.password)
                } footer: {
                    Text("パスワードは復元処理にだけ使い、保存しません。")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(DiaryTheme.emergency)
                    }
                }
            }
            .navigationTitle("バックアップを開く")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確認") { decryptArchive() }
                        .disabled(password.isEmpty || isWorking)
                }
            }
            .overlay {
                if isWorking {
                    ProgressView("確認中…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
        .onDisappear { password = "" }
    }

    private func decryptArchive() {
        let passwordForDecryption = password
        isWorking = true
        errorMessage = nil

        Task {
            do {
                let archive = try await Task.detached(priority: .userInitiated) {
                    try DiaryArchiveCrypto.decrypt(
                        encryptedData: encryptedData,
                        password: passwordForDecryption
                    )
                }.value
                password = ""
                onDecrypted(archive)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            isWorking = false
        }
    }
}

private struct RestorePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: PendingRestore
    let onRestore: (RestoreConflictPolicy) -> Bool

    @State private var policy: RestoreConflictPolicy = .keepCurrent

    var body: some View {
        NavigationStack {
            List {
                Section("バックアップの内容") {
                    countRow("日記", item.preview.archiveCounts.moodEntries)
                    countRow("セルフチェック", item.preview.archiveCounts.assessments)
                    countRow("安全確認日時", item.preview.archiveCounts.safetyChecks)
                    countRow("新しく追加される記録", item.preview.newRecordCount)
                }

                Section {
                    Picker("同じIDの記録", selection: $policy) {
                        ForEach(RestoreConflictPolicy.allCases) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("競合 \(item.preview.conflictCounts.total)件")
                } footer: {
                    Text("既定では端末内の現在の記録を残します。置換を選ぶと、同じIDの記録だけをバックアップ側の内容へ更新します。")
                }
            }
            .navigationTitle("復元前の確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("復元") {
                        if onRestore(policy) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func countRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)件")
                .foregroundStyle(DiaryTheme.muted)
                .monospacedDigit()
        }
    }
}

private struct FullDataDeletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let counts: DiaryDataCounts
    let onDelete: () -> Bool

    @State private var isFinalStep = false
    @State private var confirmationText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("この操作は元に戻せません", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(DiaryTheme.emergency)
                    countRow("日記", counts.moodEntries)
                    countRow("セルフチェック", counts.assessments)
                    countRow("安全確認日時", counts.safetyChecks)
                }

                if isFinalStep {
                    Section {
                        TextField("削除する", text: $confirmationText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("確認のため「削除する」と入力")
                    } footer: {
                        Text("削除は全種類をまとめて1回で確定します。途中で失敗した場合は変更を取り消します。")
                    }
                }
            }
            .navigationTitle(isFinalStep ? "最終確認" : "すべての記録を削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isFinalStep {
                        Button("完全に削除", role: .destructive) {
                            if onDelete() {
                                dismiss()
                            }
                        }
                        .disabled(confirmationText != "削除する")
                    } else {
                        Button("確認へ進む") {
                            isFinalStep = true
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isFinalStep)
    }

    private func countRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)件")
                .foregroundStyle(DiaryTheme.muted)
                .monospacedDigit()
        }
    }
}
