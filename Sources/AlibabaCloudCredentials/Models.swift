import Foundation
import Tea

public class Config: Tea.TeaModel {
    public var type: String? = "default"
    public var accessKeyId: String?
    public var accessKeySecret: String?
    public var securityToken: String?
    public var roleArn: String?
    public var roleSessionName: String?
    public var privateKeySecret: String?
    public var publicKeyId: String?
    public var roleName: String?
    public var bearerToken: String?
    public var host: String?
    public var timeout: Int?
    public var connectTimeout: Int?
    public var proxy: String?
    public var policy: String?
    public var roleSessionExpiration: Int?
    public var oidcProviderArn: String?
    public var oidcTokenFilePath: String?
    public var credentialsURI: String?
    public var regionId: String?
    
    public override init() {
        super.init()
    }
    
    public init(_ dict: [String: Any]) {
        super.init()
        self.fromMap(dict)
    }
    
    public override func toMap() -> [String : Any] {
        var map = super.toMap()
        if self.type != nil {
            map["type"] = self.type
        }
        if self.accessKeyId != nil {
            map["accessKeyId"] = self.accessKeyId
        }
        if self.accessKeySecret != nil {
            map["accessKeySecret"] = self.accessKeySecret
        }
        if self.securityToken != nil {
            map["securityToken"] = self.securityToken
        }
        if self.roleArn != nil {
            map["roleArn"] = self.roleArn
        }
        if self.roleSessionName != nil {
            map["roleSessionName"] = self.roleSessionName
        }
        if self.privateKeySecret != nil {
            map["privateKeySecret"] = self.privateKeySecret
        }
        if self.publicKeyId != nil {
            map["publicKeyId"] = self.publicKeyId
        }
        if self.roleName != nil {
            map["roleName"] = self.roleName
        }
        if self.bearerToken != nil {
            map["bearerToken"] = self.bearerToken
        }
        if self.host != nil {
            map["host"] = self.host
        }
        if self.timeout != nil {
            map["timeout"] = self.timeout
        }
        if self.connectTimeout != nil {
            map["connectTimeout"] = self.connectTimeout
        }
        if self.proxy != nil {
            map["proxy"] = self.proxy
        }
        if self.policy != nil {
            map["policy"] = self.policy
        }
        if self.roleSessionExpiration != nil {
            map["roleSessionExpiration"] = self.roleSessionExpiration
        }
        if self.oidcProviderArn != nil {
            map["oidcProviderArn"] = self.oidcProviderArn
        }
        if self.oidcTokenFilePath != nil {
            map["oidcTokenFilePath"] = self.oidcTokenFilePath
        }
        if self.credentialsURI != nil {
            map["credentialsURI"] = self.credentialsURI
        }
        if self.regionId != nil {
            map["regionId"] = self.regionId
        }
        return map
    }
    
    public override func fromMap(_ dict: [String: Any]) -> Void {
        if dict.keys.contains("type") {
            self.type = dict["type"] as! String
        }
        if dict.keys.contains("accessKeyId") {
            self.accessKeyId = dict["accessKeyId"] as! String
        }
        if dict.keys.contains("accessKeySecret") {
            self.accessKeySecret = dict["accessKeySecret"] as! String
        }
        if dict.keys.contains("securityToken") {
            self.securityToken = dict["securityToken"] as! String
        }
        if dict.keys.contains("roleArn") {
            self.roleArn = dict["roleArn"] as! String
        }
        if dict.keys.contains("roleSessionName") {
            self.roleSessionName = dict["roleSessionName"] as! String
        }
        if dict.keys.contains("privateKeySecret") {
            self.privateKeySecret = dict["privateKeySecret"] as! String
        }
        if dict.keys.contains("publicKeyId") {
            self.publicKeyId = dict["publicKeyId"] as! String
        }
        if dict.keys.contains("roleName") {
            self.roleName = dict["roleName"] as! String
        }
        if dict.keys.contains("bearerToken") {
            self.bearerToken = dict["bearerToken"] as! String
        }
        if dict.keys.contains("timeout") {
            self.timeout = dict["timeout"] as! Int
        }
        if dict.keys.contains("connectTimeout") {
            self.connectTimeout = dict["connectTimeout"] as! Int
        }
        if dict.keys.contains("proxy") {
            self.proxy = dict["proxy"] as! String
        }
        if dict.keys.contains("policy") {
            self.policy = dict["policy"] as! String
        }
        if dict.keys.contains("roleSessionExpiration") {
            self.roleSessionExpiration = dict["roleSessionExpiration"] as! Int
        }
        if dict.keys.contains("oidcProviderArn") {
            self.oidcProviderArn = dict["oidcProviderArn"] as! String
        }
        if dict.keys.contains("oidcTokenFilePath") {
            self.oidcTokenFilePath = dict["oidcTokenFilePath"] as! String
        }
        if dict.keys.contains("credentialsURI") {
            self.credentialsURI = dict["credentialsURI"] as! String
        }
        if dict.keys.contains("regionId") {
            self.regionId = dict["regionId"] as! String
        }
    }
}
