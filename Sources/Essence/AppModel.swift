import SwiftUI
import AppKit

/// Observable state for the picker. Holds the accounts and drives login/launch.
/// The login WKWebView is created on demand and released right after, so no
/// browser engine stays resident.
@MainActor
@Observable
final class AppModel {
    private let store = AccountStore()
    var accounts: [Account] = []
    var errorMessage: String?
    var isLoggingIn = false

    private var loginWindow: LoginWebView?

    init() { accounts = store.accounts }

    func launch(account: Account, character: GameCharacter) {
        errorMessage = nil
        do {
            try RuneLiteLauncher.launch(LaunchCredentials(account: account, character: character))
        } catch {
            errorMessage = "\(error)"
        }
    }

    func remove(_ account: Account) {
        store.remove(id: account.id)
        accounts = store.accounts
    }

    func beginLogin() {
        guard !isLoggingIn else { return }
        errorMessage = nil
        isLoggingIn = true

        let web = LoginWebView()
        loginWindow = web
        web.show()

        Task {
            defer {
                web.close()
                loginWindow = nil      // tear down the webview/browser process
                isLoggingIn = false
            }
            do {
                let account = try await JagexAuth.login(presenter: web)
                store.upsert(account)
                accounts = store.accounts
            } catch {
                errorMessage = "\(error)"
            }
        }
    }
}
