import Foundation

/// A single character that can be launched. `id` is Jagex's per-character
/// accountId, which becomes JX_CHARACTER_ID.
public struct GameCharacter: Codable, Identifiable, Hashable, Sendable {
    public let id: String          // -> JX_CHARACTER_ID
    public let displayName: String  // -> JX_DISPLAY_NAME
    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

/// One signed-in Jagex *account*. `id` is the stable `sub` claim from the
/// account's id_token, so re-logging in updates the same record. Each account
/// carries its own game session and character list.
public struct Account: Codable, Identifiable, Sendable {
    public let id: String          // Jagex account subject (sub) — stable key
    public var nickname: String     // display label, from the id_token
    public var sessionId: String    // -> JX_SESSION_ID
    public var refreshToken: String?
    public var characters: [GameCharacter]
    public init(id: String, nickname: String, sessionId: String,
                refreshToken: String?, characters: [GameCharacter]) {
        self.id = id
        self.nickname = nickname
        self.sessionId = sessionId
        self.refreshToken = refreshToken
        self.characters = characters
    }
}

/// The three values a launched RuneLite process needs for a Jagex account.
public struct LaunchCredentials: Sendable {
    public let sessionId: String     // JX_SESSION_ID
    public let characterId: String   // JX_CHARACTER_ID
    public let displayName: String   // JX_DISPLAY_NAME
    public init(account: Account, character: GameCharacter) {
        self.sessionId = account.sessionId
        self.characterId = character.id
        self.displayName = character.displayName
    }
}
