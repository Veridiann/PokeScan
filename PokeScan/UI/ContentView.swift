import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var socket: SocketClient
    @EnvironmentObject private var criteria: CriteriaEngine
    @EnvironmentObject private var alerts: AlertManager
    @EnvironmentObject private var dex: PokemonDex
    @EnvironmentObject private var windowController: OverlayWindowController

    @ObservedObject private var launcher = LaunchManager.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var verdict: CatchVerdict?
    @State private var isHovering = false
    @State private var showingSettings = false

    private var hasPokemon: Bool {
        socket.connectionState == .connected && socket.currentPokemon != nil
    }

    private var windowOpacity: Double {
        // Hovering always shows full opacity
        if isHovering { return 1.0 }

        // In battle - fully visible
        if hasPokemon { return 1.0 }

        // Connected but no battle - hide completely (can hover to show)
        if socket.connectionState == .connected { return settings.connectedIdleOpacity }

        // Disconnected - show dimmed so user knows status
        return settings.disconnectedOpacity
    }

    private var isShiny: Bool {
        socket.currentPokemon?.shiny ?? false
    }

    private var shouldAnimate: Bool {
        if case .catchIt = verdict { return true }
        if case .shiny = verdict { return true }
        return false
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let borderPhase = CGFloat(time.truncatingRemainder(dividingBy: 3.0) / 3.0)

            ZStack {
                // Background - metallic silver for shiny, dark for normal
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isShiny
                            ? LinearGradient(
                                colors: [
                                    Color(red: 0.75, green: 0.77, blue: 0.80),
                                    Color(red: 0.85, green: 0.87, blue: 0.90),
                                    Color(red: 0.70, green: 0.72, blue: 0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color(white: 0.08), Color(white: 0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .shadow(color: shadowColor, radius: isShiny ? 12 : 6, x: 0, y: 3)

                // Sparkles for shiny Pokemon
                if isShiny {
                    SparkleOverlay(time: time)
                }

                // Content
                cardContent

                // Animated border for catch/shiny
                if shouldAnimate {
                    AnimatedBorder(phase: borderPhase, color: isShiny ? .yellow : .green)
                }

                // Base border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isShiny ? Color.white.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)

                // Alert flash
                if alerts.borderColor != .clear {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(alerts.borderColor, lineWidth: 3)
                }
            }
            .frame(width: 300, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(width: 300, height: 200)
        .opacity(windowOpacity)
        .animation(.easeInOut(duration: 0.3), value: windowOpacity)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu { contextMenu }
        .onChange(of: socket.currentPokemon?.pid) { _ in
            updateVerdictAndAlerts()
        }
    }

    private var shadowColor: Color {
        if isShiny { return .yellow.opacity(0.4) }
        if shouldAnimate { return .green.opacity(0.3) }
        return .black.opacity(0.5)
    }

    // MARK: - Text Colors

    private var primaryTextColor: Color {
        isShiny ? Color(white: 0.1) : .white
    }

    private var secondaryTextColor: Color {
        isShiny ? Color(white: 0.3) : .white.opacity(0.7)
    }

    private var tertiaryTextColor: Color {
        isShiny ? Color(white: 0.4) : .white.opacity(0.5)
    }

    private var dividerColor: Color {
        isShiny ? Color(white: 0.5) : .white.opacity(0.2)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            Divider().background(dividerColor)
            natureRow
            statsGrid
            Divider().background(dividerColor)
            connectionRow
        }
        .padding(12)
        .foregroundStyle(primaryTextColor)
    }

    // MARK: - Connection Row

    private var connectionRow: some View {
        HStack {
            Circle()
                .fill(connectionColor)
                .frame(width: 6, height: 6)
            Text(connectionStatusText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(tertiaryTextColor)
            Spacer()
        }
    }

    private var connectionStatusText: String {
        switch socket.connectionState {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 10) {
            if socket.connectionState == .connected, let pokemon = socket.currentPokemon {
                // Sprite (larger)
                PokemonSprite(speciesId: pokemon.speciesId, isShiny: pokemon.shiny, size: 52)
                    .shadow(color: pokemon.shiny ? .yellow.opacity(0.8) : .clear, radius: 6)

                // Name and level
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        if pokemon.shiny {
                            Text("★")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 12))
                        }
                        Text(pokemon.speciesName.uppercased())
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    HStack(spacing: 4) {
                        Text("Lv.\(pokemon.level ?? 0)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                        Text(genderSymbol(pokemon.gender))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(genderColor(pokemon.gender))
                    }
                }

                Spacer()

                // Verdict badge
                verdictBadge
            } else {
                Text(socket.connectionState == .connected ? "Waiting..." : "Offline")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryTextColor)
                Spacer()
            }
        }
    }

    private var verdictBadge: some View {
        Group {
            switch verdict {
            case .shiny:
                Label("SHINY", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(red: 0.8, green: 0.6, blue: 0.0)))  // Dark gold
            case .catchIt:
                Label("CATCH", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
            case .skip:
                Text("SKIP")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryTextColor)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Nature Row

    private var natureRow: some View {
        let pokemon = socket.currentPokemon
        let hasData = socket.connectionState == .connected && pokemon != nil

        return HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Nature:")
                    .foregroundStyle(secondaryTextColor)
                Text(pokemon?.nature ?? "--")
                    .foregroundStyle(hasData ? primaryTextColor : tertiaryTextColor)
                if hasData, let effect = natureEffect(pokemon?.nature) {
                    Text(effect)
                        .foregroundStyle(tertiaryTextColor)
                }
            }
            Spacer()
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let pokemon = socket.currentPokemon
        let hasData = socket.connectionState == .connected && pokemon != nil
        let ivs = pokemon?.ivs ?? IVs(hp: 0, atk: 0, def: 0, spa: 0, spd: 0, spe: 0)
        let baseStats = pokemon?.baseStats
        let labels = ["HP", "ATK", "DEF", "SPA", "SPD", "SPE"]
        let ivValues = [ivs.hp, ivs.atk, ivs.def, ivs.spa, ivs.spd, ivs.spe]
        let baseValues = baseStats.map { [$0.hp, $0.atk, $0.def, $0.spa, $0.spd, $0.spe] }
        let natureEff = pokemon?.nature.flatMap { natureStatEffect($0) }
        let ivTotal = ivValues.reduce(0, +)
        let ivPercent = Int((Double(ivTotal) / 186.0) * 100)

        return VStack(alignment: .leading, spacing: 3) {
            // Headers
            HStack(spacing: 2) {
                Text("").frame(width: 26)
                ForEach(0..<labels.count, id: \.self) { idx in
                    let statKey = labels[idx].lowercased()
                    let effect = natureEff?[statKey] ?? 0
                    HStack(spacing: 1) {
                        if effect > 0 {
                            Text("▲").font(.system(size: 6)).foregroundStyle(.green)
                        } else if effect < 0 {
                            Text("▼").font(.system(size: 6)).foregroundStyle(.red)
                        }
                        Text(labels[idx])
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(statLabelColor(effect: effect, hasData: hasData))
                    }
                    .frame(width: 40)
                }
            }

            // IVs
            HStack(spacing: 2) {
                Text("IVs")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryTextColor)
                    .frame(width: 26, alignment: .leading)
                ForEach(0..<ivValues.count, id: \.self) { idx in
                    let statKey = labels[idx].lowercased()
                    let effect = natureEff?[statKey] ?? 0
                    VStack(spacing: 1) {
                        Text(hasData ? "\(ivValues[idx])" : "--")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(hasData ? ivColorWithNature(ivValues[idx], nature: effect) : tertiaryTextColor)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5).fill(isShiny ? Color.black.opacity(0.15) : Color.white.opacity(0.15))
                                if hasData {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(ivColor(ivValues[idx]))
                                        .frame(width: geo.size.width * CGFloat(ivValues[idx]) / 31.0)
                                }
                            }
                        }
                        .frame(height: 3)
                    }
                    .frame(width: 40)
                }
            }

            // Base stats
            HStack(spacing: 2) {
                Text("Base")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryTextColor)
                    .frame(width: 26, alignment: .leading)
                ForEach(0..<labels.count, id: \.self) { idx in
                    Text(hasData && baseValues != nil ? "\(baseValues![idx])" : "--")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(tertiaryTextColor)
                        .frame(width: 40)
                }
            }

            Spacer().frame(height: 4)

            // Footer row: Ability, HP, IV Total
            HStack(spacing: 0) {
                // Ability
                HStack(spacing: 3) {
                    Text("Ability:")
                        .foregroundStyle(tertiaryTextColor)
                    Text(pokemon?.abilityName ?? "--")
                        .foregroundStyle(hasData ? secondaryTextColor : tertiaryTextColor)
                }

                Text("  •  ")
                    .foregroundStyle(tertiaryTextColor)

                // Hidden Power
                HStack(spacing: 3) {
                    Text("HP:")
                        .foregroundStyle(tertiaryTextColor)
                    Text(pokemon?.hpType ?? "--")
                        .foregroundStyle(hasData ? secondaryTextColor : tertiaryTextColor)
                    if hasData, let power = pokemon?.hpPower {
                        Text("(\(power))")
                            .foregroundStyle(tertiaryTextColor)
                    }
                }

                Spacer()

                // IV Total
                if hasData {
                    Text("\(ivTotal)/186 (\(ivPercent)%)")
                        .foregroundStyle(ivTotalColor(ivTotal))
                }
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
        }
    }

    // MARK: - Connection

    private var connectionColor: Color {
        switch socket.connectionState {
        case .connected: return .green
        case .disconnected: return .red
        case .connecting: return .orange
        }
    }

    // MARK: - Context Menu

    private var contextMenu: some View {
        Group {
            // Launch section
            Button(action: {
                Task {
                    await launcher.quickLaunch(socketClient: socket)
                }
            }) {
                if launcher.isLaunching {
                    Text("Launching...")
                } else if launcher.mgbaRunning {
                    Label("Relaunch mGBA", systemImage: "arrow.clockwise")
                } else {
                    Label("Launch mGBA", systemImage: "play.fill")
                }
            }
            .disabled(!settings.isConfigured || launcher.isLaunching)

            Divider()

            // Profile section
            Menu("Profile: \(criteria.criteria.activeProfile)") {
                ForEach(criteria.profileKeys(), id: \.self) { key in
                    Button(key) { criteria.setActiveProfile(key) }
                }
            }
            Toggle("Sound Alerts", isOn: Binding(
                get: { criteria.criteria.alertSoundEnabled },
                set: { criteria.setSoundEnabled($0) }
            ))
            Toggle("Always on Top", isOn: Binding(
                get: { windowController.alwaysOnTop },
                set: { windowController.setAlwaysOnTop($0) }
            ))

            Divider()

            Button("Reload Criteria") { criteria.reload() }
            Button("Edit Criteria") { NSWorkspace.shared.open(criteria.fileURL) }

            Divider()

            Button("Settings...") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }

            Divider()

            Button("Quit") { NSApp.terminate(nil) }
        }
    }

    // MARK: - Verdict Logic

    private func updateVerdictAndAlerts() {
        guard let pokemon = socket.currentPokemon else {
            verdict = nil
            return
        }
        let newVerdict = criteria.evaluate(pokemon: pokemon)
        verdict = newVerdict
        switch newVerdict {
        case .shiny, .catchIt:
            alerts.flash()
            if criteria.criteria.alertSoundEnabled {
                alerts.playSound()
            }
        case .skip:
            break
        }
    }

    // MARK: - Color Helpers

    private func ivColor(_ value: Int) -> Color {
        if value == 31 { return .green }
        if value >= 26 { return .green.opacity(0.7) }
        if value >= 16 { return .white }
        if value >= 1 { return .orange }
        return .red
    }

    private func ivColorWithNature(_ value: Int, nature: Int) -> Color {
        if nature > 0 && value >= 26 { return .green }
        if nature < 0 && value >= 26 { return .orange }
        return ivColor(value)
    }

    private func ivTotalColor(_ total: Int) -> Color {
        if total >= 150 { return .green }
        if total >= 120 { return .yellow }
        if total >= 90 { return .orange }
        return .white.opacity(0.6)
    }

    private func statLabelColor(effect: Int, hasData: Bool) -> Color {
        guard hasData else { return tertiaryTextColor }
        if effect > 0 { return .green }
        if effect < 0 { return .red.opacity(0.8) }
        return secondaryTextColor
    }

    private func natureStatEffect(_ nature: String) -> [String: Int] {
        let effects: [String: (boost: String, reduce: String)] = [
            "Lonely": ("atk", "def"), "Brave": ("atk", "spe"), "Adamant": ("atk", "spa"), "Naughty": ("atk", "spd"),
            "Bold": ("def", "atk"), "Relaxed": ("def", "spe"), "Impish": ("def", "spa"), "Lax": ("def", "spd"),
            "Timid": ("spe", "atk"), "Hasty": ("spe", "def"), "Jolly": ("spe", "spa"), "Naive": ("spe", "spd"),
            "Modest": ("spa", "atk"), "Mild": ("spa", "def"), "Quiet": ("spa", "spe"), "Rash": ("spa", "spd"),
            "Calm": ("spd", "atk"), "Gentle": ("spd", "def"), "Sassy": ("spd", "spe"), "Careful": ("spd", "spa")
        ]
        var result: [String: Int] = ["hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0]
        if let effect = effects[nature] {
            result[effect.boost] = 1
            result[effect.reduce] = -1
        }
        return result
    }

    private func natureEffect(_ nature: String?) -> String? {
        guard let nature = nature else { return nil }
        let effects: [String: (String, String)] = [
            "Lonely": ("Atk", "Def"), "Brave": ("Atk", "Spe"), "Adamant": ("Atk", "SpA"), "Naughty": ("Atk", "SpD"),
            "Bold": ("Def", "Atk"), "Relaxed": ("Def", "Spe"), "Impish": ("Def", "SpA"), "Lax": ("Def", "SpD"),
            "Timid": ("Spe", "Atk"), "Hasty": ("Spe", "Def"), "Jolly": ("Spe", "SpA"), "Naive": ("Spe", "SpD"),
            "Modest": ("SpA", "Atk"), "Mild": ("SpA", "Def"), "Quiet": ("SpA", "Spe"), "Rash": ("SpA", "SpD"),
            "Calm": ("SpD", "Atk"), "Gentle": ("SpD", "Def"), "Sassy": ("SpD", "Spe"), "Careful": ("SpD", "SpA")
        ]
        if let effect = effects[nature] { return "(+\(effect.0) -\(effect.1))" }
        return nil
    }

    private func genderSymbol(_ gender: String?) -> String {
        switch gender?.lowercased() {
        case "male": return "♂"
        case "female": return "♀"
        default: return "–"
        }
    }

    private func genderColor(_ gender: String?) -> Color {
        switch gender?.lowercased() {
        case "male": return isShiny ? .blue : .cyan
        case "female": return .pink
        default: return tertiaryTextColor
        }
    }
}

// MARK: - Sparkle Overlay

struct SparkleOverlay: View {
    let time: TimeInterval

    // Fixed sparkle positions (deterministic, not random)
    private let sparkles: [(x: CGFloat, y: CGFloat, speed: Double, phase: Double, size: CGFloat)] = [
        (0.12, 0.18, 1.2, 0.0, 4), (0.88, 0.12, 0.9, 0.3, 3), (0.22, 0.78, 1.1, 0.5, 5),
        (0.72, 0.82, 1.4, 0.7, 3), (0.52, 0.28, 0.8, 0.2, 4), (0.92, 0.52, 1.0, 0.8, 3),
        (0.08, 0.42, 1.3, 0.4, 5), (0.62, 0.58, 0.7, 0.1, 3), (0.32, 0.08, 1.5, 0.6, 4),
        (0.82, 0.32, 1.1, 0.9, 3), (0.42, 0.88, 0.9, 0.35, 4), (0.18, 0.58, 1.2, 0.55, 3),
        (0.55, 0.15, 1.0, 0.25, 5), (0.75, 0.55, 1.3, 0.65, 3),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<sparkles.count, id: \.self) { i in
                let s = sparkles[i]
                let twinkle = sin((time * s.speed + s.phase) * .pi * 2)
                let opacity = 0.4 + (twinkle + 1) * 0.3  // 0.4 to 1.0

                // White sparkle with golden glow
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: s.size, height: s.size)
                    Circle()
                        .fill(Color.yellow.opacity(0.5))
                        .frame(width: s.size * 2, height: s.size * 2)
                        .blur(radius: 2)
                }
                .opacity(opacity)
                .position(
                    x: geo.size.width * s.x,
                    y: geo.size.height * s.y
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Animated Border with Tails

struct AnimatedBorder: View {
    let phase: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                // Draw tail and orb for both particles
                drawOrbWithTail(context: context, size: size, phase: phase, color: color)
                drawOrbWithTail(context: context, size: size, phase: phase + 0.5, color: color)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawOrbWithTail(context: GraphicsContext, size: CGSize, phase: CGFloat, color: Color) {
        let tailLength = 12
        var points: [CGPoint] = []

        // Calculate tail points (going backwards from current position)
        for i in 0..<tailLength {
            let tailPhase = phase - CGFloat(i) * 0.008
            points.append(pointOnRoundedRect(phase: tailPhase, size: size, cornerRadius: 16))
        }

        // Draw tail segments with fading opacity
        for i in 1..<points.count {
            let opacity = 1.0 - (Double(i) / Double(tailLength))
            let width = 4.0 * (1.0 - Double(i) / Double(tailLength))

            var path = Path()
            path.move(to: points[i - 1])
            path.addLine(to: points[i])

            context.stroke(
                path,
                with: .color(color.opacity(opacity * 0.6)),
                lineWidth: width
            )
        }

        // Draw main orb
        let orbPos = points.first ?? .zero
        let orbRect = CGRect(x: orbPos.x - 4, y: orbPos.y - 4, width: 8, height: 8)
        context.fill(Ellipse().path(in: orbRect), with: .color(color))

        // Glow
        let glowRect = CGRect(x: orbPos.x - 8, y: orbPos.y - 8, width: 16, height: 16)
        context.fill(
            Ellipse().path(in: glowRect),
            with: .color(color.opacity(0.3))
        )
    }

    private func pointOnRoundedRect(phase: CGFloat, size: CGSize, cornerRadius: CGFloat) -> CGPoint {
        let p = phase.truncatingRemainder(dividingBy: 1.0)
        let adjustedP = p < 0 ? p + 1 : p
        let w = size.width
        let h = size.height
        let r = cornerRadius

        let straightH = w - 2 * r
        let straightV = h - 2 * r
        let cornerArc = CGFloat.pi * r / 2
        let total = 2 * straightH + 2 * straightV + 4 * cornerArc

        var dist = adjustedP * total

        // Top edge
        if dist < straightH {
            return CGPoint(x: r + dist, y: 0)
        }
        dist -= straightH

        // Top-right corner
        if dist < cornerArc {
            let angle = -CGFloat.pi / 2 + (dist / r)
            return CGPoint(x: w - r + r * cos(angle), y: r + r * sin(angle))
        }
        dist -= cornerArc

        // Right edge
        if dist < straightV {
            return CGPoint(x: w, y: r + dist)
        }
        dist -= straightV

        // Bottom-right corner
        if dist < cornerArc {
            let angle = 0 + (dist / r)
            return CGPoint(x: w - r + r * cos(angle), y: h - r + r * sin(angle))
        }
        dist -= cornerArc

        // Bottom edge
        if dist < straightH {
            return CGPoint(x: w - r - dist, y: h)
        }
        dist -= straightH

        // Bottom-left corner
        if dist < cornerArc {
            let angle = CGFloat.pi / 2 + (dist / r)
            return CGPoint(x: r + r * cos(angle), y: h - r + r * sin(angle))
        }
        dist -= cornerArc

        // Left edge
        if dist < straightV {
            return CGPoint(x: 0, y: h - r - dist)
        }
        dist -= straightV

        // Top-left corner
        let angle = CGFloat.pi + (dist / r)
        return CGPoint(x: r + r * cos(angle), y: r + r * sin(angle))
    }
}
