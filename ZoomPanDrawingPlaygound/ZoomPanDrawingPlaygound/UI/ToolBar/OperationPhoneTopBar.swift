import SwiftUI

struct OperationPhoneTopBar: View {
    @Binding var interactionMode: InteractionMode
    let viewportScale: CGFloat

    var onBack: () -> Void
    var onResetZoom: () -> Void
    var onForceQuit: () -> Void
    var onOpenConfig: () -> Void

    var body: some View {
        HStack() {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 44, height: 34)
                    .contentShape(Rectangle())
            }

            modeButton("確認", .normal)
            modeButton("描画", .drawing)
            modeButton("文字認識", .camera)

            Spacer()

            Button("リセット") { onResetZoom() }

            Button(action: onForceQuit) {
                Text("強制終了")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.red.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button(action: onOpenConfig) {
                Image(systemName: "gearshape")
                    .font(.headline)
                    .frame(width: 44, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func modeButton(_ title: String, _ mode: InteractionMode) -> some View {
        Button { interactionMode = mode } label: {
            Text(title)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(interactionMode == mode ? Color.blue.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
