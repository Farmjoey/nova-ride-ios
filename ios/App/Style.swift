import SwiftUI

/// The "steel" look of the app (same palette as the web app).
enum Pal {
    static let bg = Color(red: 0.149, green: 0.149, blue: 0.149)       // #262626
    static let card = Color(red: 0.2, green: 0.2, blue: 0.2)           // #333333
    static let card2 = Color(red: 0.267, green: 0.267, blue: 0.267)    // #444444
    static let fg = Color(red: 0.925, green: 0.925, blue: 0.925)       // #ececec
    static let muted = Color(red: 0.604, green: 0.624, blue: 0.635)    // #9a9fa2
    static let line = Color(red: 0.302, green: 0.302, blue: 0.302)     // #4d4d4d
    static let ok = Color(red: 0.561, green: 0.851, blue: 0.659)       // #8fd9a8
    static let bad = Color(red: 1.0, green: 0.353, blue: 0.431)        // #ff5a6e
    static let warn = Color(red: 1.0, green: 0.69, blue: 0.0)          // #ffb000
    static let btn = Color(red: 0.839, green: 0.839, blue: 0.839)      // #d6d6d6
}

extension Color {
    init(rgb c: RGB) { self.init(red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255) }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Pal.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// Outlined button like on the board; `filled` is the accent-coloured variant.
struct OutlineButtonStyle: ButtonStyle {
    var accent: Color
    var filled = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(filled ? Color.black : Pal.fg)
            .background(RoundedRectangle(cornerRadius: 16).fill(filled ? accent : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(configuration.isPressed ? accent : Pal.btn, lineWidth: 2))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct Chip: View {
    let text: String
    let on: Bool
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundColor(on ? Pal.ok : Pal.muted)
            .overlay(Capsule().stroke(on ? Pal.ok : Pal.line, lineWidth: 1))
    }
}

struct SectionTitle: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text).font(.title3.weight(.bold)).foregroundColor(Pal.fg) }
}

struct Hint: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text).font(.subheadline).foregroundColor(Pal.muted).fixedSize(horizontal: false, vertical: true) }
}
