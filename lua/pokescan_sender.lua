-- PokeScan sender entrypoint for mGBA Lua
-- mGBA acts as TCP SERVER, Swift overlay connects as CLIENT

local function script_dir()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == '@' then
    source = source:sub(2)
  end
  return source:match("(.*/)") or "./"
end

local root = script_dir()

local json = dofile(root .. "core/json.lua")
local SocketServer = dofile(root .. "core/socket_server.lua")

dofile(root .. "adapters/emerald_us_eu.lua")

local server = SocketServer.new({
  port = 9876,
  json = json
})

local lastPID = 0
local lastHadPokemon = false
local lastSendFrame = 0
local MIN_SEND_INTERVAL = 10  -- Minimum frames between sends (prevents fast-forward flooding)
local DEBUG = false

-- Test mode: force shiny and/or perfect IVs for UI testing
local TEST_SHINY = false
local TEST_PERFECT_IVS = false

local function log(msg)
  if console and console.log then
    console:log(msg)
  else
    print(msg)
  end
end

local frameCount = 0

local function onFrame()
  frameCount = frameCount + 1
  server:tick()

  if not readWildPokemon then
    return
  end

  local data = readWildPokemon()
  if not data then
    -- Send clear message if we previously had a Pokemon
    if lastHadPokemon then
      -- Throttle clear messages too
      if frameCount - lastSendFrame >= MIN_SEND_INTERVAL then
        server:sendTable({ clear = true })
        lastSendFrame = frameCount
      end
      lastHadPokemon = false
      lastPID = 0
    end
    return
  end
  lastHadPokemon = true

  -- Apply test mode overrides
  if TEST_SHINY then
    data.shiny = true
  end
  if TEST_PERFECT_IVS then
    data.ivs = { hp = 31, atk = 31, def = 31, spa = 31, spd = 31, spe = 31 }
  end

  -- Check if client just connected - if so, always send current data
  local forceResend = server:didJustConnect()

  -- Skip if same Pokemon and not forcing resend
  if not forceResend and data.pid and data.pid == lastPID then
    return
  end

  -- Throttle sends to prevent fast-forward flooding
  if not forceResend and (frameCount - lastSendFrame) < MIN_SEND_INTERVAL then
    return
  end

  if DEBUG then
    log(string.format(
      "PokeScan: PID=%08X species=%d shiny=%s%s",
      data.pid or 0,
      data.species_id or 0,
      tostring(data.shiny),
      forceResend and " (resend)" or ""
    ))
  end

  lastPID = data.pid or lastPID
  lastSendFrame = frameCount
  server:sendTable(data)
end

if callbacks and callbacks.add then
  callbacks:add("frame", onFrame)
else
  console:log("PokeScan: callbacks API not available")
end

console:log("PokeScan: sender loaded - waiting for overlay connection on port 9876")
