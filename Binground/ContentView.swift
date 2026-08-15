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
	@AppStorage("countryCode") private var countryCode = Locale.current.region?.identifier ?? "US"
	@AppStorage("locale") private var locale = AppDelegate.defaultLocaleTag()
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
			}
			
			Section("Locale") {
				TextField("Country Code", text: $countryCode)
					.textFieldStyle(.roundedBorder)
				TextField("Locale", text: $locale)
					.textFieldStyle(.roundedBorder)
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
			
			Section("Status") {
				LabeledContent("Last Refresh") {
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
									source: source, countryCode: countryCode, locale: locale
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
			}
			
			if wallpaperManager.currentWallpaperURL != nil {
				Section("Image Information") {
					if let title = wallpaperManager.imageTitle {
						LabeledContent("Title", value: title)
					}
					if let copyright = wallpaperManager.imageCopyright {
						LabeledContent("Source", value: copyright)
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
		.frame(width: 350)
		.fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .jpeg, defaultFilename: "wallpaper") { _ in }
		.onAppear {
			launchAtLogin = SMAppService.mainApp.status == .enabled
		}
	}
	
	private func rescheduleTimer() {
		guard let delegate = NSApp.delegate as? AppDelegate else { return }
		delegate.scheduleNextRefresh()
	}
}
