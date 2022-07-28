import Foundation

open class Client {
    private var credential: Credential?
    private var config: Config
    public var _headers: [String: String]?

    public init(_ config: Config) {
        self.config = config
        self.credential = initCredential()
    }

    public func getCredential() async throws -> Credential? {
        let credentialsType: String = self.config.type!
        switch (credentialsType) {
        case CredentialType.AccessKey.rawValue:
            return try AccessKeyCredential(self.config.accessKeyId!, self.config.accessKeySecret!)
        case CredentialType.STS.rawValue:
            return try StsCredential(self.config.accessKeyId!, self.config.accessKeySecret!, self.config.securityToken!)
        case CredentialType.BearerToken.rawValue:
            return try BearerTokenCredential(self.config.bearerToken!)
        case CredentialType.EcsRamRole.rawValue:
            return try await EcsRamRoleCredentialProvider(config: self.config).getCredential()
        case CredentialType.RamRoleArn.rawValue:
            return try await RamRoleArnCredentialProvider(config: self.config).getCredential()
        case CredentialType.RsaKeyPair.rawValue:
            return try await RsaKeyPairCredentialProvider(config: self.config).getCredential()
        case CredentialType.URLSTS.rawValue:
            return try await URICredentialProvider(config: self.config).getCredential()
        default:
            throw CredentialException.UnsupportedCredentialType(credentialsType)
        }
    }
    
    private func initCredential() -> Credential? {
        let credentialsType: String = self.config.type!
        switch (credentialsType) {
        case CredentialType.AccessKey.rawValue:
            return try! AccessKeyCredential(self.config.accessKeyId!, self.config.accessKeySecret!)
        case CredentialType.STS.rawValue:
            return try! StsCredential(self.config.accessKeyId!, self.config.accessKeySecret!, self.config.securityToken!)
        case CredentialType.BearerToken.rawValue:
            return try! BearerTokenCredential(self.config.bearerToken!)
        default:
            return nil
        }
    }
    
    public func getAccessKeyId() async throws -> String {
        self.credential = try await getCredential()!
        return self.credential?.getAccessKeyId?() ?? ""
    }
    
    public func getAccessKeySecret() async throws -> String {
        self.credential = try await getCredential()!
        return self.credential?.getAccessKeySecret?() ?? ""
    }
    
    public func getSecurityToken() async throws -> String {
        self.credential = try await getCredential()!
        return self.credential?.getSecurityToken?() ?? ""
    }
    
    public func getBearerToken() -> String {
        return self.credential?.getBearerToken?() ?? ""
    }
    
    public func getType() -> String {
        return self.config.type ?? ""
    }
}
