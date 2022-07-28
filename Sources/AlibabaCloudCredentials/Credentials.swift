import Foundation

enum CredentialException: Error {
    case UnsupportedCredentialType(String)
    case EmptyOrNil(String)
    case InvalidData(String)
    case RequestError([String: Any]?)
}

public enum CredentialType: String {
    case AccessKey = "access_key"
    case STS = "sts"
    case BearerToken = "bearer"
    case EcsRamRole = "ecs_ram_role"
    case RamRoleArn = "ram_role_arn"
    case RsaKeyPair = "rsa_key_pair"
    case OIDCRoleArn = "oidc_role_arn"
    case URLSTS = "credentials_uri"
}

@objc public protocol Credential {
    var type: String { get set }
    @objc optional func getAccessKeyId() -> String
    @objc optional func getAccessKeySecret() -> String
    @objc optional func getSecurityToken() -> String
    @objc optional func getBearerToken() -> String
    func getType() -> String
}

public class AccessKeyCredential: Credential {
    public var type: String
    private var accessKeyId: String
    private var accessKeySecret: String

    public init(_ accessKeyId: String, _ accessKeySecret: String) throws {
        self.accessKeyId = accessKeyId
        self.accessKeySecret = accessKeySecret
        if (self.accessKeyId).isEmpty || (self.accessKeySecret).isEmpty {
            throw CredentialException.EmptyOrNil("accessKeyId or accessKeySecret cannot be empty.")
        }
        self.type = CredentialType.AccessKey.rawValue
    }
    
    public func getAccessKeyId() -> String {
        return self.accessKeyId
    }
    
    public func getAccessKeySecret() -> String {
        return self.accessKeySecret
    }
    
    public func getType() -> String {
        return self.type
    }
}

public class BearerTokenCredential: Credential {
    public var type: String
    private var bearerToken: String

    public init(_ bearerToken: String) throws {
        self.bearerToken = bearerToken
        if (self.bearerToken).isEmpty {
            throw CredentialException.EmptyOrNil("bearerToken cannot be empty.")
        }
        self.type = CredentialType.BearerToken.rawValue
    }
    
    public func getBearerToken() -> String {
        return self.bearerToken
    }
    
    public func getType() -> String {
        return self.type
    }
}

public class StsCredential: Credential {
    public var type: String
    private var accessKeyId: String
    private var accessKeySecret: String
    private var securityToken: String

    public init(_ accessKeyId: String, _ accessKeySecret: String, _ securityToken: String) throws {
        self.accessKeyId = accessKeyId
        self.accessKeySecret = accessKeySecret
        self.securityToken = securityToken
        if (self.accessKeyId).isEmpty || (self.accessKeySecret).isEmpty || (self.securityToken).isEmpty {
            throw CredentialException.EmptyOrNil("accessKeyId or accessKeySecret cannot be empty.")
        }
        self.type = CredentialType.STS.rawValue
    }
    
    public func getAccessKeyId() -> String {
        return self.accessKeyId
    }
    
    public func getAccessKeySecret() -> String {
        return self.accessKeySecret
    }
    
    public func getSecurityToken() -> String {
        return self.securityToken
    }
    
    public func getType() -> String {
        return self.type
    }
}
