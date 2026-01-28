import DrawingKit
import SwiftUI

extension OperationScreen {

    @ViewBuilder
    var phoneBottomBarLayer: some View {
        safeAreaBottomBar
    }

    private var safeAreaBottomBar: some View {
        VStack { Spacer() }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {

                    // ✅ モード切替（これが無いと描画できない）
                    Button {
                        interactionMode = .normal
                    } label: {
                        Label("通常", systemImage: "hand.draw")
                    }
                    .foregroundStyle(interactionMode == .normal ? .blue : .secondary)

                    Button {
                        interactionMode = .drawing
                    } label: {
                        Label("描画", systemImage: "pencil.tip")
                    }
                    .foregroundStyle(interactionMode == .drawing ? .blue : .secondary)

                    Divider().frame(height: 18)

                    Button {
                        presentedPanel = .drawing
                    } label: {
                        Label("設定", systemImage: "slider.horizontal.3")
                    }

                    Button {
                        presentedPanel = .rectList
                    } label: {
                        Label("一覧", systemImage: "square.stack")
                    }

                    Spacer()

                    Button {
                        saveMergedToPhotos()
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
    }

    // ✅ iPhone sheet router
    @ViewBuilder
    func phoneSheet(for route: PanelRoute) -> some View {
        switch route {

        case .drawing:
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .presentationDetents([.medium, .large])

        case .rectList:
            rectListPanelContent
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .presentationDetents([.medium, .large])

        case .unconfirmedParts:
            UnconfirmedPartsPanelView(
                rects: overlayRects.filter { !$0.isHidden && !$0.isChecked },
                selectedRectIDs: $selectedRectIDs,
                onZoom: { rect in
                    let c = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
                    zoomRequest = .set(
                        scale: max(viewportState.scale, 2.0),
                        centerInImage: c
                    )
                },
                onCameraCheckback: { selectedRects in
                    print("camera checkback selected:", selectedRects.count)
                }
            )
            .presentationDetents([.large])
        }
    }
}
