import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct TuneView: View {
    @EnvironmentObject var model: AppModel
    @State private var section = 0
    private let titles = ["Temaer", "Skærm", "Boot", "Widgets", "App"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Område", selection: $section) {
                    ForEach(0..<titles.count, id: \.self) { i in Text(titles[i]).tag(i) }
                }
                .pickerStyle(.segmented)

                if section != 3 && section != 4 && !model.connected {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle("Ikke forbundet")
                        Hint("Forbind til boardet (eller prøv demoen) under Hjem for at ændre indstillinger.")
                    }.card()
                } else {
                    switch section {
                    case 0: ThemesSection()
                    case 1: ScreenSection()
                    case 2: BootSection()
                    case 3: WidgetsSection()
                    default: AppSection()
                    }
                }
            }
            .padding(16)
        }
        .background(Pal.bg)
    }
}

// MARK: themes

struct ThemesSection: View {
    @EnvironmentObject var model: AppModel
    @State private var custom: Color = Color(red: 0.435, green: 0.639, blue: 0.659)
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(0..<(NovaTheme.all.count - 1), id: \.self) { i in
                    let t = NovaTheme.all[i]
                    Button {
                        model.run("Skifter tema…") { try await $0.setTheme(i) }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .bottomLeading) {
                                RoundedRectangle(cornerRadius: 8).fill(Color(rgb: t.bg))
                                VStack(alignment: .leading, spacing: 4) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color(rgb: t.neon)).frame(width: 60, height: 6)
                                    RoundedRectangle(cornerRadius: 3).fill(Color(rgb: t.panel)).frame(width: 90, height: 6)
                                    RoundedRectangle(cornerRadius: 3).fill(Color(rgb: t.ok)).frame(width: 40, height: 6)
                                }.padding(8)
                            }
                            .frame(height: 56)
                            Text(t.name).font(.footnote.weight(.bold)).foregroundColor(Pal.fg)
                        }
                        .padding(10)
                        .background(Pal.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(model.info?.theme == i ? Color(rgb: t.neon) : Color.clear, lineWidth: 2))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Egen farve")
                Hint("Vælg en accentfarve og brug den på boardet (tema EGEN).")
                ColorPicker("Accentfarve", selection: $custom, supportsOpacity: false).foregroundColor(Pal.fg)
                Button("Brug farven på boardet") {
                    let c = ImageTools.rgb(of: custom)
                    model.run("Sender farve…") { s in
                        try await s.setAccent(c)
                        try await s.setTheme(NovaTheme.customIndex)
                    }
                }
                .buttonStyle(OutlineButtonStyle(accent: Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)), filled: true))
            }
            .card()
        }
    }
}

// MARK: screen

struct ScreenSection: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("devBacklight") private var backlight = 80
    @AppStorage("devArc") private var arc = 0
    private let levels = [20, 40, 60, 80, 100]
    private let arcSteps: [(String, Int)] = [("Auto", 0), ("30", 6), ("35", 7), ("40", 8), ("50", 10), ("60", 12), ("80", 16)]

    private var shownBacklight: Int { model.info?.extra?[0] ?? backlight }
    private var shownArc: Int { model.info?.extra?[1] ?? arc }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Lysstyrke")
                HStack(spacing: 8) {
                    ForEach(levels, id: \.self) { l in
                        Button("\(l)%") {
                            backlight = l
                            model.run("Sender…") { try await $0.setBacklight(l) }
                        }
                        .buttonStyle(OutlineButtonStyle(accent: Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)), filled: shownBacklight == l))
                    }
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Fartmåler")
                Hint("Hvor stor farten kan blive på buen. Auto vokser med farten.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(arcSteps, id: \.1) { a in
                        Button(a.0) {
                            arc = a.1
                            model.run("Sender…") { try await $0.setArcMax(a.1) }
                        }
                        .buttonStyle(OutlineButtonStyle(accent: Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)), filled: shownArc == a.1))
                    }
                }
            }
            .card()
        }
    }
}

// MARK: boot screen

struct BootSection: View {
    @EnvironmentObject var model: AppModel
    @State private var text = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var gray: [UInt8]?
    @State private var threshold: Double = 128
    @State private var invert = false
    private let styles = ["Klassisk", "Navn", "Billede", "Minimal"]
    private var accent: Color { Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)) }

    private var packed: [UInt8]? { gray.map { BootImage.pack(gray: $0, threshold: Int(threshold), invert: invert) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Stil")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(0..<styles.count, id: \.self) { i in
                        Button(styles[i]) { model.run("Sender…") { try await $0.setBootStyle(i) } }
                            .buttonStyle(OutlineButtonStyle(accent: accent, filled: model.info?.bootStyle == i))
                    }
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Tekst")
                Hint("Op til 15 tegn (kun almindelige bogstaver og tal).")
                TextField("Dit navn", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { new in
                        let clean = Frames.sanitizeBootText(new)
                        if clean != new { text = clean }
                    }
                Button("Send tekst") { model.run("Sender…") { try await $0.setBootText(text) } }
                    .buttonStyle(OutlineButtonStyle(accent: accent))
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Billede")
                Hint("Billedet bliver sort/hvidt og 128 x 64 punkter. Vælg Billede som stil bagefter.")
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(gray == nil ? "Vælg billede" : "Vælg et andet billede").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Pal.btn, lineWidth: 2))
                        .foregroundColor(Pal.fg)
                }
                if let bits = packed {
                    BootPreview(bits: bits, color: Color(rgb: model.theme.neon))
                        .frame(height: 128)
                    HStack { Text("Lysstyrke").foregroundColor(Pal.muted); Slider(value: $threshold, in: 20...235) }
                    Toggle("Byt lys og mørk", isOn: $invert).foregroundColor(Pal.fg)
                    Button("Send billede til boardet") {
                        model.run("Sender billede…") { s in
                            try await s.sendBootImage(bits)
                            try await s.setBootStyle(2)
                        }
                    }
                    .buttonStyle(OutlineButtonStyle(accent: accent, filled: true))
                }
                Button("Vis bootskærmen på boardet nu") { model.run { try await $0.previewBoot() } }
                    .buttonStyle(OutlineButtonStyle(accent: accent))
            }
            .card()
        }
        .onChange(of: pickerItem) { item in
            guard let item = item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    gray = ImageTools.gray128x64(from: img)
                    if gray == nil { model.message = "Billedet kunne ikke læses." }
                } else { model.message = "Billedet kunne ikke læses." }
            }
        }
    }
}

struct BootPreview: View {
    let bits: [UInt8]
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / CGFloat(Nova.bootImageWidth)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            for y in 0..<Nova.bootImageHeight {
                for x in 0..<Nova.bootImageWidth where BootImage.pixel(bits, x: x, y: y) {
                    ctx.fill(Path(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s, height: s)), with: .color(color))
                }
            }
        }
        .aspectRatio(2, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: widgets

struct WidgetsSection: View {
    @EnvironmentObject var model: AppModel
    @State private var importing = false
    private var accent: Color { Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)) }
    private let sampleHistory = WidgetHistory.sample()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Din skærm")
                Hint("Vælg et design nedenfor og installer det. Den visuelle editor (flyt og tilpas elementer) findes i web-appen (Bluefy eller Chrome).")
                if model.connected {
                    Button("Vis standard-designet") { model.run("Skifter…") { try await $0.useOwnDesign(false) } }
                        .buttonStyle(OutlineButtonStyle(accent: accent))
                    if model.info?.flags.contains(.designStored) == true {
                        Button("Vis mit installerede design") { model.run("Skifter…") { try await $0.useOwnDesign(true) } }
                            .buttonStyle(OutlineButtonStyle(accent: accent))
                    }
                    Button("Importér design fra en fil") { importing = true }
                        .buttonStyle(OutlineButtonStyle(accent: accent))
                } else {
                    Hint("Forbind (eller prøv demoen) under Hjem for at installere et design.")
                }
            }
            .card()

            ForEach(0..<model.starters.count, id: \.self) { i in
                let d = model.starters[i]
                VStack(alignment: .leading, spacing: 10) {
                    WidgetCanvas(design: d.json, live: LiveValues.sample(t: 3), page: 0, theme: model.theme, mode: 2, history: sampleHistory)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.name).font(.headline).foregroundColor(Pal.fg)
                            if !d.detail.isEmpty { Text(d.detail).font(.footnote).foregroundColor(Pal.muted) }
                            Text(d.pages > 1 ? "\(d.pages) sider" : "1 side").font(.caption).foregroundColor(Pal.muted)
                        }
                        Spacer()
                    }
                    Button("Installér") {
                        model.run("Installerer design…") { try await $0.installDesign(d.json) }
                    }
                    .buttonStyle(OutlineButtonStyle(accent: accent, filled: true))
                    .disabled(!model.connected)
                }
                .card()
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { result in
            guard case .success(let url) = result, let f = ImageTools.readFile(url) else { model.message = "Filen kunne ikke læses."; return }
            guard let json = Widget.parse(json: Data(f.bytes)) else { model.message = "Filen er ikke et gyldigt design (JSON)."; return }
            let errors = Widget.validateFile(json)
            if let first = errors.first { model.message = "Designet kan ikke bruges: \(first)"; return }
            model.run("Installerer design…") { try await $0.installDesign(json) }
        }
    }
}

// MARK: app settings

struct AppSection: View {
    @EnvironmentObject var model: AppModel
    @State private var accent: Color = Color(red: 0.435, green: 0.639, blue: 0.659)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Live-visning")
                Hint("Når den er slået til, spørger appen boardet om fart, batteri og effekt to gange i sekundet, mens du kigger på Hjem.")
                Toggle("Vis live-data på Hjem", isOn: $model.liveEnabled).foregroundColor(Pal.fg)
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Udseende")
                ColorPicker("Appens accentfarve", selection: Binding(
                    get: { Color(rgb: RGB(hex: model.accentHex) ?? RGB(111, 163, 168)) },
                    set: { model.accentHex = ImageTools.rgb(of: $0).hex }), supportsOpacity: false)
                    .foregroundColor(Pal.fg)
            }
            .card()
        }
    }
}
