import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct WallpaperDocument: FileDocument {
	static var readableContentTypes: [UTType] { [.jpeg] }
	
	let data: Data
	
	init(data: Data) { self.data = data }
	init(configuration: ReadConfiguration) throws {
		data = configuration.file.regularFileContents ?? Data()
	}
	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		FileWrapper(regularFileWithContents: data)
	}
}

struct ContentView: View {
	@Environment(WallpaperManager.self) private var wallpaperManager
	@AppStorage("apiSource") private var apiSource = SpotlightSource.desktop.rawValue
	@AppStorage("locale") private var locale = AppDelegate.defaultLocale.identifier
	@AppStorage("refreshInterval") private var refreshInterval: Int = 1440
	@State private var launchAtLogin = SMAppService.mainApp.status == .enabled
	@State private var isExporting = false
	@State private var exportDocument: WallpaperDocument?
	
	private var lastRefreshDate: Date? {
		UserDefaults.standard.object(forKey: "lastRefreshDate") as? Date
	}
	
	var body: some View {
		Form {
			Section("Source") {
				Picker("", selection: $apiSource) {
					Text("Desktop Spotlight").tag(SpotlightSource.desktop.rawValue)
					Text("Lock Screen Spotlight").tag(SpotlightSource.lockScreen.rawValue)
				}
				.labelsHidden()
				.pickerStyle(.radioGroup)
				
				LabeledContent("Locale") {
					LocaleComboBox(selection: $locale)
						.frame(maxWidth: 80)
				}
			}
			
			Section("System") {
				Toggle("Launch at Login", isOn: $launchAtLogin)
					.onChange(of: launchAtLogin) { _, newValue in
						do {
							if newValue {
								try SMAppService.mainApp.register()
							} else {
								try SMAppService.mainApp.unregister()
							}
						} catch {
							launchAtLogin = SMAppService.mainApp.status == .enabled
						}
					}
			}
			
			Section("Image Information") {
				Picker("Refresh", selection: $refreshInterval) {
					Text("Every 5 Minutes").tag(5)
					Text("Every 15 Minutes").tag(15)
					Text("Every 30 Minutes").tag(30)
					Text("Every 1 Hour").tag(60)
					Text("Every 2 Hours").tag(120)
					Text("Every 4 Hours").tag(240)
					Text("Every 8 Hours").tag(480)
					Text("Every 12 Hours").tag(720)
					Text("Every Day").tag(1440)
				}
				.onChange(of: refreshInterval) {
					rescheduleTimer()
				}

				LabeledContent("Last Refreshed") {
					HStack(spacing: 6) {
						if let date = lastRefreshDate {
							Text(date, format: .dateTime)
						} else {
							Text("Never")
						}
						Button {
							let source = SpotlightSource(rawValue: apiSource) ?? .desktop
							Task {
								await wallpaperManager.refreshWallpaper(
									source: source, locale: Locale(identifier: locale)
								)
								rescheduleTimer()
							}
						} label: {
							if wallpaperManager.isRefreshing {
								ProgressView()
									.controlSize(.small)
							} else {
								Image(systemName: "arrow.clockwise")
							}
						}
						.buttonStyle(.borderless)
						.disabled(wallpaperManager.isRefreshing)
					}
				}
				
				if let error = wallpaperManager.lastError {
					Text(error)
						.foregroundStyle(.red)
						.font(.caption)
				}
				
				if wallpaperManager.currentWallpaperURL != nil {
					if let title = wallpaperManager.currentImage?.title {
						VStack(alignment: .leading) {
							Text("Title")
							Text(title)
								.foregroundStyle(.secondary)
						}
					}
					if let copyright = wallpaperManager.currentImage?.copyright {
						VStack(alignment: .leading) {
							Text("Source")
							Text(copyright)
								.foregroundStyle(.secondary)
						}
					}
					
					HStack {
						Button("Reveal in Finder...") {
							wallpaperManager.revealInFinder()
						}
						Button("Save...") {
							if let url = wallpaperManager.currentWallpaperURL,
							   let data = try? Data(contentsOf: url) {
								exportDocument = WallpaperDocument(data: data)
								isExporting = true
							}
						}
					}
				}
			}
			
			Button("Quit") {
				NSApp.terminate(nil)
			}
		}
		.formStyle(.grouped)
		.frame(width: 350, height: 640)
		.fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .jpeg, defaultFilename: saveFilename) { _ in }
		.onAppear {
			launchAtLogin = SMAppService.mainApp.status == .enabled
		}
	}
	
	private var saveFilename: String {
		let name = wallpaperManager.currentImage?.imageURL.lastPathComponent ?? "wallpaper.jpg"
		return String(name.split(separator: "_", maxSplits: 1).last ?? Substring(name))
	}
	
	private func rescheduleTimer() {
		guard let delegate = NSApp.delegate as? AppDelegate else { return }
		delegate.scheduleNextRefresh()
	}
}
