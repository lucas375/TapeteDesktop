import SwiftUI

@MainActor
struct SizeEditorView: View {
    private let apply: (CGSize) -> Void
    private let cancel: () -> Void
    @State private var width: String
    @State private var height: String
    @FocusState private var focused: Bool

    init(size: CGSize, apply: @escaping (CGSize) -> Void, cancel: @escaping () -> Void) {
        self.apply = apply; self.cancel = cancel
        _width = State(initialValue: String(Int(size.width.rounded())))
        _height = State(initialValue: String(Int(size.height.rounded())))
    }

    private var validSize: CGSize? {
        guard let w = Double(width.replacingOccurrences(of: ",", with: ".")),
              let h = Double(height.replacingOccurrences(of: ",", with: ".")),
              w.isFinite, h.isFinite, (240...16_000).contains(w), (180...16_000).contains(h) else { return nil }
        return CGSize(width: w, height: h)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Escolha o tamanho do tapete.").font(.headline)
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Largura (pt)").font(.caption).foregroundStyle(.secondary)
                    TextField("Largura", text: $width).focused($focused)
                        .accessibilityLabel("Largura do tapete")
                }
                Text("×").foregroundStyle(.secondary).padding(.top, 20)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Altura (pt)").font(.caption).foregroundStyle(.secondary)
                    TextField("Altura", text: $height).accessibilityLabel("Altura do tapete")
                }
            }.textFieldStyle(.roundedBorder)
            Text(validSize == nil ? "Use largura de 240 a 16.000 e altura de 180 a 16.000 pontos." : "O tapete mantém o centro ao mudar de tamanho.")
                .font(.caption).foregroundStyle(validSize == nil ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancelar", action: cancel).keyboardShortcut(.cancelAction)
                Button("Aplicar") { if let size = validSize { apply(size) } }
                    .keyboardShortcut(.defaultAction).disabled(validSize == nil)
            }
        }.padding(20).frame(width: 320)
            .background(Color(red: 0.97, green: 0.955, blue: 0.92))
            .environment(\.colorScheme, .light)
            .onAppear { focused = true }
    }
}
