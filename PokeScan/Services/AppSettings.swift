import Foundation
import SwiftUI

/// Persistent app settings stored in UserDefaults
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let mgbaPath = "mgbaPath"
        static let romPath = "romPath"
        static let saveSlot = "saveSlot"
        static let autoLaunch = "autoLaunch"
        static let luaScriptPath = "luaScriptPath"
        static let useCustomLuaScript = "useCustomLuaScript"
        static let disconnectedOpacity = "disconnectedOpacity"
        static let connectedIdleOpacity = "connectedIdleOpacity"
    }

    // MARK: - Published Properties

    @Published var mgbaPath: String {
        didSet { defaults.set(mgbaPath, forKey: Keys.mgbaPath) }
    }

    @Published var romPath: String {
        didSet { defaults.set(romPath, forKey: Keys.romPath) }
    }

    @Published var saveSlot: SaveSlotOption {
        didSet { defaults.set(saveSlot.rawValue, forKey: Keys.saveSlot) }
    }

    @Published var autoLaunch: Bool {
        didSet { defaults.set(autoLaunch, forKey: Keys.autoLaunch) }
    }

    @Published var luaScriptPath: String {
        didSet { defaults.set(luaScriptPath, forKey: Keys.luaScriptPath) }
    }

    @Published var useCustomLuaScript: Bool {
        didSet { defaults.set(useCustomLuaScript, forKey: Keys.useCustomLuaScript) }
    }

    /// Opacity when disconnected from mGBA (0.0 = invisible, 1.0 = fully visible)
    @Published var disconnectedOpacity: Double {
        didSet { defaults.set(disconnectedOpacity, forKey: Keys.disconnectedOpacity) }
    }

    /// Opacity when connected but not in battle (0.0 = invisible, 1.0 = fully visible)
    @Published var connectedIdleOpacity: Double {
        didSet { defaults.set(connectedIdleOpacity, forKey: Keys.connectedIdleOpacity) }
    }

    // MARK: - Save Slot Options

    enum SaveSlotOption: String, CaseIterable, Identifiable {
        case none = "none"
        case latest = "latest"
        case slot0 = "0"
        case slot1 = "1"
        case slot2 = "2"
        case slot3 = "3"
        case slot4 = "4"
        case slot5 = "5"
        case slot6 = "6"
        case slot7 = "7"
        case slot8 = "8"
        case slot9 = "9"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .none: return "None"
            case .latest: return "Latest"
            default: return "Slot \(rawValue)"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Load saved values or use defaults
        self.mgbaPath = defaults.string(forKey: Keys.mgbaPath) ?? Self.detectMGBA()
        self.romPath = defaults.string(forKey: Keys.romPath) ?? ""
        self.saveSlot = SaveSlotOption(rawValue: defaults.string(forKey: Keys.saveSlot) ?? "latest") ?? .latest
        self.autoLaunch = defaults.bool(forKey: Keys.autoLaunch)
        self.luaScriptPath = defaults.string(forKey: Keys.luaScriptPath) ?? ""
        self.useCustomLuaScript = defaults.bool(forKey: Keys.useCustomLuaScript)

        // Opacity settings - default: 50% when disconnected, invisible when idle
        self.disconnectedOpacity = defaults.object(forKey: Keys.disconnectedOpacity) as? Double ?? 0.5
        self.connectedIdleOpacity = defaults.object(forKey: Keys.connectedIdleOpacity) as? Double ?? 0.0
    }

    // MARK: - Validation

    var isMGBAValid: Bool {
        FileManager.default.fileExists(atPath: mgbaPath)
    }

    var isROMValid: Bool {
        FileManager.default.fileExists(atPath: romPath)
    }

    var isConfigured: Bool {
        isMGBAValid && isROMValid
    }

    var mgbaExecutablePath: String {
        "\(mgbaPath)/Contents/MacOS/mGBA"
    }

    // MARK: - Bundled Lua Script

    var effectiveLuaScriptPath: String {
        if useCustomLuaScript && !luaScriptPath.isEmpty {
            return luaScriptPath
        }
        return bundledLuaScriptPath
    }

    var bundledLuaScriptPath: String {
        // The Lua script should be in the app bundle or in a known location
        // For development, we'll look in common locations
        let possiblePaths = [
            Bundle.main.bundlePath + "/Contents/Resources/lua/pokescan_sender.lua",
            Bundle.main.bundlePath + "/../../../lua/pokescan_sender.lua", // Dev mode
            NSHomeDirectory() + "/Code/Live/PokeScan/lua/pokescan_sender.lua"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback - user will need to set custom path
        return ""
    }

    // MARK: - Auto-detection

    static func detectMGBA() -> String {
        let possiblePaths = [
            "/Applications/mGBA.app",
            NSHomeDirectory() + "/Applications/mGBA.app",
            "/opt/homebrew/Caskroom/mgba/*/mGBA.app"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find via Homebrew
        if let brewPath = try? FileManager.default.contentsOfDirectory(atPath: "/opt/homebrew/Caskroom/mgba") {
            for version in brewPath {
                let appPath = "/opt/homebrew/Caskroom/mgba/\(version)/mGBA.app"
                if FileManager.default.fileExists(atPath: appPath) {
                    return appPath
                }
            }
        }

        return "/Applications/mGBA.app"
    }

    // MARK: - Save State Path

    func saveStatePath() -> String? {
        guard isROMValid else { return nil }

        let romURL = URL(fileURLWithPath: romPath)
        let romDir = romURL.deletingLastPathComponent().path
        let romBase = romURL.deletingPathExtension().lastPathComponent

        switch saveSlot {
        case .none:
            return nil

        case .latest:
            // Find most recent save state
            return findLatestSaveState(in: romDir, baseName: romBase)

        default:
            // Specific slot
            let ssPath = "\(romDir)/\(romBase).ss\(saveSlot.rawValue)"
            return FileManager.default.fileExists(atPath: ssPath) ? ssPath : nil
        }
    }

    private func findLatestSaveState(in directory: String, baseName: String) -> String? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return nil }

        var latestPath: String?
        var latestDate: Date?

        for file in files {
            if file.hasPrefix(baseName) && file.contains(".ss") {
                let fullPath = "\(directory)/\(file)"
                if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                   let modDate = attrs[.modificationDate] as? Date {
                    if latestDate == nil || modDate > latestDate! {
                        latestDate = modDate
                        latestPath = fullPath
                    }
                }
            }
        }

        return latestPath
    }
}
