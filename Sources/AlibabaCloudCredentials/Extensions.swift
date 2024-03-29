import Foundation
import Alamofire
import CryptoSwift

extension Int {
    public func toString() -> String {
        String(self)
    }
}

extension String {

    public mutating func generateSignature(secret: String, method: HMAC.Variant = HMAC.Variant.sha1) -> String {
        self = try! (HMAC(key: secret, variant: .sha1).authenticate(self.bytes).toBase64() ?? "");
        return self
    }

    public func urlEncode() -> String {
        let unreserved = "*-._"
        let allowedCharacterSet = NSMutableCharacterSet.alphanumeric()
        allowedCharacterSet.addCharacters(in: unreserved)
        allowedCharacterSet.addCharacters(in: " ")
        var encoded = addingPercentEncoding(withAllowedCharacters: allowedCharacterSet as CharacterSet)
        encoded = encoded?.replacingOccurrences(of: " ", with: "%20")
        return encoded ?? ""
    }

    public func convertToDate(format: String = "yyyy-MM-dd'T'HH:mm:ss'Z'") -> Date {
        dateFormatter(format: format).date(from: self)!
    }

    public func convertToDate(formatter: DateFormatter) -> Date {
        formatter.date(from: self)!
    }

    public func jsonDecode() -> [String: AnyObject] {
        let jsonData: Data = self.data(using: .utf8)!
        guard let data = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String: AnyObject] else {
            return [String: AnyObject]()
        }
        return data
    }
}

extension Date {
    public func toString(format: String = "yyyy-MM-dd'T'HH:mm:ss'Z'") -> String {
        dateFormatter(format: format).string(from: self)
    }

    public func toString(formatter: DateFormatter) -> String {
        formatter.string(from: self)
    }

    public func toTimestamp() -> TimeInterval {
        TimeInterval(self.timeIntervalSince1970)
    }
}
