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

                Button("全解除") {
                    selectedRectIDs.removeAll()
                }

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

        VStack(alignment: .leading, spacing: 6) {

            HStack(alignment: .center, spacing: 8) {

                // name（メイン）
                Text(rect.name.isEmpty ? "（名称未設定）" : rect.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                    .lineLimit(1)
                    .opacity(rect.isHidden ? 0.4 : 1.0)

                if rect.isChecked {
                    Text("✓")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                if rect.isHidden {
                    Text("非表示")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Spacer()

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

            // サブ情報（外部ID + 座標）
            HStack(spacing: 8) {
                if let ext = rect.externalID {
                    Text(ext)
                }

                Text(rectSummary(rect.rect))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider().opacity(0.2)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        // ✅ 非表示・チェック済みはタップ無効にしたいならここで弾く
        .onTapGesture {
            guard !rect.isHidden && !rect.isChecked else { return }

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
}
