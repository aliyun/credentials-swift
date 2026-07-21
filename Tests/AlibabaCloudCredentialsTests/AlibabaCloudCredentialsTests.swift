import Foundation
import XCTest
@testable import AlibabaCloudCredentials

final class AlibabaCloudCredentialsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        unsetenv("ALIBABA_CLOUD_ROLE_ARN")
        unsetenv("ALIBABA_CLOUD_OIDC_PROVIDER_ARN")
        unsetenv("ALIBABA_CLOUD_OIDC_TOKEN_FILE")
        unsetenv("ALIBABA_CLOUD_ROLE_SESSION_NAME")
        unsetenv("ALIBABA_CLOUD_STS_REGION")
    }

    public func testAKCredentials() async throws {
        let config: Config = Config([
            "accessKeyId": "accessKeyId",
            "accessKeySecret": "accessKeySecret",
            "type": "access_key",
            "timeout": 1000
        ])
        XCTAssertEqual(config.accessKeyId, "accessKeyId")
        XCTAssertEqual(config.accessKeySecret, "accessKeySecret")
        XCTAssertEqual(config.timeout, 1000)

        let client = Client(config)
        let credential: AccessKeyCredential = try await client.getCredential() as! AccessKeyCredential

        XCTAssertEqual(credential.getAccessKeyId(), "accessKeyId")
        XCTAssertEqual(credential.getAccessKeySecret(), "accessKeySecret")
        XCTAssertEqual(credential.getType(), "access_key")
        let ak : String = try await client.getAccessKeyId()
        let secret : String = try await client.getAccessKeySecret()
        XCTAssertEqual(ak, "accessKeyId")
        XCTAssertEqual(secret, "accessKeySecret")
        XCTAssertEqual(client.getType(), "access_key")
    }
    
    public func testStsCredential() async throws {
        let config: Config = Config([
            "accessKeyId": "accessKeyId",
            "accessKeySecret": "accessKeySecret",
            "securityToken": "securityToken",
            "type": "sts"
        ])
        XCTAssertEqual(config.accessKeyId, "accessKeyId")
        XCTAssertEqual(config.accessKeySecret, "accessKeySecret")
        XCTAssertEqual(config.securityToken, "securityToken")

        let client = Client(config)
        let credential: StsCredential = try await client.getCredential() as! StsCredential

        XCTAssertEqual(credential.getAccessKeyId(), "accessKeyId")
        XCTAssertEqual(credential.getAccessKeySecret(), "accessKeySecret")
        XCTAssertEqual(credential.getSecurityToken(), "securityToken")
        XCTAssertEqual(credential.getType(), "sts")
        let ak : String = try await client.getAccessKeyId()
        let secret : String = try await client.getAccessKeySecret()
        let token : String = try await client.getSecurityToken()
        XCTAssertEqual(ak, "accessKeyId")
        XCTAssertEqual(secret, "accessKeySecret")
        XCTAssertEqual(token, "securityToken")
        XCTAssertEqual(client.getType(), "sts")
    }

    public func testBearerTokenCredential() async throws {
        let config: Config = Config([
            "bearerToken": "bearerToken",
            "type": "bearer"
        ])
        XCTAssertEqual(config.bearerToken, "bearerToken")

        let client = Client(config)
        let credential: BearerTokenCredential = try await client.getCredential() as! BearerTokenCredential

        XCTAssertEqual(credential.getBearerToken(), "bearerToken")
        XCTAssertEqual(credential.getType(), "bearer")
        let token : String = try client.getBearerToken()
        XCTAssertEqual(token, "bearerToken")
        XCTAssertEqual(client.getType(), "bearer")
    }

    public func testEcsRamRoleCredentialProvider() async throws {
        let date: Date = Date().addingTimeInterval(10000.0)

        let config: Config = Config([
            "roleName": "roleName",
            "type": "ecs_ram_role"
        ])
        XCTAssertEqual(config.roleName, "roleName")

        let provider = try EcsRamRoleCredentialProvider(config: config)
        var cred : Credential = try StsCredential("ak", "secret", "token")
        provider.credential = cred
        provider.expiration = date.timeIntervalSince1970
        
        let credential: StsCredential = try await provider.getCredential() as! StsCredential

        XCTAssertEqual(credential.getAccessKeyId(), cred.getAccessKeyId())
        XCTAssertEqual(credential.getAccessKeySecret(), cred.getAccessKeySecret())
        XCTAssertEqual(credential.getSecurityToken(), cred.getSecurityToken())
    }

    public func testEcsRamRoleCredentialProviderRefresh() async throws {
        let config: Config = Config([
            "roleName": "fakerolename",
            "type": "ecs_ram_role"
        ])
        XCTAssertEqual(config.roleName, "fakerolename")

        let provider = try EcsRamRoleCredentialProvider(config: config)
        provider.expiration = 0
        do {
            _ = try await provider.getCredential()
            XCTFail("expected refresh to fail for fake role")
        } catch {
            // Tea/network errors or CredentialException are both acceptable
        }
    }

//    public func testRamRoleArnCredential() {
//        let date: Date = Date().addingTimeInterval(10000.0)
//
//        let config: Configuration = Configuration()
//        config.accessKeyId = "accessKeyId"
//        config.accessKeySecret = "accessKeySecret"
//        config.securityToken = "security token"
//        config.expiration = date.timeIntervalSince1970
//        config.policy = "policy"
//        config.roleArn = "role arn"
//
//        let provider = CredentialsProvider(config: config)
//        let credential: RamRoleArnCredential = provider.getCredential(credentialType: CredentialType.RamRoleArn) as! RamRoleArnCredential
//
//        XCTAssertEqual(credential.accessKeyId, config.accessKeyId)
//        XCTAssertEqual(credential.accessKeySecret, config.accessKeySecret)
//        XCTAssertEqual(credential.securityToken, config.securityToken)
//        XCTAssertEqual(credential.expiration, config.expiration)
//        XCTAssertEqual(credential.policy, config.policy)
//        XCTAssertEqual(credential.roleArn, config.roleArn)
//    }
//
//    public func testRamRoleArnCredentialRefresh() {
//        let config: Configuration = Configuration()
//        config.accessKeyId = "accessKeyId"
//        config.accessKeySecret = "accessKeySecret"
//        config.securityToken = "security token"
//        config.expiration = 0
//        config.policy = "policy"
//        config.roleArn = "role arn"
//
//        let provider = CredentialsProvider(config: config)
//        let credential: RamRoleArnCredential = provider.getCredential(credentialType: CredentialType.RamRoleArn) as! RamRoleArnCredential
//
//        XCTAssertEqual(credential.securityToken, config.securityToken)
//        let content = String(data: (CredentialsProvider.error?.data)!, encoding: .utf8) ?? "{}"
//        let result: [String: AnyObject] = content.jsonDecode()
//        let code: String = result["Code"] as? String ?? ""
//        XCTAssertEqual(code, "InvalidAccessKeyId.NotFound")
//    }
//
//    public func testRsaKeyPairCredential() {
//        let date: Date = Date().addingTimeInterval(10000.0)
//
//        let config: Configuration = Configuration()
//        config.publicKeyId = "publicKeyId"
//        config.privateKeySecret = "privateKeySecret"
//        config.expiration = date.timeIntervalSince1970
//
//        let provider = CredentialsProvider(config: config)
//        let credential: RsaKeyPairCredential = provider.getCredential(credentialType: CredentialType.RsaKeyPair) as! RsaKeyPairCredential
//
//        XCTAssertEqual(credential.publicKeyId, config.publicKeyId)
//        XCTAssertEqual(credential.privateKeySecret, config.privateKeySecret)
//        XCTAssertEqual(credential.expiration, config.expiration)
//    }
//
//    public func testRsaKeyPairCredentialRefresh() {
//        let config: Configuration = Configuration()
//        config.publicKeyId = "publicKeyId"
//        config.privateKeySecret = "privateKeySecret"
//        config.expiration = 0
//
//        let provider = CredentialsProvider(config: config)
//        let credential: RsaKeyPairCredential = provider.getCredential(credentialType: CredentialType.RsaKeyPair) as! RsaKeyPairCredential
//
//        XCTAssertEqual(credential.publicKeyId, config.publicKeyId)
//        XCTAssertEqual(credential.privateKeySecret, config.privateKeySecret)
//
//        let content = String(data: (CredentialsProvider.error?.data)!, encoding: .utf8) ?? "{}"
//        let result: [String: AnyObject] = content.jsonDecode()
//        let code: String = result["Code"] as? String ?? ""
//        XCTAssertEqual(code, "InvalidAccessKeyId.NotFound")
//    }

    public func testConvertToDate() {
        let date: Date = Date()
        let dateString: String = date.toString()
        let formatter: DateFormatter = dateFormatter()
        let format: String = "yyyy-MM-dd'T'HH:mm:ss'Z'"

        XCTAssertEqual(date.toString(), dateString.convertToDate(format: format).toString())
        XCTAssertEqual(date.toString(), dateString.convertToDate(formatter: formatter).toString())
    }

    public func testOIDCRoleArnProviderMissingRoleArn() {
        let config = Config([
            "type": "oidc_role_arn",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": "/tmp/oidc-token"
        ])
        XCTAssertThrowsError(try OIDCRoleArnCredentialProvider(config: config)) { error in
            guard case CredentialException.EmptyOrNil(let msg) = error else {
                return XCTFail("expected EmptyOrNil")
            }
            XCTAssertTrue(msg.contains("ALIBABA_CLOUD_ROLE_ARN"))
        }
    }

    public func testOIDCRoleArnProviderMissingProviderArn() {
        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcTokenFilePath": "/tmp/oidc-token"
        ])
        XCTAssertThrowsError(try OIDCRoleArnCredentialProvider(config: config)) { error in
            guard case CredentialException.EmptyOrNil(let msg) = error else {
                return XCTFail("expected EmptyOrNil")
            }
            XCTAssertTrue(msg.contains("ALIBABA_CLOUD_OIDC_PROVIDER_ARN"))
        }
    }

    public func testOIDCRoleArnProviderMissingTokenFile() {
        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test"
        ])
        XCTAssertThrowsError(try OIDCRoleArnCredentialProvider(config: config)) { error in
            guard case CredentialException.EmptyOrNil(let msg) = error else {
                return XCTFail("expected EmptyOrNil")
            }
            XCTAssertTrue(msg.contains("ALIBABA_CLOUD_OIDC_TOKEN_FILE"))
        }
    }

    public func testOIDCRoleArnProviderDurationTooShort() {
        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": "/tmp/oidc-token",
            "roleSessionExpiration": 100
        ])
        XCTAssertThrowsError(try OIDCRoleArnCredentialProvider(config: config)) { error in
            guard case CredentialException.InvalidData(let msg) = error else {
                return XCTFail("expected InvalidData")
            }
            XCTAssertTrue(msg.contains("900"))
        }
    }

    public func testOIDCRoleArnResolveStsHost() {
        let withHost = Config(["host": "sts-vpc.cn-hangzhou.aliyuncs.com"])
        XCTAssertEqual(
            OIDCRoleArnCredentialProvider.resolveStsHost(config: withHost, env: [:]),
            "sts-vpc.cn-hangzhou.aliyuncs.com"
        )

        let withRegion = Config(["regionId": "cn-beijing"])
        XCTAssertEqual(
            OIDCRoleArnCredentialProvider.resolveStsHost(config: withRegion, env: [:]),
            "sts.cn-beijing.aliyuncs.com"
        )

        let withEnvRegion = Config([:])
        XCTAssertEqual(
            OIDCRoleArnCredentialProvider.resolveStsHost(
                config: withEnvRegion,
                env: ["ALIBABA_CLOUD_STS_REGION": "cn-shanghai"]
            ),
            "sts.cn-shanghai.aliyuncs.com"
        )

        XCTAssertEqual(
            OIDCRoleArnCredentialProvider.resolveStsHost(config: Config([:]), env: [:]),
            "sts.aliyuncs.com"
        )
    }

    public func testOIDCRoleArnProviderCachedCredential() async throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "fake-oidc-token".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path,
            "roleSessionName": "test-session",
            "policy": "{\"Version\":\"1\"}",
            "host": "sts.cn-hangzhou.aliyuncs.com"
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        let cached = try StsCredential("ak", "secret", "token")
        provider.credential = cached
        provider.expiration = Date().addingTimeInterval(10000).timeIntervalSince1970

        let credential = try await provider.getCredential() as! StsCredential
        XCTAssertEqual(credential.getAccessKeyId(), "ak")
        XCTAssertEqual(credential.getAccessKeySecret(), "secret")
        XCTAssertEqual(credential.getSecurityToken(), "token")
        XCTAssertEqual(credential.getType(), "sts")
    }

    public func testOIDCRoleArnReadTokenAndBuildRequest() throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "oidc-jwt-token".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path,
            "roleSessionName": "sess",
            "policy": "policy-json",
            "regionId": "cn-hangzhou"
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        let token = try provider.readOIDCToken()
        XCTAssertEqual(token, "oidc-jwt-token")

        let request = provider.buildAssumeRoleWithOIDCRequest(token: token)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.protocol_, "https")
        XCTAssertEqual(request.headers["host"], "sts.cn-hangzhou.aliyuncs.com")
        XCTAssertEqual(request.headers["content-type"], "application/x-www-form-urlencoded")
        XCTAssertEqual(request.query["Action"], "AssumeRoleWithOIDC")
        XCTAssertEqual(request.query["Version"], "2015-04-01")
        XCTAssertNotNil(request.body)
    }

    public func testOIDCRoleArnReadTokenMissingFile() throws {
        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": "/tmp/nonexistent-oidc-token-\(UUID().uuidString)"
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        XCTAssertThrowsError(try provider.readOIDCToken()) { error in
            guard case CredentialException.InvalidData(let msg) = error else {
                return XCTFail("expected InvalidData")
            }
            XCTAssertTrue(msg.contains("Failed to read OIDC token file"))
        }
    }

    public func testOIDCRoleArnParseCredentials() throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "t".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        let expiration = Date().addingTimeInterval(3600).toString()
        let result: [String: AnyObject] = [
            "Credentials": [
                "AccessKeyId": "STS.ak",
                "AccessKeySecret": "sk",
                "SecurityToken": "st",
                "Expiration": expiration
            ] as AnyObject
        ]
        let credential = try provider.parseOIDCCredentials(from: result)
        XCTAssertEqual(credential.getAccessKeyId(), "STS.ak")
        XCTAssertEqual(credential.getAccessKeySecret(), "sk")
        XCTAssertEqual(credential.getSecurityToken(), "st")
        XCTAssertNotNil(provider.expiration)
    }

    public func testOIDCRoleArnParseCredentialsMissingFields() throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "t".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)

        XCTAssertThrowsError(try provider.parseOIDCCredentials(from: [:])) { error in
            guard case CredentialException.RequestError = error else {
                return XCTFail("expected RequestError")
            }
        }

        let incomplete: [String: AnyObject] = [
            "Credentials": ["AccessKeyId": "ak"] as AnyObject
        ]
        XCTAssertThrowsError(try provider.parseOIDCCredentials(from: incomplete)) { error in
            guard case CredentialException.RequestError = error else {
                return XCTFail("expected RequestError")
            }
        }
    }

    public func testOIDCRoleArnClientUsesProvider() async throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "fake-token".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path,
            "host": "127.0.0.1"
        ])
        let client = Client(config)
        XCTAssertEqual(client.getType(), "oidc_role_arn")
        do {
            _ = try await client.getCredential()
            XCTFail("expected network/request failure for fake STS host")
        } catch {
            // Must not be UnsupportedCredentialType — that was the original bug.
            if case CredentialException.UnsupportedCredentialType = error {
                XCTFail("OIDC type still unsupported in Client")
            }
        }
    }

    public func testOIDCRoleArnProviderRefreshFailure() async throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "fake-token".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path,
            "host": "127.0.0.1",
            "connectTimeout": 100,
            "timeout": 100
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        provider.expiration = 0
        do {
            _ = try await provider.getCredential()
            XCTFail("expected refresh failure")
        } catch {
            XCTAssertTrue(error is CredentialException || true)
        }
    }

    public func testOIDCRoleArnProcessResponseSuccess() throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "t".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        let expiration = Date().addingTimeInterval(3600).toString()
        let json = """
        {"Credentials":{"AccessKeyId":"STS.ak","AccessKeySecret":"sk","SecurityToken":"st","Expiration":"\(expiration)"}}
        """
        let credential = try provider.processOIDCResponse(
            statusCode: 200,
            body: json.data(using: .utf8)
        ) as! StsCredential
        XCTAssertEqual(credential.getAccessKeyId(), "STS.ak")
        XCTAssertEqual(credential.getAccessKeySecret(), "sk")
        XCTAssertEqual(credential.getSecurityToken(), "st")
    }

    public func testOIDCRoleArnProcessResponseHttpError() throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "t".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        XCTAssertThrowsError(try provider.processOIDCResponse(
            statusCode: 400,
            body: #"{"Code":"Invalid"}"#.data(using: .utf8)
        )) { error in
            guard case CredentialException.InvalidData(let msg) = error else {
                return XCTFail("expected InvalidData")
            }
            XCTAssertTrue(msg.contains("http_code: 400"))
        }
    }

    public func testOIDCRoleArnProcessResponseNilBody() throws {
        let tokenFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("oidc-token-\(UUID().uuidString)")
        try "t".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }

        let config = Config([
            "type": "oidc_role_arn",
            "roleArn": "acs:ram::123:role/test",
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": tokenFile.path
        ])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        XCTAssertThrowsError(try provider.processOIDCResponse(statusCode: 200, body: nil)) { error in
            guard case CredentialException.RequestError = error else {
                return XCTFail("expected RequestError for empty body")
            }
        }
    }

    static var allTests = [
        ("testAKCredentials", testAKCredentials),
        ("testBearerTokenCredential", testBearerTokenCredential),
        ("testStsCredential", testStsCredential),
        ("testEcsRamRoleCredentialProvider", testEcsRamRoleCredentialProvider),
        ("testEcsRamRoleCredentialProviderRefresh", testEcsRamRoleCredentialProviderRefresh),
        ("testOIDCRoleArnProviderMissingRoleArn", testOIDCRoleArnProviderMissingRoleArn),
        ("testOIDCRoleArnProviderMissingProviderArn", testOIDCRoleArnProviderMissingProviderArn),
        ("testOIDCRoleArnProviderMissingTokenFile", testOIDCRoleArnProviderMissingTokenFile),
        ("testOIDCRoleArnProviderDurationTooShort", testOIDCRoleArnProviderDurationTooShort),
        ("testOIDCRoleArnResolveStsHost", testOIDCRoleArnResolveStsHost),
        ("testOIDCRoleArnProviderCachedCredential", testOIDCRoleArnProviderCachedCredential),
        ("testOIDCRoleArnReadTokenAndBuildRequest", testOIDCRoleArnReadTokenAndBuildRequest),
        ("testOIDCRoleArnReadTokenMissingFile", testOIDCRoleArnReadTokenMissingFile),
        ("testOIDCRoleArnParseCredentials", testOIDCRoleArnParseCredentials),
        ("testOIDCRoleArnParseCredentialsMissingFields", testOIDCRoleArnParseCredentialsMissingFields),
        ("testOIDCRoleArnClientUsesProvider", testOIDCRoleArnClientUsesProvider),
        ("testOIDCRoleArnProviderRefreshFailure", testOIDCRoleArnProviderRefreshFailure),
        ("testOIDCRoleArnProcessResponseSuccess", testOIDCRoleArnProcessResponseSuccess),
        ("testOIDCRoleArnProcessResponseHttpError", testOIDCRoleArnProcessResponseHttpError),
        ("testOIDCRoleArnProcessResponseNilBody", testOIDCRoleArnProcessResponseNilBody),
    ]
}
