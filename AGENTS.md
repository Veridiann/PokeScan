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
├── AGENTS.md                 # This file - architecture documentation
├── README.md                 # User documentation
├── Package.swift             # Swift package manifest (macOS 13.0+)
├── LICENSE                   # MIT License
│
├── .codex/                   # Codex skill config + references
├── .claude/                  # Legacy assistant config
│
├── launcher/                 # One-click launcher system
│   ├── install.sh            # Installs PokeScan Launcher.app
│   ├── install-app.sh        # Installs PokeScan.app (overlay only)
│   ├── launcher.sh           # Main launcher script
│   └── pokescan.conf         # Config template
│
├── lua/                      # mGBA Lua scripts (server-side)
│   ├── pokescan_sender.lua   # Main entry point (~117 lines)
│   ├── core/
│   │   ├── json.lua          # Pure Lua JSON encoder (~68 lines)
│   │   └── socket_server.lua # TCP server implementation (~202 lines)
│   └── adapters/
│       └── emerald_us_eu.lua # Pokemon Emerald memory addresses (~200 lines)
│
├── PokeScan/                 # Swift source code (client-side)
│   ├── App/
│   │   └── PokeScanApp.swift # App entry, window management (~141 lines)
│   ├── UI/
│   │   ├── ContentView.swift # Main overlay UI (~703 lines)
│   │   ├── OverlayWindow.swift # Floating window (~84 lines)
│   │   ├── PokemonSprite.swift # Sprite loading (~66 lines)
│   │   └── SettingsView.swift # Settings panel UI (~200+ lines)
│   ├── Models/
│   │   └── PokemonData.swift # Data structures, Pokedex (~139 lines)
│   ├── Adapters/
│   │   └── GameAdapter.swift # Game adapter protocol (~84 lines)
│   ├── Services/
│   │   ├── SocketClient.swift # TCP client (~238 lines)
│   │   ├── CriteriaEngine.swift # Catch criteria evaluation (~188 lines)
│   │   ├── AlertManager.swift # Sound/visual alerts (~47 lines)
│   │   ├── AppSettings.swift # UserDefaults preferences (~223 lines)
│   │   └── LaunchManager.swift # mGBA launcher service (~130 lines)
│   └── Resources/
│       ├── pokemon_data.json # Species data - 386 Pokemon (~7,741 lines)
│       ├── growth_rates.json # EXP curves for level calculation
│       ├── catch_criteria.json # Default catch profiles (~43 lines)
│       ├── pokemon_alert.aiff # Alert sound (~19.5 KB)
│       └── sprites/          # Pokemon sprite images
│           ├── regular/      # r_1.png through r_386.png
│           └── shiny/        # s_1.png through s_386.png
│
├── dev/                      # Development files (gitignored)
│   ├── logs/                 # Runtime logs
│   │   ├── lua.log           # Lua script output
│   │   └── port              # Port file for client discovery
│   └── SAVE_STATES.md        # Save state documentation
│
├── dev.sh                    # Dev launcher (builds + runs)
└── test.sh                   # Automated test script
```


## Component Details

### Lua Script (`lua/`)

The Lua script runs inside mGBA's scripting environment and acts as a TCP server.

#### Entry Point: `pokescan_sender.lua`

Main orchestrator that:
- Loads core modules (json, socket_server)
- Loads game adapter (emerald_us_eu)
- Registers frame callback via `callbacks:add("frame", onFrame)`
- Implements throttling to prevent fast-forward flooding
- Tracks state transitions (entering/leaving battle)
- Sends JSON data to connected clients

**Key Variables:**
```lua
local lastPID = 0              -- Last Pokemon PID (detect changes)
local lastHadPokemon = false   -- Track battle state transitions
local lastSendAt = 0           -- Last send time (seconds)
local MIN_SEND_INTERVAL = 0.25 -- Min seconds between sends
local pending = nil            -- Coalesced payload
local TEST_SHINY = false       -- Force shiny for UI testing
local TEST_PERFECT_IVS = false -- Force perfect IVs for testing
```


**State Machine:**
- `lastHadPokemon = false` → `true`: Entering battle (bypasses throttle)
- `lastHadPokemon = true` → `false`: Leaving battle (sends clear)
- Same Pokemon (same PID): Skip sending
- Different Pokemon: Send update

#### Socket Server: `core/socket_server.lua`

TCP server using mGBA's socket API:
- Binds to port 9876 (auto-increments on conflict, up to 10 retries)
- Single client connection model
- Writes port to `dev/logs/port` for client discovery
- Uses callbacks for async connection handling

**Key Methods:**
```lua
SocketServer:start()           -- Bind and listen
SocketServer:tick()            -- Poll for events (call each frame)
SocketServer:sendTable(tbl)    -- Encode and send JSON
SocketServer:isConnected()     -- Check client status
SocketServer:didJustConnect()  -- One-shot flag for resend
```

**Connection Handling:**
- `server:add("received", cb)` - Fires when client connects (on listening socket)
- `client:add("error", cb)` - Clears client reference on disconnect
- `client:poll()` - Processes pending events

#### Game Adapter: `adapters/emerald_us_eu.lua`

Memory addresses and decryption for Pokemon Emerald US/EU:

**Memory Addresses:**
```lua
local enemyAddr = 0x2024744    -- Wild Pokemon data (100 bytes)
local wildTypeAddr = 0x20240FD -- Battle type: 0=none, 1=wild, 2+=trainer
local gMainAddr = 0x30022C0    -- Main struct (US/EU)
local gMainInBattleAddr = gMainAddr + 0x439 -- inBattle bit (0x2)
```


**Lookup Tables:**
- 25 nature names (Hardy through Quirky)
- 16 Hidden Power types (Fighting through Dark)
- 386 species names (National Dex)
- 386 gender ratios

**Core Functions:**
```lua
getOffset(pid)           -- Calculate block offset (Gen 3 data scrambling)
getIVs(ivWord)           -- Unpack 32-bit IV value into 6 stats
getHPTypeAndPower(ivs)   -- Calculate Hidden Power type/power
shinyCheck(pid, otid)    -- Determine shiny status (square vs star)
getGender(pid, species)  -- Determine gender from PID and ratio
readWildPokemon()        -- Main function: returns Pokemon table or nil
inBattle()               -- Uses gMain.inBattle when available
```

**Data Structure (returned):**
```lua
{
  type = "wild",
  game = "emerald_us_eu",
  pid = 0x12345678,
  species_id = 280,          -- National Dex number
  species_index = 280,       -- Same as species_id for Gen 3
  exp = 125,                 -- Raw EXP value
  nature = "Timid",
  ability_slot = 0,          -- 0 or 1
  gender = "female",         -- "male", "female", "genderless"
  ivs = { hp=25, atk=12, def=18, spa=31, spd=28, spe=30 },
  hp_type = "Electric",
  hp_power = 58,
  shiny = false,
  shiny_type = nil           -- "square" or "star" if shiny
}
```

### Swift App (`PokeScan/`)

The Swift app is a macOS overlay that connects to the Lua server.

#### App Entry: `PokeScanApp.swift`

SwiftUI application with:
- `@main` entry point
- `NSApplicationDelegate` for window management
- Window creation with `OverlayWindow`
- Settings observer for first-launch detection
- Keyboard shortcuts (global)

**Keyboard Shortcuts:**
| Key | Action |
|-----|--------|
| 1-9 | Switch catch criteria profile |
| Cmd+, | Open Settings panel |
| Space | Clear current Pokemon display |

**Auto-Launch Logic:**
```swift
// On app start, if autoLaunch enabled and mGBA not running:
if settings.autoLaunch && !launchManager.mgbaRunning {
    launchManager.launchMGBA(settings: settings, socket: socket)
}
```

#### Overlay Window: `OverlayWindow.swift`

Custom `NSPanel` subclass:
- Style: borderless, titled (for drag), non-activating
- Collection behavior: can join all spaces, full screen auxiliary
- Level: `.floating` (always on top)
- Background: transparent (handled by SwiftUI)

**Key Features:**
- `canBecomeKey = true` for keyboard events
- `isMovableByWindowBackground = true` for dragging
- `TransparentHostingView` wraps SwiftUI content

#### Main UI: `ContentView.swift`

SwiftUI view (~700 lines) with:

**Layout Sections:**
1. Header: Sprite, name, level, gender
2. IV Grid: 6 IVs with color-coded bars
3. Stats: Nature, ability, Hidden Power
4. Footer: IV total percentage, catch verdict

**Visual Effects:**
- Color-coded IV bars (red → yellow → green → blue)
- Nature stat modifiers (+Atk/-Def notation)
- Animated border pulse on catch alert
- Sparkle overlay for shiny Pokemon
- Dynamic opacity based on connection state

**Opacity States:**
| State | Default Opacity |
|-------|-----------------|
| Disconnected | 50% |
| Connected, idle (no Pokemon) | 0% (invisible) |
| Connected, in battle | 100% |
| Hovering | 100% |

**Context Menu:**
- Settings...
- Launch mGBA / Relaunch mGBA
- Quit

#### Socket Client: `SocketClient.swift`

TCP client using Network.framework:

**Published State:**
```swift
@Published var currentPokemon: PokemonData?
@Published var connectionState: ConnectionState  // .disconnected/.connecting/.connected
```

**Throttling (Fast-Forward Protection):**
```swift
private var lastMessageTime: Date = .distantPast
private let minMessageInterval: TimeInterval = 0.5  // Max 2 updates/second
private let maxBufferSize = 65536  // 64KB buffer limit
```

**Connection Lifecycle:**
1. `start()` - Begin connection attempts
2. `connect()` - Create NWConnection to host:port
3. `.ready` state - Cancel pending reconnect, start receiving
4. `receiveData()` - Async receive loop
5. `processBuffer()` - Parse newline-delimited JSON
6. `decodeMessage()` - Decode and throttle messages
7. On disconnect - Schedule reconnect (2 second delay)

**Port Discovery:**
```swift
// Priority: environment variable → port file → default 9876
let portFilePath = ProcessInfo.processInfo.environment["POKESCAN_PORT_FILE"]
    ?? (FileManager.default.currentDirectoryPath + "/dev/logs/port")
```

#### Criteria Engine: `CriteriaEngine.swift`

Catch criteria evaluation:

**Profile Structure:**
```swift
struct CatchProfile {
    var name: String
    var species: [String]?           // Species filter (optional)
    var requiredNatures: [String]?   // Required natures (optional)
    var minIVs: [String: Int]?       // Min IVs per stat
    var minIVTotal: Int?             // Min IV sum (0-186)
    var minIVPercent: Int?           // Min IV % (0-100)
}
```

**Verdicts:**
- `CATCH` - Meets all criteria
- `SKIP` - Does not meet criteria
- `SHINY` - Shiny Pokemon (always alerts if enabled)

**Persistence:**
- Location: `~/Library/Application Support/PokeScan/catch_criteria.json`
- Bundled default fallback
- Active profile switching with keyboard shortcuts

#### Alert Manager: `AlertManager.swift`

Audio and visual alerts:
```swift
func playSound()    // Play pokemon_alert.aiff
func flash()        // Yellow border, 5 autoreverses, 1.5 seconds
func clearFlash()   // Reset border color
```

#### App Settings: `AppSettings.swift`

UserDefaults wrapper:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `mgbaPath` | String | auto-detect | Path to mGBA.app |
| `romPath` | String | "" | Path to Pokemon ROM |
| `saveSlot` | String | "none" | Save state: "latest", "0"-"9", "none" |
| `autoLaunch` | Bool | false | Launch mGBA on app start |
| `luaScriptPath` | String | "" | Custom Lua script path |
| `useCustomLuaScript` | Bool | false | Use custom vs bundled |
| `disconnectedOpacity` | Double | 0.5 | Opacity when disconnected |
| `connectedIdleOpacity` | Double | 0.0 | Opacity when idle |

**mGBA Auto-Detection:**
```swift
// Checks in order:
// 1. /Applications/mGBA.app
// 2. ~/Applications/mGBA.app
// 3. /opt/homebrew/bin/mgba-qt
// 4. /usr/local/bin/mgba-qt
```

#### Launch Manager: `LaunchManager.swift`

mGBA process management:

**Published State:**
```swift
@Published var mgbaRunning: Bool
@Published var isLaunching: Bool
@Published var lastError: String?
```

**Launch Process:**
1. Kill existing mGBA instances
2. Build command line arguments:
   - ROM path
   - `--script <lua_path>`
   - `-t <state>` for save state (if configured)
3. Launch via `Process`
4. Monitor running status (2-second poll)

### Game Adapters (`Adapters/`)

Protocol-based abstraction for multi-game support:

```swift
protocol GameAdapter {
    func normalize(_ raw: RawPokemonPayload, dex: PokemonDex) -> PokemonData?
}

class GameAdapterRegistry {
    func normalize(_ raw: RawPokemonPayload, dex: PokemonDex) -> PokemonData?
}
```

Currently registered: `emerald_us_eu`

## Data Structures

### Pokemon Data (JSON Wire Format)

Sent from Lua to Swift:
```json
{
  "type": "wild",
  "game": "emerald_us_eu",
  "pid": 2847593821,
  "species_id": 280,
  "species_index": 280,
  "exp": 125,
  "nature": "Timid",
  "ability_slot": 0,
  "gender": "female",
  "shiny": false,
  "shiny_type": null,
  "ivs": {
    "hp": 25, "atk": 12, "def": 18,
    "spa": 31, "spd": 28, "spe": 30
  },
  "hp_type": "Electric",
  "hp_power": 58
}
```

### Clear Message

Sent when leaving battle:
```json
{"clear": true}
```

### Catch Criteria Profile

```json
{
  "name": "Ralts Hunt",
  "species": ["Ralts"],
  "requiredNatures": ["Timid", "Modest"],
  "minIVs": { "spa": 25, "spe": 20 },
  "minIVPercent": 70
}
```

### Species Data (pokemon_data.json)

```json
{
  "id": 280,
  "name": "Ralts",
  "types": ["Psychic", "Fairy"],
  "baseStats": {
    "hp": 28, "atk": 25, "def": 25,
    "spa": 45, "spd": 35, "spe": 40
  },
  "abilities": ["Synchronize", "Trace"],
  "growthRateId": 4
}
```

## Communication Protocol

### TCP Connection

| Property | Value |
|----------|-------|
| Port | 9876 (auto-increments on conflict) |
| Server | Lua script in mGBA |
| Client | Swift overlay app |
| Format | Newline-delimited JSON |

### Message Flow

```
┌─────────┐                              ┌─────────┐
│  Lua    │                              │  Swift  │
└────┬────┘                              └────┬────┘
     │                                        │
     │◄─────── TCP Connect ──────────────────┤
     │                                        │
     │──── {"type":"wild",...} ──────────►│  (on battle start)
     │                                        │
     │──── {"type":"wild",...} ──────────►│  (on Pokemon change)
     │                                        │
     │──── {"clear":true} ──────────────────►│  (on battle end)
     │                                        │
     │◄─────── TCP Disconnect ───────────────┤
     │                                        │
```

### Connection Lifecycle

1. Lua script starts, binds to port 9876
2. Writes port to `dev/logs/port`
3. Swift reads port file (or uses default)
4. Swift connects as TCP client
5. Lua sets `justConnected = true`, sends current data
6. Each frame: Lua checks for new Pokemon, sends updates if changed
7. On disconnect: Swift schedules reconnect (2s delay)
8. Lua detects new connection, replaces old client

## Performance Optimizations

### Throttling (Dual-Layer)

**Layer 1: Lua (Time-Based + Coalescing)**
```lua
local MIN_SEND_INTERVAL = 0.25  -- Minimum seconds between sends
if not pending.clear and (now - lastSendAt) < MIN_SEND_INTERVAL then
    return
end
```

**Layer 2: Swift (Time-Based)**
```swift
private let minMessageInterval: TimeInterval = 0.5  // Max 2 updates/second
if now.timeIntervalSince(lastMessageTime) < minMessageInterval {
    return  // Skip this message
}
```

### Throttle Bypass Conditions

Throttling is bypassed for:
1. **Battle entry** - Transition from no Pokemon to has Pokemon
2. **Client just connected** - Ensure client has current state
3. **Clear messages** - Always send battle end immediately

### Buffer Protection

```swift
private let maxBufferSize = 65536  // 64KB max buffer
if self.buffer.count > self.maxBufferSize {
    log("PokeScan: Buffer overflow, clearing")
    self.buffer = Data()
}
```

### Change Detection

```lua
-- Skip if same Pokemon (by PID)
if not forceResend and data.pid and data.pid == lastPID then
    return
end
```

## Memory Layout (Pokemon Emerald)

### Battle Addresses

| Address | Description |
|---------|-------------|
| 0x02024744 | Wild/Enemy Pokemon (100 bytes) |
| 0x020240FD | Battle type flag |
| 0x030022C0 | gMain (US/EU) |
| 0x03002360 | gMain (JPN) |



**Battle State Signal (Emerald):**
- Prefer `gMain.inBattle` (bit 0x2 at `gMain + 0x439`). This is robust during fast-forward and avoids overworld false positives.
- Use `wildTypeAddr` and ad-hoc flags only as fallback signals.

**Battle Type Values:**
| Value | Meaning |
|-------|---------|
| 0 | Not in battle |
| 1 | Wild encounter |
| 2+ | Trainer battle |

### Pokemon Data Structure (Encrypted)

```
Offset  Size  Description
0x00    4     PID (Personality ID)
0x04    4     OTID (Original Trainer ID)
0x08    10    Nickname
0x12    2     Language
0x14    8     OT Name
0x1C    1     Markings
0x1D    1     Checksum (lower byte)
0x1E    2     Checksum
0x20    48    Data blocks (4x12 bytes, encrypted)
```

### Data Blocks (Decrypted)

Block order determined by `PID % 24`:

| Block | Contents |
|-------|----------|
| Growth | Species, item, EXP, friendship, moves |
| Attacks | PP, move data |
| EVs | Effort values, contest stats |
| Misc | Pokerus, met location, IVs, ability, ribbons |

### IV Bit Layout (32-bit word)

```
Bits 0-4:   HP IV (0-31)
Bits 5-9:   Attack IV
Bits 10-14: Defense IV
Bits 15-19: Speed IV
Bits 20-24: Sp. Attack IV
Bits 25-29: Sp. Defense IV
Bits 30-31: Unused
```

### Encryption

- Key: `PID XOR OTID`
- Each 4-byte word in data blocks XORed with key
- Block order permuted based on `PID % 24`

## Key Calculations

### Shiny Determination

```lua
local p1 = bit.band(pid, 0xFFFF)
local p2 = bit.rshift(pid, 16)
local t1 = bit.band(otid, 0xFFFF)
local t2 = bit.rshift(otid, 16)
local shinyValue = bit.bxor(bit.bxor(p1, p2), bit.bxor(t1, t2))

if shinyValue < 8 then
    return true, (shinyValue == 0) and "square" or "star"
end
```

### Nature Calculation

```lua
local nature = pid % 25
-- Natures: Hardy, Lonely, Brave, Adamant, Naughty, Bold, Docile, ...
```

### Hidden Power

```lua
-- Type (0-15): Based on IV least significant bits
local typeNum = math.floor(
    ((hp%2) + (atk%2)*2 + (def%2)*4 + (spe%2)*8 + (spa%2)*16 + (spd%2)*32) * 15 / 63
)

-- Power (30-70): Based on IV second-least significant bits
local power = math.floor(
    ((hp%4>=2 and 1 or 0) + ...) * 40 / 63 + 30
)
```

## Development Workflow

For the automated AI iteration loop (launcher, logs, and validation), see `AI_DEV_LOOP.md`.

### Quick Start

```bash
# Build and run (development)
./dev.sh

# Or manually:
swift build -c release
swift run
```

### Manual Testing

```bash
# Terminal 1: Run Swift app
POKESCAN_LOG=/tmp/pokescan.log swift run

# Terminal 2: Launch mGBA with script
/Applications/mGBA.app/Contents/MacOS/mGBA \
  ~/Game/Pokemon/Emerald.gba \
  --script lua/pokescan_sender.lua
```

### Viewing Logs

```bash
# Swift client log
tail -f /tmp/pokescan.log

# Lua server log
tail -f dev/logs/lua.log
```

### Debugging & Lessons Learned

- **Battle detection**: `wildTypeAddr` can be stale and false-positive on overworld tiles. Use `gMain.inBattle` when available.
- **Fast-forward stability**: real-time throttling plus coalescing prevents backlog and keeps UI state consistent at high emu speeds.
- **Lua debug mode**: create `dev/logs/debug` to enable richer battle state logging to `dev/logs/lua_sender.log`.
- **State scanning**: create `dev/logs/scan` to compare `dev/emerald.ss1` (out of battle) vs `dev/emerald.ss2` (in battle) for candidate flags.
- **Reference materials**: large reference bundles live outside the repo in the workspace:
  - `../Reference Projects/PokeLua`
  - `../gba_refs_md`


### Building for Release

```bash
# Build release binary
swift build -c release

# Install to /Applications
./launcher/install-app.sh
```

### Code Signing (macOS)

After installation, sign the app:
```bash
xattr -cr /Applications/PokeScan.app
codesign --force --deep --sign - /Applications/PokeScan.app
```

### Adding a New Game Adapter

1. Create `lua/adapters/newgame.lua`:
```lua
local enemyAddr = 0x????????
local wildTypeAddr = 0x????????

function readWildPokemon()
    -- Check if in battle
    local battleType = emu:read8(wildTypeAddr)
    if battleType == 0 then return nil end

    -- Read and decrypt Pokemon data
    -- Return table with species_id, ivs, nature, etc.
end
```

2. Load in `pokescan_sender.lua`:
```lua
dofile(root .. "adapters/newgame.lua")
```

3. Register in Swift `GameAdapterRegistry`:
```swift
adapters["newgame"] = DefaultAdapter()
```

## Troubleshooting

### Connection Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| "Connection refused" | mGBA not running or script not loaded | Launch mGBA, load script via Tools → Scripting |
| "Waiting" then disconnect | Port conflict or firewall | Check port 9876, try different port |
| Cycling connect/disconnect | Stale reconnect task | Fixed in code - cancel reconnect on successful connect |
| "Buffer overflow" | Fast-forward flooding | Normal - buffer auto-clears |

### Display Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| Overlay invisible | Opacity set to 0% | Check Settings, hover to reveal |
| Wrong Pokemon shown | Stale memory data | Fixed - battle type check added |
| No shiny sparkles | Not actually shiny | Check shiny calculation |
| IVs all zero | Reading wrong address | Check game adapter memory addresses |

### Script Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| "callbacks API not available" | Wrong mGBA version | Use mGBA 0.10.x stable |
| "socket.bind failed" | Port in use | Script auto-retries, or restart mGBA |
| No log output | Log file not writable | Check dev/logs/ directory exists |

### Build Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| "Code Signature Invalid" | Unsigned after install | Run `codesign --force --deep --sign -` |
| Missing sprites | Resources not bundled | Check Package.swift resources |
| "Cannot find module" | Swift build cache | Run `swift package clean` |

## File Summary

| Category | Count | Description |
|----------|-------|-------------|
| Swift source | 13 files | ~2,200 lines |
| Lua scripts | 4 files | ~587 lines |
| JSON data | 3 files | ~7,800 lines |
| Sprites | 772 images | 386 regular + 386 shiny |
| Shell scripts | 5 files | Launcher and dev tools |
| Documentation | 3 files | README.md, AGENTS.md, AI_DEV_LOOP.md |

## License

MIT License - See LICENSE file.
