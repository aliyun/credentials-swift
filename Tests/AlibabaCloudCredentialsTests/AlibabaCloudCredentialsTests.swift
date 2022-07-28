import Foundation
import XCTest
@testable import AlibabaCloudCredentials

final class AlibabaCloudCredentialsTests: XCTestCase {

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
        let ak : String = try await client.getAccessKeyId()
        let secret : String = try await client.getAccessKeySecret()
        XCTAssertEqual(ak, "accessKeyId")
        XCTAssertEqual(secret, "accessKeySecret")
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
        let ak : String = try await client.getAccessKeyId()
        let secret : String = try await client.getAccessKeySecret()
        let token : String = try await client.getSecurityToken()
        XCTAssertEqual(ak, "accessKeyId")
        XCTAssertEqual(secret, "accessKeySecret")
        XCTAssertEqual(token, "securityToken")
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
        let token : String = try client.getBearerToken()
        XCTAssertEqual(token, "bearerToken")
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

        XCTAssertEqual(credential.getAccessKeyId(), cred.getAccessKeyId!())
        XCTAssertEqual(credential.getAccessKeySecret(), cred.getAccessKeySecret!())
        XCTAssertEqual(credential.getSecurityToken(), cred.getSecurityToken!())
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
            let credential: StsCredential = try await provider.getCredential() as! StsCredential
            assert(false)
        } catch {
            if (error is CredentialException) {
                assert(true)
            } else {
                assertionFailure()
            }
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

    static var allTests = [
        ("testAKCredentials", testAKCredentials),
        ("testBearerTokenCredential", testBearerTokenCredential),
        ("testStsCredential", testStsCredential),
        ("testEcsRamRoleCredentialProvider", testEcsRamRoleCredentialProvider),
        ("testEcsRamRoleCredentialProviderRefresh", testEcsRamRoleCredentialProviderRefresh),
    ]
}
