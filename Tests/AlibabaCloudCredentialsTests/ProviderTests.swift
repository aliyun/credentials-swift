import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import Tea
@testable import AlibabaCloudCredentials

private struct CapturedRequest: Decodable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: String

    var pathname: String { URLComponents(string: path)?.path ?? path }
    var query: [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(string: path)?.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
    }
}

private struct ProviderFixture {
    let baseURL: URL
    let tlsHost: String

    init() throws {
        #if os(Linux)
        guard let server = ProcessInfo.processInfo.environment["CREDENTIALS_TEST_SERVER"],
              let baseURL = URL(string: server),
              let tlsHost = ProcessInfo.processInfo.environment["CREDENTIALS_TEST_TLS_HOST"] else {
            throw XCTSkip("Provider network tests require the isolated credentials HTTP fixture")
        }
        self.baseURL = baseURL
        self.tlsHost = tlsHost
        #else
        throw XCTSkip("Provider network fixture runs in the isolated Linux container")
        #endif
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }.resume()
        }
    }

    func reset(_ responses: [[String: Any]]) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("reset"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["responses": responses])
        let (_, response) = try await data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    func requests() async throws -> [CapturedRequest] {
        let (data, response) = try await data(for: URLRequest(url: baseURL.appendingPathComponent("requests")))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        return try JSONDecoder().decode([CapturedRequest].self, from: data)
    }
}

final class ProviderTests: XCTestCase {
    private let expiration = "2099-01-01T00:00:00Z"
    private let environmentKeys = [
        "ALIBABA_CLOUD_ROLE_ARN", "ALIBABA_CLOUD_OIDC_PROVIDER_ARN",
        "ALIBABA_CLOUD_OIDC_TOKEN_FILE", "ALIBABA_CLOUD_ROLE_SESSION_NAME",
        "ALIBABA_CLOUD_STS_REGION"
    ]
    private var savedEnvironment: [String: String] = [:]

    override func setUp() {
        super.setUp()
        for key in environmentKeys {
            savedEnvironment[key] = ProcessInfo.processInfo.environment[key]
            unsetenv(key)
        }
    }

    override func tearDown() {
        for key in environmentKeys {
            if let value = savedEnvironment[key] {
                setenv(key, value, 1)
            } else {
                unsetenv(key)
            }
        }
        super.tearDown()
    }

    private func response(_ body: String, status: Int = 200) -> [String: Any] {
        ["status": status, "body": body]
    }

    private var sessionJSON: String {
        """
        {"Code":"Success","AccessKeyId":"id","AccessKeySecret":"secret","SecurityToken":"token","Expiration":"\(expiration)"}
        """
    }

    private var nestedSessionJSON: String {
        """
        {"Credentials":{"AccessKeyId":"id","AccessKeySecret":"secret","SecurityToken":"token","Expiration":"\(expiration)"}}
        """
    }

    private func assertSession(_ credential: Credential?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(credential?.getAccessKeyId(), "id", file: file, line: line)
        XCTAssertEqual(credential?.getAccessKeySecret(), "secret", file: file, line: line)
        XCTAssertEqual(credential?.getSecurityToken(), "token", file: file, line: line)
        XCTAssertEqual(credential?.getType(), "sts", file: file, line: line)
    }

    private func oidcConfig(_ values: [String: Any] = [:]) -> Config {
        var config: [String: Any] = [
            "roleArn": "role", "oidcProviderArn": "provider",
            "oidcTokenFilePath": "/unused-token-file", "roleSessionName": "session"
        ]
        config.merge(values) { _, new in new }
        return Config(config)
    }

    private func bodyForm(_ request: TeaRequest) throws -> [String: String] {
        let stream = try XCTUnwrap(request.body)
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw stream.streamError ?? CocoaError(.fileReadUnknown) }
            if count == 0 { break }
            body.append(contentsOf: buffer.prefix(count))
        }
        return bodyForm(String(decoding: body, as: UTF8.self))
    }

    private func bodyForm(_ body: String) -> [String: String] {
        var components = URLComponents()
        components.percentEncodedQuery = body
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    func testBaseProviderReturnsNilAndRetainsExistingCredential() async throws {
        let provider = CredentialsProvider()
        XCTAssertTrue(provider.shouldRefresh())
        let empty = try await provider.getCredential()
        XCTAssertNil(empty)
        let cached = try AccessKeyCredential("id", "secret")
        provider.credential = cached
        let refreshed = try await provider.getCredential()
        XCTAssertTrue(refreshed === cached)
        provider.expiration = Date().addingTimeInterval(3600).timeIntervalSince1970
        XCTAssertFalse(provider.shouldRefresh())
        let valid = try await provider.getCredential()
        XCTAssertTrue(valid === cached)
        provider.expiration = Date().addingTimeInterval(60).timeIntervalSince1970
        XCTAssertTrue(provider.shouldRefresh())
    }

    func testEcsExplicitRoleRefreshAndCache() async throws {
        let fixture = try ProviderFixture()
        let provider = try EcsRamRoleCredentialProvider(config: Config(["roleName": "worker-role"]))
        try await fixture.reset([response(sessionJSON)])
        let credential = try await provider.getCredential()
        assertSession(credential)
        XCTAssertEqual(provider.expiration, expiration.convertToDate().timeIntervalSince1970)
        let cached = try await provider.getCredential()
        XCTAssertTrue(credential === cached)
        let requests = try await fixture.requests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.pathname, "/latest/meta-data/ram/security-credentials/worker-role")
        XCTAssertEqual(request.headers["host"], "100.100.100.200")
        XCTAssertEqual(request.headers["user-agent"], getDefaultUserAgent())
    }

    func testEcsDiscoversRoleOnceAndReusesItAfterExpiration() async throws {
        let fixture = try ProviderFixture()
        let provider = try EcsRamRoleCredentialProvider(config: Config(["connectTimeout": 5000, "timeout": 10000]))
        try await fixture.reset([response("discovered-role"), response(sessionJSON), response(sessionJSON)])
        let first = try await provider.getCredential()
        assertSession(first)
        provider.expiration = 0
        let second = try await provider.getCredential()
        assertSession(second)
        let requests = try await fixture.requests()
        XCTAssertEqual(requests.map { $0.pathname }, [
            "/latest/meta-data/ram/security-credentials/",
            "/latest/meta-data/ram/security-credentials/discovered-role",
            "/latest/meta-data/ram/security-credentials/discovered-role"
        ])
    }

    func testEcsRoleDiscoveryHTTPFailures() async throws {
        let fixture = try ProviderFixture()
        for status in [404, 503] {
            let provider = try EcsRamRoleCredentialProvider(config: Config())
            try await fixture.reset([response("missing", status: status)])
            do {
                _ = try await provider.getCredential()
                XCTFail("Expected metadata failure")
            } catch CredentialException.InvalidData(let message) {
                XCTAssertEqual(message, status == 404
                    ? "The role name was not found in the instance"
                    : "Failed to get RAM session credentials from ECS metadata service. HttpCode=503")
            }
            let requests = try await fixture.requests()
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testEcsCredentialHTTPFailure() async throws {
        let fixture = try ProviderFixture()
        let provider = try EcsRamRoleCredentialProvider(config: Config(["roleName": "role"]))
        try await fixture.reset([response("denied", status: 403)])
        do {
            _ = try await provider.getCredential()
            XCTFail("Expected metadata failure")
        } catch CredentialException.InvalidData(let message) {
            XCTAssertEqual(message, "Failed to get RAM session credentials from ECS metadata service. HttpCode=403")
        }
    }

    func testEcsEmptyRoleDiscoveryAndServiceError() async throws {
        let fixture = try ProviderFixture()
        let provider = try EcsRamRoleCredentialProvider(config: Config())
        try await fixture.reset([response(""), response(#"{"Code":"Denied","Message":"unavailable"}"#)])
        do {
            _ = try await provider.getCredential()
            XCTFail("Expected metadata service error")
        } catch CredentialException.RequestError(let result) {
            XCTAssertEqual(result?["Code"] as? String, "Denied")
            XCTAssertEqual(result?["Message"] as? String, "unavailable")
        }
        let requests = try await fixture.requests()
        XCTAssertEqual(requests.map { $0.pathname }, [
            "/latest/meta-data/ram/security-credentials/", "/latest/meta-data/ram/security-credentials/"
        ])
    }

    func testRamRoleArnRejectsMissingAccessKeyFields() {
        for values in [[:], ["accessKeyId": "id"], ["accessKeySecret": "secret"],
                       ["accessKeyId": "", "accessKeySecret": "secret"]] as [[String: Any]] {
            XCTAssertThrowsError(try RamRoleArnCredentialProvider(config: Config(values))) { error in
                guard case CredentialException.EmptyOrNil(let message) = error else {
                    return XCTFail("Expected EmptyOrNil, got \(error)")
                }
                XCTAssertEqual(message, "accessKeyId or accessKeySecret cannot be empty.")
            }
        }
    }

    func testRamRoleArnRefreshParsesNestedCredentials() async throws {
        let fixture = try ProviderFixture()
        let provider = try RamRoleArnCredentialProvider(config: Config([
            "accessKeyId": "source-id", "accessKeySecret": "source-secret",
            "roleArn": "role", "regionId": "cn-beijing", "roleSessionName": "custom-session",
            "roleSessionExpiration": 1800, "policy": "policy-json", "connectTimeout": 5000, "timeout": 10000
        ]))
        try await fixture.reset([response(nestedSessionJSON)])
        let credential = try await provider.getCredential()
        assertSession(credential)
        XCTAssertEqual(provider.expiration, expiration.convertToDate().timeIntervalSince1970)
        let requests = try await fixture.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.pathname, "/")
        XCTAssertEqual(request.headers["host"], "sts.aliyuncs.com")
        XCTAssertEqual(request.headers["user-agent"], getDefaultUserAgent())
        XCTAssertEqual(request.query["Action"], "AssumeRole")
        XCTAssertEqual(request.query["DurationSeconds"], "1800")
        XCTAssertEqual(request.query["RoleArn"], "role")
        XCTAssertEqual(request.query["RegionId"], "cn-beijing")
        XCTAssertEqual(request.query["RoleSessionName"], "custom-session")
        XCTAssertEqual(request.query["Policy"], "policy-json")
        assertSignature(request, id: "source-id", secret: "source-secret")
    }

    func testRamRoleArnDefaultsAndServiceError() async throws {
        let fixture = try ProviderFixture()
        let provider = try RamRoleArnCredentialProvider(config: Config(["accessKeyId": "id", "accessKeySecret": "secret"]))
        try await fixture.reset([response(#"{"Code":"InvalidAccessKeyId.NotFound"}"#, status: 400)])
        do {
            _ = try await provider.getCredential()
            XCTFail("Expected STS error")
        } catch CredentialException.RequestError(let result) {
            XCTAssertEqual(result?["Code"] as? String, "InvalidAccessKeyId.NotFound")
        }
        let requests = try await fixture.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.query["DurationSeconds"], "3600")
        XCTAssertEqual(request.query["RoleArn"], "")
        XCTAssertEqual(request.query["RegionId"], "cn-hangzhou")
        XCTAssertEqual(request.query["RoleSessionName"], "defaultSessionName")
        XCTAssertNil(request.query["Policy"])
    }

    private func assertSignature(_ request: CapturedRequest, id: String, secret: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(request.query["AccessKeyId"], id, file: file, line: line)
        XCTAssertEqual(request.query["Format"], "JSON", file: file, line: line)
        XCTAssertEqual(request.query["Version"], "2015-04-01", file: file, line: line)
        XCTAssertEqual(request.query["SignatureVersion"], "1.0", file: file, line: line)
        XCTAssertEqual(request.query["SignatureMethod"], "HMAC-SHA1", file: file, line: line)
        XCTAssertNotNil(request.query["Timestamp"], file: file, line: line)
        XCTAssertNotNil(request.query["SignatureNonce"], file: file, line: line)
        var unsigned = request.query
        unsigned.removeValue(forKey: "Signature")
        var canonical = stringToSign(method: "GET", query: unsigned)
        XCTAssertEqual(request.query["Signature"], canonical.generateSignature(secret: secret + "&"), file: file, line: line)
    }

    func testRsaRejectsMissingKeyFields() {
        for values in [[:], ["publicKeyId": "id"], ["privateKeySecret": "secret"],
                       ["publicKeyId": "id", "privateKeySecret": ""]] as [[String: Any]] {
            XCTAssertThrowsError(try RsaKeyPairCredentialProvider(config: Config(values))) { error in
                guard case CredentialException.EmptyOrNil(let message) = error else {
                    return XCTFail("Expected EmptyOrNil, got \(error)")
                }
                XCTAssertEqual(message, "You must provide a valid pair of Public Key ID(Config.publicKeyId) and Private Key Secret(Config.privateKeySecret).")
            }
        }
    }

    func testRsaRefreshParsesSessionAccessKeyAndSignsRequest() async throws {
        let fixture = try ProviderFixture()
        let provider = try RsaKeyPairCredentialProvider(config: Config([
            "publicKeyId": "public-id", "privateKeySecret": "private-secret",
            "regionId": "cn-shanghai", "roleSessionExpiration": 1800, "connectTimeout": 5000, "timeout": 10000
        ]))
        try await fixture.reset([response("""
            {"SessionAccessKey":{"SessionAccessKeyId":"session-id","SessionAccessKeySecret":"session-secret","Expiration":"\(expiration)"}}
            """)])
        let credential = try await provider.getCredential()
        XCTAssertEqual(credential?.getAccessKeyId(), "session-id")
        XCTAssertEqual(credential?.getAccessKeySecret(), "session-secret")
        XCTAssertEqual(credential?.getType(), "access_key")
        XCTAssertEqual(provider.expiration, expiration.convertToDate().timeIntervalSince1970)
        let requests = try await fixture.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.pathname, "/")
        XCTAssertEqual(request.headers["host"], "sts.aliyuncs.com")
        XCTAssertEqual(request.headers["user-agent"], getDefaultUserAgent())
        XCTAssertEqual(request.query["Action"], "GenerateSessionAccessKey")
        XCTAssertEqual(request.query["DurationSeconds"], "1800")
        XCTAssertEqual(request.query["RegionId"], "cn-shanghai")
        assertSignature(request, id: "public-id", secret: "private-secret")
    }

    func testRsaDefaultsAndServiceError() async throws {
        let fixture = try ProviderFixture()
        let provider = try RsaKeyPairCredentialProvider(config: Config(["publicKeyId": "id", "privateKeySecret": "secret"]))
        try await fixture.reset([response(#"{"Code":"InvalidPublicKeyId.NotFound"}"#, status: 400)])
        do {
            _ = try await provider.getCredential()
            XCTFail("Expected STS error")
        } catch CredentialException.RequestError(let result) {
            XCTAssertEqual(result?["Code"] as? String, "InvalidPublicKeyId.NotFound")
        }
        let requests = try await fixture.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.query["DurationSeconds"], "3600")
        XCTAssertEqual(request.query["RegionId"], "cn-hangzhou")
    }

    func testURIRejectsMissingEndpoint() {
        for config in [Config(), Config(["credentialsURI": ""])] {
            XCTAssertThrowsError(try URICredentialProvider(config: config)) { error in
                guard case CredentialException.EmptyOrNil(let message) = error else {
                    return XCTFail("Expected EmptyOrNil, got \(error)")
                }
                XCTAssertEqual(message, "Credential URI cannot be empty.")
            }
        }
    }

    func testURIRefreshAcceptsSuccessfulStatusRange() async throws {
        let fixture = try ProviderFixture()
        let provider = try URICredentialProvider(config: Config([
            "credentialsURI": "127.0.0.1", "connectTimeout": 5000, "timeout": 10000
        ]))
        try await fixture.reset([response(sessionJSON, status: 299)])
        let credential = try await provider.getCredential()
        assertSession(credential)
        XCTAssertEqual(provider.expiration, expiration.convertToDate().timeIntervalSince1970)
        let requests = try await fixture.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.headers["host"], "127.0.0.1")
    }

    func testURIHTTPFailuresIncludeStatusAndBody() async throws {
        let fixture = try ProviderFixture()
        for status in [300, 500] {
            let provider = try URICredentialProvider(config: Config(["credentialsURI": "127.0.0.1"]))
            try await fixture.reset([response("server-error", status: status)])
            do {
                _ = try await provider.getCredential()
                XCTFail("Expected endpoint HTTP failure")
            } catch CredentialException.InvalidData(let message) {
                XCTAssertEqual(message, "Failed to get credentials from server: 127.0.0.1\nHttpStatusCode=\(status)\nHttpRAWContent=server-error")
            }
        }
    }

    func testURIServiceAndInvalidJSONErrors() async throws {
        let fixture = try ProviderFixture()
        for body in [#"{"Code":"Denied"}"#, "not JSON"] {
            let provider = try URICredentialProvider(config: Config(["credentialsURI": "127.0.0.1"]))
            try await fixture.reset([response(body)])
            do {
                _ = try await provider.getCredential()
                XCTFail("Expected endpoint service error")
            } catch CredentialException.RequestError(let result) {
                XCTAssertEqual(result?["Code"] as? String, body == "not JSON" ? nil : "Denied")
            }
        }
    }

    func testRefreshTransportFailurePreservesCachedCredential() async throws {
        let fixture = try ProviderFixture()
        let provider = try URICredentialProvider(config: Config(["credentialsURI": "127.0.0.1"]))
        let cached = try StsCredential("old-id", "old-secret", "old-token")
        provider.credential = cached
        provider.expiration = 0
        try await fixture.reset([["disconnect": true]])
        do {
            _ = try await provider.getCredential()
            XCTFail("Expected transport error")
        } catch {
            XCTAssertTrue(error is RetryableError, "Unexpected error: \(error)")
            XCTAssertTrue(provider.credential === cached)
            XCTAssertEqual(provider.expiration, 0)
        }
    }

    func testOIDCRefreshBuildsRequestAndCachesResult() async throws {
        let fixture = try ProviderFixture()
        let tokenFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "jwt +/=& token\n".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }
        let provider = try OIDCRoleArnCredentialProvider(config: oidcConfig([
            "oidcTokenFilePath": tokenFile.path, "policy": "{\"Version\":\"1\"}",
            "host": fixture.tlsHost, "roleSessionExpiration": 900, "connectTimeout": 5000, "timeout": 10000
        ]))
        try await fixture.reset([response(nestedSessionJSON)])
        let credential = try await provider.getCredential()
        assertSession(credential)
        let cached = try await provider.getCredential()
        XCTAssertTrue(credential === cached)
        let requests = try await fixture.requests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.pathname, "/")
        XCTAssertEqual(request.headers["host"], fixture.tlsHost)
        XCTAssertEqual(request.headers["user-agent"], getDefaultUserAgent())
        XCTAssertEqual(request.headers["content-type"], "application/x-www-form-urlencoded")
        XCTAssertEqual(request.query["Action"], "AssumeRoleWithOIDC")
        XCTAssertEqual(request.query["Format"], "JSON")
        XCTAssertEqual(request.query["Version"], "2015-04-01")
        XCTAssertNotNil(request.query["Timestamp"])
        XCTAssertEqual(bodyForm(request.body), [
            "RoleArn": "role", "OIDCProviderArn": "provider", "OIDCToken": "jwt +/=& token\n",
            "RoleSessionName": "session", "DurationSeconds": "900", "Policy": "{\"Version\":\"1\"}"
        ])
    }

    func testOIDCEnvironmentFallbackAndConfigPrecedence() throws {
        let values = [
            "ALIBABA_CLOUD_ROLE_ARN": "env-role", "ALIBABA_CLOUD_OIDC_PROVIDER_ARN": "env-provider",
            "ALIBABA_CLOUD_OIDC_TOKEN_FILE": "/env-token", "ALIBABA_CLOUD_ROLE_SESSION_NAME": "env-session",
            "ALIBABA_CLOUD_STS_REGION": "cn-beijing"
        ]
        for (key, value) in values { setenv(key, value, 1) }
        let environmentProvider = try OIDCRoleArnCredentialProvider(config: Config([
            "roleArn": "", "oidcProviderArn": "", "oidcTokenFilePath": "", "roleSessionName": ""
        ]))
        let environmentRequest = environmentProvider.buildAssumeRoleWithOIDCRequest(token: "token")
        XCTAssertEqual(environmentRequest.headers["host"], "sts.cn-beijing.aliyuncs.com")
        XCTAssertEqual(try bodyForm(environmentRequest), [
            "RoleArn": "env-role", "OIDCProviderArn": "env-provider", "OIDCToken": "token",
            "RoleSessionName": "env-session", "DurationSeconds": "3600"
        ])
        let configured = try OIDCRoleArnCredentialProvider(config: oidcConfig(["regionId": "cn-shanghai"]))
        let configuredRequest = configured.buildAssumeRoleWithOIDCRequest(token: "token")
        let form = try bodyForm(configuredRequest)
        XCTAssertEqual(form["RoleArn"], "role")
        XCTAssertEqual(form["OIDCProviderArn"], "provider")
        XCTAssertEqual(form["RoleSessionName"], "session")
        XCTAssertNil(form["Policy"])
        XCTAssertEqual(configuredRequest.headers["host"], "sts.cn-shanghai.aliyuncs.com")
    }

    func testOIDCDefaultSessionAndEmptyRegions() throws {
        let config = oidcConfig(["roleSessionName": "", "host": "", "regionId": ""])
        let provider = try OIDCRoleArnCredentialProvider(config: config)
        let form = try bodyForm(provider.buildAssumeRoleWithOIDCRequest(token: "token"))
        XCTAssertTrue(form["RoleSessionName"]?.hasPrefix("credentials-swift-") == true)
        XCTAssertEqual(OIDCRoleArnCredentialProvider.resolveStsHost(config: config, env: ["ALIBABA_CLOUD_STS_REGION": ""]), "sts.aliyuncs.com")
        XCTAssertEqual(OIDCRoleArnCredentialProvider.resolveStsHost(config: config, env: ["ALIBABA_CLOUD_STS_REGION": "cn-shenzhen"]), "sts.cn-shenzhen.aliyuncs.com")
    }

    func testOIDCRefreshReportsHTTPError() async throws {
        let fixture = try ProviderFixture()
        let tokenFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "token".write(to: tokenFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tokenFile) }
        let provider = try OIDCRoleArnCredentialProvider(config: oidcConfig(["oidcTokenFilePath": tokenFile.path, "host": fixture.tlsHost]))
        try await fixture.reset([response("denied", status: 403)])
        do {
            _ = try await provider.getCredential()
            XCTFail("Expected OIDC STS HTTP error")
        } catch CredentialException.InvalidData(let message) {
            XCTAssertEqual(message, "error refreshing credentials from oidc_role_arn, http_code: 403, result: denied")
        }
    }

    func testOIDCRejectsEmptyOrWrongTypedNestedFields() throws {
        let provider = try OIDCRoleArnCredentialProvider(config: oidcConfig())
        let valid: [String: Any] = [
            "AccessKeyId": "id", "AccessKeySecret": "secret", "SecurityToken": "token", "Expiration": expiration
        ]
        for key in valid.keys {
            for value in ["", 42] as [Any] {
                if key == "Expiration" && value is String { continue }
                var credentials = valid
                credentials[key] = value
                XCTAssertThrowsError(try provider.parseOIDCCredentials(from: ["Credentials": credentials as AnyObject])) { error in
                    guard case CredentialException.RequestError = error else {
                        return XCTFail("Expected RequestError for \(key), got \(error)")
                    }
                }
            }
        }
        XCTAssertThrowsError(try provider.parseOIDCCredentials(from: ["Credentials": "invalid" as AnyObject]))
        XCTAssertThrowsError(try provider.processOIDCResponse(statusCode: 200, body: Data([0xFF])))
    }
}
