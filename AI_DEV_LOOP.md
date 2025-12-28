# PokeScan AI Dev Loop (mGBA + Lua + Swift)

This repo already contains a zero-touch loop for agents to launch the emulator, run the Lua server, start the Swift overlay, and verify the connection/data flow. The loop is implemented by `dev.sh` and `test.sh` plus the `dev/` fixtures.

## What the loop does

`dev.sh` is the one-click launcher used for fast iteration:

1. Kills any running `mGBA` or `PokeScan` processes.
2. Clears logs in `dev/logs/`.
3. Builds the Swift app with `swift build --product PokeScan`.
4. Launches mGBA with a ROM, Lua script, and save state.
5. Waits for the Lua server to write `dev/logs/port`.
6. Launches the Swift app, pointing it at the port file.
7. Writes logs to `dev/logs/lua.log` and `dev/logs/swift.log`.

`test.sh` runs the full loop and asserts that:
- mGBA is running
- PokeScan is running
- The socket connects (looks for `CONNECTED to mGBA` in the Swift log)
- Pokemon data is flowing (looks for `Pokemon:` log entries)

## One-time setup (local machine)

These items live in `dev/` and are intentionally gitignored, but required for the loop:

- `dev/mGBA.app` (the emulator)
- `dev/emerald.gba` (ROM)
- `dev/emerald.ss0` (battle save state used for testing)

The launcher expects exactly these paths. If you keep them elsewhere, symlink or copy into `dev/`.

Save state details are documented in `dev/SAVE_STATES.md`.

## Quick start (agent-friendly)

Run the full loop:

```bash
./dev.sh
```

Run a full loop with automated checks:

```bash
./test.sh
```

Watch logs (useful for agent feedback):

```bash
tail -f dev/logs/lua.log
```

```bash
tail -f dev/logs/swift.log
```

Expected log lines:
- Lua: `PokeScan: Server listening on port ...`
- Swift: `PokeScan: CONNECTED to mGBA`
- Swift: `PokeScan: Pokemon: ...`

## How the wiring works

- `lua/core/socket_server.lua` writes the chosen port to `dev/logs/port`.
- `PokeScan/Services/SocketClient.swift` reads the port file via:
  - `POKESCAN_PORT_FILE` env var (preferred), or
  - `./dev/logs/port` relative to the current directory.
- `dev.sh` sets:
  - `POKESCAN_LOG=dev/logs/swift.log`
  - `POKESCAN_PORT_FILE=dev/logs/port`

## Typical agent iteration loop

1. Edit Swift or Lua code.
2. Run `./dev.sh` (or `./test.sh` if you want validation).
3. Check logs for connection and data flow.
4. Repeat.

`dev.sh` is safe to rerun; it will kill the old processes before starting a new session.

## Optional: Run from Xcode

If you want to debug the Swift app in Xcode:

1. Open `Package.swift` in Xcode.
2. Ensure the working directory is the repo root.
3. Add environment variables to the scheme:
   - `POKESCAN_PORT_FILE=dev/logs/port`
   - `POKESCAN_LOG=dev/logs/swift.log`
4. Run `./dev.sh` (or launch mGBA manually) so the Lua server is running.

## Troubleshooting

- No `dev/logs/port` file:
  - The Lua server did not start. Check `dev/logs/lua.log`.
- `Connection refused` in Swift logs:
  - mGBA not running or Lua script not loaded.
- No `Pokemon:` lines:
  - Save state may not be in a battle. Update `dev/emerald.ss0`.
- Socket API errors:
  - Ensure mGBA has sockets enabled (use `lua/test_socket.lua` for a quick check).

## Files involved

- Launcher: `dev.sh`
- Automated checks: `test.sh`
- Lua server: `lua/pokescan_sender.lua`, `lua/core/socket_server.lua`
- Swift client: `PokeScan/Services/SocketClient.swift`
- Dev fixtures/logs: `dev/` and `dev/logs/`
