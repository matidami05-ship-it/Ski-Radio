import Foundation

struct Country: Identifiable, Hashable, Codable {
    let code: String
    var stationCount: Int = 0

    var id: String { code }

    var name: String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// "PL" -> 🇵🇱
    var flag: String {
        code.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127_397 + $0.value) }
            .map(String.init)
            .joined()
    }

    static var current: Country {
        Country(code: Locale.current.region?.identifier ?? "US")
    }
}
