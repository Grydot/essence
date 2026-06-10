import AppKit
import WebKit

/// AppKit WKWebView host that drives the Jagex login and bridges navigation
/// interception into async/await. One instance reuses a single non-persistent
/// data store across both OAuth stages, so the stage-1 login cookie carries
/// into stage-2 consent — and a fresh instance per *account* means adding a
/// second account starts at a clean login form (no silent SSO into the first).
@MainActor
public final class LoginWebView: NSObject, AuthWebPresenter, WKNavigationDelegate {
    public let window: NSWindow
    private let webView: WKWebView
    private var matcher: ((URL) -> Bool)?
    private var continuation: CheckedContinuation<URL, Error>?

    public override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        let frame = NSRect(x: 0, y: 0, width: 480, height: 720)
        webView = WKWebView(frame: frame, configuration: cfg)
        window = NSWindow(contentRect: frame,
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "Sign in to Jagex"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = webView
        webView.navigationDelegate = self
    }

    public func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() { window.orderOut(nil) }

    public func awaitRedirect(loading url: URL,
                              matches: @escaping (URL) -> Bool) async throws -> URL {
        matcher = matches
        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: WKNavigationDelegate

    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let match = matcher, match(url) {
            decisionHandler(.cancel)
            let cont = continuation
            continuation = nil
            matcher = nil
            cont?.resume(returning: url)
            return
        }
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        // "Frame load interrupted" (102) and cancellations are the expected
        // result of us cancelling the matched redirect — ignore them.
    }
}
