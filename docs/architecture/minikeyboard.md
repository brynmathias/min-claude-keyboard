# minikeyboard

A CH57x mini macro pad (USB `1189:8890`, 6 buttons + 1 pressable knob) used
as a mode-switching controller for Claude Code, the browser, and our own apps.

## Design

Two parts:

1. **Hardware layer (flashed once).** `ch57x-keyboard-tool` writes
   `keyboard.yaml` to the pad. Every control sends an otherwise-unused key
   (F13–F20, plus `ctrl-alt-f20` for the knob press). The pad holds no
   per-mode logic, because it cannot tell the Mac which layer it is on.
2. **Host layer (Hammerspoon).** `init.lua` binds those keys, keeps the
   current mode, translates each key to the mode's action, and shows the
   mode in the menu bar.

### Physical layout (2 rows × 3, knob on the side)

| Control       | Sends          | Role            |
|---------------|----------------|-----------------|
| Button 1      | F13            | Talk: tap = Enter, hold = push-to-talk |
| Button 2      | F18            | Yes / prev tab  |
| Button 3      | ctrl-alt-F16   | No / next tab   |
| Button 4      | F16            | Clear typed text |
| Button 5      | F17            | Mode-specific A |
| Button 6      | ctrl-alt-F19   | Mode (cycle)    |

F14/F15 are not used: macOS grabs them for screen brightness before
Hammerspoon sees them.
| Knob left     | F19            | Knob mode: nav up / quieter / dimmer |
| Knob right    | F20            | Knob mode: nav down / louder / brighter |
| Knob press    | ctrl-alt-F20   | Select / knob-mode press |

Talk, Clear and Mode behave the same in every mode, for muscle memory.
Button 4 clears typed text based on the app in front (not the mode):
In a terminal (Claude Code) it kills the draft line by line, up to 12 lines,
with Ctrl+K, Ctrl+U, Backspace, since Claude Code has no single clear-input key
(Ctrl+L is a screen redraw). Elsewhere: Cmd+A, Delete.

### Modes

- **Claude** — knob = Up/Down arrows, press = Enter, Yes = Enter,
  No = Esc, A = Shift+Tab.

### Talk backends

Each mode's `talk` field picks what holding Talk does. Claude mode uses
`claude`; every other mode defaults to `dictation`. Hold Talk (past 0.25 s)
to start, release to stop; a short tap sends Enter. The menu bar shows 🎤
while recording. If a release is ever missed, the next Talk press stops it.

- `dictation` — macOS Dictation, works in any app. F13 is captured by an eventtap and swallowed, because a real key event
  reaching macOS while Dictation listens ends it. Requires System Settings >
  Keyboard > Dictation > Shortcut = Customise… = Control+Option+Command+D
  (`DICTATION_SHORTCUT` in `init.lua`); a synthetic "Control twice" is
  ignored by macOS. On-device for English on Apple silicon. Weaker than
  Claude Code's own voice on project vocabulary.
- `claude` — holds Space, which Claude Code's own voice dictation reads as
  push-to-talk. Terminal only; audio goes to Anthropic for transcription,
  with the project name and branch as vocabulary hints, so it hears project
  words better than macOS Dictation.
- **iTerm** — knob = scroll, press = Enter, Yes = previous tab
  (Cmd+Shift+[), No = next tab (Cmd+Shift+]), A = next split pane
  (Cmd+], wraps round). Uses iTerm2's default shortcuts.
- **Browser** — knob = scroll, press = Enter, Yes = previous tab,
  No = next tab, A = back, Clear (4) = close tab (Cmd+W). A mode may set
  `clear` to override button 4; default is clear typed text.
- **Meet** — Google Meet, tab must be in front. 1 (tap) = toggle mic
  (Cmd+D, latched: tap to mute, tap to unmute; hold still dictates),
  2 = raise/lower hand (Ctrl+Cmd+H), 3 = toggle camera (Cmd+E),
  5 = captions (Ctrl+Cmd+C), knob = scroll, press = Enter. A mode may set
  `tap` to override what a short tap of 1 does; default is Enter.
- **Apps** — knob = Up/Down arrows, press = Enter, A = Tab.

### Switching modes

- **Double-tap Mode**: enter SELECT. The menu bar shows
  `🔀 1=CLAUDE 2=ITERM 3=BROWSER 4=APPS 5=MEET knob=KNOB`. Press that button
  buttons to switch. Any other button, button 6 again, or 5 s of nothing,
  cancels and leaves the mode as it was.
- **Single tap Mode**: reserved, does nothing yet.
- The menu bar item can also be clicked to pick a mode.

Why not hold-Mode chords: the pad sends any button that has modifiers
(Mode, No, knob press) as an instant press+release burst, however long it's
physically held. Plain keys (Talk, Yes, Clear, A, knob turns) are held
properly with autorepeat. So Mode can never be "held" on the host side.

### Knob modes (independent of the button mode)

The knob has its own mode, shown as an icon after the button mode in the
menu bar. To change it: double-tap 6 (SELECT), press the knob, turn the
knob to step through the list (applied live, current one in brackets),
press the knob to finish. 6 or 5 s of nothing also finishes.
Clockwise is always up / louder / brighter.

- **nav ⇅** — whatever the button mode defines (arrows in Claude, iTerm and
  Apps; scroll in Browser and Meet). Press = the button mode's select.
- **volume 🔊** — macOS volume via the keyboard's own media keys (HUD shows).
  Press = play/pause.
- **brightness ☀️** — screen brightness, likewise. Press = mode's select.

A knob mode may define its own `press`; otherwise the press falls through
to the button mode. Survives reload like the button mode.

### Indicator

The current mode and knob mode show in the menu bar (with 🎤 while recording),
followed by what buttons 1–5 do in that mode, e.g.
`🤖 CLAUDE ⇅   1·Talk 2·Enter 3·Esc 4·Clear 5·⇧Tab`. Each mode's `keys`
table supplies the labels; 1 and 4 are the same everywhere.
`SHOW_LEGEND = false` in `init.lua` hides the legend.
Clicking it lists the modes. No on-screen overlay.

Adding a mode = adding one table entry in `init.lua`.

## Acceptance criteria

1. Double-tapping Mode shows the SELECT prompt in the menu bar; pressing
   button 1 / 2 / 3 / 4 / 5 switches to Claude / iTerm / Browser / Apps / Meet and
   the menu bar item updates within 100 ms.
2. In Claude mode with the knob in nav, turning the knob moves the
   highlighted option in an AskUserQuestion prompt; pressing the knob
   selects it. SELECT → knob press → turn → knob press changes the knob
   mode and the icon updates.
3. Yes sends Enter, No sends Esc, in every mode.
4. Holding Talk records (macOS Dictation or Claude Code voice, per
   `TALK_BACKEND`); releasing stops it. A short tap sends Enter.
5. In Browser mode, the knob scrolls the page under the cursor.
6. The current mode survives a Hammerspoon config reload.
7. If Hammerspoon is not running, the pad sends only F13–F20 (no harmful
   side effects).
8. In iTerm mode, Yes/No move between tabs and A cycles through the panes
   of the current tab.
