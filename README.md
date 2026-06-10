# Essence <img width="24" height="24" alt="pure_essence" src="https://github.com/user-attachments/assets/68c6cc01-e3c3-4f5f-a508-04d9eb4492ba" />

A lightweight, Apple Silicon-native Jagex launcher alternative for macOS. Support for multiple Jagex Accounts with credentials securely stored in the macOS Keychain.

## Example
<img width="360" alt="image" src="https://github.com/user-attachments/assets/614fcb56-d6e4-4e4d-ba72-6caf35bf4957" />


## Build & Run (Swift Package Manager)
Requirements:  
Requires macOS 14+ and the Swift toolchain (`xcode-select --install`)  
RuneLite installed as a standard Mac app (no .jar support yet) (https://runelite.net)

Quick compile check:
```sh
swift build
```

Build the app bundle and run it:
```sh
./bundle.sh
open Essence.app
```

`bundle.sh` does a release `swift build`, then assembles `Essence.app` by copying
`Info.plist` and `Essence.icns` and ad-hoc signing. To see logs in the terminal:
```sh
./Essence.app/Contents/MacOS/Essence
```

## Lightweight & Mac first design

- **Swift** - Built using modern swift and swiftUI.
- **Keychain** - Securely stores information in the native macOS credential manager.
- **WebKit** — Built using WebKits WKWebView to avoid a bloated resource-heavy CEF binary.
- **Native ARM Support** - With Intel Mac support being sunsetted in the upcoming macOS 27 and the Jagex launcher still running through Rosetta 2 there was no better time to make an ARM native Jagex Launcher replacement.

## Multi-account

If youre like me and have seperate Jagex accounts you'll know how much of a pain it is to switch between them on the official launcher. Essence allows you to log into as many Jagex accounts as you'll ever need. The main window lists every character across every account. Simply sign in and click the character to launch a new RuneLite session for that character.

## Files

| File | Role |
|---|---|
| `EssenceApp.swift` | `@main` App: a single `Window`, quit-on-close delegate |
| `AppModel.swift` | `@Observable` state; login/launch/remove; webview lifecycle |
| `PickerView.swift` | The character list UI (the main-window menu) |
| `AccountStore.swift` | All accounts, persisted to Keychain |
| `Models.swift` | `GameCharacter`, `Account`, `LaunchCredentials` (Codable) |
| `Keychain.swift` | Generic Codable Keychain storage |
| `JWT.swift` | id_token payload decode (`sub`, `nickname`) |
| `JagexAuth.swift` | Two-stage OAuth as async/await + PKCE |
| `LoginWebView.swift` | AppKit WKWebView bridged to async (login only) |
| `RuneLiteLauncher.swift` | Spawns RuneLite.app with `JX_*` env vars |
| `Info.plist` | All bundle metadata (name, id, version, icon) — single source of truth |
| `bundle.sh` | Builds, then assembles `Essence.app` by copying `Info.plist` + `Essence.icns` |

## Credits & Acknowledgements
Essence is an independent, unofficial tool built by @Grydot.

- **Bolt by Adamcake** - The cross-platform RuneScape launcher that inspired this project. While Essence shares none of Bolt's code; Bolt was the conceptual starting point.
- **linux-jagex-launcher by aitoiaita** - The reference for the Jagex-account OAuth flow that Essence reimplements in Swift.
- **RuneLite** - The client Essence launches.
- **Jagex** - The Jagex Account.
- **Apple** - Built with SwiftUI, AppKit, WebKit, Security and CryptoKit.

## Disclaimer

Essence is an unofficial third-party project and is not in any way affiliated with any of the games or companies it interacts with. Said games and companies are not responsible for any problems with Essence nor any damage caused by using it.

Essence is NOT a game client. It simply runs RuneLite.app while passing the necessary arguments to login with a Jagex account. Essence has absolutely no ability to modify or automate gameplay.
