# min-claude-keyboard

A cheap CH57x macro pad (6 buttons + a knob, USB `1189:8890`) turned into a
mode-switching controller for Claude Code, iTerm2, the browser and anything
else, with push-to-talk dictation that works in any app.

The pad is flashed once to send otherwise-unused keys (F13–F20). All the
behaviour lives on the Mac in a Hammerspoon script: modes, what each button
does per mode, a menu-bar indicator, and a Talk button that holds Claude
Code's voice input in Claude mode and macOS Dictation everywhere else.

Design, layout, modes and the gotchas (why the Mode button can't be held,
why Dictation needs a custom shortcut) are in
[`docs/architecture/minikeyboard.md`](docs/architecture/minikeyboard.md).

## Hardware

The pad used here:
[6-key + knob CH57x macro pad on AliExpress](https://www.aliexpress.com/item/1005008160436349.html).
It shows up as USB `1189:8890` and flashes as `model: ch57x-2`.

Its vendor software is Windows-only, but you don't need it:
`ch57x-keyboard-tool` (below) programs it from macOS.

Things we learnt:
- macOS and apps like BetterDisplay grab F14 and F15 for screen brightness,
  so the pad doesn't send them.
- One switch had a bent pin and sent nothing. If a single button is dead
  after flashing, check the switch before blaming the config.

## Setup

1. Flash the pad:
   ```sh
   cargo install ch57x-keyboard-tool
   ch57x-keyboard-tool upload < services/minikeyboard/keyboard.yaml
   ```
2. Install Hammerspoon (`brew install --cask hammerspoon`), grant it
   Accessibility, and load the script from `~/.hammerspoon/init.lua`:
   ```lua
   dofile(os.getenv("HOME") .. "/git/min-claude-keyboard/services/minikeyboard/init.lua")
   ```
3. For dictation outside Claude Code: System Settings → Keyboard → Dictation
   → Shortcut → Customise… → Control+Option+Command+D (matches
   `DICTATION_SHORTCUT` in `init.lua`).

## Buttons

Top row 1 2 3, bottom row 4 5 6, knob on the side.

| Button | Every mode |
|---|---|
| 1 | Talk: tap = Enter, hold = push-to-talk |
| 4 | Clear typed text |
| 6 | Mode: double-tap = pick a mode (1–5), single tap reserved |
| Knob | Turn = nav / volume / brightness (own mode, picked via 6 6 + knob); press = select, or play/pause in volume |

Buttons 2, 3, 5 and the knob are mode-specific; see the design doc.
