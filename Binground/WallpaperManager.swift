import AppKit
import os

@MainActor @Observable
class WallpaperManager {
    var isRefreshing = false
    var lastError: String?
    var currentImage: SpotlightImage? = {
        guard let data = UserDefaults.standard.data(forKey: "currentImage") else { return nil }
        return try? JSONDecoder().decode(SpotlightImage.self, from: data)
    }()

    private static let logger = Logger(subsystem: "com.kurtwink.Binground", category: "WallpaperManager")

    private var wallpapersDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Binground/Wallpapers", isDirectory: true)
    }

    func refreshWallpaper(source: SpotlightSource, locale: Locale) async {
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        do {
            let spotlight = try await SpotlightAPIClient.fetchImage(
                source: source, locale: locale
            )
            let localURL = try await downloadImage(from: spotlight.imageURL)
            try setWallpaper(imageURL: localURL)
            cleanupOldImages(keeping: localURL)
            currentImage = spotlight
            UserDefaults.standard.set(Date(), forKey: "lastRefreshDate")
            if let encoded = try? JSONEncoder().encode(spotlight) {
                UserDefaults.standard.set(encoded, forKey: "currentImage")
            }
            Self.logger.info("Wallpaper set: \(spotlight.title ?? "untitled")")
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("Refresh failed: \(error.localizedDescription)")
        }
    }

    private func downloadImage(from url: URL) async throws -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: wallpapersDirectory.path) {
            try fm.createDirectory(at: wallpapersDirectory, withIntermediateDirectories: true)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw SpotlightError.httpError(statusCode: http.statusCode)
        }

        let filename = "wallpaper-\(Int(Date().timeIntervalSince1970)).jpg"
        let localURL = wallpapersDirectory.appendingPathComponent(filename)
        try data.write(to: localURL)
        return localURL
    }

    private func setWallpaper(imageURL: URL) throws {
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
        }
    }

    var currentWallpaperURL: URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: wallpapersDirectory, includingPropertiesForKeys: nil
        ) else { return nil }
        return contents.first
    }

    func revealInFinder() {
        guard let url = currentWallpaperURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func cleanupOldImages(keeping currentURL: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: wallpapersDirectory, includingPropertiesForKeys: nil
        ) else { return }

        for file in contents where file != currentURL {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
