import SwiftUI

@MainActor
struct RotationArrows: View {
    @ObservedObject var rug: RugController
    private let accent = Color(red: 0.48, green: 0.18, blue: 0.22)

    var body: some View {
        HStack(spacing: 7) {
            Button { rug.turnCounterclockwise() } label: {
                Image(systemName: "rotate.left").font(.system(size: 17, weight: .medium))
                    .frame(width: 35, height: 36)
            }.buttonStyle(.plain).foregroundStyle(accent)
                .accessibilityLabel("Girar para a esquerda").help("Girar para o lado anterior")
            Spacer(minLength: 0)
            ForEach(RugOrientation.allCases) { side in
                Button { rug.setRotation(side.degrees) } label: {
                    Image(systemName: side.symbol).font(.system(size: 15, weight: .semibold))
                        .frame(width: 35, height: 36)
                        .foregroundStyle(rug.orientation == side ? Color.white : Color.primary.opacity(0.7))
                        .background(rug.orientation == side ? accent : Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.black.opacity(0.07)))
                }.buttonStyle(.plain).accessibilityLabel("Virar " + side.title.lowercased())
                    .accessibilityAddTraits(rug.orientation == side ? .isSelected : [])
                    .help(side.title)
            }
            Spacer(minLength: 0)
            Button { rug.turnClockwise() } label: {
                Image(systemName: "rotate.right").font(.system(size: 17, weight: .medium))
                    .frame(width: 35, height: 36)
            }.buttonStyle(.plain).foregroundStyle(accent)
                .accessibilityLabel("Girar para a direita").help("Girar para o próximo lado")
        }
    }
}
