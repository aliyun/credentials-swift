import Foundation
import XCTest
import AlamofirePromiseKit
import AwaitKit
import Alamofire
@testable import AlibabaCloudCredentials

final class AlibabaCloudCredentialsTests: XCTestCase {

    public func testAKCredentials() {
        let config: Configuration = Configuration()
        config.accessKeyId = "accessKeyId"
        config.accessKeySecret = "accessKeySecret"

        let provider = CredentialsProvider(config: config)
        let credential: AccessKeyCredential = provider.getCredential(credentialType: CredentialType.AccessKey) as! AccessKeyCredential

        XCTAssertEqual(credential.accessKeyId, config.accessKeyId)
        XCTAssertEqual(credential.accessKeySecret, config.accessKeySecret)
    }

    public func testBearerTokenCredential() {
        let config: Configuration = Configuration()
        config.bearerToken = "bearer token"

        let provider = CredentialsProvider(config: config)
        let credential: BearerTokenCredential = provider.getCredential(credentialType: CredentialType.BearerToken) as! BearerTokenCredential

        XCTAssertEqual(credential.bearerToken, config.bearerToken)
    }

    public func testEcsRamRoleCredential() {
        let date: Date = Date().addingTimeInterval(10000.0)

        let config: Configuration = Configuration()
        config.accessKeyId = "accessKeyId"
        config.accessKeySecret = "accessKeySecret"
        config.securityToken = "security token"
        config.expiration = date.timeIntervalSince1970

        let provider = CredentialsProvider(config: config)
        let credential: EcsRamRoleCredential = provider.getCredential(credentialType: CredentialType.EcsRamRole) as! EcsRamRoleCredential

        XCTAssertEqual(credential.accessKeyId, config.accessKeyId)
        XCTAssertEqual(credential.accessKeySecret, config.accessKeySecret)
        XCTAssertEqual(credential.securityToken, config.securityToken)
        XCTAssertEqual(credential.expiration, config.expiration)
    }

    public func testEcsRamRoleCredentialRefresh() {
        let config: Configuration = Configuration()
        config.accessKeyId = "accessKeyId"
        config.accessKeySecret = "accessKeySecret"
        config.securityToken = "security token"
        config.expiration = 0
        config.connectTimeout = 10;
        config.readTimeout = 10;

        let provider = CredentialsProvider(config: config)
        var credential: EcsRamRoleCredential = provider.getCredential(credentialType: CredentialType.EcsRamRole) as! EcsRamRoleCredential

        // request for get role name
        XCTAssertEqual(0, credential.expiration)

        config.roleName = "fakerolename"
        provider.config = config
        credential = provider.getCredential(credentialType: CredentialType.EcsRamRole) as! EcsRamRoleCredential

        XCTAssertEqual(credential.securityToken, config.securityToken)
    }

    public func testRamRoleArnCredential() {
        let date: Date = Date().addingTimeInterval(10000.0)

        let config: Configuration = Configuration()
        config.accessKeyId = "accessKeyId"
        config.accessKeySecret = "accessKeySecret"
        config.securityToken = "security token"
        config.expiration = date.timeIntervalSince1970
        config.policy = "policy"
        config.roleArn = "role arn"

        let provider = CredentialsProvider(config: config)
        let credential: RamRoleArnCredential = provider.getCredential(credentialType: CredentialType.RamRoleArn) as! RamRoleArnCredential

        XCTAssertEqual(credential.accessKeyId, config.accessKeyId)
        XCTAssertEqual(credential.accessKeySecret, config.accessKeySecret)
        XCTAssertEqual(credential.securityToken, config.securityToken)
        XCTAssertEqual(credential.expiration, config.expiration)
        XCTAssertEqual(credential.policy, config.policy)
        XCTAssertEqual(credential.roleArn, config.roleArn)
    }

    public func testRamRoleArnCredentialRefresh() {
        let config: Configuration = Configuration()
        config.accessKeyId = "accessKeyId"
        config.accessKeySecret = "accessKeySecret"
        config.securityToken = "security token"
        config.expiration = 0
        config.policy = "policy"
        config.roleArn = "role arn"

        let provider = CredentialsProvider(config: config)
        let credential: RamRoleArnCredential = provider.getCredential(credentialType: CredentialType.RamRoleArn) as! RamRoleArnCredential

        XCTAssertEqual(credential.securityToken, config.securityToken)
        let content = String(data: (CredentialsProvider.error?.data)!, encoding: .utf8) ?? "{}"
        let result: [String: AnyObject] = content.jsonDecode()
        let code: String = result["Code"] as? String ?? ""
        XCTAssertEqual(code, "InvalidAccessKeyId.NotFound")
    }

    public func testRsaKeyPairCredential() {
        let date: Date = Date().addingTimeInterval(10000.0)

        let config: Configuration = Configuration()
        config.publicKeyId = "publicKeyId"
        config.privateKeySecret = "privateKeySecret"
        config.expiration = date.timeIntervalSince1970

        let provider = CredentialsProvider(config: config)
        let credential: RsaKeyPairCredential = provider.getCredential(credentialType: CredentialType.RsaKeyPair) as! RsaKeyPairCredential

        XCTAssertEqual(credential.publicKeyId, config.publicKeyId)
        XCTAssertEqual(credential.privateKeySecret, config.privateKeySecret)
        XCTAssertEqual(credential.expiration, config.expiration)
    }

    public func testRsaKeyPairCredentialRefresh() {
        let config: Configuration = Configuration()
        config.publicKeyId = "publicKeyId"
        config.privateKeySecret = "privateKeySecret"
        config.expiration = 0

        let provider = CredentialsProvider(config: config)
        let credential: RsaKeyPairCredential = provider.getCredential(credentialType: CredentialType.RsaKeyPair) as! RsaKeyPairCredential

        XCTAssertEqual(credential.publicKeyId, config.publicKeyId)
        XCTAssertEqual(credential.privateKeySecret, config.privateKeySecret)

        let content = String(data: (CredentialsProvider.error?.data)!, encoding: .utf8) ?? "{}"
        let result: [String: AnyObject] = content.jsonDecode()
        let code: String = result["Code"] as? String ?? ""
        XCTAssertEqual(code, "InvalidAccessKeyId.NotFound")
    }

    public func testStsCredential() {
        let config: Configuration = Configuration()
        config.accessKeyId = "accessKeyId"
        config.accessKeySecret = "accessKeySecret"
        config.securityToken = "security token"

        let provider = CredentialsProvider(config: config)
        let credential: StsCredential = provider.getCredential(credentialType: CredentialType.STS) as! StsCredential

        XCTAssertEqual(credential.accessKeyId, config.accessKeyId)
        XCTAssertEqual(credential.accessKeySecret, config.accessKeySecret)
        XCTAssertEqual(credential.securityToken, config.securityToken)
    }

    func testComposeUrl() {
        let host: String = "fake.domain.com"
        var query: [String: Any] = [String: Any]()
        var pathname: String = ""
        var schema: String = "http"
        var port: String = "80"

        XCTAssertEqual("http://fake.domain.com", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))

        port = "8080"
        XCTAssertEqual("http://fake.domain.com:8080", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))

        pathname = "/index.html"
        XCTAssertEqual("http://fake.domain.com:8080/index.html", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))

        query["foo"] = ""
        XCTAssertEqual("http://fake.domain.com:8080/index.html", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))

        query["foo"] = "bar"
        XCTAssertEqual("http://fake.domain.com:8080/index.html?foo=bar", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))

        schema = "https"
        pathname = "/index.html?a=b"
        XCTAssertEqual("https://fake.domain.com:8080/index.html?a=b&foo=bar", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))

        pathname = "/index.html?a=b&"
        XCTAssertEqual("https://fake.domain.com:8080/index.html?a=b&foo=bar", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))

        query["fake"] = nil
        XCTAssertEqual("https://fake.domain.com:8080/index.html?a=b&foo=bar", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))

        query["fake"] = "val"
        XCTAssertEqual("https://fake.domain.com:8080/index.html?a=b&fake=val&foo=bar", composeUrl(host: host, params: query, pathname: pathname, schema: schema, port: port))
    }

    public func testConvertToDate() {
        let date: Date = Date()
        let dateString: String = date.toString()
        let formatter: DateFormatter = dateFormatter()
        let format: String = "yyyy-MM-dd'T'HH:mm:ss'Z'"

        XCTAssertEqual(date.toString(), dateString.convertToDate(format: format).toString())
        XCTAssertEqual(date.toString(), dateString.convertToDate(formatter: formatter).toString())
    }

    static var allTests = [
        ("testAKCredentials", testAKCredentials),
        ("testBearerTokenCredential", testBearerTokenCredential),
        ("testEcsRamRoleCredential", testEcsRamRoleCredential),
    ]
}
