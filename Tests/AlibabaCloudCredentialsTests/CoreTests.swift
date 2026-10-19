import Foundation
import XCTest
@testable import AlibabaCloudCredentials

final class CoreTests: XCTestCase {
    func testConfigRoundTripsEveryField() {
        let values: [String: Any] = [
            "type": "ram_role_arn",
            "accessKeyId": "access-key",
            "accessKeySecret": "access-secret",
            "securityToken": "security-token",
            "roleArn": "acs:ram::123:role/test",
            "roleSessionName": "session",
            "privateKeySecret": "private-key",
            "publicKeyId": "public-key",
            "roleName": "role",
            "bearerToken": "bearer-token",
            "host": "sts.example.com",
            "timeout": 2000,
            "connectTimeout": 1000,
            "proxy": "http://proxy.example.com:8080",
            "policy": "{\"Version\":\"1\"}",
            "roleSessionExpiration": 1800,
            "oidcProviderArn": "acs:ram::123:oidc-provider/test",
            "oidcTokenFilePath": "/tmp/token",
            "credentialsURI": "credentials.example.com",
            "regionId": "cn-beijing"
        ]
        let config = Config(values)
        XCTAssertEqual(config.toMap() as NSDictionary, values as NSDictionary)

        config.fromMap(nil)
        config.fromMap([:])
        var invalid: [String: Any?] = [:]
        for (key, value) in values {
            if value is String {
                invalid[key] = 0
            } else {
                invalid[key] = "invalid"
            }
        }
        config.fromMap(invalid)
        config.fromMap(["accessKeyId": nil])
        XCTAssertEqual(config.toMap() as NSDictionary, values as NSDictionary)

        config.fromMap(["accessKeyId": "replacement"])
        XCTAssertEqual(config.accessKeyId, "replacement")
        XCTAssertEqual(config.accessKeySecret, "access-secret")
    }

    func testConfigOmitsUnsetFields() {
        let config = Config()
        XCTAssertEqual(config.toMap() as NSDictionary, ["type": "default"] as NSDictionary)
        config.type = nil
        XCTAssertTrue(config.toMap().isEmpty)
    }

    func testLegacyConfigurationDefaults() {
        let config = Configuration()
        XCTAssertEqual(config.type, .AccessKey)
        XCTAssertEqual(config.host, "")
        XCTAssertEqual(config.proxy, "")
        XCTAssertEqual(config.connectTimeout, 10000)
        XCTAssertEqual(config.readTimeout, 10000)
        XCTAssertEqual(config.durationSeconds, 3600)
        XCTAssertEqual(config.expiration, 0)
        XCTAssertEqual(config.accessKeyId, "")
        XCTAssertEqual(config.accessKeySecret, "")
        XCTAssertEqual(config.bearerToken, "")
        XCTAssertEqual(config.securityToken, "")
        XCTAssertEqual(config.roleName, "")
        XCTAssertEqual(config.roleArn, "")
        XCTAssertEqual(config.policy, "")
        XCTAssertEqual(config.publicKeyId, "")
        XCTAssertEqual(config.privateKeySecret, "")
        XCTAssertEqual(config.privateKeyFile, "")
        XCTAssertEqual(config.certFile, "")
        XCTAssertEqual(config.certPassword, "")
    }

    func testBaseCredentialDefaults() {
        let credential = Credential()
        XCTAssertEqual(credential.getAccessKeyId(), "")
        XCTAssertEqual(credential.getAccessKeySecret(), "")
        XCTAssertEqual(credential.getSecurityToken(), "")
        XCTAssertEqual(credential.getBearerToken(), "")
        XCTAssertEqual(credential.getType(), "")
    }

    func testCredentialsRejectEachEmptyRequiredField() {
        for (accessKeyId, accessKeySecret) in [("", "secret"), ("id", ""), ("", "")] {
            XCTAssertThrowsError(try AccessKeyCredential(accessKeyId, accessKeySecret)) { error in
                guard case CredentialException.EmptyOrNil(let message) = error else {
                    return XCTFail("Expected EmptyOrNil, got \(error)")
                }
                XCTAssertEqual(message, "accessKeyId or accessKeySecret cannot be empty.")
            }
        }
        for (accessKeyId, accessKeySecret, token) in [("", "secret", "token"), ("id", "", "token"), ("id", "secret", "")] {
            XCTAssertThrowsError(try StsCredential(accessKeyId, accessKeySecret, token)) { error in
                guard case CredentialException.EmptyOrNil = error else {
                    return XCTFail("Expected EmptyOrNil, got \(error)")
                }
            }
        }
        XCTAssertThrowsError(try BearerTokenCredential("")) { error in
            guard case CredentialException.EmptyOrNil(let message) = error else {
                return XCTFail("Expected EmptyOrNil, got \(error)")
            }
            XCTAssertEqual(message, "bearerToken cannot be empty.")
        }
    }

    func testBearerClientReturnsEmptyAccessKeyFields() async throws {
        let client = Client(Config(["type": "bearer", "bearerToken": "token"]))
        let accessKeyId = try await client.getAccessKeyId()
        let accessKeySecret = try await client.getAccessKeySecret()
        let securityToken = try await client.getSecurityToken()
        XCTAssertEqual(accessKeyId, "")
        XCTAssertEqual(accessKeySecret, "")
        XCTAssertEqual(securityToken, "")
        XCTAssertEqual(client.getBearerToken(), "token")
    }

    func testClientReadsCurrentConfig() async throws {
        let config = Config(["type": "access_key", "accessKeyId": "old-id", "accessKeySecret": "old-secret"])
        let client = Client(config)
        XCTAssertEqual(client.getBearerToken(), "")
        config.accessKeyId = "new-id"
        config.accessKeySecret = "new-secret"
        let credential = try await client.getCredential()
        XCTAssertEqual(credential?.getAccessKeyId(), "new-id")
        XCTAssertEqual(credential?.getAccessKeySecret(), "new-secret")
    }

    func testClientRejectsUnsupportedTypes() async {
        for type in ["default", "unsupported", ""] {
            let config = Config(["type": type])
            let client = Client(config)
            XCTAssertEqual(client.getType(), type)
            XCTAssertEqual(client.getBearerToken(), "")
            do {
                _ = try await client.getCredential()
                XCTFail("Expected unsupported credential type")
            } catch CredentialException.UnsupportedCredentialType(let value) {
                XCTAssertEqual(value, type)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            config.type = nil
            XCTAssertEqual(client.getType(), "")
        }
    }

    func testClientDispatchesProviderValidation() async {
        for type in ["ram_role_arn", "rsa_key_pair", "credentials_uri"] {
            let client = Client(Config([
                "type": type,
                "roleArn": "",
                "oidcProviderArn": "",
                "oidcTokenFilePath": ""
            ]))
            do {
                _ = try await client.getCredential()
                XCTFail("Expected missing provider configuration to fail for \(type)")
            } catch CredentialException.EmptyOrNil(let message) {
                XCTAssertFalse(message.isEmpty)
            } catch {
                XCTFail("Unexpected error for \(type): \(error)")
            }
        }
    }

    func testQueryCanonicalizationAndSigning() {
        XCTAssertEqual(httpQueryString(query: [:]), "")
        XCTAssertEqual(httpQueryString(query: ["empty": ""]), "")
        XCTAssertEqual(httpQueryString(query: ["z": 42, "a": "a b+/%?&=", "empty": ""]),
                       "a=a%20b%2B%2F%25%3F%26%3D&z=42")
        XCTAssertEqual("AZaz09*-._ ".urlEncode(), "AZaz09*-._%20")
        XCTAssertEqual(stringToSign(method: "get", query: ["q": "a b"]), "GET&%2F&q%3Da%2520b")
        var message = "The quick brown fox jumps over the lazy dog"
        XCTAssertEqual(message.generateSignature(secret: "key"), "3nybhbi3iqa8ino29wqQcBydtNk=")
        XCTAssertEqual(message, "3nybhbi3iqa8ino29wqQcBydtNk=")
    }

    func testComposeUrlPreservesExistingQuery() {
        XCTAssertEqual(composeUrl(host: "example.com", params: [:], pathname: "/path", schema: "HTTPS"),
                       "https://example.com/path")
        XCTAssertEqual(composeUrl(host: "localhost", params: ["q": "hello world"], pathname: "/path", schema: "HTTP", port: "8080"),
                       "http://localhost:8080/path?q=hello%20world")
        XCTAssertEqual(composeUrl(host: "example.com", params: ["q": "value"], pathname: "/path?existing=1"),
                       "https://example.com/path?existing=1&q=value")
        XCTAssertEqual(composeUrl(host: "example.com", params: ["q": "value"], pathname: "/path?existing=1&"),
                       "https://example.com/path?existing=1&q=value")
        XCTAssertEqual(composeUrl(host: "example.com", params: ["empty": ""]), "https://example.com")
    }

    func testJSONDecodeRequiresAnObject() {
        let value = #"{"name":"test","count":2,"nested":{"enabled":true}}"#.jsonDecode()
        XCTAssertEqual(value["name"] as? String, "test")
        XCTAssertEqual(value["count"] as? Int, 2)
        XCTAssertEqual((value["nested"] as? [String: Any])?["enabled"] as? Bool, true)
        for invalid in ["", "not JSON", "[]", "null", "42"] {
            XCTAssertTrue(invalid.jsonDecode().isEmpty, invalid)
        }
    }

    func testDateFormattingAndExpiration() {
        let epoch = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(epoch.toString(), "1970-01-01T00:00:00Z")
        XCTAssertEqual("1970-01-01T00:00:00Z".convertToDate(), epoch)
        XCTAssertEqual(epoch.toTimestamp(), 0)
        let formatter = dateFormatter(format: "yyyy/MM/dd HH:mm:ss")
        XCTAssertEqual(formatter.timeZone.secondsFromGMT(), 0)
        XCTAssertEqual(epoch.toString(formatter: formatter), "1970/01/01 00:00:00")
        XCTAssertEqual("1970/01/01 00:00:00".convertToDate(formatter: formatter), epoch)
        XCTAssertTrue(hasExpired(expiration: Date().addingTimeInterval(-3600).timeIntervalSince1970))
        XCTAssertTrue(hasExpired(expiration: Date().addingTimeInterval(60).timeIntervalSince1970))
        XCTAssertFalse(hasExpired(expiration: Date().addingTimeInterval(3600).timeIntervalSince1970))
    }

    func testRequestMetadata() {
        XCTAssertEqual((-42).toString(), "-42")
        let nonce = uuid()
        XCTAssertNotNil(nonce.range(of: "^[0-9a-f]{32}$", options: .regularExpression))
        XCTAssertNotEqual(nonce, uuid())
        XCTAssertNotNil(osName().range(of: "^[A-Za-z]+/[0-9]+\\.[0-9]+\\.[0-9]+$", options: .regularExpression))
        XCTAssertEqual(getDefaultUserAgent(), "AlibabaCloud \(osName()) Swift TeaDSL/1")
    }
}
