import ServiceManagement
import SwiftUI

@main
struct BingroundApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Binground", id: "settings") {
            ContentView()
                .environment(appDelegate.wallpaperManager)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let wallpaperManager = WallpaperManager()
    private var refreshTimer: DispatchSourceTimer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        scheduleNextRefresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func scheduleNextRefresh() {
        refreshTimer?.cancel()

        let lastRefresh = UserDefaults.standard.object(forKey: "lastRefreshDate") as? Date ?? .distantPast
        let nextRefresh = lastRefresh.addingTimeInterval(86400)
        let delay = max(0, nextRefresh.timeIntervalSinceNow)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(wallDeadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            self?.performRefresh()
        }
        timer.resume()
        refreshTimer = timer
    }

    private func performRefresh() {
        let source = SpotlightSource(rawValue: UserDefaults.standard.string(forKey: "apiSource") ?? "") ?? .desktop
        let countryCode = UserDefaults.standard.string(forKey: "countryCode")
            ?? Locale.current.region?.identifier ?? "US"
        let locale = UserDefaults.standard.string(forKey: "locale")
            ?? Self.defaultLocaleTag()

        Task {
            await wallpaperManager.refreshWallpaper(source: source, countryCode: countryCode, locale: locale)
            scheduleNextRefresh()
        }
    }

    static func defaultLocaleTag() -> String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let region = Locale.current.region?.identifier ?? "US"
        return "\(lang)-\(region)"
    }
}
