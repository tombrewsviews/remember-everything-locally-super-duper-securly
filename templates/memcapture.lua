-- Memory Capture Module for Hammerspoon
-- Provides global hotkeys for quick text, screenshot, and audio capture.
-- SYSTEM_NAME is replaced by install.sh via sed.

local M = {}

-- ── Module State ──────────────────────────────────────────
local isRecording = false
local recordingIndicator = nil  -- hs.menubar during audio recording
local recordingCanvas = nil     -- floating "Recording..." overlay
local textChooser = nil         -- hs.chooser for text input

-- ── Paths ────────────────────────────────────────────────
local HOME = os.getenv("HOME")
local SYS_DIR = HOME .. "/.SYSTEM_NAME/.sys"
local LOG_FILE = HOME .. "/.SYSTEM_NAME/.sys/capture.log"
local CAPTURE_TEXT = SYS_DIR .. "/capture-text.sh"
local CAPTURE_SCREEN = SYS_DIR .. "/capture-screen.sh"
local CAPTURE_AUDIO = SYS_DIR .. "/capture-audio.sh"

-- ── Stealth: Hide Dock Icon ───────────────────────────────
hs.dockicon.hide()

-- ── Logging ──────────────────────────────────────────────

--- Log to both Hammerspoon console AND a persistent log file for debugging.
local function log(msg)
  local ts = os.date("%H:%M:%S")
  local line = string.format("[%s] %s", ts, msg)
  hs.printf("[memcapture] %s", line)
  -- Append to log file (create if needed)
  local f = io.open(LOG_FILE, "a")
  if f then
    f:write(os.date("%Y-%m-%d ") .. line .. "\n")
    f:close()
  end
end

--- Show a brief on-screen alert (dark rounded overlay, center of screen).
-- hs.alert always works — no notification permission needed.
local function notify(title)
  hs.alert.show(title, 2)
  log("NOTIFY: " .. title)
end

local function screenshotFailureHint()
  return "Check Screen Recording permission for Hammerspoon in System Settings."
end

local function fileExistsAndNotEmpty(path)
  local f = io.open(path, "rb")
  if not f then return false, 0 end
  local size = f:seek("end") or 0
  f:close()
  return size > 0, size
end

-- ── Shell Environment ────────────────────────────────────

--- Full PATH that includes Homebrew. hs.task runs with a minimal PATH
--- that doesn't include /opt/homebrew/bin, so sox/whisper-cli/curl won't be found.
local function shellPath()
  return "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
end

--- Run a shell script asynchronously via /bin/bash with proper PATH.
local function runScript(script, args, callback)
  log("RUN: " .. script .. " " .. table.concat(args, " "))

  -- Build shell-safe argument string
  local shellArgs = {}
  for _, a in ipairs(args) do
    local escaped = a:gsub("'", "'\\''")
    table.insert(shellArgs, "'" .. escaped .. "'")
  end

  local cmd = "export PATH='" .. shellPath() .. "'; "
             .. "'" .. script .. "' " .. table.concat(shellArgs, " ")

  local task = hs.task.new("/bin/bash", function(exitCode, stdout, stderr)
    log("DONE: " .. script .. " → exit " .. tostring(exitCode))
    if stdout and stdout ~= "" then
      log("  stdout: " .. stdout:gsub("\n+$", ""))
    end
    if stderr and stderr ~= "" then
      log("  stderr: " .. stderr:gsub("\n+$", ""))
    end
    if callback then callback(exitCode, stdout, stderr) end
  end, { "-c", cmd })

  local ok = task:start()
  if not ok then
    log("ERROR: Failed to start: " .. script)
    notify("Capture error — script failed")
  end
end

-- ══════════════════════════════════════════════════════════
-- TEXT CAPTURE  (Ctrl+Opt+T)
-- Uses hs.dialog.textPrompt — a native macOS dialog that ALWAYS closes
-- when OK/Cancel is pressed. No chooser popup bugs.
-- ══════════════════════════════════════════════════════════

local function showTextCapture()
  log("Text: opening input dialog")

  -- hs.dialog.textPrompt is modal but runs on the main thread.
  -- Returns immediately when user clicks OK or Cancel.
  local button, text = hs.dialog.textPrompt(
    "Quick Memory",
    "Type a thought, note, or idea:",
    "",    -- default text
    "Save",
    "Cancel"
  )

  if button == "Cancel" or text == nil or text == "" then
    log("Text: cancelled or empty")
    return
  end

  log("Text: saving \"" .. text .. "\"")
  notify("Saving...")

  runScript(CAPTURE_TEXT, { text }, function(exitCode, stdout, stderr)
    if exitCode == 0 then
      local filepath = (stdout or ""):match("^(.-)\n") or stdout or ""
      log("Text: saved → " .. filepath)
      notify("Memory saved")
    else
      log("Text ERROR: " .. (stderr or "unknown"))
      notify("Text capture failed")
    end
  end)
end

-- ══════════════════════════════════════════════════════════
-- SCREENSHOT CAPTURE  (Ctrl+Opt+S)
-- Uses Hammerspoon native hs.screen:snapshot() with interactive
-- region selection via hs.canvas overlay + mouse drag.
-- This avoids the macOS screencapture tool which has permission
-- inheritance issues on macOS 15+/26+.
-- ══════════════════════════════════════════════════════════

local selectionCanvas = nil   -- full-screen overlay for region selection
local selectionOverlay = nil  -- rectangle highlight during drag
local escHotkey = nil         -- escape key binding during selection

local function saveScreenshotRegion(rect)
  local tmpFile = "/tmp/.memcap_" .. os.time() .. ".png"
  log("Screenshot: saving region → " .. tmpFile)

  -- Capture the specific region using Hammerspoon's native API
  local screen = hs.screen.mainScreen()
  local img = screen:snapshot(rect)

  if not img then
    log("Screenshot: snapshot returned nil")
    notify("Screenshot failed — " .. screenshotFailureHint())
    return
  end

  img:saveToFile(tmpFile, "PNG")

  local ok, size = fileExistsAndNotEmpty(tmpFile)
  if not ok then
    log("Screenshot: file empty after save (size=" .. tostring(size) .. ")")
    notify("Screenshot failed — " .. screenshotFailureHint())
    os.remove(tmpFile)
    return
  end

  log("Screenshot: captured (" .. tostring(size) .. " bytes), asking for annotation")

  -- Ask for optional annotation
  local button, annotation = hs.dialog.textPrompt(
    "Screenshot Saved",
    "Add a note (optional):",
    "",
    "Save",
    "Skip"
  )

  if button == "Skip" then annotation = "" end
  if annotation == nil then annotation = "" end

  local args = { tmpFile }
  if annotation ~= "" then
    table.insert(args, annotation)
    log("Screenshot: saving with note \"" .. annotation .. "\"")
  else
    log("Screenshot: saving without note")
  end

  notify("Saving screenshot...")

  runScript(CAPTURE_SCREEN, args, function(code, stdout, stderr)
    if code == 0 then
      local filepath = (stdout or ""):match("^(.-)\n") or stdout or ""
      log("Screenshot: saved → " .. filepath)
      notify("Screenshot saved")
    else
      log("Screenshot ERROR: " .. (stderr or "unknown"))
      os.remove(tmpFile)
      notify("Screenshot failed — " .. screenshotFailureHint())
    end
  end)
end

local function cleanupSelection()
  if selectionCanvas then selectionCanvas:delete(); selectionCanvas = nil end
  if selectionOverlay then selectionOverlay:delete(); selectionOverlay = nil end
  if escHotkey then escHotkey:delete(); escHotkey = nil end
end

local function captureScreenshot()
  log("Screenshot: starting native region select")

  local screen = hs.screen.mainScreen()
  local frame = screen:fullFrame()

  -- Track mouse state for drag selection
  local startPoint = nil
  local isDragging = false

  -- Create full-screen transparent overlay to capture mouse events
  selectionCanvas = hs.canvas.new(frame)
  selectionCanvas:appendElements({
    -- Dim overlay
    { type = "rectangle",
      fillColor = { white = 0, alpha = 0.25 },
      action = "fill" },
    -- Instruction text
    { type = "text",
      text = hs.styledtext.new("Click and drag to select a region  ·  Press Escape to cancel", {
        font = { name = ".AppleSystemUIFont", size = 18 },
        color = { white = 1, alpha = 0.85 },
        paragraphStyle = { alignment = "center" },
      }),
      frame = { x = 0, y = frame.h / 2 - 20, w = frame.w, h = 40 } },
  })
  selectionCanvas:level(hs.canvas.windowLevels.overlay)
  selectionCanvas:clickActivating(false)
  selectionCanvas:canvasMouseEvents(true, true, false, true)
  selectionCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)

  -- Escape key to cancel
  escHotkey = hs.hotkey.bind({}, "escape", function()
    log("Screenshot: cancelled by user (Escape)")
    notify("Screenshot cancelled")
    cleanupSelection()
  end)

  selectionCanvas:mouseCallback(function(canvas, event, id, x, y)
    if event == "mouseDown" then
      startPoint = { x = frame.x + x, y = frame.y + y }
      isDragging = true
      -- Create selection rectangle overlay
      if selectionOverlay then selectionOverlay:delete() end
      selectionOverlay = hs.canvas.new({ x = startPoint.x, y = startPoint.y, w = 1, h = 1 })
      selectionOverlay:appendElements({
        { type = "rectangle",
          strokeColor = { red = 0.2, green = 0.6, blue = 1.0, alpha = 0.9 },
          fillColor = { red = 0.2, green = 0.6, blue = 1.0, alpha = 0.12 },
          strokeWidth = 2,
          action = "strokeAndFill" },
      })
      selectionOverlay:level(hs.canvas.windowLevels.overlay + 1)
      selectionOverlay:clickActivating(false)
      selectionOverlay:show()

    elseif event == "mouseMove" and isDragging and startPoint then
      -- Update selection rectangle as user drags
      local curX = frame.x + x
      local curY = frame.y + y
      local rx = math.min(startPoint.x, curX)
      local ry = math.min(startPoint.y, curY)
      local rw = math.abs(curX - startPoint.x)
      local rh = math.abs(curY - startPoint.y)
      if rw > 0 and rh > 0 and selectionOverlay then
        selectionOverlay:frame({ x = rx, y = ry, w = rw, h = rh })
      end

    elseif event == "mouseUp" and isDragging and startPoint then
      isDragging = false
      local endPoint = { x = frame.x + x, y = frame.y + y }

      -- Clean up UI first
      cleanupSelection()

      -- Calculate the selected rectangle
      local rx = math.min(startPoint.x, endPoint.x)
      local ry = math.min(startPoint.y, endPoint.y)
      local rw = math.abs(endPoint.x - startPoint.x)
      local rh = math.abs(endPoint.y - startPoint.y)

      -- Minimum selection size (avoid accidental clicks)
      if rw < 10 or rh < 10 then
        log("Screenshot: selection too small (" .. tostring(rw) .. "x" .. tostring(rh) .. ")")
        notify("Screenshot cancelled — selection too small")
        return
      end

      log("Screenshot: selected region " .. tostring(rw) .. "x" .. tostring(rh)
          .. " at " .. tostring(rx) .. "," .. tostring(ry))

      -- Small delay to let the overlay disappear before capturing
      hs.timer.doAfter(0.2, function()
        saveScreenshotRegion({ x = rx, y = ry, w = rw, h = rh })
      end)
    end
  end)

  selectionCanvas:show()
end

-- ══════════════════════════════════════════════════════════
-- AUDIO RECORDING  (Ctrl+Opt+A)
-- Toggle start/stop with visual feedback:
--   • Menu bar red dot ● while recording
--   • Floating "Recording..." overlay on screen
--   • Notifications on start/stop
-- ══════════════════════════════════════════════════════════

--- Create a floating "Recording..." indicator at top of screen
local function showRecordingOverlay()
  if recordingCanvas then recordingCanvas:delete() end

  local screen = hs.screen.mainScreen():frame()
  local w, h = 200, 36
  local x = screen.x + (screen.w - w) / 2
  local y = screen.y + 6

  recordingCanvas = hs.canvas.new({ x = x, y = y, w = w, h = h })
  recordingCanvas:appendElements({
    -- Background
    { type = "rectangle",
      fillColor = { red = 0.85, green = 0.1, blue = 0.1, alpha = 0.92 },
      roundedRectRadii = { xRadius = 10, yRadius = 10 },
      action = "fill" },
    -- Text
    { type = "text",
      text = hs.styledtext.new("● Recording...", {
        font = { name = ".AppleSystemUIFont", size = 15 },
        color = { white = 1, alpha = 1 },
        paragraphStyle = { alignment = "center" },
      }),
      frame = { x = 0, y = 6, w = w, h = h - 6 } },
  })
  recordingCanvas:level(hs.canvas.windowLevels.floating)
  recordingCanvas:clickActivating(false)
  recordingCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  recordingCanvas:show()
end

local function hideRecordingOverlay()
  if recordingCanvas then
    recordingCanvas:delete()
    recordingCanvas = nil
  end
end

local function toggleAudioRecording()
  if isRecording then
    -- ── STOP ──
    log("Audio: stopping recording")
    notify("Stopping recording...")
    hideRecordingOverlay()

    runScript(CAPTURE_AUDIO, { "stop" }, function(exitCode, stdout, stderr)
      isRecording = false

      if recordingIndicator then
        recordingIndicator:delete()
        recordingIndicator = nil
      end

      if exitCode == 0 then
        local duration = "0"
        if stdout then duration = stdout:match("^(%d+)") or "0" end
        log("Audio: saved (" .. duration .. "s)")
        notify("Voice note saved (" .. duration .. "s)")
      else
        log("Audio stop ERROR: " .. (stderr or "unknown"))
        notify("Recording error")
      end
    end)
  else
    -- ── START ──
    log("Audio: starting recording")

    runScript(CAPTURE_AUDIO, { "start" }, function(exitCode, stdout, stderr)
      if exitCode == 0 then
        isRecording = true
        log("Audio: recording started")
        notify("Recording — press Ctrl+Opt+A to stop")

        -- Menu bar red dot
        recordingIndicator = hs.menubar.new()
        if recordingIndicator then
          recordingIndicator:setTitle(hs.styledtext.new("● REC", {
            color = { red = 1, green = 0.15, blue = 0.15 },
            font = { name = ".AppleSystemUIFont", size = 13 },
          }))
          recordingIndicator:setClickCallback(function()
            toggleAudioRecording()  -- click menu bar to stop
          end)
        end

        -- Floating screen overlay
        showRecordingOverlay()
      else
        log("Audio start ERROR: " .. (stderr or "unknown"))
        notify("Recording failed — is sox installed?")
      end
    end)
  end
end

-- ══════════════════════════════════════════════════════════
-- DEBUG LOG VIEWER  (Ctrl+Opt+L)
-- Shows last 30 lines of capture.log in a dialog
-- ══════════════════════════════════════════════════════════

local function showDebugLog()
  log("Debug: opening log viewer")

  local f = io.open(LOG_FILE, "r")
  if f == nil then
    hs.dialog.blockAlert("Capture Debug Log", "No log file found.\n\nPath: " .. LOG_FILE)
    return
  end

  local content = f:read("*a")
  f:close()

  -- Get last 40 lines
  local lines = {}
  for line in content:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  local startLine = math.max(1, #lines - 39)
  local recent = {}
  for i = startLine, #lines do
    table.insert(recent, lines[i])
  end

  local logText = table.concat(recent, "\n")
  if logText == "" then logText = "(empty log)" end

  -- Show in a dialog with text area
  hs.dialog.textPrompt(
    "Capture Debug Log (last 40 lines)",
    logText,
    "",
    "Close",
    "Clear Log"
  )
end

local function clearDebugLog()
  local f = io.open(LOG_FILE, "w")
  if f then
    f:write("")
    f:close()
    log("Debug: log cleared")
    notify("Log cleared")
  end
end

-- ══════════════════════════════════════════════════════════
-- HOTKEY BINDINGS
-- ══════════════════════════════════════════════════════════

hs.hotkey.bind({ "ctrl", "alt" }, "t", showTextCapture)
hs.hotkey.bind({ "ctrl", "alt" }, "s", captureScreenshot)
hs.hotkey.bind({ "ctrl", "alt" }, "a", toggleAudioRecording)
hs.hotkey.bind({ "ctrl", "alt" }, "l", showDebugLog)

log("Module loaded — Ctrl+Opt+T/S/A/L active")

-- ── Auto-Reload on Config Change ──────────────────────────

local function reloadConfig(files)
  local doReload = false
  for _, file in pairs(files) do
    if file:sub(-4) == ".lua" then
      doReload = true
      break
    end
  end
  if doReload then
    log("Config changed — reloading")
    hs.reload()
  end
end

local configWatcher = hs.pathwatcher.new(
  HOME .. "/.hammerspoon/",
  reloadConfig
)
configWatcher:start()

return M
