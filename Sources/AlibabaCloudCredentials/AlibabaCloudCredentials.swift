import Foundation
import AlamofirePromiseKit
import Alamofire
import AwaitKit

enum CredentialException: Error {
    case UnsupportedCredentialType(String)
    case EmptyOrNil(String)
    case RequestEcsRamError
    case InvalidData(String)
    case RequestStsError([String: AnyObject])
}

public enum CredentialType: String {
    case AccessKey = "ACCESS_KEY"
    case BearerToken = "BEARER_TOKEN"
    case EcsRamRole = "ECS_RAM_ROLE"
    case RamRoleArn = "RAM_ROLE_ARN"
    case RsaKeyPair = "RSA_KEY_PAIR"
    case STS = "STS"
}

public protocol CredentialProtocol {
    var config: Configuration { get set }
    var credentialType: CredentialType { get }
}

let DateFormat: String = "yyyy-MM-dd'T'HH:mm:ss'Z'"

open class CredentialsProvider {
    var credential: CredentialProtocol?
    var config: Configuration
    private static var lastResult: DefaultDataResponse? = nil
    public static var error: DefaultDataResponse? {
        get {
            lastResult
        }
        set(value) {
            lastResult = value
        }
    }

    init(config: Configuration) {
        self.config = config
    }

    public func getCredential(credentialType: CredentialType? = nil) -> CredentialProtocol? {
        let credentialsType: CredentialType = credentialType ?? self.config.type

        do {
            switch (credentialsType) {
            case .AccessKey:
                self.config.type = CredentialType.AccessKey
                return try AccessKeyCredential(config: self.config)
            case .BearerToken:
                self.config.type = CredentialType.BearerToken
                return BearerTokenCredential(config: self.config)
            case .EcsRamRole:
                self.config.type = CredentialType.EcsRamRole
                return EcsRamRoleCredential(config: self.config)
            case .RamRoleArn:
                self.config.type = CredentialType.EcsRamRole
                return RamRoleArnCredential(config: self.config)
            case .RsaKeyPair:
                self.config.type = CredentialType.EcsRamRole
                return try RsaKeyPairCredential(config: self.config)
            case .STS:
                self.config.type = CredentialType.STS
                return StsCredential(config: self.config)
            }
        } catch CredentialException.UnsupportedCredentialType(let type) {
            print("UnsupportedCredentialType : \(type) ")
        } catch CredentialException.EmptyOrNil(let msg) {
            print(msg)
        } catch CredentialException.RequestEcsRamError {
            print("Request EcsRam Server Error")
        } catch CredentialException.RequestStsError(let result) {
            print("request Sts server error : ", result)
        } catch CredentialException.InvalidData(let msg) {
            print(msg)
        } catch {
            print("Unexpected error: \(error).")
        }
        return nil
    }
}

open class AccessKeyCredential: CredentialProtocol {
    public var credentialType: CredentialType = CredentialType.AccessKey
    public var config: Configuration

    public var accessKeyId: String {
        get {
            self.config.accessKeyId
        }
    }
    public var accessKeySecret: String {
        get {
            self.config.accessKeySecret
        }
    }

    public init(config: Configuration) throws {
        self.config = config
        if (self.config.accessKeyId).isEmpty || (self.config.accessKeySecret).isEmpty {
            throw CredentialException.EmptyOrNil("accessKeyId or accessKeySecret cannot be empty.")
        }
    }
}

open class BearerTokenCredential: CredentialProtocol {
    public var credentialType: CredentialType = CredentialType.BearerToken
    public var config: Configuration
    public var bearerToken: String {
        get {
            self.config.bearerToken
        }
    }

    public init(config: Configuration) {
        self.config = config
    }
}

open class EcsRamRoleCredential: CredentialProtocol {
    private static var roleName: String = ""
    private static let urlInEcsMetaData: String = "/latest/meta-data/ram/security-credentials/"
    private static let ecsMetaDataFetchErrorMsg: String = "Failed to get RAM session credentials from ECS metadata service."
    private static let metadataServiceHost: String = "100.100.100.200"

    public var credentialType: CredentialType = CredentialType.EcsRamRole
    public var config: Configuration

    public var accessKeyId: String {
        get {
            refresh()
            return self.config.accessKeyId
        }
    }

    public var accessKeySecret: String {
        get {
            refresh()
            return self.config.accessKeySecret
        }
    }

    public var securityToken: String {
        refresh()
        return self.config.securityToken
    }

    public var expiration: TimeInterval {
        get {
            refresh()
            return self.config.expiration
        }
        set(value) {
            self.config.expiration = value
        }
    }

    public init(config: Configuration) {
        self.config = config
    }

    private func refresh() {
        if (hasExpired(expiration: self.config.expiration)) {
            self.refreshRam()
        }
    }

    private func refreshRam() {
        if EcsRamRoleCredential.roleName.isEmpty {
            let config: URLSessionConfiguration = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = self.config.connectTimeout
            config.timeoutIntervalForResource = self.config.readTimeout
            let url: String = "http://" + EcsRamRoleCredential.metadataServiceHost + EcsRamRoleCredential.urlInEcsMetaData
            let queue = DispatchQueue(label: "AlibabaCloud.Credentials.EcsRamRoleCredential.queue")
            let session: SessionManager = Alamofire.SessionManager(configuration: config)
            let promise = session.request(url, method: HTTPMethod.get).response(queue: queue)
            do {
                let response: DefaultDataResponse = try await(promise)
                let content = String(data: response.data!, encoding: .utf8)
                if content != nil && content != "" {
                    EcsRamRoleCredential.roleName = content ?? ""
                    self.refreshCredential()
                }
            } catch {
                print("EcsRamRoleCredential : get role name error")
            }
        } else {
            self.refreshCredential()
        }
    }

    private func refreshCredential() {
        let config: URLSessionConfiguration = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = self.config.connectTimeout
        config.timeoutIntervalForResource = self.config.readTimeout
        let url: String = "http://" + EcsRamRoleCredential.metadataServiceHost + EcsRamRoleCredential.urlInEcsMetaData
        let session: SessionManager = Alamofire.SessionManager(configuration: config)
        let queue = DispatchQueue(label: "AlibabaCloud.Credentials.EcsRamRoleCredential.queue")
        let promise = session.request(url, method: HTTPMethod.get).response(queue: queue)
        do {
            let response = try await(promise)
            let content = String(data: response.data!, encoding: .utf8) ?? "{}"
            let result: [String: AnyObject] = content.jsonDecode()
            let code: String = result["Code"] as? String ?? ""
            if code == "Success" {
                self.config.accessKeyId = result["AccessKeyId"] as! String
                self.config.accessKeySecret = result["AccessKeySecret"] as! String
                let expiration: String = result["Expiration"] as! String
                self.config.expiration = expiration.convertToDate(format: DateFormat).toTimestamp()
                let token: String = result["SecurityToken"] as! String
                self.config.securityToken = token
            } else {
                CredentialsProvider.error = response
                print("EcsRamRoleCredential refresh error!")
                print(result)
            }
        } catch {
            print("EcsRamRoleCredential : refresh error")
        }
    }

}

open class RamRoleArnCredential: CredentialProtocol {
    public static var roleSessionName: String = "defaultSessionName"
    private static var regionId: String = "cn-hangzhou"

    public var credentialType: CredentialType = CredentialType.EcsRamRole
    public var config: Configuration

    public var roleArn: String {
        get {
            self.config.roleArn
        }
    }

    public var policy: String {
        get {
            self.config.policy
        }
    }

    public var accessKeyId: String {
        get {
            refresh()
            return self.config.accessKeyId
        }
    }

    public var accessKeySecret: String {
        get {
            refresh()
            return self.config.accessKeySecret
        }
    }

    public var securityToken: String {
        get {
            refresh()
            return self.config.securityToken
        }
    }

    public var expiration: TimeInterval {
        get {
            refresh()
            return self.config.expiration
        }
        set(value) {
            self.config.expiration = value
        }
    }

    public init(config: Configuration) {
        self.config = config
    }

    private func refresh() {
        if (hasExpired(expiration: self.config.expiration)) {
            var params: [String: String] = [String: String]()
            params["Action"] = "AssumeRole"
            params["Format"] = "JSON"
            params["Version"] = "2015-04-01"
            params["DurationSeconds"] = self.config.durationSeconds.toString();
            params["RoleArn"] = self.roleArn;
            params["AccessKeyId"] = self.config.accessKeyId;
            params["RegionId"] = RamRoleArnCredential.regionId;
            params["RoleSessionName"] = RamRoleArnCredential.roleSessionName;
            params["SignatureVersion"] = "1.0"
            params["SignatureMethod"] = "HMAC-SHA1"
            params["Timestamp"] = Date().toString(format: DateFormat)
            params["SignatureNonce"] = uuid()
            if !self.policy.isEmpty {
                params["Policy"] = self.policy
            }
            let response: DefaultDataResponse = stsRequest(
                    accessKeySecret: self.config.accessKeySecret,
                    connectTimeout: self.config.connectTimeout,
                    readTimeout: self.config.readTimeout,
                    query: params)
            let content = String(data: response.data!, encoding: .utf8) ?? "{}"
            let result: [String: AnyObject] = content.jsonDecode()
            let code: String = result["Code"] as? String ?? ""
            if code == "Success" {
                let credentials: [String: String] = result["Credentials"] as! [String: String]
                self.config.accessKeyId = credentials["AccessKeyId"] ?? ""
                self.config.accessKeySecret = credentials["AccessKeySecret"] ?? ""
                self.config.expiration = credentials["Expiration"]?.convertToDate(format: DateFormat).toTimestamp() ?? 0
                self.config.securityToken = credentials["SecurityToken"] ?? ""
            } else {
                CredentialsProvider.error = response
                print("RamRoleArnCredential refresh error!")
                print(result)
            }
        }
    }
}

open class RsaKeyPairCredential: CredentialProtocol {
    private static var regionId: String = "cn-hangzhou"

    public var config: Configuration
    public var credentialType: CredentialType = CredentialType.RsaKeyPair

    public var publicKeyId: String {
        get {
            refresh()
            return self.config.publicKeyId
        }
    }

    public var privateKeySecret: String {
        get {
            refresh()
            return self.config.privateKeySecret
        }
    }

    public var expiration: TimeInterval {
        get {
            refresh()
            return self.config.expiration
        }
    }

    public init(config: Configuration) throws {
        self.config = config
        if self.config.publicKeyId.isEmpty || self.config.privateKeySecret.isEmpty {
            throw CredentialException.InvalidData(
                    "You must provide a valid pair of Public Key ID(Configuration.publicKeyId) and Private Key Secret(Configuration.privateKeySecret)."
            )
        }
    }

    public func refresh() {
        if (hasExpired(expiration: self.config.expiration)) {
            var params: [String: String] = [String: String]()
            params["Action"] = "GenerateSessionAccessKey"
            params["Format"] = "JSON"
            params["Version"] = "2015-04-01"
            params["DurationSeconds"] = self.config.durationSeconds.toString();
            params["AccessKeyId"] = self.config.publicKeyId;
            params["RegionId"] = RsaKeyPairCredential.regionId;
            params["SignatureVersion"] = "1.0"
            params["SignatureMethod"] = "HMAC-SHA1"
            params["Timestamp"] = Date().toString(format: DateFormat)
            params["SignatureNonce"] = uuid()

            let response: DefaultDataResponse = stsRequest(
                    accessKeySecret: self.config.privateKeySecret,
                    connectTimeout: self.config.connectTimeout,
                    readTimeout: self.config.readTimeout,
                    query: params)
            let content = String(data: response.data!, encoding: .utf8) ?? "{}"
            let result: [String: AnyObject] = content.jsonDecode()
            let code: String = result["Code"] as? String ?? ""
            if code == "Success" {
                let credentials: [String: String] = result["Credentials"] as! [String: String]
                self.config.publicKeyId = credentials["AccessKeyId"] ?? ""
                self.config.privateKeySecret = credentials["AccessKeySecret"] ?? ""
                self.config.expiration = credentials["Expiration"]?.convertToDate(format: DateFormat).toTimestamp() ?? 0
                self.config.securityToken = credentials["SecurityToken"] ?? ""
            } else {
                CredentialsProvider.error = response
                print("RsaKeyPairCredential refresh error!")
                print(result)
            }
        }
    }
}

open class StsCredential: CredentialProtocol {
    public var credentialType: CredentialType = CredentialType.STS
    public var config: Configuration

    public var accessKeyId: String {
        get {
            self.config.accessKeyId
        }
    }

    public var accessKeySecret: String {
        get {
            self.config.accessKeySecret
        }
    }

    public var securityToken: String {
        get {
            self.config.securityToken
        }
    }

    public init(config: Configuration) {
        self.config = config
    }
}