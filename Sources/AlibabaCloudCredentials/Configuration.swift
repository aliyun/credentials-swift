//
//  File.swift
//  
//
//  Created by Axios on 2020/1/7.
//

import Foundation

open class Configuration {
    // credential type
    var type: CredentialType = CredentialType.AccessKey

    // for request
    var host: String = ""
    var proxy: String = ""
    var connectTimeout: Double = 10000.0
    var readTimeout: Double = 10000.0
    var durationSeconds: Int = 3600

    // common configuration
    var expiration: TimeInterval = 0

    // for AccessKeyCredential
    var accessKeyId: String = ""
    var accessKeySecret: String = ""

    // for BearerTokenCredential
    var bearerToken: String = ""

    // for EcsRamRoleCredential&RamRoleArnCredential
    var securityToken: String = ""
    var roleName: String = ""
    var roleArn: String = ""
    var policy: String = ""

    // forRsaKeyPairCredential
    var publicKeyId: String = ""
    var privateKeySecret: String = ""
    var privateKeyFile: String = ""
    var certFile: String = ""
    var certPassword: String = ""
}
