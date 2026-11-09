import Foundation

/// Stations that aren't in the Radio Browser directory, added by hand.
/// Each stream was checked to play from the US.
enum BuiltInStations {
    static let idPrefix = "ski-"

    /// Polish stations broadcasting in the Chicago area.
    static let polishChicago: [Station] = [
        make("polskie-radio-chicago", "Polskie Radio Chicago 1030 AM",
             "https://usa13.fastcast4u.com/proxy/andkog01?mp=/1",
             tags: "polish,news,talk,music", country: "The United States Of America", code: "US", bitrate: 320,
             logo: "https://polskieradio.com/favicon.ico"),
        make("polski-fm-chicago", "Polski FM 92.7 Chicago",
             "https://usa8.fastcast4u.com/proxy/live?mp=/1",
             tags: "polish,pop,hits", country: "The United States Of America", code: "US", bitrate: 128,
             logo: "https://polski.fm/favicon.ico"),
    ]

    /// Polish stations missing from the directory.
    static let polishExtra: [Station] = [
        make("radio-wawa", "Radio Wawa",
             "https://ic1.smcdn.pl/1380-1.mp3",
             tags: "polish,pop,polish hits", country: "Poland", code: "PL", bitrate: 128,
             logo: nil),
        make("radio-pik", "Radio PiK",
             "https://stream4.nadaje.com:9005/",
             tags: "polish,regional,news", country: "Poland", code: "PL", bitrate: 128,
             logo: "https://www.radiopik.pl/favicon.ico"),
    ]

    static var all: [Station] { polishChicago + polishExtra }

    static func isBuiltIn(_ station: Station) -> Bool {
        station.stationuuid.hasPrefix(idPrefix)
    }

    /// Built-in stations matching a search, respecting the country filter.
    static func matching(_ text: String, countryCode: String?) -> [Station] {
        let query = text.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return all.filter { station in
            if let countryCode, station.countrycode != countryCode { return false }
            guard !query.isEmpty else { return countryCode != nil }
            let haystack = "\(station.name) \(station.tags ?? "")".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            return haystack.contains(query)
        }
    }

    private static func make(_ id: String, _ name: String, _ url: String, tags: String,
                             country: String, code: String, bitrate: Int, logo: String?) -> Station {
        Station(stationuuid: idPrefix + id, name: name, url: url, urlResolved: url, favicon: logo,
                tags: tags, country: country, countrycode: code, codec: "MP3", bitrate: bitrate)
    }
}
