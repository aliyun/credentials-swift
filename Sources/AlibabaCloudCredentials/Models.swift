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
    
    public override func fromMap(_ dict: [String: Any?]?) -> Void {
        guard let dict else { return }
        if let value = dict["type"] as? String {
            self.type = value
        }
        if let value = dict["accessKeyId"] as? String {
            self.accessKeyId = value
        }
        if let value = dict["accessKeySecret"] as? String {
            self.accessKeySecret = value
        }
        if let value = dict["securityToken"] as? String {
            self.securityToken = value
        }
        if let value = dict["roleArn"] as? String {
            self.roleArn = value
        }
        if let value = dict["roleSessionName"] as? String {
            self.roleSessionName = value
        }
        if let value = dict["privateKeySecret"] as? String {
            self.privateKeySecret = value
        }
        if let value = dict["publicKeyId"] as? String {
            self.publicKeyId = value
        }
        if let value = dict["roleName"] as? String {
            self.roleName = value
        }
        if let value = dict["bearerToken"] as? String {
            self.bearerToken = value
        }
        if let value = dict["timeout"] as? Int {
            self.timeout = value
        }
        if let value = dict["connectTimeout"] as? Int {
            self.connectTimeout = value
        }
        if let value = dict["proxy"] as? String {
            self.proxy = value
        }
        if let value = dict["policy"] as? String {
            self.policy = value
        }
        if let value = dict["roleSessionExpiration"] as? Int {
            self.roleSessionExpiration = value
        }
        if let value = dict["oidcProviderArn"] as? String {
            self.oidcProviderArn = value
        }
        if let value = dict["oidcTokenFilePath"] as? String {
            self.oidcTokenFilePath = value
        }
        if let value = dict["credentialsURI"] as? String {
            self.credentialsURI = value
        }
        if let value = dict["regionId"] as? String {
            self.regionId = value
        }
    }
}
