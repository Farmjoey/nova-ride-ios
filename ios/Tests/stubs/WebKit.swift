// Stand-in for Apple's WebKit, only to type-check the app on a PC.
import Foundation
import UIKit
open class WKUserContentController { public init() {}; public func add(_ handler: WKScriptMessageHandler, name: String) {} }
open class WKWebViewConfiguration { public init() {}; public var userContentController = WKUserContentController() }
open class WKScriptMessage { public var body: Any = 0 }
public protocol WKScriptMessageHandler: AnyObject { func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) }
open class WKWebView: UIView {
    public init(frame: CGRect, configuration: WKWebViewConfiguration) { super.init() }
    public func loadFileURL(_ url: URL, allowingReadAccessTo readAccessURL: URL) {}
    public func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {}
}

// ---- used by the version-3 shell app (signatures follow the real WebKit)
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
open class WKNavigation {}
open class WKWebsiteDataStore { public static func `default`() -> WKWebsiteDataStore { WKWebsiteDataStore() } }
public protocol WKNavigationDelegate: AnyObject {}
extension WKWebViewConfiguration { public var websiteDataStore: WKWebsiteDataStore { get { .default() } set {} } }
extension WKWebView {
    public var scrollView: UIScrollView { UIScrollView() }
    public var backgroundColor: UIColor? { get { nil } set {} }
    public weak var navigationDelegate: WKNavigationDelegate? { get { nil } set {} }
    @discardableResult public func load(_ request: URLRequest) -> WKNavigation? { nil }
}
