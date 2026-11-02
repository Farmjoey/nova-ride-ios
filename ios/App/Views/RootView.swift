import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            if !model.message.isEmpty || !model.status.isEmpty { Banner() }
            TabView(selection: $tab) {
                HomeView().tabItem { Label("Hjem", systemImage: "house") }.tag(0)
                TuneView().tabItem { Label("Tilpas", systemImage: "paintpalette") }.tag(1)
                SafetyView().tabItem { Label("Sikkerhed", systemImage: "shield") }.tag(2)
                SystemView().tabItem { Label("System", systemImage: "gearshape") }.tag(3)
            }
        }
        .background(Pal.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .tint(Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)))
    }
}

struct HeaderBar: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Text("NOVA").foregroundColor(Pal.fg)
                Text("RIDE").foregroundColor(Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)))
            }
            .font(.system(size: 22, weight: .heavy))
            .tracking(4)
            Spacer()
            Text(model.connected ? (model.demo ? "Demo" : "Forbundet") : "Ikke forbundet")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundColor(model.connected ? Pal.ok : Pal.muted)
                .background(Pal.card)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Pal.bg)
    }
}

struct Banner: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 6) {
            if !model.message.isEmpty {
                HStack(alignment: .top) {
                    Text(model.message).font(.subheadline).foregroundColor(Pal.fg).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button { model.message = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Pal.muted) }
                }
                .padding(12)
                .background(Color(red: 0.25, green: 0.18, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Pal.warn.opacity(0.6), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if !model.status.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(model.status).font(.subheadline).foregroundColor(Pal.fg).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(12)
                .background(Pal.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }
}
