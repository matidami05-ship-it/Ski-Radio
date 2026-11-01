import CarPlay
import Combine
import SwiftUI
import UIKit

/// The CarPlay interface: four tabs (Favorites, Recent, Popular, Genres) plus the system Now Playing screen.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var cancellables = Set<AnyCancellable>()

    private let player = RadioPlayer.shared
    private let library = Library.shared
    private var popular: [Station] = []

    private lazy var favoritesTemplate = makeTab(
        title: "Favorites", symbol: "heart.fill",
        empty: "No favorites yet", emptyDetail: "Tap the heart on a station in Ski Radio on your iPhone."
    )
    private lazy var recentsTemplate = makeTab(
        title: "Recent", symbol: "clock.fill",
        empty: "Nothing played yet", emptyDetail: "Stations you play show up here."
    )
    private lazy var popularTemplate = makeTab(
        title: "Popular", symbol: "flame.fill",
        empty: "Loading…", emptyDetail: nil
    )
    private lazy var genresTemplate = makeGenresTab()

    private var monograms: [String: UIImage] = [:]

    private func monogram(for station: Station) -> UIImage {
        if let cached = monograms[station.id] { return cached }
        let image = UIImage.monogram(for: station, side: CPListItem.maximumImageSize.width)
        monograms[station.id] = image
        return image
    }

    // MARK: - Scene lifecycle

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let tabBar = CPTabBarTemplate(templates: [favoritesTemplate, recentsTemplate, popularTemplate, genresTemplate])
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

        CPNowPlayingTemplate.shared.isUpNextButtonEnabled = false
        CPNowPlayingTemplate.shared.isAlbumArtistButtonEnabled = false

        library.$favorites
            .combineLatest(library.$recents, player.$station, player.$status)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        refresh()
        loadPopular()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        cancellables.removeAll()
        self.interfaceController = nil
    }

    // MARK: - Templates

    private func makeTab(title: String, symbol: String, empty: String, emptyDetail: String?) -> CPListTemplate {
        let template = CPListTemplate(title: title, sections: [])
        template.tabTitle = title
        template.tabImage = UIImage(systemName: symbol)
        template.emptyViewTitleVariants = [empty]
        if let emptyDetail { template.emptyViewSubtitleVariants = [emptyDetail] }
        return template
    }

    private func makeGenresTab() -> CPListTemplate {
        let items = Genre.all.map { genre -> CPListItem in
            let icon = UIImage(systemName: genre.symbol)?
                .withTintColor(UIColor(genre.color), renderingMode: .alwaysOriginal)
            let item = CPListItem(text: genre.name, detailText: nil, image: icon)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.openGenre(genre)
                completion()
            }
            return item
        }
        let template = CPListTemplate(title: "Genres", sections: [CPListSection(items: items)])
        template.tabTitle = "Genres"
        template.tabImage = UIImage(systemName: "square.grid.2x2.fill")
        return template
    }

    private func openGenre(_ genre: Genre) {
        let template = CPListTemplate(title: genre.name, sections: [])
        template.emptyViewTitleVariants = ["Loading…"]
        interfaceController?.pushTemplate(template, animated: true, completion: nil)

        Task { [weak self, weak template] in
            do {
                let stations = try await RadioBrowser.shared.stations(tag: genre.tag)
                guard let self, let template else { return }
                if stations.isEmpty { template.emptyViewTitleVariants = ["No stations found"] }
                template.updateSections([CPListSection(items: self.items(for: stations))])
            } catch {
                template?.emptyViewTitleVariants = ["Couldn't load stations"]
                template?.emptyViewSubtitleVariants = ["Check your phone's connection."]
                template?.updateSections([])
            }
        }
    }

    // MARK: - Content

    private func refresh() {
        favoritesTemplate.updateSections([CPListSection(items: items(for: library.favorites))])
        recentsTemplate.updateSections([CPListSection(items: items(for: library.recents))])
        popularTemplate.updateSections([CPListSection(items: items(for: popular))])
        updateNowPlayingButtons()
    }

    private func loadPopular() {
        Task { [weak self] in
            let code = Locale.current.region?.identifier ?? "US"
            let stations = (try? await RadioBrowser.shared.stations(countryCode: code)) ?? []
            guard let self else { return }
            self.popular = stations
            if stations.isEmpty {
                self.popularTemplate.emptyViewTitleVariants = ["Couldn't load stations"]
                self.popularTemplate.emptyViewSubtitleVariants = ["Check your phone's connection."]
            }
            self.refresh()
        }
    }

    private func items(for stations: [Station]) -> [CPListItem] {
        let limited = Array(stations.prefix(CPListTemplate.maximumItemCount))
        return limited.map { station in
            let item = CPListItem(text: station.displayName, detailText: station.subtitle, image: monogram(for: station))
            item.isPlaying = player.station?.id == station.id && player.isPlaying
            item.playingIndicatorLocation = .trailing
            item.handler = { [weak self] _, completion in
                self?.play(station, from: limited)
                completion()
            }
            loadLogo(for: station, into: item)
            return item
        }
    }

    private func loadLogo(for station: Station, into item: CPListItem) {
        guard let url = station.artworkURL else { return }
        Task { [weak item] in
            guard let image = await ImageCache.shared.image(for: url) else { return }
            item?.setImage(image.squareThumbnail(side: CPListItem.maximumImageSize.width))
        }
    }

    // MARK: - Playback

    private func play(_ station: Station, from list: [Station]) {
        player.play(station, from: list)
        showNowPlaying()
    }

    private func showNowPlaying() {
        guard let interfaceController else { return }
        let nowPlaying = CPNowPlayingTemplate.shared
        if interfaceController.topTemplate === nowPlaying { return }
        if interfaceController.templates.contains(where: { $0 === nowPlaying }) {
            interfaceController.pop(to: nowPlaying, animated: true, completion: nil)
        } else {
            interfaceController.pushTemplate(nowPlaying, animated: true, completion: nil)
        }
    }

    /// Heart button on the CarPlay Now Playing screen.
    private func updateNowPlayingButtons() {
        guard let station = player.station else {
            CPNowPlayingTemplate.shared.updateNowPlayingButtons([])
            return
        }
        let symbol = library.isFavorite(station) ? "heart.fill" : "heart"
        guard let image = UIImage(systemName: symbol) else { return }
        let favoriteButton = CPNowPlayingImageButton(image: image) { [weak self] _ in
            guard let self, let current = self.player.station else { return }
            self.library.toggleFavorite(current)
        }
        CPNowPlayingTemplate.shared.updateNowPlayingButtons([favoriteButton])
    }
}
