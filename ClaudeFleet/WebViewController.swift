import AppKit
import WebKit

class WebViewController: NSViewController, WKScriptMessageHandler {
    var webView: WKWebView!
    var onCommand: (([String: Any]) -> Void)?

    private var isWebViewLoaded = false
    private var pendingCalls: [String] = []

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let contentController = config.userContentController
        contentController.add(self, name: "fleet")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        self.view = webView

        webView.navigationDelegate = self

        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
    }

    // MARK: - JS → Swift bridge

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "fleet",
              let body = message.body as? [String: Any] else { return }
        onCommand?(body)
    }

    // MARK: - Swift → JS

    func pushState(_ stateJSON: String) {
        evaluateWhenReady("fleet._onState(\(stateJSON))")
    }

    func pushDaemonStatus(_ connected: Bool) {
        evaluateWhenReady("fleet._onDaemonStatus(\(connected))")
    }

    func pushAttentionCount(_ count: Int) {
        evaluateWhenReady("fleet._onAttentionCount(\(count))")
    }

    // MARK: - Queue

    private func evaluateWhenReady(_ js: String) {
        if isWebViewLoaded {
            webView.evaluateJavaScript(js) { _, error in
                if let error {
                    NSLog("[WebVC] JS error: \(error.localizedDescription)")
                }
            }
        } else {
            pendingCalls.append(js)
        }
    }

    private func flushPendingCalls() {
        isWebViewLoaded = true
        let calls = pendingCalls
        pendingCalls.removeAll()
        for js in calls {
            webView.evaluateJavaScript(js) { _, error in
                if let error {
                    NSLog("[WebVC] JS error (queued): \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        flushPendingCalls()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[WebVC] Navigation failed: \(error.localizedDescription)")
    }
}
