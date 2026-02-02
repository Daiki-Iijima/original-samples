import SwiftUI
import DrawingKit


extension OperationScreen {
    @ViewBuilder
    func phoneSheet(for route: PanelRoute) -> some View {
        switch route {
        case .drawingTools:
            VStack{
                // 描画ツール選択：普通のシート
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
            }
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)

        case .unconfirmedParts:
            // 未確認部材一覧：出たままでいじれる系（detentsで半常駐っぽく）
            VStack(spacing: 0) {
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
                    onCameraCheckback: { _ in },
                    onOpenProject: { pid, rect in
                        openProject(projectID: pid, zoomRect: rect)
                    }
                )
                .padding(2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(2)
                .presentationDetents([.fraction(0.35)])
            }
            .presentationDetents([.fraction(0.35)])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
        case .memo:
            VStack{
                MemoPanelView(
                    text: $memoText,
                    onSave: { /*saveMemo(text: memoText);*/ presentedPanel = nil },
                    onDiscard: { memoText = ""; presentedPanel = nil }
                )
                .padding(2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(2)
                .presentationDetents([.fraction(0.35)])
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .linkProjects:
            // リンクプロジェクト：普通のシート（リスト）
            VStack{
                LinkProjectsPanelView(
                    items: SampleData.linkProjects,
                    onTap: { item in
                        openProject(projectID: item.id, zoomRect: nil)
                        presentedPanel = nil
                    }
                )
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(6)
                .presentationDetents([.fraction(0.35)])
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
