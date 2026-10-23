import AppKit
import WebKit

// What the web view needs from the app: links, downloads, file pickers and JavaScript dialogs.
extension AppDelegate: WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard webView.url?.host == "localhost", let overlay = loading else { return }
    loading = nil
    overlay.dismiss()
  }

  // External links and new windows open in the default browser
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if let u = navigationAction.request.url { NSWorkspace.shared.open(u) }
    return nil
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if navigationAction.shouldPerformDownload { decisionHandler(.download); return }
    if let u = navigationAction.request.url, navigationAction.navigationType == .linkActivated,
       let host = u.host, host != "localhost" {
      NSWorkspace.shared.open(u)
      decisionHandler(.cancel)
      return
    }
    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
               decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
    decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
  }

  // Exports (PNG etc.) go to ~/Downloads, numbered instead of overwriting
  func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
  func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
  func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
    let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    let base = (suggestedFilename as NSString).deletingPathExtension
    let ext = (suggestedFilename as NSString).pathExtension
    var dest = dir.appendingPathComponent(suggestedFilename)
    var n = 1
    while FileManager.default.fileExists(atPath: dest.path) {
      dest = dir.appendingPathComponent("\(base) \(n)" + (ext.isEmpty ? "" : ".\(ext)"))
      n += 1
    }
    completionHandler(dest)
  }

  // File upload
  func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = parameters.allowsMultipleSelection
    panel.canChooseDirectories = parameters.allowsDirectories
    panel.begin { completionHandler($0 == .OK ? panel.urls : nil) }
  }

  // alert · confirm
  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
    alert(message)
    completionHandler()
  }

  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
    completionHandler(alert(message, buttons: ["OK", "Cancel"]) == .alertFirstButtonReturn)
  }
}
