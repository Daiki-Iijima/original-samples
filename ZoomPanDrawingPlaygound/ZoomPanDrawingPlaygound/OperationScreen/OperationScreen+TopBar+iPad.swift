import DrawingKit
import SwiftUI

extension OperationScreen {

    var topBarLayer: some View {
        VStack {
            topBar
            Spacer()
        }
        .padding()
    }

    var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                modeButton("Normal", .normal)
                modeButton("描画", .drawing)
                modeButton("Zoom指定", .zoomPreset)
                modeButton("Rect追加", .rectPreset)

                Spacer()

                Button("Rect一覧") { isRectListVisible.toggle() }

                Button("Reset Zoom") { zoomRequest = .reset }

                Text(String(format: "scale: %.2f", viewportState.scale))
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

                Button("Save(Local)") { saveDrawingLocal() }
                Button("Load(Local)") { loadDrawingLocal() }

                Spacer()

                Button("Save(Photos)") { saveMergedToPhotos() }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func modeButton(_ title: String, _ mode: InteractionMode) -> some View {
        Button {
            interactionMode = mode
        } label: {
            Text(title)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(interactionMode == mode ? Color.blue.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
