// NOVA RIDE for iPhone (version 3, M5Stack StickS3).
// The app the stick serves over its own Wi-Fi (http://192.168.4.1) is shown full screen in a web view, so the iPhone app always
// matches the firmware on the stick: the code (PIN), the dashboard editor, locking, updates - everything comes from the stick.
// Without the stick's Wi-Fi a native screen explains how to connect; "Demo" opens the copy of the app bundled with this build.
import SwiftUI
import UIKit
import WebKit

@main
struct NovaRideApp: App {
    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.dark)
        }
    }
}

/// Is the stick's web server reachable? (One INFO request, exactly like the web app's first command.)
final class StickFinder: ObservableObject {
    static let appURL = URL(string: "http://192.168.4.1/")!
    @Published var reachable: Bool? = nil        // nil = checking right now

    func check() {
        reachable = nil
        var req = URLRequest(url: URL(string: "http://192.168.4.1/api/ctrl")!,
                             cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3)
        req.httpMethod = "POST"
        req.httpBody = Data([0x01])
        URLSession.shared.dataTask(with: req) { data, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200 && data?.first == 0x01
            DispatchQueue.main.async { self.reachable = ok }
        }.resume()
    }
}

enum Page: Equatable { case connect, stick, demo }

struct RootView: View {
    @StateObject private var finder = StickFinder()
    @State private var page: Page = .connect
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch page {
            case .stick:
                WebView(url: StickFinder.appURL, isFile: false, onFail: { page = .connect; finder.check() })
                    .ignoresSafeArea(.container, edges: .bottom)
            case .demo:
                if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
                    VStack(spacing: 0) {
                        HStack {
                            Button("‹ Tilbage") { page = .connect; finder.check() }
                                .foregroundColor(.orange)
                            Spacer()
                            Text("Demo").foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        WebView(url: url, isFile: true, onFail: {})
                    }
                } else {
                    Text("Demo-appen mangler i denne bygning.").foregroundColor(.gray)
                }
            case .connect:
                ConnectView(finder: finder, onDemo: { page = .demo })
            }
        }
        .onAppear { finder.check() }
        .onChange(of: finder.reachable) { ok in
            if ok == true && page == .connect { page = .stick }
        }
        .onChange(of: phase) { p in
            if p == .active && page == .connect { finder.check() }   // back from Settings after joining the Wi-Fi
        }
    }
}

struct ConnectView: View {
    @ObservedObject var finder: StickFinder
    let onDemo: () -> Void
    private let orange = Color(red: 1.0, green: 0.48, blue: 0.1)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                (Text("NOVA ").foregroundColor(.white) + Text("RIDE").foregroundColor(orange))
                    .font(.system(size: 22, weight: .bold)).tracking(3)
                    .padding(.top, 24)
                VStack(alignment: .leading, spacing: 12) {
                    Text(finder.reachable == nil ? "Leder efter stick'en…" : "Ikke forbundet til stick'en")
                        .font(.title3.bold()).foregroundColor(.white)
                    step(1, "På stick'en: hold B (sideknappen) for MENU, tryk B ned til PHONE APP og tryk A.")
                    step(2, "Scan QR-koden med kameraet, eller gå på Wi-Fi'et NOVA RIDE i Indstillinger (koden står på stick'en).")
                    step(3, "Kom tilbage hertil – appen forbinder af sig selv.")
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.07)))

                if finder.reachable == nil {
                    HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                }
                Button(action: { finder.check() }) {
                    Text("Prøv igen").font(.headline).frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(orange)).foregroundColor(.black)
                }
                Button(action: {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }) {
                    Text("Åbn Indstillinger").font(.headline).frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12))).foregroundColor(.white)
                }
                Button(action: onDemo) {
                    Text("Prøv demo uden stick").font(.headline).frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12))).foregroundColor(.white)
                }
                Text("Første gang spørger iPhone om adgang til det lokale netværk: tryk Tillad.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.subheadline.bold()).foregroundColor(.black)
                .frame(width: 26, height: 26).background(Circle().fill(orange))
            Text(text).font(.subheadline).foregroundColor(Color(white: 0.75))
        }
    }
}

/// The stick's app in a web view. Cookies and localStorage (a remembered code) are kept between launches.
struct WebView: UIViewRepresentable {
    let url: URL
    let isFile: Bool
    let onFail: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFail: onFail) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.scrollView.contentInsetAdjustmentBehavior = .never   // the page handles the safe areas itself (viewport-fit=cover)
        view.navigationDelegate = context.coordinator
        if isFile {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8))
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onFail: () -> Void
        init(onFail: @escaping () -> Void) { self.onFail = onFail }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onFail()
        }
    }
}
