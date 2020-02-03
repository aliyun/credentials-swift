import Foundation
import XCTest
import AlamofirePromiseKit
import AwaitKit
import Alamofire
@testable import AlibabaCloudCredentials

final class AlibabaCloudCredentialsTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

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

    static var allTests = [
        ("testAKCredentials", testAKCredentials),
        ("testBearerTokenCredential", testBearerTokenCredential),
        ("testEcsRamRoleCredential", testEcsRamRoleCredential),
    ]
}
