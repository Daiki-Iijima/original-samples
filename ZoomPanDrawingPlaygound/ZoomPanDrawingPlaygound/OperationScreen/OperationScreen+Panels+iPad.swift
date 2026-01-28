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
                    onClose: { selectedRectIDs.removeAll() },
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
}
