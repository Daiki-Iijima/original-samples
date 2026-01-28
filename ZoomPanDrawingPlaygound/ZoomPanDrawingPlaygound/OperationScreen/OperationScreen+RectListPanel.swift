import DrawingKit
import SwiftUI

extension OperationScreen {

    var rectListPanelContent: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("count: \(overlayRects.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("全部クリア") {
                    overlayRects.removeAll()
                    selectedRectIDs.removeAll()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if overlayRects.isEmpty {
                        Text("Rectがありません")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(overlayRects.enumerated()), id: \.element.id) { index, item in
                            rectRow(index: index, rect: item)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 200, maxHeight: 400)
        }
    }

    @ViewBuilder
    func rectRow(index: Int, rect: CanvasRect) -> some View {
        let isSelected = selectedRectIDs.contains(rect.id)
        let isDisabled = rect.isHidden || rect.isChecked

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {

                Text(rect.name.isEmpty ? "（名称未設定）" : rect.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                    .lineLimit(1)
                    .opacity(isDisabled ? 0.45 : 1.0)

                Spacer()

                if rect.isHidden {
                    Text("非表示")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                if rect.isChecked {
                    Text("確認済")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }

                Button("Zoom") {
                    let center = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
                    let targetScale = max(viewportState.scale, 2.0)
                    zoomRequest = .set(scale: targetScale, centerInImage: center)
                }

                Button(role: .destructive) {
                    overlayRects.removeAll { $0.id == rect.id }
                    selectedRectIDs.remove(rect.id)
                } label: {
                    Image(systemName: "trash")
                }
            }

            HStack(spacing: 8) {
                if let ext = rect.externalID {
                    Text(ext)
                }
                Text(rectSummary(rect.rect))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // ✅ 一覧側操作（表示/チェックのトグルを入れたいならここに追加しやすい）
            HStack(spacing: 10) {
                Button(rect.isHidden ? "表示" : "非表示") {
                    toggleHidden(rectID: rect.id)
                }
                Button(rect.isChecked ? "未確認" : "確認済") {
                    toggleChecked(rectID: rect.id)
                }
                Spacer()
            }
            .font(.caption.weight(.semibold))

            Divider().opacity(0.2)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            // ✅ 非表示/確認済はタップで選択させない
            guard !isDisabled else { return }

            if isSelected {
                selectedRectIDs.remove(rect.id)
            } else {
                selectedRectIDs.insert(rect.id)
            }
        }
    }

    func rectSummary(_ r: CGRect) -> String {
        String(
            format: "x: %.1f  y: %.1f  w: %.1f  h: %.1f",
            r.origin.x, r.origin.y, r.size.width, r.size.height)
    }

    // MARK: - list operations

    func toggleHidden(rectID: UUID) {
        guard let idx = overlayRects.firstIndex(where: { $0.id == rectID }) else { return }
        overlayRects[idx].isHidden.toggle()

        // 非表示にしたら選択も解除（仕様）
        if overlayRects[idx].isHidden {
            selectedRectIDs.remove(rectID)
        }
    }

    func toggleChecked(rectID: UUID) {
        guard let idx = overlayRects.firstIndex(where: { $0.id == rectID }) else { return }
        overlayRects[idx].isChecked.toggle()

        // 確認済にしたら選択も解除（仕様）
        if overlayRects[idx].isChecked {
            selectedRectIDs.remove(rectID)
        }
    }
}
