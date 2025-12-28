# PokeScan

A real-time IV overlay for Pokemon Emerald running on mGBA. Displays IVs, nature, ability, hidden power, and catch recommendations as a floating macOS window while you play.

![macOS](https://img.shields.io/badge/platform-macOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

![PokeScan in action](assets/screenshots/battle-overlay.png)

## Features

- **Real-time IV display** - See all 6 IVs with color-coded quality indicators
- **Nature analysis** - Shows stat modifiers (+Atk/-Def, etc.)
- **Hidden Power** - Displays type and power
- **Catch criteria** - Configurable profiles to highlight Pokemon worth catching
- **Shiny detection** - Special alerts and visual effects for shinies
- **Floating overlay** - Stays on top, transparent when not in battle

![Overlay detail](assets/screenshots/overlay-detail.png)

## How It Works

PokeScan consists of two parts:
1. **Lua script** - Runs in mGBA, reads Pokemon data from memory, sends it over TCP
2. **Swift app** - Receives data, calculates IVs, displays the overlay

## Requirements

- macOS 13.0+
- [mGBA](https://mgba.io/) emulator
- Pokemon Emerald ROM (US or EU version)

## Installation

### Build and Install

```bash
git clone https://github.com/Veridiann/PokeScan.git
cd PokeScan
swift build -c release
./launcher/install-app.sh
```

This builds PokeScan and installs it to `/Applications/PokeScan.app`.

### Using Xcode

1. Open `Package.swift` in Xcode
2. Select the PokeScan scheme
3. Build and Run (Cmd+R)

### Developer Loop (AI/Automation)

For the zero-touch loop that launches mGBA + Lua + PokeScan, wires logs/ports, and validates the connection, see [AI_DEV_LOOP.md](AI_DEV_LOOP.md).

## Usage

### Quick Start (Recommended)

1. **Launch PokeScan** from Applications
2. **Settings opens automatically** on first run
3. **Configure paths:**
   - mGBA.app (auto-detected if in /Applications)
   - Pokemon Emerald ROM (use Browse button)
   - Save state slot (latest/specific/none)
4. **Click "Launch mGBA"** button
5. **Enter a wild battle** - overlay shows Pokemon data

### Context Menu

Right-click the overlay to:
- **Launch/Relaunch mGBA** - Start mGBA with your configured settings
- **Switch profiles** - Change catch criteria
- **Toggle sound alerts**
- **Open Settings** - Configure paths and preferences
- **Edit Criteria** - Customize catch rules

### Keyboard Shortcuts

- **Cmd+,** - Open Settings
- **1-9** - Quick switch catch profiles
- **Space** - Clear alert flash

### Standalone Launcher (Alternative)

If you prefer a separate launcher app:

```bash
./launcher/install.sh
```

Then edit `~/.config/pokescan/pokescan.conf` and double-click **PokeScan Launcher** in Applications.

### Manual Usage

1. **Start mGBA** with Pokemon Emerald loaded

2. **Load the Lua script** in mGBA:
   - Go to Tools → Scripting → File → Load Script
   - Select `lua/pokescan_sender.lua`

3. **Run PokeScan**:
   ```bash
   swift run
   # or run the built executable
   .build/release/PokeScan
   ```

4. **Enter a wild battle** - the overlay will display Pokemon data

### Catch Criteria

Right-click the overlay to:
- Switch between catch profiles
- Toggle sound alerts
- Edit the criteria file

Criteria are stored at `~/Library/Application Support/PokeScan/catch_criteria.json`:

```json
{
  "activeProfile": "high_ivs",
  "alwaysAlertShiny": true,
  "alertSoundEnabled": true,
  "profiles": {
    "high_ivs": {
      "name": "High IVs",
      "minIVPercent": 80,
      "notes": "Catch any Pokemon with 80%+ IVs"
    },
    "ralts": {
      "name": "Ralts Hunt",
      "species": ["Ralts"],
      "requiredNatures": ["Timid", "Modest"],
      "minIVs": {"spa": 25, "spe": 20}
    }
  }
}
```

## Project Structure

```
PokeScan/
├── lua/
│   ├── core/           # JSON encoding, socket server
│   ├── adapters/       # Game-specific memory addresses
│   └── pokescan_sender.lua
├── PokeScan/
│   ├── App/            # App entry point, window controller
│   ├── UI/             # SwiftUI views
│   ├── Models/         # Data structures
│   ├── Services/       # Socket client, criteria engine
│   └── Resources/      # Pokemon data, sprites, sounds
└── Package.swift
```

## Supported Games

Currently supports:
- Pokemon Emerald (US)
- Pokemon Emerald (EU)

Adding support for other Gen 3 games requires creating a new adapter in `lua/adapters/`.

## Credits

- Pokemon data sourced from [PokeAPI](https://pokeapi.co/)
- Sprites from the Pokemon games (Nintendo/Game Freak)
- Built with [mGBA](https://mgba.io/) Lua scripting API

## License

MIT License - see [LICENSE](LICENSE) for details.
