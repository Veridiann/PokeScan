import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let showSettings = Notification.Name("showSettings")
}

// MARK: - App

@main
struct PokeScanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: OverlayWindow?
    private var settingsWindow: NSWindow?
    private var keyMonitor: Any?

    private let dex = PokemonDex()
    private lazy var socketClient = SocketClient(dex: dex)
    private let criteria = CriteriaEngine()
    private let alerts = AlertManager()
    private let windowController = OverlayWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupOverlayWindow()
        setupSettingsObserver()
        socketClient.start()
        installKeyMonitor()

        // Auto-launch mGBA if configured
        if AppSettings.shared.autoLaunch && AppSettings.shared.isConfigured {
            Task {
                // Small delay to let the app fully initialize
                try? await Task.sleep(nanoseconds: 500_000_000)
                await LaunchManager.shared.quickLaunch(socketClient: socketClient)
            }
        }

        // Show settings on first launch if not configured
        if !AppSettings.shared.isConfigured {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showSettings()
            }
        }
    }

    private func setupOverlayWindow() {
        let contentView = ContentView()
            .environmentObject(socketClient)
            .environmentObject(criteria)
            .environmentObject(alerts)
            .environmentObject(dex)
            .environmentObject(windowController)

        window = OverlayWindow(rootView: contentView, controller: windowController)
        window?.makeKeyAndOrderFront(nil)
    }

    private func setupSettingsObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings),
            name: .showSettings,
            object: nil
        )
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(socketClient)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "PokeScan Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Space - clear flash
            if event.keyCode == 49 {
                self.alerts.clearFlash()
                return nil
            }

            // Comma - open settings
            if event.keyCode == 43 && event.modifierFlags.contains(.command) {
                self.showSettings()
                return nil
            }

            // Number keys 1-9 - switch profiles
            if let chars = event.charactersIgnoringModifiers, let digit = Int(chars), digit >= 1, digit <= 9 {
                let keys = self.criteria.profileKeys()
                let index = digit - 1
                if index < keys.count {
                    self.criteria.setActiveProfile(keys[index])
                    return nil
                }
            }

            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
