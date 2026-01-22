import DrawingKit
import SwiftUI

extension OperationScreen {

    // モード別の小パネル（zoomPreset / rectPreset）
    @ViewBuilder
    var modePanelLayer: some View {
        if interactionMode == .zoomPreset {
            VStack {
                zoomPresetPanel
                Spacer()
            }
            .padding()
        } else if interactionMode == .rectPreset {
            VStack {
                rectPresetPanel
                Spacer()
            }
            .padding()
        }
    }

    // 描画パネル（drawing のときだけ表示）
    @ViewBuilder
    var drawingPanelLayer: some View {
        if interactionMode == .drawing {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .drawing,
                    containerSize: proxy.size,
                    width: panelWidth,
                    margin: 12,
                    headerHeight: 44,
                    title: "書き込みモード",
                    onClose: { interactionMode = .normal },
                    trailing: { AnyView(EmptyView()) },
                    position: $panelPos,
                    didInitPosition: $didInitPanelPos
                ) {
                    DrawingModePanel(
                        drawMode: toolBinding,
                        stampKind: stampKindBinding,
                        color: activeColorBinding,
                        lineWidth: activeSizeBinding,
                        opacity: activeOpacityBinding,
                        eraserRadius: eraserRadiusBinding,
                        onUndo: { canvas?.undo() },
                        onRedo: { canvas?.redo() },
                        onSave: { saveMergedToPhotos() }
                    )
                    .padding(.horizontal, 12)
                }
            }
            .ignoresSafeArea()
        }
    }

    // Rect一覧パネル
    //  1つでも選択されていたら表示する
    @ViewBuilder
    var rectListPanelLayer: some View {
        if isRectListVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .rectList,
                    containerSize: proxy.size,
                    width: rectListPanelWidth,
                    margin: 12,
                    headerHeight: 44,
                    title: "Rect一覧（overlay）",
                    onClose: { isRectListVisible = false },
                    trailing: { AnyView(EmptyView()) },
                    position: $rectListPanelPos,
                    didInitPosition: $didInitRectListPanelPos
                ) {
                    rectListPanelContent
                        .padding(.horizontal, 12)
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    var selectedRectPanelLayer: some View {
        if !selectedRectIDs.isEmpty {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .selection,
                    containerSize: proxy.size,
                    width: selectionPanelWidth,
                    margin: 12,
                    headerHeight: 44,
                    title: "選択中",
                    onClose: { selectedRectIDs.removeAll() },  // ✅ 閉じる＝選択解除
                    trailing: { AnyView(EmptyView()) },
                    position: $selectionPanelPos,
                    didInitPosition: $didInitSelectionPanelPos
                ) {
                    selectedRectPanelContent
                        .padding(.horizontal, 12)
                }
            }
            .ignoresSafeArea()
        }
    }

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
                    // ✅ 複数なら「平均中心」へ寄せる（とりあえず）
                    let union =
                        selectedRects
                        .map(\.rect)
                        .reduce(CGRect.null) { $0.union($1) }
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
                selectedRectIDs.remove(rect.id)  // ✅ 0になればパネルが勝手に消える
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // タップでZoomとかにしてもいい（好み）
            let c = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
            zoomRequest = .set(scale: max(viewportState.scale, 2.0), centerInImage: c)
        }
    }
}
