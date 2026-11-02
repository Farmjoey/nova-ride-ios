import SwiftUI
import UniformTypeIdentifiers

struct SystemView: View {
    @EnvironmentObject var model: AppModel
    @State private var section = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Område", selection: $section) {
                    Text("Enhed").tag(0)
                    Text("Opdater").tag(1)
                }
                .pickerStyle(.segmented)
                if section == 0 { DeviceSection() } else { UpdateSection() }
            }
            .padding(16)
        }
        .background(Pal.bg)
    }
}

struct DeviceSection: View {
    @EnvironmentObject var model: AppModel
    private var accent: Color { Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)) }
    private let styles = ["Klassisk", "Navn", "Billede", "Minimal"]

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundColor(Pal.muted); Spacer(); Text(v).foregroundColor(Pal.fg) }.font(.subheadline)
    }

    var body: some View {
        VStack(spacing: 16) {
            if let i = model.info {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle("Boardet")
                    row("Firmware", i.version)
                    row("Profil", i.profile)
                    row("Tema", NovaTheme.all[min(i.theme, NovaTheme.all.count - 1)].name)
                    row("Bootskærm", styles[min(i.bootStyle, 3)])
                    if !i.bootText.isEmpty { row("Tekst", i.bootText) }
                    row("Design", i.flags.contains(.customDesign) ? "Eget" : "Standard")
                    HStack(spacing: 8) {
                        Chip(text: "Telefon", on: i.flags.contains(.phoneLinked))
                        Chip(text: "Løbehjul", on: i.flags.contains(.scooterLinked))
                    }
                }
                .card()
                Button("Afbryd") { model.disconnect() }.buttonStyle(OutlineButtonStyle(accent: accent))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Ikke forbundet")
                    Hint("Forbind under Hjem for at se boardets oplysninger.")
                }.card()
            }
        }
    }
}

struct UpdateSection: View {
    @EnvironmentObject var model: AppModel
    @State private var importing = false
    @State private var file: (name: String, bytes: [UInt8])?
    private var accent: Color { Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)) }

    private var check: FirmwareCheck? { file.map { Firmware.check($0.bytes, fileName: $0.name) } }

    private func crcText(_ v: UInt32) -> String { String(format: "%08X", v) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Opdater firmware")
                Hint("1. På boardet: Settings > TOOLS > UPDATE. Hold knappen i 1,5 sekund, så åbner opdateringsvinduet (2 minutter).")
                Hint("2. Vælg den almindelige .bin-fil her (ikke .factory.bin).")
                Hint("3. Tryk Send og lad telefonen og boardet ligge stille, til boardet genstarter.")
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                Button("Vælg .bin-fil") { importing = true }
                    .buttonStyle(OutlineButtonStyle(accent: accent))
                if let f = file, let c = check {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(f.name).font(.headline).foregroundColor(Pal.fg)
                        Text("\(f.bytes.count / 1024) KB · CRC \(crcText(c.crc))").font(.footnote).foregroundColor(Pal.muted)
                        Text(c.message).font(.subheadline).foregroundColor(c.ok ? Pal.ok : Pal.bad)
                    }
                    Button("Send opdatering") {
                        let bytes = f.bytes
                        model.run("Opdaterer…") { try await $0.updateFirmware(bytes) }
                    }
                    .buttonStyle(OutlineButtonStyle(accent: accent, filled: true))
                    .disabled(!c.ok || !model.connected || model.working)
                    if !model.connected { Hint("Forbind under Hjem først.") }
                }
                if model.ota.total > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: Double(model.ota.received), total: Double(max(1, model.ota.total)))
                        Text("\(OtaText.states[min(model.ota.state.rawValue, 5)])  \(model.ota.received * 100 / max(1, model.ota.total)) %  (\(model.ota.received / 1024) / \(model.ota.total / 1024) KB)")
                            .font(.footnote).foregroundColor(Pal.muted)
                    }
                }
            }
            .card()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
            guard case .success(let url) = result else { return }
            if let f = ImageTools.readFile(url) { file = f } else { model.message = "Filen kunne ikke læses." }
        }
    }
}
