-- minikeyboard: mode-switching controller for a CH57x macro pad (1189:8890).
-- The pad sends F13–F20 (see keyboard.yaml); this file decides what they do.
-- Design: docs/architecture/minikeyboard.md

local SETTINGS_KEY = "minikeyboard.mode"
local SHOW_LEGEND = true -- menu bar shows what buttons 1–5 do in the current mode
local TALK_REPEAT_SECONDS = 0.03 -- Claude Code detects "hold" via key repeat
-- What holding Talk does is per mode (`talk` field, default "dictation"):
--   "dictation" = macOS Dictation, works in any app (see DICTATION_SHORTCUT).
--   "claude"    = hold Space for Claude Code's own voice (better vocabulary,
--                 terminal only). Used by Claude mode.

local function tap(mods, key)
  return function() hs.eventtap.keyStroke(mods, key, 0) end
end

-- Media/system keys (volume, play, brightness). Behaves like the keyboard's
-- own keys, including the on-screen HUD.
local function systemKey(name)
  return function()
    hs.eventtap.event.newSystemKeyEvent(name, true):post()
    hs.eventtap.event.newSystemKeyEvent(name, false):post()
  end
end

local function scroll(lines)
  return function() hs.eventtap.scrollWheel({ 0, lines }, {}, "line") end
end

-- Clear typed text. Depends on the app in front, not the mode, so it does
-- the right thing even if the pad is in the "wrong" mode.
-- In a terminal (Claude Code), kill line by line; see clearText.
local CLEAR_MAX_LINES = 12
-- Elsewhere: select all, then delete.
local TERMINALS = {
  ["iTerm2"] = true, ["Terminal"] = true, ["Ghostty"] = true,
  ["WezTerm"] = true, ["Warp"] = true, ["kitty"] = true, ["Alacritty"] = true,
}

local function clearText()
  local app = hs.application.frontmostApplication()
  if app and TERMINALS[app:name()] then
    -- Claude Code has no single clear-input key (Ctrl+L is a redraw). Per
    -- line: Ctrl+K kills to end, Ctrl+U to start, Backspace joins the
    -- previous line. Repeating covers multi-line drafts from any cursor
    -- position; extra rounds on an empty box do nothing. Verified 2.1.318.
    for _ = 1, CLEAR_MAX_LINES do
      hs.eventtap.keyStroke({ "ctrl" }, "k", 0)
      hs.eventtap.keyStroke({ "ctrl" }, "u", 0)
      hs.eventtap.keyStroke({}, "delete", 0)
    end
  else
    hs.eventtap.keyStroke({ "cmd" }, "a", 0)
    hs.eventtap.keyStroke({}, "delete", 0)
  end
end

-- Modes, in cycle order. Add a mode by adding an entry here.
-- Talk / Clear / Mode are the same in every mode (see below).
local MODES = {
  {
    name = "claude", label = "🤖 CLAUDE", color = { red = 0.85, green = 0.47, blue = 0.34 },
    talk = "claude", -- Claude Code's own voice; every other mode uses macOS Dictation
    up = tap({}, "up"), down = tap({}, "down"), select = tap({}, "return"),
    yes = tap({}, "return"), no = tap({}, "escape"),
    a = tap({ "shift" }, "tab"), -- cycle permission mode
    keys = { [2] = "Enter", [3] = "Esc", [5] = "⇧Tab" },
  },
  {
    name = "iterm", label = "🖥️ ITERM", color = { red = 0.45, green = 0.45, blue = 0.5 },
    up = scroll(3), down = scroll(-3), select = tap({}, "return"),
    yes = tap({ "cmd", "shift" }, "["), -- previous iTerm tab
    no = tap({ "cmd", "shift" }, "]"),  -- next iTerm tab
    a = tap({ "cmd" }, "]"),            -- next split pane
    keys = { [2] = "◀Tab", [3] = "Tab▶", [5] = "Pane" },
  },
  {
    name = "browser", label = "🌐 BROWSER", color = { red = 0.25, green = 0.5, blue = 0.9 },
    up = scroll(3), down = scroll(-3), select = tap({}, "return"),
    yes = tap({ "ctrl", "shift" }, "tab"), -- previous tab
    no = tap({ "ctrl" }, "tab"),           -- next tab
    a = tap({ "cmd" }, "["),               -- back
    clear = tap({ "cmd" }, "w"),           -- 4: close tab (instead of clear text)
    keys = { [2] = "◀Tab", [3] = "Tab▶", [4] = "Close", [5] = "Back" },
  },
  {
    name = "meet", label = "📹 MEET", color = { red = 0.1, green = 0.6, blue = 0.3 },
    -- Google Meet shortcuts; the Meet tab must be in front. Talk (1) is the
    -- mic, latched: tap to mute, tap to unmute. Holding 1 still dictates.
    up = scroll(3), down = scroll(-3), select = tap({}, "return"),
    tap = tap({ "cmd" }, "d"),          -- 1: toggle microphone
    yes = tap({ "ctrl", "cmd" }, "h"),  -- 2: raise / lower hand
    no = tap({ "cmd" }, "e"),           -- 3: toggle camera
    a = tap({ "ctrl", "cmd" }, "c"),    -- 5: captions on / off
    keys = { [1] = "Mic", [2] = "Hand", [3] = "Cam", [5] = "Captions" },
  },
  {
    name = "apps", label = "🧪 APPS", color = { red = 0.3, green = 0.7, blue = 0.4 },
    up = tap({}, "up"), down = tap({}, "down"), select = tap({}, "return"),
    yes = tap({}, "return"), no = tap({}, "escape"),
    a = tap({}, "tab"),
    keys = { [2] = "Enter", [3] = "Esc", [5] = "Tab" },
  },
}

-- Button number → mode while in SELECT (double-tap Mode). Buttons are 1–6,
-- top row 1 2 3, bottom row 4 5 6; 6 is Mode.
local SELECT_KEYS = {
  { button = 1, mode = "claude" },
  { button = 2, mode = "iterm" },
  { button = 3, mode = "browser" },
  { button = 4, mode = "apps" },
  { button = 5, mode = "meet" },
}

-- The knob has its own mode, independent of the button mode, picked via
-- SELECT → knob press → turn → knob press. "nav" = whatever the button mode
-- defines for the knob (arrows or scroll); the others are the keyboard's
-- own media keys. A knob mode may define `press`; otherwise the knob press
-- is the button mode's `select`. Clockwise = up/louder/brighter.
local KNOB_MODES = {
  { name = "nav", icon = "⇅" },
  { name = "volume", icon = "🔊", ccw = systemKey("SOUND_DOWN"), cw = systemKey("SOUND_UP"),
    press = systemKey("PLAY") }, -- play/pause, like a media knob
  { name = "brightness", icon = "☀️", ccw = systemKey("BRIGHTNESS_DOWN"), cw = systemKey("BRIGHTNESS_UP") },
}
local KNOB_SETTINGS_KEY = "minikeyboard.knob"

local state = { index = 1, knob = 1, menu = nil, talkTimer = nil, hotkeys = {}, lastModeTap = nil, selecting = false }

local function currentMode() return MODES[state.index] end
local function currentKnob() return KNOB_MODES[state.knob] end

local setMode -- defined below; the menu needs it

-- Mode indicator lives in the menu bar (no overlay covering windows).
-- Clicking it lists the modes.
local function drawMarker()
  if not state.menu then
    state.menu = hs.menubar.new()
    state.menu:setMenu(function()
      local items = {}
      for i, m in ipairs(MODES) do
        items[#items + 1] = { title = m.label, checked = (i == state.index), fn = function() setMode(i) end }
      end
      return items
    end)
  end
  if state.selecting then
    local parts = {}
    for _, k in ipairs(SELECT_KEYS) do
      for _, m in ipairs(MODES) do
        if m.name == k.mode then parts[#parts + 1] = k.button .. "=" .. m.label:gsub("^%S+ ", "") end
      end
    end
    state.menu:setTitle("🔀 " .. table.concat(parts, "  ") .. "  knob=KNOB")
    return
  end
  if state.knobSelecting then
    local parts = {}
    for i, k in ipairs(KNOB_MODES) do
      local item = k.icon .. " " .. k.name
      parts[#parts + 1] = (i == state.knob) and ("[" .. item .. "]") or item
    end
    state.menu:setTitle("🎛 " .. table.concat(parts, "  "))
    return
  end
  local mode = currentMode()
  local title = mode.label .. " " .. currentKnob().icon .. (state.dictating and " 🎤" or "")
  if SHOW_LEGEND then
    local keys = { [1] = "Talk", [4] = "Clear" } -- same in every mode
    for b, name in pairs(mode.keys or {}) do keys[b] = name end
    local parts = {}
    for b = 1, 5 do parts[#parts + 1] = b .. "·" .. (keys[b] or "–") end
    title = title .. "   " .. table.concat(parts, " ")
  end
  state.menu:setTitle(title)
end

setMode = function(index)
  state.index = index
  hs.settings.set(SETTINGS_KEY, currentMode().name)
  drawMarker()
end

local function setKnob(index)
  state.knob = index
  hs.settings.set(KNOB_SETTINGS_KEY, currentKnob().name)
  drawMarker()
end

-- Knob-mode picker: entered from SELECT by pressing the knob. Turning the
-- knob then steps through KNOB_MODES (applied live, shown in the menu bar);
-- knob press, Mode, or KNOB_SELECT_TIMEOUT_SECONDS of nothing leaves it.
local KNOB_SELECT_TIMEOUT_SECONDS = 5

local function knobSelectEnd()
  state.knobSelecting = false
  if state.knobSelectTimer then state.knobSelectTimer:stop(); state.knobSelectTimer = nil end
  drawMarker()
end

local function knobSelectTouch()
  if state.knobSelectTimer then state.knobSelectTimer:stop() end
  state.knobSelectTimer = hs.timer.doAfter(KNOB_SELECT_TIMEOUT_SECONDS, knobSelectEnd)
end

local function knobSelectBegin()
  state.knobSelecting = true
  knobSelectTouch()
  drawMarker()
end

-- Knob turn: while picking, steps the knob mode. Otherwise the knob mode
-- wins unless it's "nav", which defers to the button mode's up/down.
local function knobTurn(direction) -- "ccw" or "cw"
  return function()
    if state.knobSelecting then
      local step = (direction == "cw") and 1 or -1
      setKnob((state.knob - 1 + step) % #KNOB_MODES + 1)
      knobSelectTouch()
      return
    end
    local k = currentKnob()
    if k[direction] then k[direction]() return end
    currentMode()[direction == "ccw" and "up" or "down"]()
  end
end

local function cycleMode()
  setMode(state.index % #MODES + 1)
end

-- Mode selection. The pad sends modifier combos (Mode, No, knob press) as an
-- instant press+release burst however long the button is held, so Mode can't
-- be held. Instead:
--   double-tap Mode = enter SELECT; the menu bar shows which button picks
--                     which mode; press one to switch. Mode again, or
--                     SELECT_TIMEOUT_SECONDS of nothing, cancels.
--   single tap Mode = nothing yet (reserved).
local DOUBLE_TAP_SECONDS = 0.4
local SELECT_TIMEOUT_SECONDS = 5

local function selectEnd()
  state.selecting = false
  if state.selectTimer then state.selectTimer:stop(); state.selectTimer = nil end
  drawMarker()
end

local function selectBegin()
  state.selecting = true
  state.selectTimer = hs.timer.doAfter(SELECT_TIMEOUT_SECONDS, selectEnd)
  drawMarker()
end

local function modeTap()
  local now = hs.timer.secondsSinceEpoch()
  if state.selecting then
    selectEnd()
  elseif state.knobSelecting then
    knobSelectEnd()
  elseif state.lastModeTap and now - state.lastModeTap < DOUBLE_TAP_SECONDS then
    state.lastModeTap = nil
    selectBegin()
  else
    state.lastModeTap = now -- single tap: reserved, does nothing for now
  end
end

-- Called by every button. Returns true if the press was consumed by SELECT.
local function select(button)
  if not state.selecting then return false end
  if button == "knob" then -- hand over to the knob-mode picker
    selectEnd()
    knobSelectBegin()
    return true
  end
  for _, k in ipairs(SELECT_KEYS) do
    if k.button == button then
      for i, m in ipairs(MODES) do
        if m.name == k.mode then setMode(i) end
      end
    end
  end
  selectEnd() -- any button leaves SELECT, matched or not
  return true
end

-- Claude backend: hold Space down, re-sending key-downs so Claude Code sees
-- a held key.
local function postSpace(isDown, isRepeat)
  local ev = hs.eventtap.event.newKeyEvent({}, "space", isDown)
  if isRepeat then
    ev:setProperty(hs.eventtap.event.properties.keyboardEventAutorepeat, 1)
  end
  ev:post()
end

-- macOS Dictation toggle. Two options, set in System Settings > Keyboard >
-- Dictation > Shortcut:
--   DICTATION_SHORTCUT = nil              -> "Press Control key twice"; we post
--                                            ctrl down/up twice as flagsChanged.
--   DICTATION_SHORTCUT = { mods, key }    -> "Customise…" with that combo; we
--                                            send it as an ordinary keystroke.
local DICTATION_SHORTCUT = { { "ctrl", "alt", "cmd" }, "d" }

local function dictationToggle()
  if DICTATION_SHORTCUT then
    hs.eventtap.keyStroke(DICTATION_SHORTCUT[1], DICTATION_SHORTCUT[2], 0)
    return
  end
  local ctrl = hs.keycodes.map.ctrl
  for _ = 1, 2 do
    hs.eventtap.event.newKeyEvent(ctrl, true):post()
    hs.timer.usleep(80000)
    hs.eventtap.event.newKeyEvent(ctrl, false):post()
    hs.timer.usleep(120000)
  end
end

-- The backend is chosen at start and remembered, so a mode change mid-hold
-- still stops the right thing.
local function recordStart()
  state.recordingBackend = currentMode().talk or "dictation"
  if state.recordingBackend == "dictation" then
    dictationToggle()
  else
    postSpace(true, false)
    state.talkTimer = hs.timer.doEvery(TALK_REPEAT_SECONDS, function() postSpace(true, true) end)
  end
end

local function recordStop()
  if state.recordingBackend == "dictation" then
    dictationToggle()
  else
    if state.talkTimer then state.talkTimer:stop(); state.talkTimer = nil end
    postSpace(false, false)
  end
  state.recordingBackend = nil
end

require("hs.ipc") -- lets `hs -c` talk to this config from a terminal

-- Talk: tap = Enter (send). Hold past TALK_HOLD_SECONDS = push-to-talk,
-- recording until release. F13 is swallowed by an eventtap (see below) so
-- macOS Dictation never sees the pad's key events, which would end it.
local TALK_HOLD_SECONDS = 0.25

local function talkPress()
  if select(1) then return end
  if state.talkHeld then return end
  if state.dictating then -- a release went missing; this press stops it
    state.talkRecording, state.dictating = false, false
    drawMarker()
    recordStop()
    return
  end
  state.talkHeld, state.talkRecording = true, false
  state.talkHoldTimer = hs.timer.doAfter(TALK_HOLD_SECONDS, function()
    state.talkHoldTimer = nil
    state.talkRecording, state.dictating = true, true
    drawMarker()
    recordStart()
  end)
end

local function talkRelease()
  if not state.talkHeld then return end -- press was used by SELECT
  state.talkHeld = false
  if state.talkHoldTimer then state.talkHoldTimer:stop(); state.talkHoldTimer = nil end
  if state.talkRecording then
    state.talkRecording, state.dictating = false, false
    drawMarker()
    recordStop()
  else
    (currentMode().tap or tap({}, "return"))() -- short tap: send, unless the mode overrides it
  end
end

local function role(name)
  return function() currentMode()[name]() end
end

local function unlessSelecting(button, fn)
  return function() if not select(button) then fn() end end
end

local function bind(mods, key, pressed, released)
  table.insert(state.hotkeys, hs.hotkey.bind(mods, key, pressed, released))
end

-- Restore the last mode.
local saved = hs.settings.get(SETTINGS_KEY)
for i, m in ipairs(MODES) do
  if m.name == saved then state.index = i end
end
local savedKnob = hs.settings.get(KNOB_SETTINGS_KEY)
for i, k in ipairs(KNOB_MODES) do
  if k.name == savedKnob then state.knob = i end
end

-- Talk (F13) is handled by an eventtap, not a hotkey, so the key events are
-- swallowed before any app or input method (macOS Dictation) sees them.
-- F13 with modifiers is left alone (nothing binds it today).
local F13 = hs.keycodes.map.f13
local AUTOREPEAT = hs.eventtap.event.properties.keyboardEventAutorepeat
state.talkTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp }, function(ev)
  if ev:getKeyCode() ~= F13 then return false end
  local f = ev:getFlags()
  if f.ctrl or f.alt or f.cmd or f.shift then return false end
  if ev:getType() == hs.eventtap.event.types.keyDown then
    if ev:getProperty(AUTOREPEAT) == 0 then talkPress() end
  else
    talkRelease()
  end
  return true -- swallow
end):start()
bind({}, "f18", unlessSelecting(2, role("yes")))                  -- Yes (prev tab in Browser)
bind({ "ctrl", "alt" }, "f16", nil, unlessSelecting(3, role("no"))) -- No (next tab in Browser)
bind({}, "f16", unlessSelecting(4, function() (currentMode().clear or clearText)() end)) -- Clear typed text, unless the mode overrides
bind({}, "f17", unlessSelecting(5, role("a")))                      -- Mode-specific A
bind({ "ctrl", "alt" }, "f19", nil, modeTap)           -- Mode: double-tap = SELECT (single tap reserved)
bind({}, "f19", knobTurn("ccw"))                       -- Knob left: nav up / quieter / dimmer
bind({}, "f20", knobTurn("cw"))                        -- Knob right: nav down / louder / brighter
bind({ "ctrl", "alt" }, "f20", nil, function()         -- Knob press: finish picking, else knob-mode press, else mode select
  if state.knobSelecting then knobSelectEnd() return end
  if select("knob") then return end
  (currentKnob().press or currentMode().select)()
end)
-- While Mode is held the pad may still hold Ctrl+Alt, so catch those variants too.

drawMarker()

minikeyboard = state -- global, so nothing is garbage-collected
return state
