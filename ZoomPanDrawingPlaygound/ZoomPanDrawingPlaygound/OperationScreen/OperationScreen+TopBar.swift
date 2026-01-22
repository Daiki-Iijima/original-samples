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

                if interactionMode != .normal {
                    Button {
                        emphasizeNormalMode()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .background(Color.black.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                modeButton("Normal", .normal)
                modeButton("描画", .drawing)
                modeButton("Zoom指定", .zoomPreset)
                modeButton("Rect追加", .rectPreset)
                Button {
                    isRectListVisible.toggle()
                } label: {
                    Text("Rect一覧")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(isRectListVisible ? Color.blue.opacity(0.25) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Spacer()

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

    /// Normal に戻るときの共通処理（お好みでここを増やせる）
    func emphasizeNormalMode() {
        interactionMode = .normal
    }
}
