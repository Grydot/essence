import Foundation
import Security
import CryptoKit

public enum AuthError: Error, CustomStringConvertible {
    case parse(String)
    case server(String, Int, String)   // stage, http status, body
    public var description: String {
        switch self {
        case .parse(let what): return "Could not parse \(what)."
        case .server(let stage, let code, let body):
            return "\(stage) failed (HTTP \(code)): \(body.prefix(200))"
        }
    }
}

/// Presents the Jagex login and resolves with the redirect URL that matches.
/// Implemented by the AppKit LoginWebView; kept abstract so JagexAuth stays
/// decoupled from UI and unit-testable.
@MainActor
public protocol AuthWebPresenter: AnyObject {
    func awaitRedirect(loading url: URL, matches: @escaping (URL) -> Bool) async throws -> URL
}

public enum JagexAuth {
    // Real endpoints (same two-stage flow proven in the Obj-C version).
    static let authURL          = "https://account.jagex.com/oauth2/auth"
    static let tokenURL         = "https://account.jagex.com/oauth2/token"
    static let launcherClient   = "com_jagex_auth_desktop_launcher"
    static let launcherRedirect = "https://secure.runescape.com/m=weblogin/launcher-redirect"
    static let consentClient    = "1fddee4e-b100-4f4e-b2b0-097f9088f9d2"
    static let consentRedirect  = "http://localhost"
    static let sessionsEndpoint = "https://auth.jagex.com/game-session/v1/sessions"
    static let accountsEndpoint = "https://auth.jagex.com/game-session/v1/accounts"

    // MARK: - Orchestration

    /// Runs the full interactive login and returns a populated Account.
    @MainActor
    public static func login(presenter: AuthWebPresenter) async throws -> Account {
        let verifier = randomURLSafe(48)
        let challenge = pkceChallenge(verifier)
        let state1 = randomURLSafe(9)

        // Stage 1: launcher login -> capture code (jagex: bounce or query form).
        let cb1 = try await presenter.awaitRedirect(loading: launcherAuthURL(challenge: challenge, state: state1)) { url in
            url.scheme == "jagex"
                || (url.absoluteString.hasPrefix(launcherRedirect) && (url.query?.contains("code=") ?? false))
        }
        guard let (code, st1) = launcherCode(from: cb1) else { throw AuthError.parse("launcher code") }
        if let st1, st1 != state1 { throw AuthError.parse("state mismatch") }

        let tokens = try await exchangeToken(code: code, verifier: verifier)
        let refresh = tokens["refresh_token"] as? String

        // Stage 2: consent -> capture id_token from the localhost fragment.
        let state2 = randomURLSafe(9)
        let nonce  = randomURLSafe(18)
        let cb2 = try await presenter.awaitRedirect(loading: consentAuthURL(state: state2, nonce: nonce)) { url in
            url.absoluteString.hasPrefix(consentRedirect)
        }
        guard let idToken = consentIDToken(from: cb2) else { throw AuthError.parse("id_token") }

        let claims = JWT.payload(idToken) ?? [:]
        let sub = (claims["sub"] as? String) ?? UUID().uuidString
        let nickname = (claims["nickname"] as? String) ?? "Account"

        // Stage 3: game session + characters.
        let sessionId = try await fetchGameSession(idToken: idToken)
        let characters = try await fetchAccounts(sessionId: sessionId)

        return Account(id: sub, nickname: nickname, sessionId: sessionId,
                       refreshToken: refresh, characters: characters)
    }

    // MARK: - Network steps (pure async, unit-testable)

    static func exchangeToken(code: String, verifier: String) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var comps = URLComponents()
        comps.queryItems = [
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "client_id", value: launcherClient),
            .init(name: "code", value: code),
            .init(name: "redirect_uri", value: launcherRedirect),
            .init(name: "code_verifier", value: verifier),
        ]
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.server("token exchange", status, String(data: data, encoding: .utf8) ?? "")
        }
        return obj
    }

    public static func fetchGameSession(idToken: String) async throws -> String {
        var req = URLRequest(url: URL(string: sessionsEndpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["idToken": idToken])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sid = obj["sessionId"] as? String else {
            throw AuthError.server("game session", code, String(data: data, encoding: .utf8) ?? "")
        }
        return sid
    }

    public static func fetchAccounts(sessionId: String) async throws -> [GameCharacter] {
        var req = URLRequest(url: URL(string: accountsEndpoint)!)
        req.setValue("Bearer \(sessionId)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw AuthError.server("accounts", code, String(data: data, encoding: .utf8) ?? "")
        }
        return arr.compactMap { d in
            guard let id = d["accountId"] as? String else { return nil }
            return GameCharacter(id: id, displayName: (d["displayName"] as? String) ?? "")
        }
    }

    // MARK: - URL building

    static func launcherAuthURL(challenge: String, state: String) -> URL {
        var c = URLComponents(string: authURL)!
        c.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: launcherClient),
            .init(name: "redirect_uri", value: launcherRedirect),
            .init(name: "scope", value: "openid offline gamesso.token.create user.profile.read"),
            .init(name: "state", value: state),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]
        return c.url!
    }

    static func consentAuthURL(state: String, nonce: String) -> URL {
        var c = URLComponents(string: authURL)!
        c.queryItems = [
            .init(name: "response_type", value: "id_token code"),
            .init(name: "client_id", value: consentClient),
            .init(name: "redirect_uri", value: consentRedirect),
            .init(name: "scope", value: "openid offline"),
            .init(name: "state", value: state),
            .init(name: "nonce", value: nonce),
        ]
        return c.url!
    }

    // MARK: - Callback parsing

    static func launcherCode(from url: URL) -> (code: String, state: String?)? {
        if url.scheme == "jagex" {
            let s = url.absoluteString
            let body = s.hasPrefix("jagex:") ? String(s.dropFirst("jagex:".count)) : s
            let p = pairs(body, separator: ",")
            if let c = p["code"] { return (c, p["state"]) }
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = comps.queryItems {
            var d: [String: String] = [:]
            for i in items { d[i.name] = i.value }
            if let c = d["code"] { return (c, d["state"]) }
        }
        return nil
    }

    static func consentIDToken(from url: URL) -> String? {
        guard let frag = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else { return nil }
        return pairs(frag, separator: "&")["id_token"]
    }

    static func pairs(_ s: String, separator: Character) -> [String: String] {
        var out: [String: String] = [:]
        for part in s.split(separator: separator) {
            guard let eq = part.firstIndex(of: "=") else { continue }
            let k = String(part[part.startIndex..<eq])
            let v = String(part[part.index(after: eq)...])
            out[k] = v.removingPercentEncoding ?? v
        }
        return out
    }

    // MARK: - PKCE helpers

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func randomURLSafe(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64url(Data(bytes))
    }

    static func pkceChallenge(_ verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return base64url(Data(hash))
    }
}
