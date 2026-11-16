import SwiftUI

@MainActor
struct RotationEditorView: View {
    @ObservedObject var rug: RugController
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Gire pelas setas.").font(.headline)
                Spacer()
                Text(rug.orientation.title).font(.caption).foregroundStyle(.secondary)
            }
            RotationArrows(rug: rug)
            Text("Cada clique vira o tapete para um dos quatro lados. Você também pode escolher uma direção nas setas do meio.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Posição original") { rug.setRotation(0) }
                Button("Centralizar") { rug.center() }
                Spacer()
                Button("Fechar", action: close).keyboardShortcut(.cancelAction)
            }
        }.padding(20).frame(width: 330)
            .background(Color(red: 0.97, green: 0.955, blue: 0.92))
            .environment(\.colorScheme, .light)
    }
}
