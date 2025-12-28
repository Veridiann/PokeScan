# PokeScan Architecture Guide

This document provides a comprehensive overview of PokeScan's architecture, components, and data flow for developers and AI agents working on the codebase.

## Overview

PokeScan is a real-time IV overlay for Pokemon Emerald running on mGBA. It consists of two main components that communicate over TCP:

1. **Lua Script** (Server) - Runs inside mGBA, reads Pokemon data from game memory
2. **Swift App** (Client) - macOS overlay that displays IV information

```
┌─────────────────┐         TCP/9876         ┌─────────────────┐
│     mGBA        │ ──────────────────────▶  │   PokeScan.app  │
│  (Lua Script)   │         JSON data        │  (Swift Overlay)│
│                 │                          │                 │
│  Reads memory   │                          │  Displays IVs   │
│  Sends Pokemon  │                          │  Catch alerts   │
│  data as JSON   │                          │  Shiny effects  │
└─────────────────┘                          └─────────────────┘
```

## Project Structure

```
PokeScan/
├── AGENTS.md                 # This file
├── README.md                 # User documentation
├── Package.swift             # Swift package manifest
├── LICENSE                   # MIT License
│
├── launcher/                 # One-click launcher system
│   ├── install.sh            # Installs PokeScan Launcher.app
│   ├── install-app.sh        # Installs PokeScan.app (overlay only)
│   ├── launcher.sh           # Main launcher script
│   └── pokescan.conf         # Config template
│
├── lua/                      # mGBA Lua scripts
│   ├── pokescan_sender.lua   # Main entry point
│   ├── core/
│   │   ├── json.lua          # JSON encoder
│   │   ├── socket_server.lua # TCP server implementation
│   │   └── socket_client.lua # TCP client (unused, for testing)
│   └── adapters/
│       └── emerald_us_eu.lua # Memory addresses for Emerald US/EU
│
├── PokeScan/                 # Swift source code
│   ├── App/
│   │   └── PokeScanApp.swift # App entry, window creation, settings
│   ├── UI/
│   │   ├── ContentView.swift # Main overlay UI
│   │   ├── OverlayWindow.swift # Transparent floating window
│   │   ├── PokemonSprite.swift # Sprite image loading
│   │   └── SettingsView.swift # Settings panel UI
│   ├── Models/
│   │   └── PokemonData.swift # Data structures, Pokedex
│   ├── Services/
│   │   ├── SocketClient.swift # TCP client to Lua server
│   │   ├── CriteriaEngine.swift # Catch criteria evaluation
│   │   ├── AlertManager.swift # Sound/visual alerts
│   │   ├── AppSettings.swift # UserDefaults preferences
│   │   └── LaunchManager.swift # mGBA launcher service
│   └── Resources/
│       ├── pokemon_data.json # Species data (names, base stats)
│       ├── growth_rates.json # EXP curves for level calc
│       ├── catch_criteria.json # Default catch profiles
│       ├── pokemon_alert.aiff # Alert sound
│       └── sprites/          # Pokemon sprite images
│           ├── r_*.png       # Regular sprites
│           └── s_*.png       # Shiny sprites
│
├── dev/                      # Development files (gitignored)
│   ├── mGBA.app              # Local mGBA copy
│   ├── emerald.gba           # ROM file
│   ├── emerald.ss*           # Save states
│   └── logs/                 # Runtime logs
│
├── dev.sh                    # Dev launcher (builds + runs)
└── test.sh                   # Automated test script
```

## Component Details

### Lua Script (`lua/`)

The Lua script runs inside mGBA's scripting environment and acts as a TCP server.

#### Entry Point: `pokescan_sender.lua`
- Loads core modules (json, socket_server)
- Loads game adapter (emerald_us_eu)
- Registers frame callback to read Pokemon data
- Sends JSON data to connected clients

#### Socket Server: `core/socket_server.lua`
- Creates TCP server on port 9876
- Uses mGBA's `socket` API
- Handles client connections/disconnections
- Serializes tables to JSON for transmission

#### Game Adapter: `adapters/emerald_us_eu.lua`
- Defines memory addresses for Pokemon Emerald US/EU
- Implements `readWildPokemon()` function
- Decrypts Pokemon data structure (PID-based XOR)
- Extracts: species, IVs, nature, ability, gender, shiny status

#### Memory Layout (Emerald)
```
Battle Pokemon addresses:
- Player: 0x02024084
- Wild/Enemy: 0x0202402C (100 bytes per Pokemon)

Pokemon data structure (encrypted):
- PID: 4 bytes (determines personality)
- OTID: 4 bytes (original trainer)
- Nickname: 10 bytes
- Data blocks: 48 bytes (4x12, order varies by PID)
  - Growth: species, item, EXP, moves
  - Attacks: move data
  - EVs/Condition: effort values
  - Misc: IVs, ability, etc.
```

### Swift App (`PokeScan/`)

The Swift app is a macOS overlay that connects to the Lua server.

#### App Entry: `PokeScanApp.swift`
- Creates floating overlay window
- Initializes services (socket, criteria, alerts)
- Sets up keyboard shortcuts (1-9 for profiles, Space to clear)

#### Overlay Window: `OverlayWindow.swift`
- `NSPanel` with borderless, transparent style
- Always-on-top floating behavior
- Movable by dragging anywhere
- `TransparentHostingView` for SwiftUI content

#### Main UI: `ContentView.swift`
- Displays Pokemon sprite, name, level, gender
- Shows all 6 IVs with color-coded quality bars
- Nature with stat modifiers (+Atk/-Def)
- Hidden Power type and power
- Ability name
- IV total percentage
- Catch verdict badge (CATCH/SKIP/SHINY)
- Animated border for catches
- Sparkle overlay for shinies
- Context menu for settings

#### Socket Client: `SocketClient.swift`
- Connects to Lua server on port 9876
- Parses JSON Pokemon data
- Publishes `currentPokemon` for UI binding
- Auto-reconnects on disconnect
- Reads port from file if available

#### Criteria Engine: `CriteriaEngine.swift`
- Loads catch criteria from JSON
- Supports multiple profiles (high_ivs, ralts_hunt, etc.)
- Evaluates Pokemon against active profile
- Criteria: min IVs, required natures, species filters

#### Alert Manager: `AlertManager.swift`
- Plays sound alerts on catch/shiny
- Visual border flash effect
- Configurable sound on/off

### Data Structures

#### Pokemon Data (from Lua)
```json
{
  "species_id": 280,
  "species_name": "Ralts",
  "pid": 2847593821,
  "level": 5,
  "nature": "Timid",
  "nature_id": 10,
  "ability": 1,
  "ability_name": "Synchronize",
  "gender": "female",
  "shiny": false,
  "ivs": {
    "hp": 25, "atk": 12, "def": 18,
    "spa": 31, "spd": 28, "spe": 30
  },
  "hp_type": "Electric",
  "hp_power": 58
}
```

#### Catch Criteria Profile
```json
{
  "name": "Ralts Hunt",
  "species": ["Ralts"],
  "requiredNatures": ["Timid", "Modest"],
  "minIVs": { "spa": 25, "spe": 20 },
  "minIVPercent": 70
}
```

## Launcher System

### Integrated Launcher (Recommended)

PokeScan has a built-in launcher accessible via the Settings panel. This is the recommended approach.

#### First Launch
1. Run PokeScan.app
2. Settings window opens automatically (if not configured)
3. Set mGBA.app path (auto-detected if in /Applications)
4. Set ROM path using file picker
5. Configure save state slot (latest/specific/none)
6. Click "Launch mGBA" button

#### Settings (`~/Library/Preferences` via UserDefaults)
- `mgbaPath` - Path to mGBA.app
- `romPath` - Path to Pokemon Emerald ROM
- `saveSlot` - Save state slot (latest, 0-9, none)
- `autoLaunch` - Auto-launch mGBA on app start
- `luaScriptPath` - Custom Lua script path (optional)
- `useCustomLuaScript` - Use custom script instead of bundled

#### Access Settings
- Right-click overlay → "Settings..."
- Keyboard: Cmd+,

#### Launch from Overlay
- Right-click overlay → "Launch mGBA" / "Relaunch mGBA"

### Standalone Launcher (Alternative)

For users who prefer a separate launcher app.

#### Install Process
1. Run `./launcher/install.sh`
2. Creates `~/.config/pokescan/pokescan.conf`
3. Installs `PokeScan Launcher.app` to /Applications

#### Configuration (`~/.config/pokescan/pokescan.conf`)
```bash
ROM_PATH="$HOME/Game/GBA/Pokemon/Emerald/Pokemon - Emerald.gba"
SAVE_SLOT="latest"  # or 0-9, or "none"
MGBA_APP=""         # auto-detects if empty
POKESCAN_DIR=""     # uses install path if empty
```

### Apps

| App | Location | Purpose |
|-----|----------|---------|
| PokeScan | /Applications | Main app with integrated launcher |
| PokeScan Launcher | /Applications | Standalone launcher (optional) |

## Communication Protocol

### TCP Connection
- Port: 9876 (configurable)
- Server: Lua script in mGBA
- Client: Swift overlay app

### Message Format
- JSON objects, newline-delimited
- Sent on: new Pokemon encounter, Pokemon change, client connect
- Clear message: `{"clear": true}` when battle ends

### Connection Flow
1. Lua script starts, creates server socket
2. Writes port to `dev/logs/port` file
3. Swift app reads port file (or uses default 9876)
4. Swift connects as TCP client
5. Lua detects connection, sends current Pokemon data
6. On each frame, Lua checks for new Pokemon, sends updates

## Development Workflow

### Quick Start
```bash
./dev.sh  # Builds Swift app, launches mGBA + overlay
```

### Manual Testing
```bash
# Terminal 1: Build and run Swift app
swift run

# Terminal 2: Launch mGBA with script
/Applications/mGBA.app/Contents/MacOS/mGBA \
  ~/Game/Pokemon/Emerald.gba \
  --script lua/pokescan_sender.lua
```

### Adding a New Game Adapter

1. Create `lua/adapters/newgame.lua`
2. Define memory addresses for that game
3. Implement `readWildPokemon()` function
4. Load it in `pokescan_sender.lua`

### Modifying the Overlay UI

1. Edit `PokeScan/UI/ContentView.swift`
2. Run `swift build -c release`
3. Run `./launcher/install-app.sh` to update installed app

## Key Implementation Notes

### IV Calculation
IVs are stored in a packed 32-bit value in the Pokemon data structure:
```
Bits 0-4:   HP IV (0-31)
Bits 5-9:   Attack IV
Bits 10-14: Defense IV
Bits 15-19: Speed IV
Bits 20-24: Sp. Attack IV
Bits 25-29: Sp. Defense IV
```

### Shiny Determination
A Pokemon is shiny if: `(PID ^ OTID) < 8`
Where OTID is the original trainer's ID.

### Nature Calculation
`Nature = PID % 25`
Natures modify stats by +10%/-10%.

### Hidden Power
Type and power are calculated from IV least significant bits.

### Data Encryption (Gen 3)
Pokemon data blocks are XOR encrypted with a key derived from PID ^ OTID.
Block order also varies based on PID % 24.

## Troubleshooting

### Overlay Not Showing
- Check window opacity (was 0.0 when disconnected, now 0.3)
- Verify PokeScan process is running

### Script Not Loading
- Check path in launcher: should be full path to lua/pokescan_sender.lua
- Verify POKESCAN_DIR is not empty in config

### Connection Refused
- mGBA must be running with script loaded first
- Check mGBA's Tools → Scripting console for errors
- Verify port 9876 is not in use

### Wrong Pokemon Data
- Ensure correct game adapter is loaded
- Check memory addresses match your ROM version
