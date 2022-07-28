import Foundation
import Tea

open class CredentialsProvider : NSObject {
    let DateFormat : String = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    var credential: Credential?
    var expiration: TimeInterval?

    func shouldRefresh() -> Bool {
        Double(expiration ?? 0) - Double(Date().timeIntervalSince1970) <= 180
    }

    public func getCredential() async throws -> Credential? {
        if shouldRefresh() {
            credential = try await refreshCredential();
        }
        return credential
    }
    
    func refreshCredential() async throws -> Credential? {
        return credential
    }
}

public class EcsRamRoleCredentialProvider: CredentialsProvider {
    private let urlInEcsMetaData: String = "/latest/meta-data/ram/security-credentials/"
    private let ecsMetaDataFetchErrorMsg: String = "Failed to get RAM session credentials from ECS metadata service."
    private let metadataServiceHost: String = "100.100.100.200"

    private var roleName: String
    private var connectionTimeout : Int
    private var readTimeout : Int

    public init(config: Config) throws {
        self.roleName = config.roleName ?? ""
        self.connectionTimeout = config.connectTimeout ?? 1000
        self.readTimeout = config.timeout ?? 1000
    }

    override func refreshCredential() async throws -> Credential {
        let request = Tea.TeaRequest()
        request.method = "GET"
        request.pathname = urlInEcsMetaData
        request.headers = [
            "host": metadataServiceHost,
            "user-agent": getDefaultUserAgent()
        ]
        let runtime : [String: Any] = [
            "connectTimeout": self.connectionTimeout,
            "readTimeout": self.readTimeout
        ]
        var response: Tea.TeaResponse
        if self.roleName.isEmpty {
            response = try await Tea.TeaCore.doAction(request, runtime)
            let content = String(data: response.body!, encoding: .utf8)
            if response.statusCode == 404 {
                throw CredentialException.InvalidData("The role name was not found in the instance")
            }
            if response.statusCode != 200 {
                throw CredentialException.InvalidData(ecsMetaDataFetchErrorMsg + " HttpCode=" + String(response.statusCode))
            }
            if content != nil && content != "" {
                self.roleName = content ?? ""
            }
        }
        request.pathname = urlInEcsMetaData + self.roleName
        response = try await Tea.TeaCore.doAction(request, runtime)
        if response.statusCode != 200 {
            throw CredentialException.InvalidData(ecsMetaDataFetchErrorMsg + " HttpCode=" + String(response.statusCode))
        }
        let content = String(data: response.body!, encoding: .utf8) ?? "{}"
        let result: [String: AnyObject] = content.jsonDecode()
        let code: String = result["Code"] as? String ?? ""
        if code == "Success" {
            let ak: String = result["AccessKeyId"] as! String
            let secret: String = result["AccessKeySecret"] as! String
            let expiration: String = result["Expiration"] as! String
            super.expiration = expiration.convertToDate(format: DateFormat).toTimestamp()
            let token: String = result["SecurityToken"] as! String
            let credential : StsCredential = try StsCredential(ak, secret, token)
            return credential
        } else {
            throw CredentialException.RequestError(result)
        }
    }

}

open class RamRoleArnCredentialProvider: CredentialsProvider {
    private var roleSessionName: String
    private var regionId: String
    private var durationSeconds: Int
    private let accessKeyId: String
    private let accessKeySecret: String

    private var roleArn: String
    private var policy: String
    private var connectionTimeout : Int
    private var readTimeout : Int

    public init(config: Config) throws {
        if (config.accessKeyId ?? "").isEmpty || (config.accessKeySecret ?? "").isEmpty {
            throw CredentialException.EmptyOrNil("accessKeyId or accessKeySecret cannot be empty.")
        }
        self.accessKeyId = config.accessKeyId!
        self.accessKeySecret = config.accessKeySecret!
        self.roleArn = config.roleArn ?? ""
        self.regionId = config.regionId ?? "cn-hangzhou"
        self.policy = config.policy ?? ""
        self.roleSessionName =  config.roleSessionName ?? "defaultSessionName"
        self.durationSeconds = config.roleSessionExpiration ?? 3600
        self.connectionTimeout = config.connectTimeout ?? 1000
        self.readTimeout = config.timeout ?? 1000
    }

    override func refreshCredential() async throws -> Credential {
        let request = Tea.TeaRequest()
        request.method = "GET"
        request.pathname = "/"
        request.headers = [
            "host": "sts.aliyuncs.com",
            "user-agent": getDefaultUserAgent()
        ]
        let runtime : [String: Any] = [
            "connectTimeout": self.connectionTimeout,
            "readTimeout": self.readTimeout
        ]
        var response: Tea.TeaResponse
        var params: [String: String] = [String: String]()
        params["Action"] = "AssumeRole"
        params["Format"] = "JSON"
        params["Version"] = "2015-04-01"
        params["DurationSeconds"] = self.durationSeconds.toString();
        params["RoleArn"] = self.roleArn;
        params["AccessKeyId"] = self.accessKeyId;
        params["RegionId"] = self.regionId;
        params["RoleSessionName"] = self.roleSessionName;
        params["SignatureVersion"] = "1.0"
        params["SignatureMethod"] = "HMAC-SHA1"
        params["Timestamp"] = Date().toString(format: DateFormat)
        params["SignatureNonce"] = uuid()
        if !self.policy.isEmpty {
            params["Policy"] = self.policy
        }
        var strToSign: String = stringToSign(method: "GET", query: params)
        params["Signature"] = strToSign.generateSignature(secret: self.accessKeySecret + "&")
        request.query = params
        response = try await Tea.TeaCore.doAction(request, runtime);
        let content = String(data: response.body!, encoding: .utf8) ?? "{}"
        let result: [String: AnyObject] = content.jsonDecode()
        if result.keys.contains("Credentials") {
            let credentials: [String: String] = result["Credentials"] as! [String: String]
            let ak: String = credentials["AccessKeyId"] as! String
            let secret: String = credentials["AccessKeySecret"] as! String
            let token: String = result["SecurityToken"] as! String
            let expiration: String = credentials["Expiration"] as! String
            super.expiration = expiration.convertToDate(format: DateFormat).toTimestamp()
            let credential : StsCredential = try StsCredential(ak, secret, token)
            return credential
        } else {
            throw CredentialException.RequestError(result)
        }
    }
}

open class RsaKeyPairCredentialProvider: CredentialsProvider {
    private var regionId: String
    private var durationSeconds: Int

    private let publicKeyId: String
    private let privateKeySecret: String
    private var connectionTimeout : Int
    private var readTimeout : Int

    public init(config: Config) throws {
        if (config.publicKeyId ?? "").isEmpty || (config.privateKeySecret ?? "").isEmpty {
            throw CredentialException.EmptyOrNil(
                    "You must provide a valid pair of Public Key ID(Config.publicKeyId) and Private Key Secret(Config.privateKeySecret)."
            )
        }
        self.publicKeyId = config.publicKeyId!
        self.privateKeySecret = config.privateKeySecret!
        self.regionId = config.regionId ?? "cn-hangzhou"
        self.durationSeconds = config.roleSessionExpiration ?? 3600
        self.connectionTimeout = config.connectTimeout ?? 1000
        self.readTimeout = config.timeout ?? 1000
    }

    override func refreshCredential() async throws -> Credential {
        let request = Tea.TeaRequest()
        request.method = "GET"
        request.pathname = "/"
        request.headers = [
            "host": "sts.aliyuncs.com",
            "user-agent": getDefaultUserAgent()
        ]
        let runtime : [String: Any] = [
            "connectTimeout": self.connectionTimeout,
            "readTimeout": self.readTimeout
        ]
        var response: Tea.TeaResponse
        var params: [String: String] = [String: String]()
        params["Action"] = "GenerateSessionAccessKey"
        params["Format"] = "JSON"
        params["Version"] = "2015-04-01"
        params["DurationSeconds"] = self.durationSeconds.toString();
        params["AccessKeyId"] = self.publicKeyId;
        params["RegionId"] = self.regionId;
        params["SignatureVersion"] = "1.0"
        params["SignatureMethod"] = "HMAC-SHA1"
        params["Timestamp"] = Date().toString(format: DateFormat)
        params["SignatureNonce"] = uuid()
        var strToSign: String = stringToSign(method: "GET", query: params)
        params["Signature"] = strToSign.generateSignature(secret: self.privateKeySecret + "&")
        request.query = params
        response = try await Tea.TeaCore.doAction(request, runtime);
        let content = String(data: response.body!, encoding: .utf8) ?? "{}"
        let result: [String: AnyObject] = content.jsonDecode()
        if result.keys.contains("SessionAccessKey") {
            let credentials: [String: String] = result["SessionAccessKey"] as! [String: String]
            let ak: String = credentials["SessionAccessKeyId"] as! String
            let secret: String = credentials["SessionAccessKeySecret"] as! String
            let expiration: String = credentials["Expiration"] as! String
            super.expiration = expiration.convertToDate(format: DateFormat).toTimestamp()
            let credential : AccessKeyCredential = try AccessKeyCredential(ak, secret)
            return credential
        } else {
            throw CredentialException.RequestError(result)
        }
    }
}

open class URICredentialProvider: CredentialsProvider {
    private let credentialsURI: String
    private var connectionTimeout : Int
    private var readTimeout : Int

    public init(config: Config) throws {
        if (config.credentialsURI ?? "").isEmpty {
            throw CredentialException.EmptyOrNil("Credential URI cannot be empty.")
        }
        self.credentialsURI = config.credentialsURI!
        self.connectionTimeout = config.connectTimeout ?? 1000
        self.readTimeout = config.timeout ?? 1000
    }

    override func refreshCredential() async throws -> Credential {
        let request = Tea.TeaRequest()
        request.method = "GET"
        request.headers = [
            "host": credentialsURI
        ]
        let runtime : [String: Any] = [
            "connectTimeout": self.connectionTimeout,
            "readTimeout": self.readTimeout
        ]
        var response: Tea.TeaResponse
        response = try await Tea.TeaCore.doAction(request, runtime);
        if response.statusCode >= 300 || response.statusCode < 200 {
            throw CredentialException.InvalidData("Failed to get credentials from server: \(self.credentialsURI)" + "\nHttpStatusCode=\(String(response.statusCode))" + "\nHttpRAWContent=\(String(data: response.body!, encoding: .utf8) ?? "")")
        }
        let content = String(data: response.body!, encoding: .utf8) ?? "{}"
        let result: [String: AnyObject] = content.jsonDecode()
        let code: String = result["Code"] as? String ?? ""
        if code == "Success" {
            let ak: String = result["AccessKeyId"] as! String
            let secret: String = result["AccessKeySecret"] as! String
            let token: String = result["SecurityToken"] as! String
            let expiration: String = result["Expiration"] as! String
            super.expiration = expiration.convertToDate(format: DateFormat).toTimestamp()
            let credential : StsCredential = try StsCredential(ak, secret, token)
            return credential
        } else {
            throw CredentialException.RequestError(result)
        }
    }
}
