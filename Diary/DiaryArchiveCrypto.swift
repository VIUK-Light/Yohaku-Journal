import CommonCrypto
import CryptoKit
import Foundation
import Security
import SwiftUI
import UniformTypeIdentifiers

struct DiaryArchiveCryptoMetadata: Equatable, Sendable {
    let formatVersion: Int
    let kdfAlgorithm: String
    let iterations: Int
    let cipher: String
}

private struct EncryptedDiaryArchiveHeader: Codable, Equatable, Sendable {
    static let magicValue = "YOHK-ARCHIVE"
    static let currentFormatVersion = 1
    static let kdfName = "PBKDF2-HMAC-SHA256"
    static let cipherName = "AES-256-GCM"

    let magic: String
    let formatVersion: Int
    let kdfAlgorithm: String
    let iterations: Int
    let salt: Data
    let cipher: String
}

private struct EncryptedDiaryArchiveEnvelope: Codable, Equatable, Sendable {
    let header: EncryptedDiaryArchiveHeader
    let nonce: Data
    let ciphertext: Data
    let authenticationTag: Data
}

enum DiaryArchivePasswordPolicy {
    static let minimumCharacterCount = 12
    static let maximumUTF8ByteCount = 1_024

    static func validate(_ password: String) throws {
        guard password.count >= minimumCharacterCount else {
            throw DiaryArchiveCryptoError.passwordTooShort
        }
        guard password.utf8.count <= maximumUTF8ByteCount else {
            throw DiaryArchiveCryptoError.passwordTooLong
        }
    }
}

enum DiaryArchiveCryptoError: Error, Equatable, LocalizedError {
    case passwordTooShort
    case passwordTooLong
    case randomGenerationFailed
    case keyDerivationFailed(Int32)
    case invalidFile
    case fileTooLarge
    case unsupportedEncryption
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .passwordTooShort:
            return "バックアップ用パスワードは12文字以上にしてください。"
        case .passwordTooLong:
            return "バックアップ用パスワードが長すぎます。"
        case .randomGenerationFailed, .keyDerivationFailed:
            return "暗号化の準備に失敗しました。バックアップは作成されていません。"
        case .invalidFile:
            return "Yohaku Journalのバックアップ形式を確認できませんでした。"
        case .fileTooLarge:
            return "バックアップファイルが大きすぎるため、安全に開けません。"
        case .unsupportedEncryption:
            return "このバックアップの暗号化方式には対応していません。"
        case .authenticationFailed:
            return "パスワードが違うか、バックアップファイルが破損しています。"
        }
    }
}

/// PBKDF2-HMAC-SHA256で鍵を作り、AES-256-GCMで内容とヘッダーを認証付き暗号化する。
enum DiaryArchiveCrypto {
    static let currentIterations = 600_000
    static let saltByteCount = 16
    static let keyByteCount = 32
    static let nonceByteCount = 12
    static let authenticationTagByteCount = 16
    static let maximumSupportedIterations = 2_000_000

    static func encrypt(
        archive: DiaryArchiveV1,
        password: String
    ) async throws -> Data {
        try Task.checkCancellation()
        try DiaryArchivePasswordPolicy.validate(password)
        try archive.validate()
        try Task.checkCancellation()

        let salt = try secureRandomData(count: saltByteCount)
        let header = EncryptedDiaryArchiveHeader(
            magic: EncryptedDiaryArchiveHeader.magicValue,
            formatVersion: EncryptedDiaryArchiveHeader.currentFormatVersion,
            kdfAlgorithm: EncryptedDiaryArchiveHeader.kdfName,
            iterations: currentIterations,
            salt: salt,
            cipher: EncryptedDiaryArchiveHeader.cipherName
        )
        let authenticatedHeader = try canonicalEncoder().encode(header)
        let plaintext = try archiveEncoder().encode(archive)
        try Task.checkCancellation()
        guard plaintext.count <= DiaryArchiveLimits.maximumEncryptedFileBytes else {
            throw DiaryArchiveCryptoError.fileTooLarge
        }

        let derivedKey = try deriveKeyData(
            password: password,
            salt: salt,
            iterations: currentIterations,
            keyByteCount: keyByteCount
        )
        try Task.checkCancellation()
        let symmetricKey = SymmetricKey(data: derivedKey)
        let nonceData = try secureRandomData(count: nonceByteCount)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.seal(
            plaintext,
            using: symmetricKey,
            nonce: nonce,
            authenticating: authenticatedHeader
        )
        try Task.checkCancellation()

        let envelope = EncryptedDiaryArchiveEnvelope(
            header: header,
            nonce: nonceData,
            ciphertext: sealed.ciphertext,
            authenticationTag: sealed.tag
        )
        let encryptedData = try canonicalEncoder().encode(envelope)
        try Task.checkCancellation()
        guard encryptedData.count <= DiaryArchiveLimits.maximumEncryptedFileBytes else {
            throw DiaryArchiveCryptoError.fileTooLarge
        }
        return encryptedData
    }

    static func decrypt(
        encryptedData: Data,
        password: String
    ) async throws -> DiaryArchiveV1 {
        try Task.checkCancellation()
        guard encryptedData.count <= DiaryArchiveLimits.maximumEncryptedFileBytes else {
            throw DiaryArchiveCryptoError.fileTooLarge
        }
        try DiaryArchivePasswordPolicy.validate(password)

        let envelope: EncryptedDiaryArchiveEnvelope
        do {
            envelope = try canonicalDecoder().decode(
                EncryptedDiaryArchiveEnvelope.self,
                from: encryptedData
            )
        } catch {
            throw DiaryArchiveCryptoError.invalidFile
        }
        try validate(envelope)

        let authenticatedHeader = try canonicalEncoder().encode(envelope.header)
        let derivedKey = try deriveKeyData(
            password: password,
            salt: envelope.header.salt,
            iterations: envelope.header.iterations,
            keyByteCount: keyByteCount
        )
        try Task.checkCancellation()

        let plaintext: Data
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: envelope.nonce),
                ciphertext: envelope.ciphertext,
                tag: envelope.authenticationTag
            )
            plaintext = try AES.GCM.open(
                sealedBox,
                using: SymmetricKey(data: derivedKey),
                authenticating: authenticatedHeader
            )
        } catch {
            try Task.checkCancellation()
            throw DiaryArchiveCryptoError.authenticationFailed
        }
        try Task.checkCancellation()

        let archive: DiaryArchiveV1
        do {
            archive = try archiveDecoder().decode(DiaryArchiveV1.self, from: plaintext)
        } catch {
            try Task.checkCancellation()
            throw DiaryArchiveCryptoError.invalidFile
        }
        try Task.checkCancellation()
        try archive.validate()
        try Task.checkCancellation()
        return archive
    }

    static func metadata(from encryptedData: Data) throws -> DiaryArchiveCryptoMetadata {
        guard encryptedData.count <= DiaryArchiveLimits.maximumEncryptedFileBytes else {
            throw DiaryArchiveCryptoError.fileTooLarge
        }
        let envelope: EncryptedDiaryArchiveEnvelope
        do {
            envelope = try canonicalDecoder().decode(
                EncryptedDiaryArchiveEnvelope.self,
                from: encryptedData
            )
        } catch {
            throw DiaryArchiveCryptoError.invalidFile
        }
        try validate(envelope)
        return DiaryArchiveCryptoMetadata(
            formatVersion: envelope.header.formatVersion,
            kdfAlgorithm: envelope.header.kdfAlgorithm,
            iterations: envelope.header.iterations,
            cipher: envelope.header.cipher
        )
    }

    /// 既知ベクトル試験でも使用するため、反復回数を受け取る低水準関数。
    /// 実際のアーカイブ作成は必ず`currentIterations`を使用する。
    static func deriveKeyData(
        password: String,
        salt: Data,
        iterations: Int,
        keyByteCount: Int
    ) throws -> Data {
        guard iterations > 0,
              iterations <= maximumSupportedIterations,
              keyByteCount > 0 else {
            throw DiaryArchiveCryptoError.unsupportedEncryption
        }

        let normalizedPassword = password.precomposedStringWithCanonicalMapping
        var passwordBytes = Array(normalizedPassword.utf8)
        var derivedBytes = [UInt8](repeating: 0, count: keyByteCount)
        defer {
            passwordBytes.withUnsafeMutableBytes { buffer in
                buffer.initializeMemory(as: UInt8.self, repeating: 0)
            }
            _ = derivedBytes.withUnsafeMutableBytes { buffer in
                buffer.initializeMemory(as: UInt8.self, repeating: 0)
            }
        }

        let status: Int32 = derivedBytes.withUnsafeMutableBytes { derivedBuffer in
            passwordBytes.withUnsafeBytes { passwordBuffer in
                salt.withUnsafeBytes { saltBuffer in
                    let passwordPointer = passwordBuffer
                        .bindMemory(to: Int8.self)
                        .baseAddress
                    let saltPointer = saltBuffer
                        .bindMemory(to: UInt8.self)
                        .baseAddress
                    let derivedPointer = derivedBuffer
                        .bindMemory(to: UInt8.self)
                        .baseAddress

                    return CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPointer,
                        passwordBytes.count,
                        saltPointer,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedPointer,
                        keyByteCount
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw DiaryArchiveCryptoError.keyDerivationFailed(status)
        }
        return Data(derivedBytes)
    }

    private static func validate(_ envelope: EncryptedDiaryArchiveEnvelope) throws {
        guard envelope.header.magic == EncryptedDiaryArchiveHeader.magicValue,
              envelope.header.formatVersion == EncryptedDiaryArchiveHeader.currentFormatVersion,
              envelope.header.kdfAlgorithm == EncryptedDiaryArchiveHeader.kdfName,
              envelope.header.cipher == EncryptedDiaryArchiveHeader.cipherName,
              envelope.header.iterations >= currentIterations,
              envelope.header.iterations <= maximumSupportedIterations,
              envelope.header.salt.count == saltByteCount,
              envelope.nonce.count == nonceByteCount,
              envelope.authenticationTag.count == authenticationTagByteCount,
              envelope.ciphertext.count <= DiaryArchiveLimits.maximumEncryptedFileBytes else {
            throw DiaryArchiveCryptoError.unsupportedEncryption
        }
    }

    private static func secureRandomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw DiaryArchiveCryptoError.randomGenerationFailed
        }
        return Data(bytes)
    }

    private static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func canonicalDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    private static func archiveEncoder() -> JSONEncoder {
        let encoder = canonicalEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private static func archiveDecoder() -> JSONDecoder {
        let decoder = canonicalDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}

extension UTType {
    static let yohakuJournalBackup = UTType(
        exportedAs: "org.viuk-light.yohaku-journal.backup",
        conformingTo: .data
    )
}

/// SwiftUIの書き出し経路へ渡すのは、すでに暗号化されたDataだけに限定する。
struct EncryptedDiaryArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.yohakuJournalBackup] }

    let encryptedData: Data

    init(encryptedData: Data) {
        self.encryptedData = encryptedData
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw DiaryArchiveCryptoError.invalidFile
        }
        guard data.count <= DiaryArchiveLimits.maximumEncryptedFileBytes else {
            throw DiaryArchiveCryptoError.fileTooLarge
        }
        encryptedData = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: encryptedData)
        var attributes = wrapper.fileAttributes
        attributes[FileAttributeKey.protectionKey.rawValue] = FileProtectionType.complete
        wrapper.fileAttributes = attributes
        return wrapper
    }
}
