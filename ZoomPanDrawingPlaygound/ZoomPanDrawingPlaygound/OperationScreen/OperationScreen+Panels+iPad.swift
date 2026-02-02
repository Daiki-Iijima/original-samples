import DrawingKit
import SwiftUI

extension OperationScreen {

    @ViewBuilder
    var drawingSettingPanelLayer: some View {
        if interactionMode == .drawing && isDrawingSettingsPanelVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .drawing,
                    containerSize: proxy.size,
                    width: panelWidth,
                    margin: 12,
                    headerHeight: 44,
                    title: "ツール選択",
                    onClose: { isDrawingSettingsPanelVisible = false },
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
    var unconfirmedPartsPanelLayer: some View {
        if isUnconfirmedPartsVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .unconfirmedParts,
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
                        onCameraCheckback: { selected in
                            // 必要なら
                        },
                        onOpenProject: { pid,rect in
                            openProject(projectID: pid,zoomRect: rect)
                        },
                    )
                    .frame(
                        minHeight: proxy.size.height * 2.0 / 3.0
                    )
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    var memoPanelLayer: some View {
        if isMemoVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .memo,
                    containerSize: proxy.size,
                    width: memoPanelWidth,
                    margin: 12,
                    headerHeight: 44,
                    title: "メモ",
                    onClose: { isMemoVisible = false },
                    trailing: { AnyView(EmptyView()) },
                    position: $memoPanelPos,
                    didInitPosition: $didInitMemoPanelPos
                ) {
                    MemoPanelView(
                        text: $memoText,
                        onSave: { /*saveMemo(text: memoText)*/ },
                        onDiscard: { memoText = "" ; isMemoVisible = false }
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    var linkProjectsPanelLayer: some View {
        if isLinkProjectsVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .linkProjects,
                    containerSize: proxy.size,
                    width: linkProjectsPanelWidth,
                    margin: 12,
                    headerHeight: 50,
                    title: "リンクプロジェクトリスト",
                    onClose: { isLinkProjectsVisible = false },
                    trailing: { AnyView(EmptyView()) },
                    position: $linkProjectsPos,
                    didInitPosition: $didInitLinkProjectsPanelPos
                ) {
                    LinkProjectsPanelView(items: SampleData.linkProjects){selectedProject in
                        openProject(projectID: selectedProject.id, zoomRect: nil)
                    }
                    .frame(
                        minHeight: proxy.size.height * 2.0 / 4.0
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
    
}
