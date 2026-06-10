import Foundation

public enum LaunchError: Error, CustomStringConvertible {
    case notFound(String)
    case spawn(String)
    public var description: String {
        switch self {
        case .notFound(let p): return "RuneLite not found at \(p)."
        case .spawn(let m): return "Failed to launch RuneLite: \(m)."
        }
    }
}

/// Launches RuneLite.app with Jagex credentials as JX_* environment variables.
/// Each call spawns an independent process, so characters from different
/// accounts can run at the same time.
public enum RuneLiteLauncher {
    @discardableResult
    public static func launch(_ creds: LaunchCredentials,
                              appPath: String = "/Applications/RuneLite.app") throws -> Process {
        let exe = (appPath as NSString).appendingPathComponent("Contents/MacOS/RuneLite")
        guard FileManager.default.isExecutableFile(atPath: exe) else {
            throw LaunchError.notFound(exe)
        }
        var env = ProcessInfo.processInfo.environment
        env["JX_SESSION_ID"]   = creds.sessionId
        env["JX_CHARACTER_ID"] = creds.characterId
        env["JX_DISPLAY_NAME"] = creds.displayName

        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.environment = env
        do {
            try p.run()
        } catch {
            throw LaunchError.spawn(error.localizedDescription)
        }
        return p
    }
}
