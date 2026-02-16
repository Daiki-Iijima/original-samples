import SwiftUI
import DrawingKit
import UIKit

/// iPhone の `.sheet(item:)` で出す中身をまとめるView
/// - OperationScreen の extension に散らばるのを避ける
/// - store を起点に Binding を組み立てて、呼び出し側の引数を減らす
struct IPhoneSheets: View {

    // MARK: - Inputs
    let route: PanelRoute

    @ObservedObject var store: OperationStore
    @Binding var canvas: DrawingCanvasView?

    /// 「写真へ保存」だけはキャンバス合成の都合で外から注入（ルールをここに持たせない）
    let saveMergedToPhotos: (_ currentLoadedImage: LoadedImage) -> Void


    // MARK: - Body
    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch route {

        case .drawingTools:
            VStack {
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
            }
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)

        case .unconfirmedParts:
            VStack(spacing: 0) {
                UnconfirmedPartsPanelView(
                    rects: store.renderingRects.filter { !$0.isHidden && !$0.isChecked },
                    selectedRectIDs: $store.selectedRectIDs,
                    mode: .review,
                    actionButtonText: "カメラチャックバック",
                    checkingPipeIDs: store.checkingPipeIDs,
                    onZoom: { rect in
                        let c = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
                        store.zoomRequest = .set(
                            scale: max(store.viewportState.scale, 2.0),
                            centerInImage: c
                        )
                    },
                    onTapActionButtn: { _ in },
                    onOpenProject: { pid, rect in
                        store.openProject(projectID: pid, zoomRect: rect)
                        store.presentedPanel = nil
                    }
                )
                .padding(2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(2)
            }
            .presentationDetents([.fraction(0.35)])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)

        case .memo:
            VStack {
                MemoPanelView(
                    text: $store.memoText,
                    onSave: { store.presentedPanel = nil },
                    onDiscard: {
                        store.memoText = ""
                        store.presentedPanel = nil
                    }
                )
                .padding(2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(2)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .linkProjects:
            VStack {
                LinkProjectsPanelView(
                    items: store.linkProjectItems,
                    onTap: { item in
                        store.openProject(projectID: item.id, zoomRect: nil)
                        store.presentedPanel = nil
                    }
                )
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(6)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

//  MARK: - DrawingSetting(お絵描き機能)のパラメータを単体で変更できるバインディングを作成する
//  変更対象のDrawingSettingはStoreに入っている
extension IPhoneSheets {
    private var toolBinding: Binding<DrawMode> {
        Binding(
            get: { store.drawingSettings.tool },
            set: { store.drawingSettings.tool = $0 }
        )
    }

    private var stampKindBinding: Binding<StampKind> {
        Binding(
            get: { store.drawingSettings.stamp.kind },
            set: { store.drawingSettings.stamp.kind = $0 }
        )
    }

    private var activeColorBinding: Binding<Color> {
        Binding(
            get: {
                switch store.drawingSettings.tool {
                case .stamp: return store.drawingSettings.stamp.color
                default:     return store.drawingSettings.pen.color
                }
            },
            set: { newValue in
                switch store.drawingSettings.tool {
                case .stamp: store.drawingSettings.stamp.color = newValue
                default:     store.drawingSettings.pen.color = newValue
                }
            }
        )
    }

    private var activeSizeBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch store.drawingSettings.tool {
                case .stamp: return store.drawingSettings.stamp.size
                default:     return store.drawingSettings.pen.width
                }
            },
            set: { newValue in
                switch store.drawingSettings.tool {
                case .stamp: store.drawingSettings.stamp.size = newValue
                default:     store.drawingSettings.pen.width = newValue
                }
            }
        )
    }

    private var activeOpacityBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch store.drawingSettings.tool {
                case .stamp: return store.drawingSettings.stamp.opacity
                default:     return store.drawingSettings.pen.opacity
                }
            },
            set: { newValue in
                switch store.drawingSettings.tool {
                case .stamp: store.drawingSettings.stamp.opacity = newValue
                default:     store.drawingSettings.pen.opacity = newValue
                }
            }
        )
    }

    private var eraserRadiusBinding: Binding<CGFloat> {
        Binding(
            get: { store.drawingSettings.eraser.radius },
            set: { store.drawingSettings.eraser.radius = $0 }
        )
    }
}
