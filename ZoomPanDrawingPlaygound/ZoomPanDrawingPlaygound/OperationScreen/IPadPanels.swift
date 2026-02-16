import SwiftUI
import DrawingKit
import UIKit

struct IPadPanels: View {
    struct VisiblePanels: OptionSet {
        let rawValue: Int
        static let drawing       = VisiblePanels(rawValue: 1 << 0)
        static let unconfirmed   = VisiblePanels(rawValue: 1 << 1)
        static let memo          = VisiblePanels(rawValue: 1 << 2)
        static let linkProjects  = VisiblePanels(rawValue: 1 << 3)
        static let checkback     = VisiblePanels(rawValue: 1 << 4)

        static let `default`: VisiblePanels = [.drawing, .unconfirmed, .memo, .linkProjects]
    }
    
    let visiblePanels: VisiblePanels
    
    //  MARK: - 外部から受け取る
    @ObservedObject var store: OperationStore
    @Binding var canvas: DrawingCanvasView?

    // 操作系はクロージャで注入（Panelsはルールを持たない）
    let openProject: (_ projectID: String, _ zoomRect: CanvasRect?) -> Void
    let setUnconfirmedPartsVisible: (_ visible: Bool) -> Void
    let saveMergedToPhotos: (_ currentLoadedImage: LoadedImage) -> Void
    let selectedRectsAction: (_ selectedPipeRects: [CanvasRect]) -> Void

    var body: some View {
            Group {
                if visiblePanels.contains(.drawing) { drawingSettingPanelLayer }

                if visiblePanels.contains(.checkback) {
                    checkbackPartsPanelLayer
                } else if visiblePanels.contains(.unconfirmed) {
                    unconfirmedPartsPanelLayer
                }

                if visiblePanels.contains(.memo) { memoPanelLayer }
                if visiblePanels.contains(.linkProjects) { linkProjectsPanelLayer }
            }
        }
    @ViewBuilder
    private var drawingSettingPanelLayer: some View {
        if store.interactionMode == .drawing && store.isDrawingSettingsPanelVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .drawing,
                    containerSize: proxy.size,
                    width: CGFloat(store.config.panels.drawingTools),
                    margin: 12,
                    headerHeight: 44,
                    title: "ツール選択",
                    onClose: { store.isDrawingSettingsPanelVisible = false },
                    isShowCloseButton: true,
                    trailing: { AnyView(EmptyView()) },
                    position: $store.panelPos,
                    didInitPosition: $store.didInitPanelPos
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
                        onSave: { saveMergedToPhotos(store.currentLoadedImage) }
                    )
                    .padding(.horizontal, 12)
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var unconfirmedPartsPanelLayer: some View {
        if store.isUnconfirmedPartsVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .unconfirmedParts,
                    containerSize: proxy.size,
                    width: CGFloat(store.config.panels.unconfirmedParts),
                    margin: 12,
                    headerHeight: 44,
                    title: "未確認部材一覧",
                    onClose: { setUnconfirmedPartsVisible(false) },
                    isShowCloseButton: true,
                    trailing: { AnyView(EmptyView()) },
                    position: $store.unconfirmedPartsPanelPos,
                    didInitPosition: $store.didInitUnconfirmedPartsPanelPos
                ) {
                    UnconfirmedPartsPanelView(
                        rects: store.renderingRects.filter { !$0.isHidden && !$0.isChecked },
                        selectedRectIDs: $store.selectedRectIDs,
                        mode: .review,
                        actionButtonText: "カメラチェックバック",
                        checkingPipeIDs: store.checkingPipeIDs,
                        onZoom: { rect in
                            let c = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
                            store.zoomRequest = .set(
                                scale: max(store.viewportState.scale, 2.0),
                                centerInImage: c
                            )
                        },
                        onTapActionButtn: { items in
                            selectedRectsAction(items)
                        },
                        onOpenProject: { pid, rect in openProject(pid, rect) }
                    )
                    .frame(minHeight: proxy.size.height * 2.0 / 3.0)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    public var checkbackPartsPanelLayer: some View {
        GeometryReader { proxy in
            CommonFloatingPanel(
                kind: .unconfirmedParts,
                containerSize: proxy.size,
                width: CGFloat(store.config.panels.unconfirmedParts),
                margin: 12,
                headerHeight: 44,
                title: "チェックバック",
                onClose: { setUnconfirmedPartsVisible(false) },
                isShowCloseButton: false,
                trailing: { AnyView(EmptyView()) },
                position: $store.unconfirmedPartsPanelPos,
                didInitPosition: $store.didInitUnconfirmedPartsPanelPos
            ) {
                UnconfirmedPartsPanelView(
                    rects: store.checkbackPanelRects,
                    selectedRectIDs: $store.selectedRectIDs,
                    mode: .checkbackSelect,
                    actionButtonText: "チェックバック実行",
                    checkingPipeIDs: store.checkingPipeIDs,
                    onZoom: { rect in
                        let c = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
                        store.zoomRequest = .set(
                            scale: max(store.viewportState.scale, 2.0),
                            centerInImage: c
                        )
                    },
                    onTapActionButtn: { canvasRects in
                        selectedRectsAction(canvasRects)
                    },
                    onOpenProject: { pid, rect in openProject(pid, rect) }
                )
                .frame(minHeight: proxy.size.height * 2.0 / 3.0)
            }
        }
    }

    @ViewBuilder
    private var memoPanelLayer: some View {
        if store.isMemoVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .memo,
                    containerSize: proxy.size,
                    width: CGFloat(store.config.panels.memo),
                    margin: 12,
                    headerHeight: 44,
                    title: "メモ",
                    onClose: { store.isMemoVisible = false },
                    isShowCloseButton: true,
                    trailing: { AnyView(EmptyView()) },
                    position: $store.memoPanelPos,
                    didInitPosition: $store.didInitMemoPanelPos
                ) {
                    MemoPanelView(
                        text: $store.memoText,
                        onSave: { /* saveMemo */ },
                        onDiscard: { store.memoText = ""; store.isMemoVisible = false }
                    )
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var linkProjectsPanelLayer: some View {
        if store.isLinkProjectsVisible {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .linkProjects,
                    containerSize: proxy.size,
                    width: CGFloat(store.config.panels.linkProjects),
                    margin: 12,
                    headerHeight: 50,
                    title: "リンクプロジェクトリスト",
                    onClose: { store.isLinkProjectsVisible = false },
                    isShowCloseButton: true,
                    trailing: { AnyView(EmptyView()) },
                    position: $store.linkProjectsPos,
                    didInitPosition: $store.didInitLinkProjectsPanelPos
                ) {
                    LinkProjectsPanelView(items: store.linkProjectItems) { selected in
                        openProject(selected.id, nil)
                    }
                    .frame(minHeight: proxy.size.height * 2.0 / 4.0)
                }
            }
            .ignoresSafeArea()
        }
    }
}


//  MARK: - DrawingSetting(お絵描き機能)のパラメータを単体で変更できるバインディングを作成する
//  変更対象のDrawingSettingはStoreに入っている
extension IPadPanels{
    var toolBinding: Binding<DrawMode> {
        Binding(
            get: { store.drawingSettings.tool },
            set: { store.drawingSettings.tool = $0 }
        )
    }

    var stampKindBinding: Binding<StampKind> {
        Binding(
            get: { store.drawingSettings.stamp.kind },
            set: { store.drawingSettings.stamp.kind = $0 }
        )
    }

    /// 「今アクティブな色」
    /// - stamp中は stamp.color
    /// - それ以外は pen.color
    var activeColorBinding: Binding<Color> {
        Binding(
            get: {
                switch store.drawingSettings.tool {
                case .stamp:
                    return store.drawingSettings.stamp.color
                default:
                    return store.drawingSettings.pen.color
                }
            },
            set: { newValue in
                switch store.drawingSettings.tool {
                case .stamp:
                    store.drawingSettings.stamp.color = newValue
                default:
                    store.drawingSettings.pen.color = newValue
                }
            }
        )
    }

    /// 「今アクティブなサイズ」
    /// - stamp中は stamp.size
    /// - それ以外は pen.width
    var activeSizeBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch store.drawingSettings.tool {
                case .stamp:
                    return store.drawingSettings.stamp.size
                default:
                    return store.drawingSettings.pen.width
                }
            },
            set: { newValue in
                switch store.drawingSettings.tool {
                case .stamp:
                    store.drawingSettings.stamp.size = newValue
                default:
                    store.drawingSettings.pen.width = newValue
                }
            }
        )
    }

    /// 「今アクティブな不透明度」
    /// - stamp中は stamp.opacity
    /// - それ以外は pen.opacity
    var activeOpacityBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch store.drawingSettings.tool {
                case .stamp:
                    return store.drawingSettings.stamp.opacity
                default:
                    return store.drawingSettings.pen.opacity
                }
            },
            set: { newValue in
                switch store.drawingSettings.tool {
                case .stamp:
                    store.drawingSettings.stamp.opacity = newValue
                default:
                    store.drawingSettings.pen.opacity = newValue
                }
            }
        )
    }

    var eraserRadiusBinding: Binding<CGFloat> {
        Binding(
            get: { store.drawingSettings.eraser.radius },
            set: { store.drawingSettings.eraser.radius = $0 }
        )
    }
}
