import Foundation
import AppKit

/// Manages launching and monitoring mGBA
@MainActor
final class LaunchManager: ObservableObject {
    static let shared = LaunchManager()

    @Published var mgbaRunning = false
    @Published var lastError: String?
    @Published var isLaunching = false

    private var mgbaProcess: Process?
    private var checkTimer: Timer?

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Check mGBA status periodically
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMGBAStatus()
            }
        }
        checkMGBAStatus()
    }

    private func checkMGBAStatus() {
        let running = NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.endrift.mgba" || app.localizedName == "mGBA"
        }
        if mgbaRunning != running {
            mgbaRunning = running
        }
    }

    // MARK: - Launch

    func launchMGBA() async {
        let settings = AppSettings.shared

        guard settings.isConfigured else {
            lastError = "Please configure mGBA and ROM paths in Settings"
            return
        }

        guard !settings.effectiveLuaScriptPath.isEmpty else {
            lastError = "Lua script not found. Please configure in Settings."
            return
        }

        isLaunching = true
        lastError = nil

        // Kill existing mGBA instances
        await killExistingMGBA()

        // Small delay to ensure cleanup
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Build arguments
        var arguments = [settings.romPath, "--script", settings.effectiveLuaScriptPath]

        // Add save state if configured
        if let saveStatePath = settings.saveStatePath() {
            arguments.append(contentsOf: ["-t", saveStatePath])
        }

        // Launch mGBA
        let process = Process()
        process.executableURL = URL(fileURLWithPath: settings.mgbaExecutablePath)
        process.arguments = arguments

        do {
            try process.run()
            mgbaProcess = process

            // Wait a moment then check if it's running
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            checkMGBAStatus()

            if mgbaRunning {
                print("PokeScan: mGBA launched successfully")
            } else {
                lastError = "mGBA failed to start"
            }
        } catch {
            lastError = "Failed to launch mGBA: \(error.localizedDescription)"
            print("PokeScan: \(lastError!)")
        }

        isLaunching = false
    }

    func killExistingMGBA() async {
        // Kill via NSWorkspace
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier == "com.endrift.mgba" || app.localizedName == "mGBA" {
                app.terminate()
            }
        }

        // Also try pkill as backup
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killProcess.arguments = ["-x", "mGBA"]
        try? killProcess.run()
        killProcess.waitUntilExit()
    }

    // MARK: - Quick Launch

    /// Launch mGBA and auto-connect (called from button)
    func quickLaunch(socketClient: SocketClient) async {
        await launchMGBA()

        if mgbaRunning && lastError == nil {
            // Wait for Lua server to start
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Reconnect socket client
            socketClient.reconnect()
        }
    }
}
