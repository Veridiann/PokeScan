import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launcher = LaunchManager.shared
    @EnvironmentObject var socket: SocketClient

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    mgbaSection
                    romSection
                    saveStateSection
                    luaScriptSection
                    transparencySection
                    launchSection
                }
                .padding(20)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 500, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("PokeScan Settings")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - mGBA Section

    private var mgbaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("mGBA Application", systemImage: "app.badge.checkmark")
                .font(.headline)

            HStack {
                TextField("Path to mGBA.app", text: $settings.mgbaPath)
                    .textFieldStyle(.roundedBorder)

                Button("Browse...") {
                    selectApp()
                }
            }

            HStack(spacing: 4) {
                Image(systemName: settings.isMGBAValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(settings.isMGBAValid ? .green : .red)
                Text(settings.isMGBAValid ? "mGBA found" : "mGBA not found at this path")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - ROM Section

    private var romSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Pokemon ROM", systemImage: "doc.fill")
                .font(.headline)

            HStack {
                TextField("Path to ROM file (.gba)", text: $settings.romPath)
                    .textFieldStyle(.roundedBorder)

                Button("Browse...") {
                    selectROM()
                }
            }

            HStack(spacing: 4) {
                Image(systemName: settings.isROMValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(settings.isROMValid ? .green : .red)
                Text(settings.isROMValid ? "ROM found" : "ROM not found at this path")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Save State Section

    private var saveStateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Save State", systemImage: "arrow.counterclockwise.circle")
                .font(.headline)

            Picker("Load save state:", selection: $settings.saveSlot) {
                ForEach(AppSettings.SaveSlotOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)

            if let saveStatePath = settings.saveStatePath() {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Will load: \(URL(fileURLWithPath: saveStatePath).lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if settings.saveSlot != .none {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("No save state found for selected slot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Lua Script Section

    private var luaScriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Lua Script", systemImage: "doc.text.fill")
                .font(.headline)

            Toggle("Use custom Lua script path", isOn: $settings.useCustomLuaScript)

            if settings.useCustomLuaScript {
                HStack {
                    TextField("Path to pokescan_sender.lua", text: $settings.luaScriptPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        selectLuaScript()
                    }
                }
            }

            HStack(spacing: 4) {
                let scriptExists = FileManager.default.fileExists(atPath: settings.effectiveLuaScriptPath)
                Image(systemName: scriptExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(scriptExists ? .green : .red)
                Text(scriptExists ? "Script: \(URL(fileURLWithPath: settings.effectiveLuaScriptPath).lastPathComponent)" : "Lua script not found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Transparency Section

    private var transparencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Overlay Transparency", systemImage: "circle.lefthalf.filled")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                // Disconnected opacity
                HStack {
                    Text("When disconnected:")
                        .frame(width: 140, alignment: .leading)
                    Slider(value: $settings.disconnectedOpacity, in: 0...1, step: 0.1)
                    Text("\(Int(settings.disconnectedOpacity * 100))%")
                        .frame(width: 40)
                        .font(.caption.monospacedDigit())
                }

                // Connected idle opacity
                HStack {
                    Text("When idle (no battle):")
                        .frame(width: 140, alignment: .leading)
                    Slider(value: $settings.connectedIdleOpacity, in: 0...1, step: 0.1)
                    Text("\(Int(settings.connectedIdleOpacity * 100))%")
                        .frame(width: 40)
                        .font(.caption.monospacedDigit())
                }

                Text("In battle: always 100% visible. Hover over overlay to temporarily show it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Launch Section

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Launch", systemImage: "play.circle.fill")
                .font(.headline)

            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        await launcher.quickLaunch(socketClient: socket)
                    }
                }) {
                    HStack {
                        if launcher.isLaunching {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Launch mGBA")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!settings.isConfigured || launcher.isLaunching)

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(launcher.mgbaRunning ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(launcher.mgbaRunning ? "mGBA Running" : "mGBA Not Running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = launcher.lastError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Toggle("Auto-launch mGBA when PokeScan starts", isOn: $settings.autoLaunch)
                .font(.subheadline)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(socket.connectionState == .connected ? .green : (socket.connectionState == .connecting ? .orange : .red))
                    .frame(width: 8, height: 8)
                Text(connectionStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.return)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var connectionStatusText: String {
        switch socket.connectionState {
        case .connected: return "Overlay Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Overlay Disconnected"
        }
    }

    // MARK: - File Pickers

    private func selectApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Select mGBA.app"

        if panel.runModal() == .OK, let url = panel.url {
            settings.mgbaPath = url.path
        }
    }

    private func selectROM() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "gba") ?? .data]
        panel.message = "Select Pokemon Emerald ROM"

        if let lastROM = settings.romPath.isEmpty ? nil : URL(fileURLWithPath: settings.romPath).deletingLastPathComponent() {
            panel.directoryURL = lastROM
        }

        if panel.runModal() == .OK, let url = panel.url {
            settings.romPath = url.path
        }
    }

    private func selectLuaScript() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "lua") ?? .data]
        panel.message = "Select pokescan_sender.lua"

        if panel.runModal() == .OK, let url = panel.url {
            settings.luaScriptPath = url.path
        }
    }
}

