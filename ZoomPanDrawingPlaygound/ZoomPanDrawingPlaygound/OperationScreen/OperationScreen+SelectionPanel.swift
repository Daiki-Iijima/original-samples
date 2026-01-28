import DrawingKit
import SwiftUI

extension OperationScreen {

    var selectedRectPanelContent: some View {
        let selectedRects = overlayRects.filter { selectedRectIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: 10) {

            Text("selected: \(selectedRects.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(selectedRects) { rect in
                        selectedRectRow(rect)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 120, maxHeight: 260)

            Divider().opacity(0.2)

            HStack {
                Button("全解除") { selectedRectIDs.removeAll() }

                Spacer()

                Button("Zoom") {
                    let union = selectedRects.map(\.rect).reduce(CGRect.null) { $0.union($1) }
                    guard !union.isNull else { return }
                    let c = CGPoint(x: union.midX, y: union.midY)
                    zoomRequest = .set(scale: max(viewportState.scale, 2.0), centerInImage: c)
                }
            }
        }
    }

    @ViewBuilder
    func selectedRectRow(_ rect: CanvasRect) -> some View {
        HStack(spacing: 8) {
            Text(rect.name.isEmpty ? "（名称未設定）" : rect.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            Button("解除") {
                selectedRectIDs.remove(rect.id)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let c = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
            zoomRequest = .set(scale: max(viewportState.scale, 2.0), centerInImage: c)
        }
    }
}
