import SwiftUI
import DrawingKit

struct UnconfirmedPartsPanelView: View {

    let rects: [CanvasRect]                 // 表示対象（OperationScreen側でフィルタして渡す）
    @Binding var selectedRectIDs: Set<UUID> // OperationScreenの選択と直結

    var onZoom: (CanvasRect) -> Void = { _ in }
    var onCameraCheckback: (_ selected: [CanvasRect]) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {

            headerRow

            ScrollView {
                VStack(spacing: 0) {
                    if rects.isEmpty {
                        Text("未確認の項目がありません")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(rects) { rect in
                            row(rect)
                            Divider().opacity(0.25)
                        }
                    }
                }
            }

            if !selectedRectIDs.isEmpty {
                Button {
                    let selected = rects.filter { selectedRectIDs.contains($0.id) }
                    onCameraCheckback(selected)
                } label: {
                    Text("カメラチェックバック")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.black)
                .background(Color.green.opacity(0.65))
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("count: \(rects.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !selectedRectIDs.isEmpty {
                Button("全解除") { selectedRectIDs.removeAll() }
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private func row(_ rect: CanvasRect) -> some View {
        let isSelected = selectedRectIDs.contains(rect.id)

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rect.externalID ?? (rect.name.isEmpty ? "（名称未設定）" : rect.name))
                    .font(.body)
                    .lineLimit(1)

                if let ext = rect.externalID, !rect.name.isEmpty {
                    Text(rect.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                toggle(rect.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.square" : "square")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            onZoom(rect) // 行タップはズーム
        }
    }

    private func toggle(_ id: UUID) {
        if selectedRectIDs.contains(id) {
            selectedRectIDs.remove(id)
        } else {
            selectedRectIDs.insert(id)
        }
    }
}
