import Foundation

/// The song a station is playing, split from its "Artist - Title" stream text.
struct SongInfo: Equatable {
    let artist: String?
    let title: String

    init(streamTitle: String) {
        let separators = [" - ", " – ", " — ", " ~ ", " | "]
        for separator in separators {
            let parts = streamTitle.components(separatedBy: separator)
            if parts.count >= 2 {
                let artist = parts[0].trimmingCharacters(in: .whitespaces)
                let title = parts.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespaces)
                if !artist.isEmpty && !title.isEmpty {
                    self.artist = artist
                    self.title = title
                    return
                }
            }
        }
        artist = nil
        title = streamTitle
    }
}

/// Finds cover art for the current song using Apple's free iTunes Search API (no key needed).
actor AlbumArt {
    static let shared = AlbumArt()

    private var cache: [String: URL?] = [:]

    private struct SearchResponse: Decodable {
        struct Result: Decodable {
            let artworkUrl100: String?
        }
        let results: [Result]
    }

    func coverURL(for song: SongInfo) async -> URL? {
        // Without an artist the text is usually a station slogan or ad, not a song.
        guard let artist = song.artist else { return nil }

        let key = "\(artist)|\(song.title)".lowercased()
        if let cached = cache[key] { return cached }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(Self.stripExtras(song.title))"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components.url,
              let result = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(SearchResponse.self, from: result.0),
              let small = response.results.first?.artworkUrl100 else {
            cache[key] = .some(nil)
            return nil
        }

        // Ask for a large version of the same image.
        let large = URL(string: small.replacingOccurrences(of: "100x100bb", with: "600x600bb"))
        cache[key] = .some(large)
        return large
    }

    /// "Song (Radio Edit) [feat. X]" -> "Song" for better matches.
    private static func stripExtras(_ title: String) -> String {
        var result = title
        for (open, close) in [("(", ")"), ("[", "]")] {
            while let start = result.firstIndex(of: Character(open)),
                  let end = result[start...].firstIndex(of: Character(close)) {
                result.removeSubrange(start...end)
            }
        }
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? title : trimmed
    }
}
