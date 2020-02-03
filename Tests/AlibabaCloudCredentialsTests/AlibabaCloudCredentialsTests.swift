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

    static var allTests = [
        ("testAKCredentials", testAKCredentials),
        ("testBearerTokenCredential", testBearerTokenCredential),
        ("testEcsRamRoleCredential", testEcsRamRoleCredential),
    ]
}
