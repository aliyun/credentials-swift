import Foundation
import XCTest
@testable import AlibabaCloudCredentials

final class OIDCTokenTests: XCTestCase {
    private func provider(tokenFile: URL) throws -> OIDCRoleArnCredentialProvider {
        return try OIDCRoleArnCredentialProvider(config: Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path
        ]))
    }

    func testOIDCTokenReadPreservesContentAndObservesAtomicReplacement() async throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tokenFile) }
        let provider = try provider(tokenFile: tokenFile)

        let original = " token-旧值\n"
        try original.write(to: tokenFile, atomically: true, encoding: .utf8)
        let originalRead = try await provider.readOIDCToken()
        XCTAssertEqual(originalRead, original)

        let replacement = " refreshed-凭证\n"
        try replacement.write(to: tokenFile, atomically: true, encoding: .utf8)
        let replacementRead = try await provider.readOIDCToken()
        XCTAssertEqual(replacementRead, replacement)

        try "".write(to: tokenFile, atomically: true, encoding: .utf8)
        let emptyRead = try await provider.readOIDCToken()
        XCTAssertEqual(emptyRead, "")
    }

    func testOIDCTokenReadInvalidUTF8PreservesError() async throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tokenFile) }
        try Data([0xFF, 0xFE, 0xFD]).write(to: tokenFile)
        let provider = try provider(tokenFile: tokenFile)

        do {
            _ = try await provider.readOIDCToken()
            XCTFail("Expected an invalid UTF-8 token file to fail")
        } catch CredentialException.InvalidData(let message) {
            XCTAssertEqual(message, "Failed to read OIDC token file: \(tokenFile.path)")
        }
    }
}
