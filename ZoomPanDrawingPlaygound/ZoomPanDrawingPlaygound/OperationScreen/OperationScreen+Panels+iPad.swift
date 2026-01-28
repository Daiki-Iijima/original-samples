import DrawingKit
import SwiftUI

extension OperationScreen {

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
    var unconfirmedPartsPanelLayer: some View {
        if isUnconfirmedPartsVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .rectList, // 専用kindが無いなら一旦これでOK（できれば .unconfirmed を増やす）
                    containerSize: proxy.size,
                    width: unconfirmedPartsPanelWidth,
                    margin: 12,
                    headerHeight: 44,
                    title: "未確認部材一覧",
                    onClose: { isUnconfirmedPartsVisible = false },
                    trailing: { AnyView(EmptyView()) },
                    position: $unconfirmedPartsPanelPos ,
                    didInitPosition: $didInitUnconfirmedPartsPanelPos
                ) {
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
                    .frame(
                        minHeight: proxy.size.height * 2.0 / 3.0
                    )
                }
            }
            .ignoresSafeArea()
        }
    }

}
