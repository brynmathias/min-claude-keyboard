# minikeyboard — threats

Scope: local-only. No network, no secrets, no stored data apart from the
current mode name (in Hammerspoon settings).

| STRIDE | Threat | Mitigation |
|---|---|---|
| Spoofing | Another app synthesises F13–F20 to drive actions | Actions are only ordinary keystrokes the app could send itself; no privilege gained. |
| Tampering | `init.lua` edited by something else | Lives in the user's home dir under git; Hammerspoon needs Accessibility permission granted by the user. |
| Repudiation | n/a | n/a |
| Info disclosure | Hammerspoon has Accessibility access (can read keystrokes) | Config only binds the 9 pad keys; no logging of other keys. |
| DoS | Stuck Talk key holds Space down | Release handler always sends Space key-up; reloading the config also releases it. |
| Elevation | Pad sends a dangerous key in the wrong app (e.g. Enter approves a Claude permission) | Intended behaviour, but the on-screen mode marker makes the active mode visible. |

Supply chain: `hammerspoon` (Homebrew cask, signed) and
`ch57x-keyboard-tool` (crates.io) are installed by the user.
