import Foundation

/// Persists all signed-in accounts (Codable -> Keychain). Plain class for now;
/// the SwiftUI layer will wrap/observe this next chunk.
public final class AccountStore {
    public static let service = "com.grydot.essence"
    public static let key = "accounts"

    public private(set) var accounts: [Account]

    public init() {
        accounts = (try? Keychain.load([Account].self, service: Self.service, account: Self.key)) ?? []
    }

    /// Insert or update by account id (the id_token `sub`).
    public func upsert(_ account: Account) {
        if let i = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[i] = account
        } else {
            accounts.append(account)
        }
        persist()
    }

    public func remove(id: String) {
        accounts.removeAll { $0.id == id }
        persist()
    }

    public func clear() {
        accounts.removeAll()
        Keychain.delete(service: Self.service, account: Self.key)
    }

    /// Flat list across every account — what the launch menu shows so you can
    /// fire off characters from different accounts at once.
    public var allCharacters: [(account: Account, character: GameCharacter)] {
        accounts.flatMap { acc in acc.characters.map { (acc, $0) } }
    }

    private func persist() {
        try? Keychain.save(accounts, service: Self.service, account: Self.key)
    }
}
