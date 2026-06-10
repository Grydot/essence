import SwiftUI
import AppKit

/// Window-only app (no resident menu-bar item) that quits when its window
/// closes — the lightest footprint: zero idle cost, and the saved login lives
/// in the Keychain so reopening never needs a re-login.
@main
struct EssenceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Essence", id: "main") {
            PickerView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Closing the window fully quits the app -> no background battery drain.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove the default menus we don't use. Done after launch (async) so
        // it runs once SwiftUI has finished building the menu bar.
        DispatchQueue.main.async {
            guard let main = NSApp.mainMenu else { return }
            let drop: Set<String> = ["Edit", "View", "Help"]
            for item in main.items where drop.contains(item.submenu?.title ?? "") {
                main.removeItem(item)
            }
        }
    }
}
