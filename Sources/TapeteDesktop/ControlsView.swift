import SwiftUI

@MainActor
struct ControlsView: View {
    @ObservedObject var rug: RugController
    var close: () -> Void = {}
    var quit: () -> Void = { NSApp.terminate(nil) }
    @State private var adjusting = false
    private let ink = Color(red: 0.22, green: 0.24, blue: 0.24)
    private let muted = Color(red: 0.45, green: 0.45, blue: 0.42)
    private let accent = Color(red: 0.48, green: 0.18, blue: 0.22)
    private let paper = Color(red: 0.97, green: 0.955, blue: 0.92)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TAPETEDESKTOP").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2.2).foregroundStyle(muted)
                    Text("Um lugar para o caos.").font(.system(size: 23, weight: .regular, design: .serif)).foregroundStyle(ink)
                }
                Spacer()
                Circle().fill(rug.isVisible ? Color(red: 0.37, green: 0.48, blue: 0.36) : muted.opacity(0.4))
                    .frame(width: 7, height: 7).padding(.top, 5)
                    .accessibilityLabel(rug.isVisible ? "Tapete visível" : "Tapete oculto")
            }.padding(.bottom, 19)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.91, green: 0.90, blue: 0.86))
                // A subtle desktop grid gives scale to the textile preview.
                Canvas { context, size in
                    for x in stride(from: CGFloat(12), to: size.width, by: 16) {
                        for y in stride(from: CGFloat(12), to: size.height, by: 16) {
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(.black.opacity(0.1)))
                        }
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 12))
                GeometryReader { geometry in
                    let canvas = RugRotation.canvasSize(baseSize: rug.size, degrees: rug.rotationDegrees)
                    let scale = min((geometry.size.width - 56) / canvas.width, (geometry.size.height - 36) / canvas.height)
                    Image(nsImage: RugArtwork.image(size: rug.size, palette: rug.palette))
                        .resizable().interpolation(.high)
                        .frame(width: rug.size.width * scale, height: rug.size.height * scale)
                        .rotationEffect(.degrees(rug.rotationDegrees))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 5)
                }.opacity(rug.opacity)
                HStack(spacing: 5) {
                    Image(systemName: rug.isLocked ? "lock.fill" : "hand.draw")
                    Text(rug.isLocked ? "TRAVADO" : "TECIDO INTERATIVO")
                }.font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(0.7)
                    .foregroundStyle(ink.opacity(0.7)).padding(.leading, 13).padding(.bottom, 11)
            }.frame(height: 174).padding(.bottom, 17)

            HStack {
                Text("Paleta").font(.system(size: 12, weight: .medium))
                Spacer()
                ForEach(RugPalette.allCases) { palette in
                    Button { rug.setPalette(palette) } label: {
                        Circle().fill(Color(cgColor: palette.colors.color(palette.colors.field)))
                            .frame(width: 21, height: 21)
                            .overlay(Circle().strokeBorder(paper, lineWidth: 3))
                            .overlay(Circle().stroke(rug.palette == palette ? ink.opacity(0.65) : Color.clear, lineWidth: 1))
                    }.buttonStyle(.plain).help(palette.title)
                        .accessibilityLabel("Paleta \(palette.title)")
                        .accessibilityAddTraits(rug.palette == palette ? .isSelected : [])
                }
            }.padding(.bottom, 17)

            HStack {
                Label("Rotação", systemImage: "rotate.right").font(.system(size: 12, weight: .medium))
                Spacer()
                Button("Quatro lados") { rug.showRotationEditor() }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.plain).foregroundStyle(muted).help("Abrir setas de giro")
                    .accessibilityLabel("Abrir setas de giro")
            }
            RotationArrows(rug: rug).padding(.top, 8).padding(.bottom, 16)

            HStack {
                Label("Opacidade", systemImage: "circle.lefthalf.filled").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int((rug.opacity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(muted).monospacedDigit()
            }
            Slider(value: Binding(get: { rug.opacity }, set: { rug.setOpacity($0) }), in: 0.15...1)
                .tint(accent).accessibilityLabel("Opacidade do tapete").padding(.top, 4).padding(.bottom, 12)
            divider

            Toggle(isOn: Binding(get: { rug.isLocked }, set: { rug.setLocked($0) })) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Travar tapete", systemImage: rug.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 12, weight: .medium))
                    Text(rug.isLocked ? "Os cliques passam para a Mesa." : (rug.settings.clothEnabled ? "Arraste para dobrar; ⌥ + arraste para mover." : "⌥ + arraste para mover; bordas redimensionam."))
                        .font(.system(size: 10)).foregroundStyle(muted)
                }
            }.toggleStyle(.switch).controlSize(.small).tint(accent).padding(.vertical, 13)
            divider

            HStack(spacing: 8) {
                action(rug.isVisible ? "Ocultar" : "Mostrar", symbol: rug.isVisible ? "eye.slash" : "eye") {
                    rug.setVisible(!rug.isVisible)
                }
                action("Centralizar", symbol: "viewfinder") { rug.center() }
                action("Alisar", symbol: "wind") { rug.flatten() }
            }.padding(.top, 14).padding(.bottom, 11)

            DisclosureGroup(isExpanded: $adjusting) {
                VStack(alignment: .leading, spacing: 11) {
                    Toggle("Dobrar ao arrastar", isOn: Binding(get: { rug.settings.clothEnabled }, set: { rug.setClothEnabled($0) }))
                        .font(.system(size: 11)).toggleStyle(.checkbox).padding(.top, 8)
                    HStack {
                        Text("Flexibilidade").font(.system(size: 10)).foregroundStyle(muted)
                        Slider(value: Binding(get: { rug.settings.flexibility }, set: { rug.setFlexibility($0) }), in: 0.5...1.6)
                            .tint(accent).accessibilityLabel("Flexibilidade do tecido")
                    }
                    Text("Arraste para dobrar o tecido no lugar. Option + arrastar move o tapete pela Mesa. Dois cliques alisam.")
                        .font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        dimension("Largura", value: rug.size.width, change: { rug.resize(width: $0) })
                        Text("×").foregroundStyle(muted)
                        dimension("Altura", value: rug.size.height, change: { rug.resize(height: $0) })
                    }.padding(.top, 9)
                    HStack(spacing: 7) {
                        Text("Mover").font(.system(size: 10)).foregroundStyle(muted)
                        Spacer()
                        moveButton("arrow.left", label: "Mover para a esquerda", dx: -20, dy: 0)
                        moveButton("arrow.up", label: "Mover para cima", dx: 0, dy: 20)
                        moveButton("arrow.down", label: "Mover para baixo", dx: 0, dy: -20)
                        moveButton("arrow.right", label: "Mover para a direita", dx: 20, dy: 0)
                    }
                    Toggle("Incluir Spaces de tela cheia", isOn: Binding(get: { rug.settings.joinsFullScreen }, set: { rug.setFullScreen($0) }))
                        .font(.system(size: 10)).toggleStyle(.checkbox)
                    Text("Presente em todos os Spaces, atrás das janelas. Em tela cheia, a visibilidade depende do macOS e do aplicativo.")
                        .font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                }.padding(.bottom, 12)
            } label: {
                Text("Tecido, tamanho e posição").font(.system(size: 10, weight: .medium)).foregroundStyle(muted)
            }.tint(muted).padding(.bottom, 14)
            divider

            HStack {
                Text("Sua Mesa, debaixo do tapete.").font(.system(size: 9)).foregroundStyle(muted)
                Spacer()
                Button("Encerrar", action: quit).font(.system(size: 10, weight: .medium)).buttonStyle(.plain).foregroundStyle(muted)
                    .keyboardShortcut("q", modifiers: .command)
            }.padding(.top, 12)
        }
        .padding(22).frame(width: 356).background(paper).foregroundStyle(ink)
        .environment(\.colorScheme, .light)
    }

    private var divider: some View { Rectangle().fill(ink.opacity(0.10)).frame(height: 1) }
    private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: symbol).font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(ink.opacity(0.10)))
        }.buttonStyle(.plain)
    }
    private func dimension(_ title: String, value: CGFloat, change: @escaping (Double) -> Void) -> some View {
        DimensionField(title: title, value: value, minimum: title == "Largura" ? 240 : 180, change: change)
    }
    private func moveButton(_ symbol: String, label: String, dx: CGFloat, dy: CGFloat) -> some View {
        Button { rug.move(dx: dx, dy: dy) } label: {
            Image(systemName: symbol).font(.system(size: 10)).frame(width: 25, height: 22)
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
        }.buttonStyle(.plain).accessibilityLabel(label).help(label)
    }
}


/// Commit on Return or focus loss, so intermediate digits are never clamped while typing.
@MainActor
private struct DimensionField: View {
    let title: String
    let value: CGFloat
    let minimum: Double
    let change: (Double) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title + " (pt)").font(.system(size: 9)).foregroundStyle(.secondary)
            TextField(title, text: $draft)
                .focused($focused).onSubmit(commit)
                .textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced))
                .accessibilityLabel(title)
                .onAppear { draft = formatted(value) }
                .onChange(of: value) { if !focused { draft = formatted($0) } }
                .onChange(of: focused) { if !$0 { commit() } }
        }
    }
    private func formatted(_ number: CGFloat) -> String { String(Int(number.rounded())) }
    private func commit() {
        guard let number = Double(draft.replacingOccurrences(of: ",", with: ".")), number.isFinite else {
            draft = formatted(value); return
        }
        let clamped = min(16_000, max(minimum, number))
        draft = String(Int(clamped.rounded())); change(clamped)
    }
}
