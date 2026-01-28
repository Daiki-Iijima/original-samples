import SwiftUI

struct OperationiPadTopBar: View {
    @Binding var interactionMode: InteractionMode
    @Binding var isRectListVisible: Bool
    let viewportScale: CGFloat

    @Binding var imageKey: String
    @Binding var drawingKey: String
    @Binding var isUnconfirmedPartsVisible: Bool

    var onResetZoom: () -> Void
    var onSaveLocal: () -> Void
    var onLoadLocal: () -> Void
    var onSavePhotos: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                modeButton("確認モード", .normal)
                modeButton("描画モード", .drawing)
                modeButton("Zoom指定", .zoomPreset)
                modeButton("Rect追加", .rectPreset)

                Spacer()

                Button("未確認部材一覧") {isUnconfirmedPartsVisible.toggle()}
                Button("Rect一覧") { isRectListVisible.toggle() }
                Button("Reset Zoom") { onResetZoom() }

                Text(String(format: "scale: %.2f", viewportScale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField("imageKey", text: $imageKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)

                TextField("drawingKey", text: $drawingKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Button("Save(Local)") { onSaveLocal() }
                Button("Load(Local)") { onLoadLocal() }

                Spacer()

                Button("Save(Photos)") { onSavePhotos() }
            }
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

#Preview {
    @Previewable @State var interactionMode: InteractionMode = .normal
    @Previewable @State var isRectListVisible = false
    @Previewable @State var isUnconfirmedPartsVisible = false
    @Previewable @State var imageKey = "sample1"
    @Previewable @State var drawingKey = "v1"

    OperationiPadTopBar(
        interactionMode: $interactionMode,
        isRectListVisible: $isRectListVisible,
        viewportScale: 1.23,
        imageKey: $imageKey,
        drawingKey: $drawingKey,
        isUnconfirmedPartsVisible: $isUnconfirmedPartsVisible,
        onResetZoom: {},
        onSaveLocal: {},
        onLoadLocal: {},
        onSavePhotos: {}
    )
    .padding()
}
