import Foundation

/// Number formatting per the design's content rules: thousands separators in
/// stat rows ("13,100"), compact in stat grids ("13.1k"), "4.36 GB" storage.
public enum Format {
    public static func thousands(_ value: Int) -> String {
        var result = ""
        for (i, char) in String(value).reversed().enumerated() {
            if i > 0, i % 3 == 0, char != "-" {
                result = "," + result
            }
            result = String(char) + result
        }
        return result
    }

    public static func compact(_ value: Int) -> String {
        switch value {
        case ..<1000:
            return String(value)
        case ..<1_000_000:
            return trim(Double(value) / 1000) + "k"
        default:
            return trim(Double(value) / 1_000_000) + "M"
        }
    }

    /// One decimal, trailing ".0" dropped: 13.1, 26.
    public static func trim(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    /// Kilobytes (as the API reports diskUsage) to a human size.
    public static func storage(kilobytes: Int) -> String {
        let mb = Double(kilobytes) / 1024
        if mb < 1 {
            return "\(kilobytes) KB"
        }
        if mb < 1024 {
            return String(format: "%.1f MB", mb)
        }
        return String(format: "%.2f GB", mb / 1024)
    }

    /// "as of Aug 20" timestamps for degraded states.
    public static func asOf(_ date: Date) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let parts = utc.dateComponents([.month, .day], from: date)
        return "as of \(months[(parts.month ?? 1) - 1]) \(parts.day ?? 1)"
    }
}
