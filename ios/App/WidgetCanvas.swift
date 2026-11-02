import SwiftUI

/// A design drawn at 320 x 240 scaled to the available width.
struct WidgetCanvas: View {
    let design: [String: Any]
    let live: LiveValues
    var page = 0
    let theme: NovaTheme
    var mode: Int? = nil
    var history: WidgetHistory? = nil

    var body: some View {
        Canvas { ctx, size in
            WidgetPainter.paint(ctx, size: size, design: design, live: live, page: page, theme: theme, mode: mode, history: history)
        }
        .aspectRatio(320.0 / 240.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Pal.line, lineWidth: 1))
    }
}
