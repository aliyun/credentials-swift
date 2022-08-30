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

open class Credential {
    open func getAccessKeyId() -> String {
        return ""
    }
    open func getAccessKeySecret() -> String {
        return ""
    }
    open func getSecurityToken() -> String {
        return ""
    }
    open func getBearerToken() -> String {
        return ""
    }
    open func getType() -> String {
        return ""
    }
}

public class AccessKeyCredential: Credential {
    private var accessKeyId: String
    private var accessKeySecret: String

    public init(_ accessKeyId: String, _ accessKeySecret: String) throws {
        self.accessKeyId = accessKeyId
        self.accessKeySecret = accessKeySecret
        if (self.accessKeyId).isEmpty || (self.accessKeySecret).isEmpty {
            throw CredentialException.EmptyOrNil("accessKeyId or accessKeySecret cannot be empty.")
        }
    }
    
    public override func getAccessKeyId() -> String {
        return self.accessKeyId
    }
    
    public override func getAccessKeySecret() -> String {
        return self.accessKeySecret
    }
    
    public override func getType() -> String {
        return CredentialType.AccessKey.rawValue
    }
}

public class BearerTokenCredential: Credential {
    private var bearerToken: String

    public init(_ bearerToken: String) throws {
        self.bearerToken = bearerToken
        if (self.bearerToken).isEmpty {
            throw CredentialException.EmptyOrNil("bearerToken cannot be empty.")
        }
    }
    
    public override func getBearerToken() -> String {
        return self.bearerToken
    }
    
    public override func getType() -> String {
        return CredentialType.BearerToken.rawValue
    }
}

public class StsCredential: Credential {
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
    }
    
    public override func getAccessKeyId() -> String {
        return self.accessKeyId
    }
    
    public override func getAccessKeySecret() -> String {
        return self.accessKeySecret
    }
    
    public override func getSecurityToken() -> String {
        return self.securityToken
    }
    
    public override func getType() -> String {
        return CredentialType.STS.rawValue
    }
}
