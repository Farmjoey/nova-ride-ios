import SwiftUI

struct SafetyView: View {
    @EnvironmentObject var model: AppModel

    private var capOn: Binding<Bool> {
        Binding(
            get: { model.info?.flags.contains(.startCap) ?? false },
            set: { on in model.run("Sender…") { try await $0.setStartCap(on) } }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Start-begrænsning")
                    Hint("Begrænser løbehjulet til 20 km/t, hver gang boardet får forbindelse til det. Det kan kun slås til og fra her i appen.")
                    if model.connected {
                        Toggle("Begræns til 20 km/t ved hver start", isOn: capOn).foregroundColor(Pal.fg)
                        Chip(text: model.info?.flags.contains(.startCap) == true ? "Slået til" : "Slået fra",
                             on: model.info?.flags.contains(.startCap) == true)
                    } else {
                        Hint("Forbind (eller prøv demoen) under Hjem for at ændre den.")
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Gode at vide")
                    Hint("Den lovlige grænse for el-løbehjul på offentlig vej i Danmark er 20 km/t.")
                    Hint("Begrænsningen sættes igen, hver gang boardet og løbehjulet får forbindelse. På boardet kan du løfte den for én tur (stryg op på skærmen og hold knappen).")
                }
                .card()
            }
            .padding(16)
        }
        .background(Pal.bg)
    }
}
