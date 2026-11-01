import SwiftUI

struct Genre: Identifiable, Hashable {
    let name: String
    let tag: String
    let symbol: String
    let color: Color

    var id: String { tag }

    static let all: [Genre] = [
        Genre(name: "Pop", tag: "pop", symbol: "star.fill", color: .pink),
        Genre(name: "Rock", tag: "rock", symbol: "guitars.fill", color: .red),
        Genre(name: "Hip-Hop", tag: "hip hop", symbol: "music.mic", color: .purple),
        Genre(name: "Country", tag: "country", symbol: "music.note", color: .brown),
        Genre(name: "R&B", tag: "rnb", symbol: "heart.fill", color: .orange),
        Genre(name: "Jazz", tag: "jazz", symbol: "music.quarternote.3", color: .indigo),
        Genre(name: "Classical", tag: "classical", symbol: "pianokeys", color: .teal),
        Genre(name: "Electronic", tag: "electronic", symbol: "waveform", color: .blue),
        Genre(name: "Latin", tag: "latin", symbol: "sun.max.fill", color: Color(red: 0.85, green: 0.6, blue: 0.0)),
        Genre(name: "Oldies", tag: "oldies", symbol: "clock.fill", color: .gray),
        Genre(name: "News", tag: "news", symbol: "newspaper.fill", color: .cyan),
        Genre(name: "Talk", tag: "talk", symbol: "bubble.left.and.bubble.right.fill", color: .green),
        Genre(name: "Sports", tag: "sports", symbol: "sportscourt.fill", color: .mint),
        Genre(name: "Christian", tag: "christian", symbol: "sparkles", color: Color(red: 0.45, green: 0.35, blue: 0.75)),
    ]
}
