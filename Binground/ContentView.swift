import ServiceManagement
import SwiftUI

struct ContentView: View {
    @Environment(WallpaperManager.self) private var wallpaperManager
    @AppStorage("apiSource") private var apiSource = SpotlightSource.desktop.rawValue
    @AppStorage("countryCode") private var countryCode = Locale.current.region?.identifier ?? "US"
    @AppStorage("locale") private var locale = AppDelegate.defaultLocaleTag()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

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
                if let date = lastRefreshDate {
                    LabeledContent("Last Refresh", value: date, format: .dateTime)
                } else {
                    LabeledContent("Last Refresh", value: "Never")
                }

                if let error = wallpaperManager.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
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
                        Text("Refresh Now")
                    }
                }
                .disabled(wallpaperManager.isRefreshing)
            }

            if wallpaperManager.currentWallpaperURL != nil {
                Section("Current Image") {
                    if let title = wallpaperManager.imageTitle {
                        LabeledContent("Title", value: title)
                    }
                    if let copyright = wallpaperManager.imageCopyright {
                        LabeledContent("Source", value: copyright)
                    }

                    Button("Reveal in Finder...") {
                        wallpaperManager.revealInFinder()
                    }
                }
            }

			Button("Quit") {
				NSApp.terminate(nil)
			}
        }
        .formStyle(.grouped)
        .frame(width: 350)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func rescheduleTimer() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.scheduleNextRefresh()
    }
}
