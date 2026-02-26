-- Memory Capture Module for Hammerspoon
-- Provides global hotkeys for quick text, screenshot, and audio capture.
-- SYSTEM_NAME is replaced by install.sh via sed.

local M = {}

-- ── Module State ──────────────────────────────────────────
local isRecording = false
local recordingIndicator = nil  -- hs.menubar during audio recording
local textChooser = nil         -- hs.chooser for text input

-- ── Script Paths ──────────────────────────────────────────
local SYS_DIR = os.getenv("HOME") .. "/.SYSTEM_NAME/.sys"
local CAPTURE_TEXT = SYS_DIR .. "/capture-text.sh"
local CAPTURE_SCREEN = SYS_DIR .. "/capture-screen.sh"
local CAPTURE_AUDIO = SYS_DIR .. "/capture-audio.sh"

-- ── Stealth: Hide Dock Icon ───────────────────────────────
hs.dockicon.hide()

-- ── Helpers ───────────────────────────────────────────────

--- Show a brief notification that auto-dismisses after 2 seconds.
-- @param title string  The notification title
local function notify(title)
  local n = hs.notify.new(nil, {
    title = title,
    withdrawAfter = 2,
    hasActionButton = false,
  })
  n:send()
end

--- Run a shell script asynchronously via hs.task.
-- @param script string  Absolute path to the script
-- @param args table     Arguments to pass
-- @param callback function(exitCode, stdout, stderr)
local function runScript(script, args, callback)
  local task = hs.task.new(script, function(exitCode, stdout, stderr)
    if callback then
      callback(exitCode, stdout, stderr)
    end
  end, args)
  task:start()
end

-- ── Text Capture (Ctrl+Opt+T) ─────────────────────────────

local function onTextChosen(result)
  if result == nil then
    -- User pressed Escape — do nothing
    return
  end

  local text = result.text
  if text == nil or text == "" then
    return
  end

  runScript(CAPTURE_TEXT, { text }, function(exitCode, stdout, stderr)
    if exitCode == 0 then
      notify("Memory saved")
    else
      local errMsg = stderr or "Unknown error"
      hs.printf("[memcapture] text error: %s", errMsg)
    end
  end)
end

local function showTextCapture()
  if textChooser and textChooser:isVisible() then
    -- Duplicate shortcut focuses existing bar
    textChooser:query(nil)
    return
  end

  if textChooser == nil then
    textChooser = hs.chooser.new(onTextChosen)
    textChooser:placeholderText("Type a memory...")
    textChooser:searchSubText(false)
    textChooser:width(40)
  end

  -- No choices — user types freely and presses Enter
  textChooser:choices({})
  textChooser:show()
end

-- ── Screenshot Capture (Ctrl+Opt+S) ───────────────────────

local annotationChooser = nil

local function captureScreenshot()
  -- Generate a stealth temp file path with dot-prefix
  local tmpFile = "/tmp/.memcap_" .. os.time() .. ".png"

  -- Use macOS built-in screencapture (interactive region select)
  local task = hs.task.new("/usr/sbin/screencapture", function(exitCode)
    if exitCode ~= 0 then
      -- User cancelled (Escape) or error — clean up
      os.remove(tmpFile)
      return
    end

    -- Check file was created (user didn't cancel)
    local f = io.open(tmpFile, "r")
    if f == nil then
      return
    end
    f:close()

    -- Show annotation chooser (optional note)
    if annotationChooser == nil then
      annotationChooser = hs.chooser.new(function(result)
        local annotation = ""
        if result and result.text and result.text ~= "" then
          annotation = result.text
        end

        local args = { tmpFile }
        if annotation ~= "" then
          table.insert(args, annotation)
        end

        runScript(CAPTURE_SCREEN, args, function(code, stdout, stderr)
          if code == 0 then
            notify("Screenshot saved")
          else
            local errMsg = stderr or "Unknown error"
            hs.printf("[memcapture] screen error: %s", errMsg)
            os.remove(tmpFile)
          end
        end)
      end)
      annotationChooser:placeholderText("Add a note (optional) — Enter to save")
      annotationChooser:searchSubText(false)
      annotationChooser:width(40)
    end

    annotationChooser:choices({})
    annotationChooser:show()
  end, { "-i", "-s", tmpFile })

  task:start()
end

-- ── Audio Recording (Ctrl+Opt+A) ──────────────────────────

local function toggleAudioRecording()
  if isRecording then
    -- Stop recording
    runScript(CAPTURE_AUDIO, { "stop" }, function(exitCode, stdout, stderr)
      isRecording = false

      -- Remove menu bar indicator
      if recordingIndicator then
        recordingIndicator:delete()
        recordingIndicator = nil
      end

      if exitCode == 0 then
        -- Parse duration from first line of stdout
        local duration = "0"
        if stdout then
          duration = stdout:match("^(%d+)") or "0"
        end
        notify("Voice note saved (" .. duration .. "s)")
      else
        local errMsg = stderr or "Unknown error"
        hs.printf("[memcapture] audio stop error: %s", errMsg)
        notify("Recording error")
      end
    end)
  else
    -- Start recording
    runScript(CAPTURE_AUDIO, { "start" }, function(exitCode, stdout, stderr)
      if exitCode == 0 then
        isRecording = true

        -- Show red dot in menu bar
        recordingIndicator = hs.menubar.new()
        if recordingIndicator then
          recordingIndicator:setTitle("●")
          -- Red color via styled text
          recordingIndicator:setTitle(
            hs.styledtext.new("●", {
              color = { red = 1, green = 0, blue = 0 },
              font = { size = 18 },
            })
          )
        end
      else
        local errMsg = stderr or "Unknown error"
        hs.printf("[memcapture] audio start error: %s", errMsg)
        notify("Recording failed to start")
      end
    end)
  end
end

-- ── Hotkey Bindings ───────────────────────────────────────

hs.hotkey.bind({ "ctrl", "alt" }, "t", showTextCapture)
hs.hotkey.bind({ "ctrl", "alt" }, "s", captureScreenshot)
hs.hotkey.bind({ "ctrl", "alt" }, "a", toggleAudioRecording)

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
    hs.reload()
  end
end

local configWatcher = hs.pathwatcher.new(
  os.getenv("HOME") .. "/.hammerspoon/",
  reloadConfig
)
configWatcher:start()

return M
