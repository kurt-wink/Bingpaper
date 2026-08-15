import ServiceManagement
import SwiftUI

@main
struct BingpaperApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	var body: some Scene {
		Window("Bingpaper", id: "settings") {
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
	
	static var defaultLocale: Locale = Locale(identifier: UserDefaults.standard.string(forKey: "locale") ?? "en-NZ")
	
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
		let nextRefresh = lastRefresh.addingTimeInterval(86400) // 24 hours
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
		
		Task {
			await wallpaperManager.refreshWallpaper(source: source, locale: AppDelegate.defaultLocale)
			scheduleNextRefresh()
		}
	}
}
