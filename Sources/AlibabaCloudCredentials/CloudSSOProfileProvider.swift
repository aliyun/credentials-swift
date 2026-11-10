import CryptoSwift
import Foundation
import Tea

actor CloudSSOProfileProvider {
    private let profileName: String?
    private let configFile: String?
    private var credential: StsCredential?
    private var expiration: Date?
    private var refresh: Task<(StsCredential, Date), Error>?

    init(profileName: String?, configFile: String?) {
        self.profileName = profileName
        self.configFile = configFile
    }

    func getCredential() async throws -> Credential {
        if let credential = credential, let expiration = expiration, expiration.timeIntervalSinceNow > 180 {
            return credential
        }

        if let refresh = refresh {
            return try await refresh.value.0
        }
        let refresh = Task { try await self.exchangeCredentials() }
        self.refresh = refresh
        defer { self.refresh = nil }
        let (credential, expiration) = try await refresh.value
        self.credential = credential
        self.expiration = expiration
        return credential
    }

    private func exchangeCredentials() async throws -> (StsCredential, Date) {
        let environment = ProcessInfo.processInfo.environment
        if environment["ALIBABA_CLOUD_CLI_PROFILE_DISABLED"]?.lowercased() == "true" {
            throw CredentialException.InvalidData("CLI credentials file is disabled.")
        }
        let defaults = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent(".aliyun/config.json")
        let configPath = configFile ?? environment["ALIBABA_CLOUD_CONFIG_FILE"] ?? defaults.path
        let configURL = URL(fileURLWithPath: configPath).resolvingSymlinksInPath().standardizedFileURL
        let config: CLIConfig = try read(configURL)
        let selected = profileName ?? environment["ALIBABA_CLOUD_PROFILE"] ?? config.current
        guard let profile = config.profiles.first(where: { $0.name == selected }),
              profile.mode == "CloudSSO", let account = profile.cloud_sso_account_id,
              let accessConfig = profile.cloud_sso_access_config, !account.isEmpty, !accessConfig.isEmpty else {
            throw CredentialException.InvalidData("No valid CloudSSO CLI profile selected.")
        }

        let signInURL: String?
        let token: String?
        let expiresAt: Int64?
        if let name = profile.sso_session, !name.isEmpty {
            let sessionURL = try Self.sessionFile(config: configURL, defaults: defaults, name: name)
            let session: Session = try read(sessionURL)
            guard session.name == name else {
                throw CredentialException.InvalidData("Invalid CloudSSO session name in session file.")
            }
            signInURL = session.sign_in_url
            token = session.access_token
            expiresAt = session.expires_at
        } else {
            signInURL = profile.cloud_sso_sign_in_url
            token = profile.access_token
            expiresAt = profile.cloud_sso_access_token_expire
        }
        guard let token = token, !token.isEmpty, let expiresAt = expiresAt,
              Double(expiresAt) > Date().timeIntervalSince1970 else {
            throw CredentialException.InvalidData("CloudSSO access token is empty or expired, please re-login with CLI.")
        }
        guard let signInURL = signInURL, let url = URL(string: signInURL), let host = url.host,
              let scheme = url.scheme, scheme == "https" || scheme == "http" else {
            throw CredentialException.InvalidData("Invalid CloudSSO sign in URL.")
        }

        let request = Tea.TeaRequest()
        request.method = "POST"
        request.protocol_ = scheme
        request.pathname = "/cloud-credentials"
        request.port = url.port ?? (scheme == "https" ? 443 : 80)
        request.headers = ["host": host, "Accept": "application/json", "Content-Type": "application/json",
                           "Authorization": "Bearer " + token]
        let body = try JSONSerialization.data(withJSONObject: ["AccountId": account, "AccessConfigurationId": accessConfig])
        request.body = InputStream(data: body)
        let response = try await Tea.TeaCore.doAction(request, ["connectTimeout": 5000, "readTimeout": 10000])
        guard response.statusCode == 200, let responseBody = response.body,
              let exchange = try? JSONDecoder().decode(Exchange.self, from: responseBody),
              let expiration = ISO8601DateFormatter().date(from: exchange.CloudCredential.Expiration),
              expiration > Date() else {
            throw CredentialException.InvalidData("Invalid CloudSSO credential response.")
        }
        let keys = exchange.CloudCredential
        let credential = try StsCredential(keys.AccessKeyId, keys.AccessKeySecret, keys.SecurityToken)
        return (credential, expiration)
    }

    static func sessionFile(config: URL, defaults: URL, name: String) throws -> URL {
        guard name.range(of: #"\A[a-z0-9_-]{1,64}\z"#, options: .regularExpression) != nil else {
            throw CredentialException.InvalidData("Invalid CloudSSO session name.")
        }
        let config = config.resolvingSymlinksInPath().standardizedFileURL
        var directory = config.deletingLastPathComponent().appendingPathComponent("sso")
        if config.path != defaults.resolvingSymlinksInPath().standardizedFileURL.path {
            directory.appendPathComponent(Array(config.path.utf8).sha256().toHexString())
        }
        return directory.appendingPathComponent(name + ".json")
    }

    private func read<T: Decodable>(_ file: URL) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: file))
        } catch {
            throw CredentialException.InvalidData("Unable to read CloudSSO profile or session file.")
        }
    }

    private struct CLIConfig: Decodable {
        let current: String?
        let profiles: [Profile]
    }

    private struct Profile: Decodable {
        let name: String
        let mode: String
        let sso_session: String?
        let cloud_sso_account_id: String?
        let cloud_sso_access_config: String?
        let cloud_sso_sign_in_url: String?
        let access_token: String?
        let cloud_sso_access_token_expire: Int64?
    }

    private struct Session: Decodable {
        let name: String
        let sign_in_url: String
        let access_token: String?
        let expires_at: Int64?
    }

    private struct Exchange: Decodable {
        struct Keys: Decodable {
            let AccessKeyId: String
            let AccessKeySecret: String
            let SecurityToken: String
            let Expiration: String
        }
        let CloudCredential: Keys
    }
}
