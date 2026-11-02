import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel

    private var accent: Color { Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.connected { connectedContent } else { connectCard }
            }
            .padding(16)
        }
        .background(Pal.bg)
        .onAppear { model.setHomeVisible(true) }
        .onDisappear { model.setHomeVisible(false) }
    }

    // MARK: not connected

    private var connectCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().trim(from: 0.0, to: 0.7).stroke(accent, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(120))
                    Text("N").font(.system(size: 34, weight: .heavy)).foregroundColor(Pal.fg)
                }
                .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOVA RIDE OS").font(.title2.weight(.heavy)).foregroundColor(Pal.fg)
                    Text("CYD-dashboard til dit løbehjul").font(.subheadline).foregroundColor(Pal.muted)
                    Text("App-version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")").font(.caption).foregroundColor(Pal.muted)
                }
                Spacer()
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Forbind")
                Hint("På boardet: Settings > PHONE APP. Scan QR-koden med kameraet, så går iPhonen på boardets Wi-Fi NOVA RIDE. Kom så tilbage hhertil og tryk Forbind.")
                Button {
                    model.connect(demo: false)
                } label: {
                    HStack { if model.connecting { ProgressView() }; Text(model.connecting ? "Forbinder…" : "Forbind til boardet") }
                }
                .buttonStyle(OutlineButtonStyle(accent: accent))
                .disabled(model.connecting)
                Button("Prøv demo uden board") { model.connect(demo: true) }
                    .buttonStyle(OutlineButtonStyle(accent: accent))
                    .disabled(model.connecting)
            }
            .card()
        }
    }

    // MARK: connected

    private var connectedContent: some View {
        VStack(spacing: 16) {
            if let design = model.standardDesign {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetCanvas(design: design, live: liveForCanvas, page: 0, theme: model.theme, mode: model.liveValues.mode, history: model.history)
                    if !(model.liveEnabled || model.demo) {
                        Hint("Live-visningen er slukket. Slå den til under Tilpas > App.")
                    } else if model.live == nil {
                        Hint("Venter på data fra boardet…")
                    }
                }
                .card()
            }

            HStack(spacing: 8) {
                Chip(text: "Telefon", on: model.info?.flags.contains(.phoneLinked) ?? false)
                Chip(text: "Løbehjul", on: model.info?.flags.contains(.scooterLinked) ?? false)
                Chip(text: "Start 20 km/t", on: model.info?.flags.contains(.startCap) ?? false)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Musik")
                HStack(spacing: 10) {
                    musicButton("backward.fill", 0)
                    musicButton("playpause.fill", 1)
                    musicButton("forward.fill", 2)
                }
            }
            .card()

            Button("Afbryd") { model.disconnect() }
                .buttonStyle(OutlineButtonStyle(accent: accent))
        }
    }

    private var liveForCanvas: LiveValues {
        var v = model.liveValues
        v.demo = model.demo
        return v
    }

    private func musicButton(_ symbol: String, _ key: Int) -> some View {
        Button {
            model.run { try await $0.music(key) }
        } label: {
            Image(systemName: symbol).font(.title2)
        }
        .buttonStyle(OutlineButtonStyle(accent: accent))
    }
}
