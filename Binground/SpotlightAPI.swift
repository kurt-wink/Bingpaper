import AppKit
import os

enum SpotlightSource: String, CaseIterable, Codable {
    case desktop
    case lockScreen
}

struct SpotlightImage {
    let imageURL: URL
    let title: String?
    let copyright: String?
}

enum SpotlightError: LocalizedError {
    case noItems
    case invalidInnerJSON
    case missingImageURL
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noItems: "No images returned by the API"
        case .invalidInnerJSON: "Failed to parse creative payload"
        case .missingImageURL: "Creative payload missing image URL"
        case .httpError(let code): "HTTP error \(code)"
        }
    }
}

// MARK: - Response Models

struct BatchResponse: Codable {
    let batchrsp: BatchRsp
}

struct BatchRsp: Codable {
    let items: [BatchItem]
}

struct BatchItem: Codable {
    let item: String
}

struct DesktopCreative: Codable {
    let ad: DesktopAd
}

struct DesktopAd: Codable {
    let landscapeImage: DesktopImage
    let title: String?
    let description: String?
    let copyright: String?
    let iconHoverText: String?
}

struct DesktopImage: Codable {
    let asset: String
}

struct LockScreenCreative: Codable {
    let ad: LockScreenAd
}

struct LockScreenAd: Codable {
    let image_fullscreen_001_landscape: LockScreenImageValue?
    let title_text: LockScreenTextValue?
    let copyright_text: LockScreenTextValue?
}

struct LockScreenImageValue: Codable {
    let u: String
}

struct LockScreenTextValue: Codable {
    let tx: String
}

// MARK: - API Client

enum SpotlightAPIClient {
    private static let logger = Logger(subsystem: "com.kurtwink.Binground", category: "SpotlightAPI")

    static func fetchImage(source: SpotlightSource, countryCode: String, locale: String) async throws -> SpotlightImage {
        let url = buildURL(source: source, countryCode: countryCode, locale: locale)
        logger.info("Fetching from \(source.rawValue): \(url)")

        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw SpotlightError.httpError(statusCode: http.statusCode)
        }

        let batch = try JSONDecoder().decode(BatchResponse.self, from: data)
        guard let first = batch.batchrsp.items.first else {
            throw SpotlightError.noItems
        }

        let innerData = Data(first.item.utf8)

        switch source {
        case .desktop:
            let creative = try JSONDecoder().decode(DesktopCreative.self, from: innerData)
            guard let imageURL = URL(string: creative.ad.landscapeImage.asset) else {
                throw SpotlightError.missingImageURL
            }
            let location = creative.ad.iconHoverText?
                .components(separatedBy: "\r\n").first
            return SpotlightImage(
                imageURL: imageURL,
                title: location,
                copyright: creative.ad.copyright
            )

        case .lockScreen:
            let creative = try JSONDecoder().decode(LockScreenCreative.self, from: innerData)
            guard let urlString = creative.ad.image_fullscreen_001_landscape?.u,
                  let imageURL = URL(string: urlString) else {
                throw SpotlightError.missingImageURL
            }
            return SpotlightImage(
                imageURL: imageURL,
                title: creative.ad.title_text?.tx,
                copyright: creative.ad.copyright_text?.tx
            )
        }
    }

    private static func buildURL(source: SpotlightSource, countryCode: String, locale: String) -> URL {
        var components: URLComponents

        switch source {
        case .desktop:
            components = URLComponents(string: "https://fd.api.iris.microsoft.com/v4/api/selection")!
            components.queryItems = [
                URLQueryItem(name: "placement", value: "88000820"),
                URLQueryItem(name: "bcnt", value: "1"),
                URLQueryItem(name: "country", value: countryCode),
                URLQueryItem(name: "locale", value: locale),
                URLQueryItem(name: "fmt", value: "json"),
            ]

        case .lockScreen:
            let (w, h) = largestScreenPixelSize()
            components = URLComponents(string: "https://arc.msn.com/v3/Delivery/Placement")!
            components.queryItems = [
                URLQueryItem(name: "pid", value: "338387"),
                URLQueryItem(name: "fmt", value: "json"),
                URLQueryItem(name: "ua", value: "WindowsShellClient"),
                URLQueryItem(name: "cdm", value: "1"),
                URLQueryItem(name: "disphorzres", value: String(w)),
                URLQueryItem(name: "dispvertres", value: String(h)),
                URLQueryItem(name: "lo", value: "80217"),
                URLQueryItem(name: "pl", value: locale),
                URLQueryItem(name: "lc", value: locale),
                URLQueryItem(name: "ctry", value: countryCode),
                URLQueryItem(name: "rafb", value: "0"),
            ]
        }

        return components.url!
    }

    private static func largestScreenPixelSize() -> (width: Int, height: Int) {
        guard let largest = NSScreen.screens.max(by: {
            ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height)
        }) else {
            return (1920, 1080)
        }
        let scale = largest.backingScaleFactor
        return (Int(largest.frame.width * scale), Int(largest.frame.height * scale))
    }
}
