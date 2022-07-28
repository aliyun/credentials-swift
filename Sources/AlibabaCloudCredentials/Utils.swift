import Foundation

func dateFormatter(format: String = "yyyy-MM-dd'T'HH:mm:ss'Z'") -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = format
    return formatter
}

func hasExpired(expiration: TimeInterval) -> Bool {
    Double(expiration) - Double(Date().timeIntervalSince1970) <= 180
}

func composeUrl(host: String, params: [String: Any], pathname: String = "", schema: String = "https", port: String = "80") -> String {
    var url: String = ""
    url = url + schema.lowercased() + "://" + host
    if port != "80" {
        url = url + ":" + port
    }
    url = url + pathname
    if params.count > 0 {
        let queryString = httpQueryString(query: params)
        if url.contains("?") {
            if url.last != "&" {
                url = url + "&" + queryString
            } else {
                url = url + queryString
            }
        } else if queryString != "" {
            url = url + "?" + queryString
        }
    }
    return url
}

func httpQueryString(query: [String: Any]) -> String {
    var url: String = ""
    if query.count > 0 {
        let keys = Array(query.keys).sorted()
        var arr: [String] = [String]()
        for key in keys {
            let value: String = "\(query[key] ?? "")"
            if value.isEmpty {
                continue
            }
            arr.append(key + "=" + "\(value)".urlEncode())
        }
        arr = arr.sorted()
        if arr.count > 0 {
            url = arr.joined(separator: "&")
        }
    }
    return url
}

func stringToSign(method: String, query: [String: Any]) -> String {
    var params: [String] = [String]()
    params.append(method.uppercased())
    params.append("/".urlEncode())
    params.append(httpQueryString(query: query).urlEncode())
    return params.joined(separator: "&")
}

func uuid() -> String {
    let timestamp: TimeInterval = Date().toTimestamp()
    let timestampStr: String = String(timestamp)
    return (String.randomString(len: 10) + timestampStr + UUID().uuidString).md5()
}

func osName() -> String {
    let osNameVersion: String = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        let osName: String = {
            #if os(iOS)
            return "iOS"
            #elseif os(watchOS)
            return "watchOS"
            #elseif os(tvOS)
            return "tvOS"
            #elseif os(macOS)
            return "OSX"
            #elseif os(Linux)
            return "Linux"
            #else
            return "Unknown"
            #endif
        }()

        return "\(osName)/\(versionString)"
    }()
    return osNameVersion
}

func getDefaultUserAgent() -> String {
    var defaultUserAgent: String = "AlibabaCloud"
    defaultUserAgent += " " + osName() + " Swift" + " TeaDSL/1"
    return defaultUserAgent
}
